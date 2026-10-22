"""The Any Passant katana (a curved blade, a gold guard, a wrapped grip) and its scabbard, built in Blender.

Run inside Blender: exec(open(path).read()); make_katana(); export_katana(); render_katana().
Units are studs. The blade runs along -Y (in-game -Z, the front) with its edge down (-Z) and the
spine up; it curves up towards the tip. The origin is the centre of the guard. Four mesh objects,
all sharing that origin, so the 3D Importer keeps them lined up:
  Blade  (steel)        Guard (the gold collar, guard and pommel cap)
  Grip   (the wrapped handle)
  Saya   (the black lacquered scabbard, sitting over the blade; it is moved on its own in game)
"""
import bpy
import bmesh
import math
import os
from mathutils import Vector

exec(open(r"C:\Users\liter\Documents\CLAUDE\chess\art\pieces\make_sets.py").read().split("# --- Classic")[0])
OUT = r"C:\Users\liter\Documents\CLAUDE\chess\art\props"

BLADE = 1.75  # length from the guard to the tip
SORI = 0.11  # how far the tip rises (the curve)
GRIP = 0.62


def _curve(t):
    """The blade's centre line at t (0 = the guard, 1 = the tip)."""
    return Vector((0, -BLADE * t, SORI * t * t))


def _tangent(t):
    return Vector((0, -BLADE, 2 * SORI * t)).normalized()


def sweep(name, section, col, stations=24, scale=lambda t: 1.0, t0=0.0, t1=1.0, cap_tip=True, grow=0.0):
    """A closed cross-section [(x, z), ...] swept along the curve, scaled by scale(t), ending in a point."""
    bm = bmesh.new()
    rings = []
    for i in range(stations + 1):
        t = t0 + (t1 - t0) * i / stations
        c = _curve(t)
        tan = _tangent(t)
        up = Vector((0, 0, 1))
        up = (up - tan * up.dot(tan)).normalized()
        side = tan.cross(up).normalized()
        s = scale(t)
        ring = [bm.verts.new(c + side * (x * s + math.copysign(grow, x) if x else 0) + up * (z * s + math.copysign(grow, z) if z else 0))
                for x, z in section]
        rings.append(ring)
    n = len(section)
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    if cap_tip:
        tip = bm.verts.new(_curve(t1) + _tangent(t1) * 0.09 + Vector((0, 0, -0.01)))
        last = rings[-1]
        for k in range(n):
            bm.faces.new((last[k], last[(k + 1) % n], tip))
    else:
        bm.faces.new(rings[-1])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    _link(obj, col)
    return obj


def ylathe(name, prof, y0, col, seg=24, sx=1.0):
    """A lathe along +Y (towards the pommel): prof is (radius, distance back) from y0; sx squashes it."""
    pts = [(0.0, prof[0][1])] + prof + [(0.0, prof[-1][1])]
    o = lathe(name, pts, col, seg)
    o.rotation_euler = (math.radians(-90), 0, 0)  # +Z -> +Y
    o.location = (0, y0, 0)
    o.scale = (sx, 1, 1)
    return o


def _keep_origin(obj):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.view_layer.objects:
        o.select_set(o == obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = True
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(30))
    except Exception:
        pass
    return obj


def make_katana():
    col = _collection("Katana")
    for o in list(col.objects):
        bpy.data.objects.remove(o)

    # blade: spine on top, a ridge line either side, a sharp edge underneath; it narrows to the tip
    section = [(0.0, 0.05), (0.016, 0.042), (0.02, 0.005), (0.0, -0.052), (-0.02, 0.005), (-0.016, 0.042)]
    blade = sweep("Blade", section, col, stations=30, t0=0.06, scale=lambda t: 1.0 - 0.32 * t)

    # guard: the collar at the blade's base, the round guard, the pommel cap
    parts = []
    parts.append(box("Habaki", (0.055, 0.1, 0.13), (0, -0.07, 0.0), col))
    parts.append(ylathe("Tsuba", [(0.13, -0.02), (0.135, -0.01), (0.135, 0.01), (0.13, 0.02)], 0, col, seg=32, sx=0.85))
    parts.append(ylathe("Fuchi", [(0.05, 0.02), (0.052, 0.07)], 0, col, seg=20, sx=0.75))
    parts.append(ylathe("Kashira", [(0.052, GRIP - 0.02), (0.054, GRIP + 0.02), (0.045, GRIP + 0.05), (0.02, GRIP + 0.06)],
                        0, col, seg=20, sx=0.75))
    guard = join(parts, "Guard")

    # grip: an oval handle with ridges for the wrap
    prof = [(0.046, 0.07)]
    n = 10
    for i in range(n):
        y0 = 0.07 + (GRIP - 0.09) * i / n
        y1 = 0.07 + (GRIP - 0.09) * (i + 0.5) / n
        prof += [(0.046, y0 + 0.005), (0.052, y1), (0.046, y0 + (GRIP - 0.09) / n - 0.005)]
    prof.append((0.046, GRIP - 0.02))
    grip = ylathe("Grip", prof, 0, col, seg=16, sx=0.75)

    # saya: the scabbard, the blade's curve but fatter, a gold mouth ring and a gold end cap
    sec = [(0.0, 0.075), (0.04, 0.05), (0.045, 0.0), (0.03, -0.065), (0.0, -0.075), (-0.03, -0.065), (-0.045, 0.0), (-0.04, 0.05)]
    saya = sweep("Saya", sec, col, stations=30, t0=0.0, t1=1.05, scale=lambda t: 1.0 - 0.18 * t, cap_tip=False)

    out = {}
    for o in (blade, guard, grip, saya):
        _keep_origin(o)
        out[o.name] = {"tris": tris(o), "size": [round(x, 3) for x in o.dimensions]}
    return out


def export_katana():
    col = bpy.data.collections["Katana"]
    for o in bpy.context.view_layer.objects:
        o.select_set(o.name in col.objects and o.type == "MESH")
    path = os.path.join(OUT, "Katana.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", use_mesh_modifiers=True)
    return path


def render_katana(path=None):
    scene = bpy.context.scene
    for c in scene.collection.children:
        c.hide_render = c.name != "Katana"
    cam = bpy.data.objects.get("KatanaCam")
    if not cam:
        cam = bpy.data.objects.new("KatanaCam", bpy.data.cameras.new("KatanaCam"))
        scene.collection.objects.link(cam)
    cam.data.lens = 50
    cam.location = (4.6, -0.5, 0.9)
    cam.rotation_euler = (Vector((0, -0.55, 0.05)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    if not bpy.data.objects.get("Key"):
        light = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
        scene.collection.objects.link(light)
        light.data.energy = 4
        light.rotation_euler = (math.radians(55), 0, math.radians(35))
    looks = {"Blade": ((0.8, 0.82, 0.85), 0.2, 1.0), "Guard": ((0.75, 0.55, 0.15), 0.35, 1.0),
             "Grip": ((0.05, 0.06, 0.12), 0.7, 0.0), "Saya": ((0.03, 0.03, 0.035), 0.25, 0.0)}
    for name, (rgb, rough, metal) in looks.items():
        mat = bpy.data.materials.get("K_" + name) or bpy.data.materials.new("K_" + name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        o = bpy.data.objects[name]
        o.data.materials.clear()
        o.data.materials.append(mat)
    # for the preview only: the scabbard drawn lower, so both show
    saya = bpy.data.objects["Saya"]
    saya.location = (0, 0, -0.35)
    scene.world = scene.world or bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.42, 0.32, 1)
    scene.render.resolution_x, scene.render.resolution_y = 1200, 600
    scene.render.filepath = path or os.path.join(OUT, "Katana_preview.png")
    bpy.ops.render.render(write_still=True)
    saya.location = (0, 0, 0)
    return scene.render.filepath
