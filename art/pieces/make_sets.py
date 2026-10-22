"""Chess piece sets for the Roblox game, built in Blender (run inside Blender: exec(open(path).read())).

make_set("Classic") / make_set("Toon") builds a collection <Set> with one mesh object per piece kind
(p r n b q k). Units are studs (1 Blender unit = 1 stud, the FBX export keeps it: verified with the
test pawn). Every piece: origin at the centre of its base's underside, standing on Z=0, its front
(the knight's face) towards Blender -Y. Heights are the final in-game sizes (Pieces.lua doesn't
scale meshes). export_set(name) writes art/pieces/<Set>.fbx (one object per piece) for Studio's 3D
Importer; render_set(name) writes a preview PNG next to it.

Classic: polished tournament Staunton. Toon: chunky, rounded, oversized heads, for phones.
"""
import bpy
import bmesh
import math
import os
from mathutils import Matrix, Vector

OUT = r"C:\Users\liter\Documents\CLAUDE\chess\art\pieces"
SEG = 48  # around the axis


# --- helpers -------------------------------------------------------------------------------------

def _collection(name):
    col = bpy.data.collections.get(name)
    if col:
        for o in list(col.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    else:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def _link(obj, col):
    col.objects.link(obj)
    return obj


def lathe(name, prof, col, seg=SEG):
    """prof: (radius, z) bottom -> top, starting and ending on the axis."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0.0, z)) for r, z in prof]
    for a, b in zip(vs, vs[1:]):
        bm.edges.new((a, b))
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:], cent=(0, 0, 0), axis=(0, 0, 1),
                   angle=math.radians(360), steps=seg, use_duplicate=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    return _link(bpy.data.objects.new(name, mesh), col)


def box(name, size, loc, col, rot=(0, 0, 0)):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    o = _link(bpy.data.objects.new(name, mesh), col)
    o.location = loc
    o.rotation_euler = rot
    return o


def sphere(name, r, loc, col, seg=24, ring=12, scale=(1, 1, 1)):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=ring, radius=r)
    bm.to_mesh(mesh)
    bm.free()
    o = _link(bpy.data.objects.new(name, mesh), col)
    o.location = loc
    o.scale = scale
    return o


def boolean(target, cutter, op="DIFFERENCE"):
    m = target.modifiers.new("Bool", "BOOLEAN")
    m.operation = op
    m.object = cutter
    m.solver = "EXACT"
    _apply(target, m)
    bpy.data.objects.remove(cutter, do_unlink=True)


def _apply(obj, mod):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.view_layer.objects:
        o.select_set(o == obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def join(objs, name):
    base = objs[0]
    bpy.context.view_layer.objects.active = base
    for o in bpy.context.view_layer.objects:
        o.select_set(o in objs)
    bpy.ops.object.join()
    base.name = name
    base.data.name = name
    return base


def finish(obj, sharp=38):
    """Weld, smooth shading with sharp rims, origin at the base's underside."""
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.view_layer.objects:
        o.select_set(o == obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = True
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(sharp))
    except Exception:
        pass
    # origin: base centre at z = min
    zmin = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
    obj.data.transform(Matrix.Translation((-obj.location.x, -obj.location.y, -zmin)))
    obj.location = (0, 0, 0)
    return obj


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def silhouette(name, pts, thickness, col, bevel=0.04):
    """A side profile (y, z) extruded along X (centred), with rounded edges: for the knight's head."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [bm.verts.new((-thickness / 2, y, z)) for y, z in pts]
    face = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(thickness, 0, 0), verts=moved)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    o = _link(bpy.data.objects.new(name, mesh), col)
    if bevel > 0:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = 3
        m.limit_method = "ANGLE"
        _apply(o, m)
    return o


# --- Classic (Staunton) -------------------------------------------------------------------------------
# A shared foot: wide base with a bead and a cove, then the body. Heights in studs (final sizes).

def staunton_base(d):
    r = d / 2
    return [(0.0, 0.0), (r, 0.0), (r * 1.01, 0.025), (r * 1.01, 0.075), (r * 0.96, 0.105), (r * 0.88, 0.12),
            (r * 0.9, 0.145), (r * 0.87, 0.17), (r * 0.78, 0.19), (r * 0.7, 0.215)]


def classic_p(col):
    prof = staunton_base(1.0) + [
        (0.29, 0.26), (0.25, 0.33), (0.22, 0.44), (0.19, 0.56), (0.175, 0.66), (0.17, 0.73),
        (0.30, 0.76), (0.32, 0.79), (0.30, 0.82), (0.19, 0.84), (0.165, 0.865),
        (0.22, 0.91), (0.26, 0.98), (0.275, 1.05), (0.27, 1.12), (0.245, 1.18), (0.2, 1.23), (0.14, 1.265), (0.07, 1.285), (0.0, 1.29)]
    return finish(lathe("p", prof, col))


def classic_r(col):
    prof = staunton_base(1.12) + [
        (0.4, 0.27), (0.36, 0.36), (0.33, 0.55), (0.32, 0.8), (0.33, 1.0), (0.36, 1.08),
        (0.42, 1.12), (0.44, 1.15), (0.42, 1.18), (0.43, 1.2), (0.45, 1.24), (0.45, 1.55), (0.0, 1.55)]
    body = lathe("r", prof, col)
    # hollow top and 6 battlement notches
    hole = lathe("hole", [(0.0, 1.38), (0.32, 1.38), (0.34, 1.6), (0.0, 1.6)], col)
    boolean(body, hole)
    for i in range(6):  # notches: narrow across the wall (y), long through it (x, radial)
        a = math.radians(i * 60 + 30)
        cut = box("notch", (0.5, 0.17, 0.2), (math.cos(a) * 0.4, math.sin(a) * 0.4, 1.53), col, (0, 0, a))
        boolean(body, cut)
    return finish(body)


def classic_b(col):
    prof = staunton_base(1.08) + [
        (0.33, 0.27), (0.27, 0.36), (0.23, 0.5), (0.2, 0.66), (0.185, 0.8), (0.18, 0.9),
        (0.33, 0.93), (0.35, 0.96), (0.33, 0.99), (0.21, 1.01), (0.18, 1.04),
        (0.23, 1.1), (0.28, 1.2), (0.3, 1.32), (0.29, 1.44), (0.25, 1.55), (0.18, 1.64), (0.1, 1.7), (0.05, 1.72),
        (0.075, 1.75), (0.085, 1.79), (0.075, 1.83), (0.04, 1.85), (0.0, 1.855)]
    body = lathe("b", prof, col)
    # the mitre slit: a thin slanted groove running front to back, seen as a diagonal from the front
    cut = box("slit", (0.065, 0.8, 0.42), (0.07, 0, 1.44), col, (0, math.radians(32), 0))
    boolean(body, cut)
    return finish(body)


def classic_q(col):
    prof = staunton_base(1.16) + [
        (0.38, 0.27), (0.31, 0.38), (0.26, 0.55), (0.22, 0.78), (0.2, 0.98), (0.2, 1.08),
        (0.36, 1.12), (0.38, 1.15), (0.36, 1.18), (0.23, 1.2), (0.2, 1.23),
        (0.26, 1.33), (0.32, 1.46), (0.36, 1.58), (0.375, 1.66), (0.36, 1.7), (0.26, 1.72), (0.18, 1.76),
        (0.15, 1.8), (0.15, 1.84), (0.0, 1.84)]
    parts = [lathe("q", prof, col)]
    # coronet: a ring of 8 small balls on the crown's rim, and a bead on top
    for i in range(8):
        a = math.radians(i * 45)
        parts.append(sphere("ball", 0.065, (math.cos(a) * 0.35, math.sin(a) * 0.35, 1.72), col, seg=14, ring=8))
    parts.append(lathe("neck", [(0.0, 1.8), (0.07, 1.8), (0.05, 1.88), (0.0, 1.88)], col, seg=20))
    parts.append(sphere("bead", 0.1, (0, 0, 1.95), col, seg=20, ring=10))
    body = join(parts, "q")
    return finish(body)


def classic_k(col):
    prof = staunton_base(1.2) + [
        (0.4, 0.27), (0.33, 0.38), (0.28, 0.56), (0.24, 0.8), (0.22, 1.02), (0.215, 1.18),
        (0.38, 1.22), (0.4, 1.25), (0.38, 1.28), (0.25, 1.3), (0.22, 1.33),
        (0.28, 1.44), (0.33, 1.56), (0.36, 1.68), (0.36, 1.74), (0.3, 1.77), (0.24, 1.82), (0.24, 1.86), (0.0, 1.86)]
    body = lathe("k", prof, col)
    # the cross, square-cut, facing the players (its arm runs across, along X)
    upright = box("up", (0.11, 0.11, 0.42), (0, 0, 2.04), col)
    arm = box("arm", (0.34, 0.11, 0.11), (0, 0, 2.08), col)
    for o in (upright, arm):
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = 0.02
        m.segments = 2
        _apply(o, m)
    body = join([body, upright, arm], "k")
    return finish(body)


def classic_n(col):
    base = lathe("nb", staunton_base(1.12) + [(0.38, 0.27), (0.34, 0.33), (0.33, 0.4), (0.0, 0.4)], col)
    # side profile of the horse (y = front-back with the face towards -Y, z = up)
    pts = [
        (0.30, 0.38), (0.30, 0.62), (0.26, 0.86), (0.24, 1.06), (0.22, 1.24), (0.17, 1.42),  # back of the neck (mane side)
        (0.10, 1.56), (0.07, 1.66), (0.02, 1.74),                                              # poll, up to the ear
        (-0.04, 1.66), (-0.10, 1.62), (-0.2, 1.58), (-0.32, 1.52), (-0.42, 1.44),             # forehead to nose
        (-0.48, 1.36), (-0.5, 1.28), (-0.46, 1.22), (-0.38, 1.2),                              # muzzle and mouth
        (-0.32, 1.16), (-0.24, 1.14), (-0.18, 1.08), (-0.18, 0.98),                            # jaw
        (-0.24, 0.86), (-0.30, 0.72), (-0.32, 0.56), (-0.32, 0.38),                            # chest
    ]
    head = silhouette("nh", pts, 0.36, col, bevel=0.06)
    # narrower face: taper the head towards the front-top
    for v in head.data.vertices:
        f = max(0.0, min(1.0, (v.co.z - 0.9) / 0.8)) * max(0.0, min(1.0, (-v.co.y + 0.1) / 0.6))
        v.co.x *= 1.0 - 0.38 * f
    ear = box("ear", (0.16, 0.08, 0.16), (0, 0.04, 1.74), col, (math.radians(-20), 0, 0))
    mane = box("mane", (0.1, 0.1, 0.8), (0, 0.25, 0.98), col, (math.radians(-14), 0, 0))
    for o in (ear, mane):
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = 0.03
        m.segments = 2
        _apply(o, m)
    # eyes: small dents on both sides
    for x in (-0.16, 0.16):  # shallow dents (the head is about 0.25 wide here)
        eye = sphere("eye", 0.035, (x, -0.2, 1.48), col, seg=10, ring=6)
        boolean(head, eye)
    body = join([base, head, ear, mane], "n")
    return finish(body, sharp=50)


CLASSIC = {"p": classic_p, "r": classic_r, "n": classic_n, "b": classic_b, "q": classic_q, "k": classic_k}


# --- Toon (chunky, rounded, for phones) --------------------------------------------------------------
# A thick rounded puck for a base, round bellies, oversized heads, soft edges everywhere; slightly
# shorter and wider than Classic so pieces read at a glance on a small screen.

def toon_base(d, h=0.22):
    r = d / 2
    return [(0.0, 0.0), (r * 0.94, 0.0), (r, 0.04), (r * 1.02, h * 0.5), (r, h - 0.04), (r * 0.94, h), (r * 0.7, h + 0.02)]


def bevel(obj, width, seg=3):
    m = obj.modifiers.new("Bevel", "BEVEL")
    m.width = width
    m.segments = seg
    m.limit_method = "ANGLE"
    _apply(obj, m)
    return obj


def toon_p(col):
    prof = toon_base(1.04) + [(0.34, 0.3), (0.3, 0.45), (0.27, 0.6), (0.3, 0.66), (0.0, 0.66)]
    head = sphere("head", 0.3, (0, 0, 0.9), col, seg=32, ring=16)
    return finish(join([lathe("p", prof, col, seg=40), head], "p"), sharp=60)


def toon_r(col):
    prof = toon_base(1.14) + [(0.42, 0.32), (0.38, 0.5), (0.37, 0.8), (0.4, 0.98), (0.48, 1.04), (0.5, 1.12), (0.5, 1.38), (0.0, 1.38)]
    body = lathe("r", prof, col, seg=40)
    hole = lathe("hole", [(0.0, 1.24), (0.34, 1.24), (0.36, 1.45), (0.0, 1.45)], col)
    boolean(body, hole)
    for i in range(4):  # four chunky merlons
        a = math.radians(i * 90 + 45)
        cut = box("notch", (0.6, 0.26, 0.24), (math.cos(a) * 0.45, math.sin(a) * 0.45, 1.36), col, (0, 0, a))
        boolean(body, cut)
    return finish(bevel(body, 0.03, 2), sharp=60)


def toon_b(col):
    prof = toon_base(1.08) + [(0.36, 0.3), (0.3, 0.46), (0.25, 0.66), (0.24, 0.8), (0.34, 0.84), (0.34, 0.9), (0.0, 0.9)]
    head = sphere("head", 0.33, (0, 0, 1.24), col, seg=32, ring=16, scale=(1, 1, 1.25))
    cut = box("slit", (0.09, 0.9, 0.5), (0.1, 0, 1.36), col, (0, math.radians(30), 0))
    boolean(head, cut)
    tip = sphere("tip", 0.1, (0, 0, 1.72), col, seg=16, ring=8)
    return finish(join([lathe("b", prof, col, seg=40), head, tip], "b"), sharp=60)


def toon_q(col):
    prof = toon_base(1.16) + [(0.4, 0.3), (0.32, 0.5), (0.27, 0.78), (0.26, 0.96), (0.38, 1.0), (0.38, 1.06), (0.28, 1.1),
                              (0.36, 1.26), (0.44, 1.44), (0.42, 1.5), (0.0, 1.5)]
    parts = [lathe("q", prof, col, seg=40)]
    for i in range(6):  # big round crown points
        a = math.radians(i * 60)
        parts.append(sphere("pt", 0.11, (math.cos(a) * 0.36, math.sin(a) * 0.36, 1.56), col, seg=16, ring=8))
    parts.append(sphere("top", 0.14, (0, 0, 1.66), col, seg=20, ring=10))
    return finish(join(parts, "q"), sharp=60)


def toon_k(col):
    prof = toon_base(1.2) + [(0.42, 0.3), (0.34, 0.52), (0.29, 0.82), (0.28, 1.02), (0.4, 1.06), (0.4, 1.12), (0.3, 1.16),
                             (0.38, 1.3), (0.42, 1.48), (0.36, 1.56), (0.0, 1.56)]
    parts = [lathe("k", prof, col, seg=40)]
    up = bevel(box("up", (0.17, 0.17, 0.5), (0, 0, 1.8), col), 0.05)
    arm = bevel(box("arm", (0.46, 0.17, 0.17), (0, 0, 1.86), col), 0.05)
    parts += [up, arm]
    return finish(join(parts, "k"), sharp=60)


def toon_n(col):
    base = lathe("nb", toon_base(1.14) + [(0.38, 0.3), (0.36, 0.4), (0.0, 0.4)], col, seg=40)
    pts = [
        (0.30, 0.36), (0.30, 0.66), (0.27, 0.92), (0.24, 1.14), (0.18, 1.34), (0.1, 1.48), (0.02, 1.56),
        (-0.08, 1.52), (-0.2, 1.46), (-0.34, 1.38), (-0.46, 1.28), (-0.5, 1.18), (-0.46, 1.08), (-0.34, 1.04),
        (-0.22, 1.0), (-0.2, 0.9), (-0.28, 0.76), (-0.32, 0.6), (-0.32, 0.36),
    ]
    head = silhouette("nh", pts, 0.5, col, bevel=0.14)
    ears = [bevel(box("ear", (0.14, 0.12, 0.2), (x, 0.06, 1.6), col, (math.radians(-15), 0, 0)), 0.04) for x in (-0.12, 0.12)]
    eyes = [sphere("eye", 0.07, (x, -0.16, 1.32), col, seg=14, ring=8) for x in (-0.2, 0.2)]
    return finish(join([base, head] + ears + eyes, "n"), sharp=60)


TOON = {"p": toon_p, "r": toon_r, "n": toon_n, "b": toon_b, "q": toon_q, "k": toon_k}


def make_set(name):
    builders = {"Classic": CLASSIC, "Toon": globals().get("TOON")}[name]
    col = _collection(name)
    out = {}
    for i, (kind, fn) in enumerate(builders.items()):
        obj = fn(col)
        obj.name = kind
        obj.location = (i * 1.6, 0, 0)
        out[kind] = {"tris": tris(obj), "size": [round(x, 3) for x in obj.dimensions]}
    return out


def export_set(name):
    col = bpy.data.collections[name]
    for o in bpy.context.view_layer.objects:
        o.select_set(o.name in col.objects and o.type == "MESH")
    # every piece at its own origin for export (the importer keeps them as separate MeshParts)
    keep = {o: o.location.copy() for o in col.objects}
    for o in col.objects:
        o.location = (0, 0, 0)
    path = os.path.join(OUT, name + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", use_mesh_modifiers=True)
    for o, loc in keep.items():
        o.location = loc
    return path


def render_set(name, path=None):
    scene = bpy.context.scene
    col = bpy.data.collections[name]
    objs = list(col.objects)
    cx = sum(o.location.x for o in objs) / len(objs)
    cam = bpy.data.objects.get("PrevCam")
    if not cam:
        cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam"))
        scene.collection.objects.link(cam)
    cam.data.lens = 50
    cam.location = (cx, -13.0, 3.6)
    cam.rotation_euler = (Vector((cx, 0, 1.0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    if not bpy.data.objects.get("Key"):
        light = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
        scene.collection.objects.link(light)
        light.data.energy = 4
        light.rotation_euler = (math.radians(55), 0, math.radians(35))
    mat = bpy.data.materials.get("Ivory") or bpy.data.materials.new("Ivory")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.92, 0.9, 0.84, 1)
    bsdf.inputs["Roughness"].default_value = 0.3
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
    scene.world = scene.world or bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.42, 0.32, 1)
    scene.render.resolution_x, scene.render.resolution_y = 1200, 500
    # hide other sets while rendering
    for c in bpy.context.scene.collection.children:
        c.hide_render = c.name != name
    scene.render.filepath = path or os.path.join(OUT, name + "_preview.png")
    bpy.ops.render.render(write_still=True)
    return scene.render.filepath
