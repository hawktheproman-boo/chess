"""Store art for CHESS?? (vault Design/Store Art), rendered in Blender from the game's own models.

Run inside Blender:
    exec(open(r"C:\\Users\\liter\\Documents\\CLAUDE\\chess\\art\\store\\make_store.py").read())
    make_icon(); render_icon()                     # -> art/store/out/icon_render.png (1024 x 1024)
    make_hero(); render_hero()                     # -> art/store/out/hero_render.png (1920 x 1080)
Then art/store/finish_icon.py adds the "??" tag and writes the 512 x 512 upload, and
art/store/finish_hero.py adds the CHESS?? title to the hero thumbnail.

The icon: the white Classic bishop, three-quarter view, the Snipe rifle floating in front of it and
aimed out to the left, its scope glowing red and a red laser running off the frame; a few dark board
squares under it and a red glow fading to black behind. Blender units are studs, Z up, the pieces'
front towards -Y (as in make_sets.py / make_rifle.py, whose builders are reused here).
"""
import bpy
import math
import os
from mathutils import Vector, Euler

ART = r"C:\Users\liter\Documents\CLAUDE\chess\art"
exec(open(os.path.join(ART, "pieces", "make_sets.py")).read())
exec(open(os.path.join(ART, "props", "make_rifle.py")).read())  # (sets OUT to props: overridden below)
OUT = os.path.join(ART, "store", "out")
VFX = os.path.join(ART, "vfx")


def _mat(name, base, rough=0.4, metal=0.0, emit=None, strength=0.0, coat=0.0, alpha=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*base, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Coat Weight"].default_value = coat
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m


def _assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def _emission_plane(name, size, loc, rot, col, color, strength, image=None, alpha_from_image=True):
    """A flat glowing card (optionally a white-on-transparent VFX texture tinted `color`)."""
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], 1)
    for c in o.users_collection:
        c.objects.unlink(o)
    col.objects.link(o)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1)
    em.inputs["Strength"].default_value = strength
    if image:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(image, check_existing=True)
        mix = nt.nodes.new("ShaderNodeMixShader")
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        nt.links.new(tex.outputs["Alpha" if alpha_from_image else "Color"], mix.inputs["Fac"])
        nt.links.new(tr.outputs[0], mix.inputs[1])
        nt.links.new(em.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
    else:
        nt.links.new(em.outputs[0], out.inputs["Surface"])
    o.data.materials.append(m)
    return o


def make_icon():
    scene = bpy.context.scene
    # a clean slate for the icon (keeps nothing else in the render)
    for c in list(scene.collection.children):
        c.hide_render = True
    col = _collection("Icon")
    col.hide_render = False

    # --- the bishop (Classic set, as in the game) ------------------------------------------------
    bishop = classic_b(col)
    bishop.name = "Bishop"
    _assign(bishop, _mat("IconIvory", (0.93, 0.91, 0.86), rough=0.28, coat=0.6))

    # --- the rifle: built by make_rifle() into its own collection, then moved into the icon ------
    make_rifle()
    rifle_col = bpy.data.collections["Rifle"]
    looks = {"Stock": _mat("IconWood", (0.1, 0.04, 0.016), rough=0.35, coat=0.5),
             "Metal": _mat("IconGunmetal", (0.05, 0.05, 0.058), rough=0.3, metal=0.9),
             "Bolt": _mat("IconSteel", (0.55, 0.55, 0.58), rough=0.25, metal=1.0),
             "Lens": _mat("IconLens", (1.0, 0.1, 0.08), rough=0.1, emit=(1.0, 0.08, 0.05), strength=12)}
    gun = bpy.data.objects.new("Gun", None)
    col.objects.link(gun)
    for o in list(rifle_col.objects):
        rifle_col.objects.unlink(o)
        col.objects.link(o)
        if o.name.split(".")[0] in looks:
            _assign(o, looks[o.name.split(".")[0]])
        o.parent = gun
    rifle_col.hide_render = True
    # floating at the bishop's chest, in front of it, the muzzle (-Y in the rifle) aimed left and a
    # touch towards the camera; slightly canted like a hero pose
    gun.location = (-0.32, -0.8, 1.0)
    aim = Vector((-1.0, -0.62, 0.05)).normalized()
    gun.rotation_euler = aim.to_track_quat("-Y", "Z").to_euler()
    gun.rotation_euler.rotate(Euler((0, math.radians(-10), 0)))
    gun.scale = (1.05, 1.05, 1.05)
    bpy.context.view_layer.update()

    # --- the laser: from the scope, out of the frame to the left ----------------------------------
    scope_front = gun.matrix_world @ Vector((0, -0.36, 0.17))
    far = scope_front + aim * 9.0
    mid = (scope_front + far) / 2
    laser = cyl("Laser", 0.012, tuple(scope_front), tuple(far), col, seg=8)
    _assign(laser, _mat("IconLaser", (1, 0.1, 0.06), emit=(1.0, 0.06, 0.04), strength=40))
    glint = _emission_plane("Glint", (0.75, 0.75), tuple(scope_front + aim * 0.02), (0, 0, 0), col,
                            (1.0, 0.25, 0.18), 18, image=os.path.join(VFX, "star.png"))
    # the glint faces the camera (set after the camera exists, below)

    # --- the floor: a few dark board squares fading out -------------------------------------------
    dark = _mat("IconSqDark", (0.015, 0.012, 0.012), rough=0.6)
    light = _mat("IconSqLight", (0.09, 0.02, 0.02), rough=0.6)
    s = 1.4
    for i in range(-2, 3):
        for j in range(-2, 3):
            sq = box("Sq", (s * 0.995, s * 0.995, 0.1), (i * s, j * s, -0.05), col)
            _assign(sq, light if (i + j) % 2 == 0 else dark)

    # --- the background: a red glow behind the bishop, fading to black ----------------------------
    # (centred where the camera's line through the bishop meets it, so the glow sits behind the bishop)
    bg = _emission_plane("Backdrop", (30, 30), (-2.9, 6.0, 1.3), (math.radians(90), 0, 0), col, (1, 1, 1), 1)
    nt = bg.data.materials[0].node_tree
    em = [n for n in nt.nodes if n.type == "EMISSION"][0]
    grad = nt.nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    mapping = nt.nodes.new("ShaderNodeMapping")
    k = 5.5  # UV 0..1 -> centred on the plane, fading to black towards the frame's corners
    mapping.inputs["Scale"].default_value = (k, k, k)
    mapping.inputs["Location"].default_value = (-0.5 * k, -0.5 * k, 0)
    coord = nt.nodes.new("ShaderNodeTexCoord")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 1)
    ramp.color_ramp.elements[0].position = 0.25
    ramp.color_ramp.elements[1].color = (0.85, 0.05, 0.03, 1)
    ramp.color_ramp.elements[1].position = 0.9
    nt.links.new(coord.outputs["UV"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs[0], grad.inputs["Vector"])
    nt.links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    em.inputs["Strength"].default_value = 1.3

    # --- camera and lights --------------------------------------------------------------------------
    cam = bpy.data.objects.get("IconCam") or bpy.data.objects.new("IconCam", bpy.data.cameras.new("IconCam"))
    if cam.name not in col.objects:
        col.objects.link(cam)
    # draft 2: a tighter crop, so the bishop and the rifle fill the icon at phone size (150 px)
    cam.data.lens = 75
    cam.location = (2.3, -4.6, 1.55)
    target = Vector((-0.3, -0.35, 0.92))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    glint.rotation_euler = (cam.location - glint.location).to_track_quat("Z", "Y").to_euler()

    def area(name, loc, look, energy, color, size):
        l = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        col.objects.link(l)
        l.data.energy = energy
        l.data.color = color
        l.data.size = size
        l.location = loc
        l.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        return l
    area("Key", (3.2, -3.0, 3.6), (0, 0, 1.0), 420, (1.0, 0.93, 0.85), 2.5)
    area("Rim", (-2.6, 2.4, 2.4), (0, 0, 1.1), 900, (1.0, 0.18, 0.12), 1.5)
    area("RimR", (2.4, 2.2, 2.0), (0, 0, 1.0), 300, (1.0, 0.35, 0.25), 1.5)
    area("Fill", (-1.5, -4.0, 1.6), (0, 0, 1.0), 45, (0.7, 0.75, 1.0), 3)

    scene.world = scene.world or bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0, 0, 0, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.0
    return {"objects": len(col.objects)}


def _setup_look(samples):
    """EEVEE, AgX Punchy and a compositor bloom: shared by every store render."""
    scene = bpy.context.scene
    os.makedirs(OUT, exist_ok=True)
    scene.render.engine = "BLENDER_EEVEE"
    try:
        scene.eevee.taa_render_samples = samples
    except Exception:
        pass
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Punchy"
    # bloom through the compositor (a Glare node)
    scene.use_nodes = True
    tree = scene.node_tree if hasattr(scene, "node_tree") and scene.node_tree else None
    if tree is None and hasattr(scene, "compositing_node_group"):
        tree = scene.compositing_node_group or bpy.data.node_groups.new("IconComp", "CompositorNodeTree")
        scene.compositing_node_group = tree
    if tree is not None:
        tree.nodes.clear()
        rl = tree.nodes.new("CompositorNodeRLayers")
        glare = tree.nodes.new("CompositorNodeGlare")
        if "Type" in glare.inputs:  # Blender 5: the settings are input sockets
            glare.inputs["Type"].default_value = "Bloom"
            glare.inputs["Threshold"].default_value = 0.9
            glare.inputs["Strength"].default_value = 0.6
            glare.inputs["Size"].default_value = 0.6
        else:
            glare.glare_type = "BLOOM"
        out_node = None
        for kind in ("CompositorNodeComposite", "NodeGroupOutput"):
            try:
                out_node = tree.nodes.new(kind)
                break
            except Exception:
                continue
        if out_node.bl_idname == "NodeGroupOutput" and not tree.interface.items_tree:
            tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        tree.links.new(rl.outputs["Image"], glare.inputs["Image"])
        tree.links.new(glare.outputs["Image"], out_node.inputs[0])


def render_icon(path=None, size=1024, samples=64):
    scene = bpy.context.scene
    _setup_look(samples)
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.filepath = path or os.path.join(OUT, "icon_render.png")
    bpy.ops.render.render(write_still=True)
    return scene.render.filepath


# --- the hero thumbnail ------------------------------------------------------------------------------
# The bishop, big in the right foreground, snipes up a diagonal of a red-and-black board: a white-hot
# bullet trail runs from the muzzle through a black knight that bursts into shards (shockwave ring,
# impact star) and on into a black pawn that's just been hit; the black king watches from the side.
# The left third is kept dark and empty for the CHESS?? title (finish_hero.py).

import random

S = 1.4  # a square, in studs


def _sq(f, r):
    return Vector(((f - 3.5) * S, (r - 3.5) * S, 0))


def _shards(col, centre, away, n, mat, seed, spread=1.0, size=0.09):
    """n black chips flying out of `centre`, mostly along `away` (the bullet's direction) and up."""
    rnd = random.Random(seed)
    out = []
    for i in range(n):
        mesh = bpy.data.meshes.new("Shard")
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1)
        bm.to_mesh(mesh)
        bm.free()
        o = bpy.data.objects.new("Shard", mesh)
        col.objects.link(o)
        d = away * rnd.uniform(0.3, 1.0) + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 1.2))) * spread
        o.location = centre + d * rnd.uniform(0.25, 1.15)
        k = size * rnd.uniform(0.5, 1.6)
        o.scale = (k * rnd.uniform(0.6, 1.4), k * rnd.uniform(0.4, 1.0), k * rnd.uniform(0.6, 1.5))
        o.rotation_euler = (rnd.uniform(0, 6.28), rnd.uniform(0, 6.28), rnd.uniform(0, 6.28))
        o.data.materials.append(mat)
        out.append(o)
    return out


def _glow_backdrop(obj, scale, loc, strength, soft=0.2):
    """A spherical red-to-black gradient on an emission plane (UV-mapped)."""
    nt = obj.data.materials[0].node_tree
    em = [n for n in nt.nodes if n.type == "EMISSION"][0]
    grad = nt.nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = scale
    mapping.inputs["Location"].default_value = loc
    coord = nt.nodes.new("ShaderNodeTexCoord")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[0].position = soft
    ramp.color_ramp.elements[1].color = (0.8, 0.05, 0.03, 1)
    ramp.color_ramp.elements[1].position = 0.95
    ramp.color_ramp.interpolation = "EASE"
    nt.links.new(coord.outputs["UV"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs[0], grad.inputs["Vector"])
    nt.links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    em.inputs["Strength"].default_value = strength


def make_hero():
    scene = bpy.context.scene
    for c in list(scene.collection.children):
        c.hide_render = True
    col = _collection("Hero")
    col.hide_render = False

    ivory = _mat("HeroIvory", (0.93, 0.91, 0.86), rough=0.28, coat=0.6)
    ebony = _mat("HeroEbony", (0.035, 0.033, 0.035), rough=0.25, coat=0.8)

    # --- the board: 8 x 8, red and near-black, glossy -----------------------------------------------
    dark = _mat("HeroSqDark", (0.012, 0.01, 0.01), rough=0.5, coat=0.08)
    light = _mat("HeroSqLight", (0.15, 0.022, 0.022), rough=0.5, coat=0.08)
    for f in range(8):
        for r in range(8):
            sq = box("Sq", (S * 0.995, S * 0.995, 0.12), tuple(_sq(f, r) + Vector((0, 0, -0.06))), col)
            _assign(sq, light if (f + r) % 2 == 1 else dark)
    frame = box("Frame", (8 * S + 0.6, 8 * S + 0.6, 0.1), (0, 0, -0.1), col)
    _assign(frame, _mat("HeroFrame", (0.05, 0.02, 0.015), rough=0.4))

    # --- the shooter: the white bishop on f2, the rifle aimed up the long diagonal --------------------
    home = _sq(5, 1)
    aim = Vector((-1, 1, 0)).normalized()
    bishop = classic_b(col)
    bishop.name = "Bishop"
    bishop.location = home
    bishop.rotation_euler = (0, 0, math.radians(45))  # its mitre slit turned towards the line
    _assign(bishop, ivory)

    make_rifle()
    rifle_col = bpy.data.collections["Rifle"]
    looks = {"Stock": _mat("IconWood", (0.1, 0.04, 0.016), rough=0.35, coat=0.5),
             "Metal": _mat("IconGunmetal", (0.05, 0.05, 0.058), rough=0.3, metal=0.9),
             "Bolt": _mat("IconSteel", (0.55, 0.55, 0.58), rough=0.25, metal=1.0),
             "Lens": _mat("IconLens", (1.0, 0.1, 0.08), rough=0.1, emit=(1.0, 0.08, 0.05), strength=12)}
    gun = bpy.data.objects.new("HeroGun", None)
    col.objects.link(gun)
    for o in list(rifle_col.objects):
        rifle_col.objects.unlink(o)
        col.objects.link(o)
        base = o.name.split(".")[0]
        if base in looks:
            _assign(o, looks[base])
        o.parent = gun
    rifle_col.hide_render = True
    left = Vector((-1, -1, 0)).normalized()  # the shooter's left (it faces up the diagonal)
    gun.location = home + left * 0.5 + aim * 0.1 + Vector((0, 0, 1.0))
    gun.rotation_euler = aim.to_track_quat("-Y", "Z").to_euler()
    gun.scale = (1.05, 1.05, 1.05)
    bpy.context.view_layer.update()
    muzzle = gun.matrix_world @ Vector((0, -1.72, 0.0))

    # --- the targets on the diagonal ------------------------------------------------------------------
    def piece(fn, f, r, name, tilt=(0, 0, 0), lift=(0, 0, 0)):
        o = fn(col)
        o.name = name
        o.location = _sq(f, r) + Vector(lift)
        o.rotation_euler = tilt
        _assign(o, ebony)
        return o
    # the knight on c5 is being blown apart: tilted back, lifted, shards everywhere
    hit = _sq(2, 4)
    piece(classic_n, 2, 4, "Knight", (math.radians(-28), math.radians(18), math.radians(-30)), (-0.35, 0.45, 0.35))
    _shards(col, hit + Vector((0, 0, 0.9)), aim, 70, ebony, seed=7, spread=1.1)
    # the pawn on b6 just behind it, knocked over and chipped
    piece(classic_p, 1, 5, "Pawn", (math.radians(55), 0, math.radians(-40)), (-0.2, 0.3, 0.3))
    _shards(col, _sq(1, 5) + Vector((0, 0, 0.6)), aim, 25, ebony, seed=11, spread=0.8, size=0.06)
    # the rook further up the line, still standing (next in line), and the king watching off the line
    piece(classic_r, 0, 6, "Rook")
    piece(classic_k, 4, 6, "King", (0, 0, math.radians(20)))

    # --- the bullet trail, the impact -----------------------------------------------------------------
    end = _sq(0, 6) + Vector((0, 0, 0.95))
    trail = cyl("Trail", 0.03, tuple(muzzle), tuple(end), col, seg=10)
    _assign(trail, _mat("HeroTrail", (1, 0.9, 0.7), emit=(1.0, 0.85, 0.6), strength=55))
    halo = cyl("TrailHalo", 0.09, tuple(muzzle), tuple(end), col, seg=10)
    _assign(halo, _mat("HeroHalo", (1, 0.3, 0.1), emit=(1.0, 0.25, 0.08), strength=6))
    impact = hit + Vector((0, 0, 0.95))
    star = _emission_plane("Impact", (1.7, 1.7), tuple(impact), (0, 0, 0), col, (1.0, 0.8, 0.5), 18,
                           image=os.path.join(VFX, "star.png"))
    ring = _emission_plane("Shockwave", (1.9, 1.9), tuple(impact), (0, 0, 0), col, (1.0, 0.35, 0.15), 1.5,
                           image=os.path.join(VFX, "ring.png"))
    ring.rotation_euler = aim.to_track_quat("Z", "Y").to_euler()  # standing across the bullet's path
    flash = _emission_plane("MuzzleFlash", (1.3, 1.3), tuple(muzzle + aim * 0.15), (0, 0, 0), col, (1.0, 0.75, 0.4), 30,
                            image=os.path.join(VFX, "star.png"))
    boom = bpy.data.objects.new("ImpactLight", bpy.data.lights.new("ImpactLight", "POINT"))
    col.objects.link(boom)
    boom.location = impact
    boom.data.energy = 500
    boom.data.color = (1.0, 0.55, 0.25)

    # --- backdrop: a red glow behind the targets, black at the edges (the title side stays dark) --------
    bg = _emission_plane("HeroBackdrop", (60, 30), (-6, 14, 3), (math.radians(90), 0, 0), col, (1, 1, 1), 1)
    _glow_backdrop(bg, (4.0, 2.2, 1), (-2.0 + 0.25, -1.1 + 0.05, 0), 1.2, soft=0.0)

    # --- camera: low, behind the bishop's right shoulder, looking up the diagonal ------------------------
    cam = bpy.data.objects.new("HeroCam", bpy.data.cameras.new("HeroCam"))
    col.objects.link(cam)
    # behind the shooter's left shoulder: the bishop and rifle on the right of the frame, the line and
    # the burst receding towards the middle, the left side dark for the title
    cam.data.lens = 30
    cam.location = home - aim * 3.4 + left * 2.9 + Vector((0, 0, 1.7))
    look = (home + hit) / 2 + Vector((0, 0, 0.85)) + left * 0.6
    cam.rotation_euler = (look - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    for o in (star, flash):
        o.rotation_euler = (cam.location - o.location).to_track_quat("Z", "Y").to_euler()

    def area(name, loc, at, energy, color, size):
        l = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        col.objects.link(l)
        l.data.energy = energy
        l.data.color = color
        l.data.size = size
        l.location = loc
        l.rotation_euler = (Vector(at) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    area("HeroKey", tuple(home + Vector((3.0, -2.0, 4.0))), tuple(home + Vector((0, 0, 1))), 700, (1.0, 0.93, 0.85), 3)
    area("HeroRim", tuple(home + Vector((-2.5, 2.5, 2.5))), tuple(home + Vector((0, 0, 1))), 900, (1.0, 0.2, 0.12), 2)
    area("HeroTop", (0, 2, 9), (0, 2, 0), 1500, (1.0, 0.85, 0.8), 10)
    scene.world = scene.world or bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.0
    return {"objects": len(col.objects)}


def render_hero(path=None, samples=96, scale=100):
    """1920 x 1080 (scale = a percentage, for quick drafts). Uses render_icon's look and bloom setup."""
    scene = bpy.context.scene
    _setup_look(samples)
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.resolution_percentage = scale
    scene.render.filepath = path or os.path.join(OUT, "hero_render.png")
    bpy.ops.render.render(write_still=True)
    return scene.render.filepath
