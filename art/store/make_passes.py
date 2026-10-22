"""The gamepass and developer-product icons for CHESS?? (vault Design/Store Art), the subjects
rendered in Blender on a transparent background; art/store/finish_passes.py puts each on its
coloured circle with the rarity ring.

Run inside Blender:
    exec(open(r"C:\\Users\\liter\\Documents\\CLAUDE\\chess\\art\\store\\make_passes.py").read())
    render_all()      # -> art/store/out/pass_<name>_render.png (1024 x 1024, transparent)
or one at a time: make_pass("jump"); render_pass("jump").

Subjects (the piece mid-ability, as in its cutscene):
  jump    the white knight rearing at the top of its leap, seen from below, glowing afterimages and
          thick blue energy trails behind it, a burst of light
  snipe   the white bishop with the rifle, aimed past the viewer (finish adds the crosshair)
  ram     the white rook charging at the viewer, black debris flying (finish adds speed lines)
  escape  the white king with feathered angel wings, a gold halo, a soft beam of light from above
  vip     the white king wearing a gold crown (finish adds even sparkles and the VIP ribbon)
  steal   a black knight bound in gold chains, half turned white, on a red sigil (finish adds "!?")
"""
import bpy
import math
import os
import random
from mathutils import Vector

exec(open(r"C:\Users\liter\Documents\CLAUDE\chess\art\store\make_store.py").read())

GOLD = (1.0, 0.72, 0.2)


def _clear(col):
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def _arc(col, name, pts, radius, mat):
    """A glowing tube along a polyline (a curve with a bevel)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 4
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p.x, p.y, p.z, 1)
        # taper the trail towards its start
        sp.points[i].radius = 0.15 + 0.85 * i / (len(pts) - 1)
    o = bpy.data.objects.new(name, cu)
    col.objects.link(o)
    o.data.materials.append(mat)
    return o


def _parabola(a, b, height, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b, t)
        p.z += height * 4 * t * (1 - t)
        out.append(p)
    return out


def _torus(col, name, loc, rot, major, minor, mat, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=24, minor_segments=8,
                                     location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    for c in o.users_collection:
        c.objects.unlink(o)
    col.objects.link(o)
    o.data.materials.append(mat)
    return o


def _camera(col, loc, look, lens):
    cam = bpy.data.objects.new("PassCam", bpy.data.cameras.new("PassCam"))
    col.objects.link(cam)
    cam.data.lens = lens
    cam.location = loc
    cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def _lights(col, rim=(1.0, 0.9, 0.8)):
    def area(name, loc, at, energy, color, size):
        l = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        col.objects.link(l)
        l.data.energy = energy
        l.data.color = color
        l.data.size = size
        l.location = loc
        l.rotation_euler = (Vector(at) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    area("Key", (3.0, -3.5, 4.0), (0, 0, 1), 450, (1.0, 0.95, 0.9), 3)
    area("Rim", (-2.8, 2.6, 2.6), (0, 0, 1), 700, rim, 2)
    area("Fill", (-2.5, -3.5, 1.2), (0, 0, 1), 90, (0.85, 0.9, 1.0), 3)


def _face_cam(objs, cam):
    for o in objs:
        o.rotation_euler = (cam.location - o.location).to_track_quat("Z", "Y").to_euler()


def make_pass(kind):
    scene = bpy.context.scene
    for c in list(scene.collection.children):
        c.hide_render = True
    col = _collection("Pass")
    _clear(col)
    col.hide_render = False
    ivory = _mat("PassIvory", (0.93, 0.91, 0.86), rough=0.28, coat=0.6)
    ebony = _mat("PassEbony", (0.035, 0.033, 0.035), rough=0.25, coat=0.8)
    gold = _mat("PassGold", (1.0, 0.7, 0.22), rough=0.22, metal=1.0)

    if kind == "jump":
        # "epic": the knight rearing at the top of its second leap, seen from below; two glowing
        # afterimages of it back along the arc, thick energy trails, a burst of light behind it
        k = classic_n(col)
        _assign(k, ivory)
        top = Vector((0, 0, 1.2))
        k.location = top
        face = (math.radians(22), 0, math.radians(59))  # its face (-Y) along the leap, nose up
        k.rotation_euler = face
        blue = _mat("PassBlueTrail", (0.4, 0.7, 1), emit=(0.35, 0.7, 1.0), strength=14)
        core = _mat("PassTrailCore", (1, 1, 1), emit=(0.85, 0.95, 1.0), strength=30)
        a, b = Vector((-3.4, 2.4, 0.0)), Vector((-1.5, 1.0, 0.4))
        _arc(col, "Leap1", _parabola(a, b, 1.6), 0.13, blue)
        leap2 = _parabola(b, top + Vector((0, 0, 0.45)), 1.1)
        _arc(col, "Leap2", leap2, 0.22, blue)
        _arc(col, "Leap2Core", leap2, 0.07, core)
        # afterimages: see-through glowing copies of the knight back along the second leap
        ghost = bpy.data.materials.new("PassGhost")
        ghost.use_nodes = True
        nt = ghost.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (0.35, 0.7, 1.0, 1)
        em.inputs["Strength"].default_value = 3.5
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mix = nt.nodes.new("ShaderNodeMixShader")
        mix.inputs["Fac"].default_value = 0.45
        nt.links.new(tr.outputs[0], mix.inputs[1])
        nt.links.new(em.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])
        for t in (0.25, 0.55):
            g = classic_n(col)
            g.name = "Ghost"
            g.location = leap2[int(t * (len(leap2) - 1))] - Vector((0, 0, 0.45))
            g.rotation_euler = face
            _assign(g, ghost)
        burst = _emission_plane("Burst", (2.2, 2.2), tuple(top + Vector((0.2, 0.9, 0.9))), (0, 0, 0), col, (0.6, 0.85, 1.0), 5,
                                image=os.path.join(VFX, "star.png"))
        glowp = _emission_plane("Glow", (3.6, 3.6), tuple(top + Vector((0.3, 0.6, 0.9))), (0, 0, 0), col, (0.3, 0.6, 1.0), 3,
                                image=os.path.join(VFX, "glow.png"))
        cam = _camera(col, (1.2, -5.6, 1.3), (-0.6, 0.4, 1.4), 44)  # a little low: looking up at it
        _face_cam([burst, glowp], cam)
        _lights(col, rim=(0.4, 0.7, 1.0))
    elif kind == "snipe":
        b = classic_b(col)
        _assign(b, ivory)
        make_rifle()
        rc = bpy.data.collections["Rifle"]
        looks = {"Stock": _mat("IconWood", (0.1, 0.04, 0.016), rough=0.35, coat=0.5),
                 "Metal": _mat("IconGunmetal", (0.05, 0.05, 0.058), rough=0.3, metal=0.9),
                 "Bolt": _mat("IconSteel", (0.55, 0.55, 0.58), rough=0.25, metal=1.0),
                 "Lens": _mat("IconLens", (1.0, 0.1, 0.08), rough=0.1, emit=(1.0, 0.08, 0.05), strength=12)}
        gun = bpy.data.objects.new("PassGun", None)
        col.objects.link(gun)
        for o in list(rc.objects):
            rc.objects.unlink(o)
            col.objects.link(o)
            if o.name.split(".")[0] in looks:
                _assign(o, looks[o.name.split(".")[0]])
            o.parent = gun
        rc.hide_render = True
        aim = Vector((-1.0, -0.75, 0.05)).normalized()
        gun.location = (-0.15, -0.7, 1.0)
        gun.rotation_euler = aim.to_track_quat("-Y", "Z").to_euler()
        bpy.context.view_layer.update()
        front = gun.matrix_world @ Vector((0, -0.36, 0.17))
        glint = _emission_plane("Glint", (0.8, 0.8), tuple(front + aim * 0.02), (0, 0, 0), col, (1.0, 0.3, 0.2), 16,
                                image=os.path.join(VFX, "star.png"))
        cam = _camera(col, (2.2, -4.8, 1.6), (-0.3, -0.35, 0.95), 50)
        _face_cam([glint], cam)
        _lights(col, rim=(1.0, 0.3, 0.2))
    elif kind == "ram":
        r = classic_r(col)
        _assign(r, ivory)
        r.location = (0, 0, 0.15)
        r.rotation_euler = (math.radians(14), 0, math.radians(8))  # leaning into the charge
        _shards(col, Vector((0, -1.0, 0.7)), Vector((0, -1, 0.3)), 28, ebony, seed=3, spread=1.0, size=0.1)
        dust = _emission_plane("Dust", (2.4, 2.4), (0, 0.3, 0.02), (0, 0, 0), col, (1.0, 0.7, 0.4), 3,
                               image=os.path.join(VFX, "ring.png"))
        cam = _camera(col, (0.9, -4.6, 1.15), (0, 0, 0.95), 42)
        _lights(col, rim=(1.0, 0.55, 0.2))
    elif kind in ("escape", "vip"):
        k = classic_k(col)
        _assign(k, ivory)
        if kind == "escape":
            # angelic: white feathered wings spread behind the king, a glowing gold halo, a gold sigil
            # under it (the finish paints the light from above)
            feather = _mat("PassFeather", (0.97, 0.96, 0.93), rough=0.5)
            tip = _mat("PassFeatherTip", (0.85, 0.88, 0.95), rough=0.5)
            for side in (-1, 1):
                for i in range(7):
                    t = i / 6
                    ang = math.radians(-5 + 85 * t)  # fanning from level to nearly straight up
                    length = 0.9 + 0.8 * math.sin(t * math.pi * 0.8)
                    root = Vector((side * 0.24, 0.3 + 0.04 * i, 1.3 + 0.06 * t))
                    d = Vector((side * math.cos(ang), 0.05, math.sin(ang)))
                    f = sphere("Feather", 1.0, tuple(root + d * (length * 0.55)), col, seg=16, ring=8)
                    f.scale = (0.13, 0.03, length * 0.55)
                    f.rotation_euler = (0, -side * (math.pi / 2 - ang), 0)
                    _assign(f, feather if i % 2 == 0 else tip)
                    # a shorter covert row over the roots
                    if i % 2 == 0:
                        c2 = sphere("Covert", 1.0, tuple(root + d * (length * 0.25) + Vector((0, -0.03, 0.02))), col, seg=16, ring=8)
                        c2.scale = (0.1, 0.03, length * 0.28)
                        c2.rotation_euler = f.rotation_euler
                        _assign(c2, feather)
            halo_m = _mat("PassHalo", (1, 0.85, 0.4), emit=(1.0, 0.82, 0.35), strength=10)
            _torus(col, "Halo", (0, 0.05, 2.45), (math.radians(14), 0, 0), 0.3, 0.04, halo_m)  # flat, floating above the cross
            _emission_plane("SigilRing", (2.3, 2.3), (0, 0, 0.02), (0, 0, 0), col, GOLD, 6, image=os.path.join(VFX, "ring.png"))
            _emission_plane("SigilStar", (1.6, 1.6), (0, 0, 0.03), (0, 0, math.radians(15)), col, GOLD, 5,
                            image=os.path.join(VFX, "star.png"))
            cam = _camera(col, (0.6, -6.0, 1.6), (0, 0, 1.3), 44)  # nearly front-on, so both wings show
            _lights(col, rim=(1.0, 0.92, 0.7))
        else:
            # a gold crown on the king's head: a band with five points and red jewels
            band = lathe("CrownBand", [(0, 0), (0.43, 0), (0.45, 0.04), (0.45, 0.2), (0.43, 0.22), (0, 0.22)], col)
            band.location = (0, 0, 1.6)
            _assign(band, gold)
            red = _mat("PassJewel", (0.8, 0.05, 0.08), rough=0.1, emit=(1.0, 0.1, 0.12), strength=1.5)
            for i in range(5):
                a = i / 5 * math.tau + math.radians(90)
                p = lathe("CrownPoint", [(0, 0), (0.1, 0), (0.0, 0.32)], col, seg=12)
                p.location = (math.cos(a) * 0.4, math.sin(a) * 0.4, 1.8)
                _assign(p, gold)
                j = sphere("Jewel", 0.06, (math.cos(a) * 0.44, math.sin(a) * 0.44, 1.71), col, seg=12, ring=6)
                _assign(j, red)
                tip = sphere("Tip", 0.045, (math.cos(a) * 0.4, math.sin(a) * 0.4, 2.13), col, seg=12, ring=6)
                _assign(tip, gold)
            cam = _camera(col, (1.0, -5.6, 1.9), (0, 0, 1.25), 52)
            _lights(col, rim=GOLD)
    elif kind == "steal":
        n = classic_n(col)
        # half turned: the lower half ivory, the head still black (a second material by height)
        _assign(n, ebony)
        n.data.materials.append(ivory)
        for poly in n.data.polygons:
            z = sum((n.data.vertices[v].co.z for v in poly.vertices)) / len(poly.vertices)
            poly.material_index = 1 if z < 0.75 else 0
        n.location = (0, 0, 0.35)
        n.rotation_euler = (0, math.radians(-6), math.radians(-28))
        # gold chains wrapped round it: links along two tilted loops
        for loop, (tilt, zc, rad) in enumerate(((18, 0.95, 0.62), (-14, 1.55, 0.55))):
            count = 18
            for i in range(count):
                a = i / count * math.tau
                pos = Vector((math.cos(a) * rad, math.sin(a) * rad, zc + math.sin(a) * math.tan(math.radians(tilt)) * rad))
                link_rot = (math.radians(90) if i % 2 == 0 else 0, 0, a + math.pi / 2)
                _torus(col, "Link", tuple(pos), link_rot, 0.085, 0.022, gold, scale=(1.5, 1.0, 1.0))
        _emission_plane("Sigil", (2.0, 2.0), (0, 0, 0.02), (0, 0, 0), col, (1.0, 0.15, 0.1), 6, image=os.path.join(VFX, "ring.png"))
        cam = _camera(col, (1.9, -5.4, 1.9), (0, 0, 1.15), 48)
        _lights(col, rim=(1.0, 0.25, 0.2))
    else:
        raise ValueError(kind)
    return {"kind": kind, "objects": len(col.objects)}


def render_pass(kind, size=1024, samples=64):
    scene = bpy.context.scene
    _setup_look(samples)
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = os.path.join(OUT, "pass_%s_render.png" % kind)
    bpy.ops.render.render(write_still=True)
    return scene.render.filepath


def render_all(size=1024, samples=64):
    out = []
    for kind in ("jump", "snipe", "ram", "escape", "vip", "steal"):
        make_pass(kind)
        out.append(render_pass(kind, size, samples))
    return out
