"""The Bishop Snipe rifle (a bolt-action sniper with a scope and bipod), built in Blender.

Run inside Blender: exec(open(path).read()); make_rifle(); export_rifle(); render_rifle().
Units are studs. The bore axis runs along Y with the muzzle towards -Y (in-game -Z, the rifle's
front); the origin is on the bore axis above the trigger. Four mesh objects, all sharing that origin,
so the 3D Importer keeps them lined up:
  Stock  (wood)          Metal (receiver, barrel, scope, bipod, magazine)
  Bolt   (slides back)   Lens  (the scope glass)
"""
import bpy
import bmesh
import math
import os
from mathutils import Matrix

exec(open(r"C:\Users\liter\Documents\CLAUDE\chess\art\pieces\make_sets.py").read().split("# --- Classic")[0])
OUT = r"C:\Users\liter\Documents\CLAUDE\chess\art\props"  # (after the helpers, which set their own OUT)


def tube(name, prof, y0, col, z=0.0, x=0.0, seg=24):
    """A lathe along -Y: prof is (radius, distance forward) from the start at y0."""
    pts = [(0.0, prof[0][1])] + prof + [(0.0, prof[-1][1])]
    o = lathe(name, pts, col, seg)
    o.rotation_euler = (math.radians(90), 0, 0)  # +Z (forward) -> -Y
    o.location = (x, y0, z)
    return o


def cyl(name, r, a, b, col, seg=12):
    """A thin rod from point a to point b."""
    from mathutils import Vector
    a, b = Vector(a), Vector(b)
    d = b - a
    o = lathe(name, [(0, 0), (r, 0), (r, d.length), (0, d.length)], col, seg)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    o.location = a
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
        bpy.ops.object.shade_auto_smooth(angle=math.radians(35))
    except Exception:
        pass
    return obj


def make_rifle():
    col = _collection("Rifle")

    # stock: a side profile (y, z), butt at +Y, forend under the barrel, a pistol grip
    prof = [(1.02, 0.05), (0.55, 0.04), (0.40, -0.02), (0.28, -0.065), (-0.78, -0.065), (-0.86, -0.10),
            (-0.82, -0.17), (-0.05, -0.17), (0.17, -0.17), (0.21, -0.40), (0.33, -0.43), (0.37, -0.21),
            (0.52, -0.17), (0.98, -0.33), (1.04, -0.34)]
    stock = silhouette("Stock", list(reversed(prof)), 0.13, col, bevel=0.025)
    pad = box("Pad", (0.14, 0.05, 0.40), (0, 1.055, -0.145), col)
    cheek = box("Cheek", (0.1, 0.32, 0.05), (0, 0.72, 0.06), col)
    stock = join([stock, pad, cheek], "Stock")

    # metal: receiver, barrel + muzzle brake, scope + rings + turrets, magazine, trigger guard, bipod
    parts = []
    parts.append(box("Receiver", (0.105, 0.62, 0.12), (0, 0.04, 0.0), col))
    parts.append(tube("Barrel", [(0.042, 0.0), (0.04, 0.4), (0.032, 1.25)], -0.27, col, seg=20))
    parts.append(tube("Brake", [(0.055, 0.0), (0.058, 0.04), (0.058, 0.18), (0.05, 0.2)], -1.52, col, seg=8))
    parts.append(tube("Scope", [(0.05, 0.0), (0.05, 0.06), (0.042, 0.1), (0.042, 0.58), (0.05, 0.62),
                                (0.075, 0.74), (0.078, 0.82)], 0.46, col, z=0.17, seg=24))
    for y in (0.22, -0.12):
        parts.append(box("Ring", (0.06, 0.05, 0.13), (0, y, 0.095), col))
    parts.append(cyl("TurretTop", 0.03, (0, 0.05, 0.2), (0, 0.05, 0.26), col))
    parts.append(cyl("TurretSide", 0.03, (0.03, 0.05, 0.17), (0.09, 0.05, 0.17), col))
    parts.append(box("Mag", (0.075, 0.16, 0.2), (0, -0.04, -0.2), col, rot=(math.radians(-8), 0, 0)))
    parts.append(box("Guard", (0.03, 0.2, 0.025), (0, 0.12, -0.27), col))
    parts.append(box("Trigger", (0.02, 0.025, 0.08), (0, 0.13, -0.21), col, rot=(math.radians(15), 0, 0)))
    parts.append(box("BipodMount", (0.08, 0.06, 0.05), (0, -0.7, -0.19), col))
    for s in (-1, 1):
        parts.append(cyl("Leg", 0.018, (s * 0.03, -0.7, -0.2), (s * 0.13, -0.78, -0.62), col))
        parts.append(cyl("Foot", 0.03, (s * 0.13, -0.78, -0.6), (s * 0.13, -0.78, -0.64), col))
    metal = join(parts, "Metal")

    # bolt: the handle out of the right side with a ball knob (slides back along +Y in game)
    bolt = join([cyl("BoltArm", 0.022, (0.05, 0.2, 0.03), (0.17, 0.22, -0.03), col),
                 sphere("Knob", 0.045, (0.18, 0.225, -0.04), col, seg=16, ring=8)], "Bolt")

    # lens: the two glass discs
    lens = join([tube("Front", [(0.07, 0.0), (0.07, 0.01)], -0.355, col, z=0.17, seg=24),
                 tube("Back", [(0.045, 0.0), (0.045, 0.01)], 0.465, col, z=0.17, seg=24)], "Lens")

    out = {}
    for o in (stock, metal, bolt, lens):
        _keep_origin(o)
        out[o.name] = {"tris": tris(o), "size": [round(x, 3) for x in o.dimensions]}
    return out


def export_rifle():
    col = bpy.data.collections["Rifle"]
    for o in bpy.context.view_layer.objects:
        o.select_set(o.name in col.objects and o.type == "MESH")
    path = os.path.join(OUT, "Sniper.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                             axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", use_mesh_modifiers=True)
    return path


def render_rifle(path=None):
    scene = bpy.context.scene
    for c in scene.collection.children:
        c.hide_render = c.name != "Rifle"
    cam = bpy.data.objects.get("RifleCam")
    if not cam:
        cam = bpy.data.objects.new("RifleCam", bpy.data.cameras.new("RifleCam"))
        scene.collection.objects.link(cam)
    cam.data.lens = 50
    cam.location = (4.2, -0.6, 1.0)
    from mathutils import Vector
    cam.rotation_euler = (Vector((0, -0.25, -0.05)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    if not bpy.data.objects.get("Key"):
        light = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
        scene.collection.objects.link(light)
        light.data.energy = 4
        light.rotation_euler = (math.radians(55), 0, math.radians(35))
    looks = {"Stock": (0.33, 0.17, 0.08), "Metal": (0.06, 0.06, 0.065), "Bolt": (0.5, 0.5, 0.52), "Lens": (0.6, 0.05, 0.05)}
    for name, rgb in looks.items():
        mat = bpy.data.materials.get("R_" + name) or bpy.data.materials.new("R_" + name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Roughness"].default_value = 0.45
        o = bpy.data.objects[name]
        o.data.materials.clear()
        o.data.materials.append(mat)
    scene.world = scene.world or bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.42, 0.32, 1)
    scene.render.resolution_x, scene.render.resolution_y = 1200, 600
    scene.render.filepath = path or os.path.join(OUT, "Sniper_preview.png")
    bpy.ops.render.render(write_still=True)
    return scene.render.filepath
