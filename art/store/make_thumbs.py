"""Thumbnails 2-5 for CHESS?? (vault Design/Store Art), rendered in Blender; art/store/finish_thumbs.py
adds the titles and builds the 2 x 2 abilities panel.

Run inside Blender:
    exec(open(r"C:\\Users\\liter\\Documents\\CLAUDE\\chess\\art\\store\\make_thumbs.py").read())
    render_thumbs()
writes art/store/out/:
  pass_passant_render.png   the pawn with a katana mid-cut, teal slashes (transparent, for thumb 2's panel;
                            the other three panels reuse the pass renders)
  thumb_dodge_render.png    3: the black king leaning out of the bullet's path, a grey afterimage where it
                            stood, the trail passing through it
  thumb_trophy_render.png   4: the champion (a blocky avatar) on a gold podium holding the trophy high, a
                            cheering crowd in front, confetti, spotlights (make_crowd)
  thumb_versus_render.png   5: two avatars playing at a park table like the lobby's, a robot head floating
                            by for "or bots" (make_table_match)
(make_trophy / make_versus are the earlier drafts, kept for reference.)
"""
import bpy
import math
import os
import random
from mathutils import Vector

exec(open(r"C:\Users\liter\Documents\CLAUDE\chess\art\store\make_passes.py").read())
exec(open(os.path.join(ART, "props", "make_katana.py")).read().split("def export_katana")[0])
OUT = os.path.join(ART, "store", "out")


def _start(name):
    scene = bpy.context.scene
    if scene.world:  # (make_trophy lights the world; everything else wants it dark)
        scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.0
    for c in list(scene.collection.children):
        c.hide_render = True
    col = _collection(name)
    _clear(col)
    col.hide_render = False
    return col


def _board(col, light, dark, rough=0.4, coat=0.2, frame=(0.05, 0.02, 0.015)):
    lm = _mat(col.name + "Light", light, rough=rough, coat=coat)
    dm = _mat(col.name + "Dark", dark, rough=rough, coat=coat)
    for f in range(8):
        for r in range(8):
            sq = box("Sq", (S * 0.995, S * 0.995, 0.12), tuple(_sq(f, r) + Vector((0, 0, -0.06))), col)
            _assign(sq, lm if (f + r) % 2 == 1 else dm)
    fr = box("Frame", (8 * S + 0.6, 8 * S + 0.6, 0.1), (0, 0, -0.1), col)
    _assign(fr, _mat(col.name + "Frame", frame, rough=0.4))


def _translucent(name, color, strength, alpha):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1)
    em.inputs["Strength"].default_value = strength
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = alpha
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def _backdrop(col, colour, loc=(-4, 14, 3), size=(60, 30), scale=(4.0, 2.2, 1), centre=(0.5, 0.5), strength=1.2):
    bg = _emission_plane(col.name + "Backdrop", size, loc, (math.radians(90), 0, 0), col, (1, 1, 1), 1)
    _glow_backdrop(bg, scale, (-scale[0] * centre[0], -scale[1] * centre[1], 0), strength, soft=0.0)
    ramp = [n for n in bg.data.materials[0].node_tree.nodes if n.type == "VALTORGB"][0]
    ramp.color_ramp.elements[1].color = (*colour, 1)
    return bg


def make_passant():
    """The pawn with a katana mid-cut, two teal slash marks hanging in the air (transparent render)."""
    col = _start("Pass")
    ivory = _mat("PassIvory", (0.93, 0.91, 0.86), rough=0.28, coat=0.6)
    p = classic_p(col)
    _assign(p, ivory)
    p.rotation_euler = (0, 0, math.radians(-20))
    make_katana()
    kc = bpy.data.collections["Katana"]
    looks = {"Blade": _mat("KBlade", (0.85, 0.87, 0.9), rough=0.15, metal=1.0),
             "Guard": _mat("KGuard", (0.8, 0.6, 0.18), rough=0.25, metal=1.0),
             "Grip": _mat("KGrip", (0.05, 0.06, 0.14), rough=0.7)}
    sword = bpy.data.objects.new("Sword", None)
    col.objects.link(sword)
    for o in list(kc.objects):
        kc.objects.unlink(o)
        base = o.name.split(".")[0]
        if base == "Saya":
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        col.objects.link(o)
        if base in looks:
            _assign(o, looks[base])
        o.parent = sword
    kc.hide_render = True
    # held out to the pawn's side, the blade swept up and across mid-cut
    sword.location = (0.45, -0.35, 0.85)
    sword.rotation_euler = (math.radians(25), math.radians(-35), math.radians(-60))
    sword.scale = (1.05, 1.05, 1.05)
    teal = (0.35, 0.95, 0.85)
    s1 = _emission_plane("Slash1", (2.6, 2.6), (-0.1, -0.6, 1.05), (0, 0, 0), col, teal, 8, image=os.path.join(VFX, "slash.png"))
    s2 = _emission_plane("Slash2", (2.2, 2.2), (0.2, -0.7, 0.75), (0, 0, 0), col, (0.8, 1.0, 0.95), 10, image=os.path.join(VFX, "slash.png"))
    cam = _camera(col, (1.4, -5.4, 1.5), (0.1, 0, 0.9), 50)
    for o, spin in ((s1, 35), (s2, -55)):
        o.rotation_euler = (cam.location - o.location).to_track_quat("Z", "Y").to_euler()
        o.rotation_euler.rotate_axis("Z", math.radians(spin))
    _lights(col, rim=teal)


def make_dodge():
    """Thumbnail 3: the black king sways out of the bullet's path (Snipe's king dodge)."""
    col = _start("Dodge")
    _board(col, (0.15, 0.022, 0.022), (0.012, 0.01, 0.01), rough=0.5, coat=0.08)
    ebony = _mat("DodgeEbony", (0.035, 0.033, 0.035), rough=0.25, coat=0.8)
    spot = _sq(3, 3)
    king = classic_k(col)
    _assign(king, ebony)
    king.location = spot + Vector((0.55, 0.15, 0))
    king.rotation_euler = (math.radians(4), math.radians(26), math.radians(-15))  # leaning hard to its left
    ghost = classic_k(col)
    _assign(ghost, _translucent("DodgeGhost", (0.75, 0.75, 0.8), 1.3, 0.55))
    ghost.location = spot
    # the bullet, from the left out of frame, straight through the afterimage's head
    a = spot + Vector((-9, -2.2, 1.55))
    b = spot + Vector((6, 1.5, 1.55))
    trail = cyl("Trail", 0.035, tuple(a), tuple(b), col, seg=10)
    _assign(trail, _mat("DodgeTrail", (1, 0.9, 0.7), emit=(1.0, 0.85, 0.6), strength=55))
    halo = cyl("TrailHalo", 0.1, tuple(a), tuple(b), col, seg=10)
    _assign(halo, _mat("DodgeHalo", (1, 0.3, 0.1), emit=(1.0, 0.25, 0.08), strength=6))
    # a white bishop far down the board, the shooter, to read the story
    shooter = classic_b(col)
    _assign(shooter, _mat("DodgeIvory", (0.93, 0.91, 0.86), rough=0.28, coat=0.6))
    shooter.location = _sq(0, 1) + Vector((-0.3, -0.4, 0))
    _backdrop(col, (0.8, 0.05, 0.03), centre=(0.55, 0.5))
    cam = _camera(col, tuple(spot + Vector((1.6, -6.2, 2.0))), tuple(spot + Vector((-0.2, 0.3, 1.0))), 40)
    _lights(col, rim=(1.0, 0.25, 0.15))
    p = bpy.data.objects.new("DodgeLight", bpy.data.lights.new("DodgeLight", "POINT"))
    col.objects.link(p)
    p.location = spot + Vector((0, -0.6, 1.6))
    p.data.energy = 250
    p.data.color = (1.0, 0.6, 0.3)


def make_trophy():
    """Thumbnail 4: a gold trophy with a white king on top, confetti, two spotlights."""
    col = _start("Trophy")
    gold = _mat("TrophyGold", (1.0, 0.72, 0.22), rough=0.18, metal=1.0)
    base_m = _mat("TrophyBase", (0.06, 0.05, 0.08), rough=0.3, coat=0.6)
    plinth = lathe("Plinth", [(0, 0), (1.0, 0), (1.0, 0.45), (0.85, 0.5), (0.85, 0.75), (0, 0.75)], col)
    _assign(plinth, base_m)
    cup = lathe("Cup", [(0, 0.75), (0.55, 0.75), (0.55, 0.85), (0.22, 0.95), (0.16, 1.35), (0.3, 1.5), (0.75, 1.7),
                        (0.95, 2.2), (1.0, 2.75), (0.92, 2.8), (0, 2.8)], col)
    _assign(cup, gold)
    for side in (-1, 1):
        _torus(col, "Handle", (side * 1.05, 0, 2.25), (math.radians(90), 0, 0), 0.35, 0.07, gold, scale=(0.8, 1.2, 1))
    for o in (plinth, cup):  # (lathe meshes come out faceted)
        for poly in o.data.polygons:
            poly.use_smooth = True
    king = classic_k(col)
    _assign(king, _mat("TrophyIvory", (0.95, 0.93, 0.88), rough=0.25, coat=0.6))
    king.location = (0, 0, 2.8)
    # confetti
    rnd = random.Random(9)
    colours = [(1, 0.3, 0.35), (0.35, 0.8, 1), (1, 0.85, 0.25), (0.45, 0.95, 0.5), (0.85, 0.5, 1)]
    for i in range(70):
        c = colours[i % len(colours)]
        m = _mat("Confetti%d" % (i % len(colours)), c, rough=0.4, emit=c, strength=0.6)
        pc = box("Confetti", (0.16, 0.06, 0.005), (rnd.uniform(-4.5, 4.5), rnd.uniform(-1.5, 2.5), rnd.uniform(0.4, 5.5)), col,
                 rot=(rnd.uniform(0, 6.3), rnd.uniform(0, 6.3), rnd.uniform(0, 6.3)))
        _assign(pc, m)
    _backdrop(col, (0.25, 0.12, 0.6), loc=(0, 10, 3), centre=(0.5, 0.55), strength=1.4)
    cam = _camera(col, (0, -13.5, 2.8), (0, 0, 2.45), 42)
    _lights(col, rim=(1.0, 0.8, 0.4))
    # a soft warm environment for the gold to reflect (a black world made it look banded)
    w = bpy.context.scene.world
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.42, 0.7, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    for side in (-1, 1):
        sl = bpy.data.objects.new("Spot", bpy.data.lights.new("Spot", "SPOT"))
        col.objects.link(sl)
        sl.data.energy = 1800
        sl.data.spot_size = math.radians(30)
        sl.data.color = (1.0, 0.9, 0.7)
        sl.location = (side * 3.5, -3.0, 7.5)
        sl.rotation_euler = (Vector((0, 0, 2.4)) - sl.location).to_track_quat("-Z", "Y").to_euler()


def make_versus():
    """Thumbnail 5: the white and black kings face off over the park's green board; a robot head by
    the black king (play bots too)."""
    col = _start("Versus")
    _board(col, (0.86, 0.86, 0.72), (0.27, 0.42, 0.18), rough=0.35, coat=0.3, frame=(0.32, 0.22, 0.12))
    wk = classic_k(col)
    _assign(wk, _mat("VsIvory", (0.95, 0.93, 0.88), rough=0.25, coat=0.6))
    wk.location = _sq(3, 3) + Vector((-0.2, -0.1, 0))
    wk.rotation_euler = (0, math.radians(-6), math.radians(-70))
    bk = classic_k(col)
    _assign(bk, _mat("VsEbony", (0.035, 0.033, 0.035), rough=0.25, coat=0.8))
    bk.location = _sq(4, 3) + Vector((0.3, 0.1, 0))
    bk.rotation_euler = (0, math.radians(6), math.radians(70))
    # a few pieces around for a mid-game feel
    for fn, f, r, colr in ((classic_p, 2, 1, "w"), (classic_n, 1, 2, "w"), (classic_p, 5, 5, "b"), (classic_b, 6, 4, "b"),
                           (classic_r, 0, 5, "b"), (classic_p, 6, 2, "w")):
        o = fn(col)
        o.location = _sq(f, r)
        _assign(o, bpy.data.materials["VsIvory" if colr == "w" else "VsEbony"])
    # the robot: a rounded box head, two glowing eyes, an antenna, floating by the black king
    head = box("RobotHead", (0.7, 0.55, 0.55), tuple(_sq(5, 3) + Vector((0.6, 0.3, 2.3))), col)
    bev = head.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.12
    bev.segments = 4
    _assign(head, _mat("RobotMetal", (0.55, 0.62, 0.72), rough=0.3, metal=0.6))
    eye = _mat("RobotEye", (0.3, 0.9, 1), emit=(0.3, 0.9, 1.0), strength=8)
    for side in (-1, 1):
        e = sphere("Eye", 0.075, tuple(head.location + Vector((side * 0.16, -0.28, 0.04))), col, seg=12, ring=6)
        _assign(e, eye)
    ant = cyl("Antenna", 0.02, tuple(head.location + Vector((0, 0, 0.27))), tuple(head.location + Vector((0, 0, 0.55))), col)
    _assign(ant, bpy.data.materials["RobotMetal"])
    tipb = sphere("AntennaTip", 0.06, tuple(head.location + Vector((0, 0, 0.58))), col, seg=12, ring=6)
    _assign(tipb, _mat("RobotTip", (1, 0.3, 0.3), emit=(1.0, 0.3, 0.3), strength=6))
    _backdrop(col, (0.35, 0.65, 1.0), centre=(0.5, 0.6), strength=1.3)
    cam = _camera(col, tuple(_sq(3.5, 3) + Vector((0, -6.6, 2.3))), tuple(_sq(3.5, 3) + Vector((0.2, 0.4, 1.25))), 40)
    _lights(col, rim=(1.0, 0.95, 0.85))


# --- blocky avatars (R6 proportions, as in the game: legs 2, torso 2, head ~1.1 studs) ---------------
# character(col, pos, facing, look, pose) builds one under an Empty: its feet at pos, facing `facing`
# radians about Z (0 = the face towards -Y). pose: limb angles in degrees about each limb's pivot
#   { "armL": (x, y), "armR": (x, y), "legL": x, "legR": x }  x: 0 = hanging, 180 = straight up,
#   -90 = forward; y: out to the side.  look = { skin, shirt, pants, hat? }
from mathutils import Matrix

SKINS = [(0.96, 0.8, 0.19), (0.92, 0.72, 0.56), (0.62, 0.42, 0.27), (0.98, 0.86, 0.72), (0.42, 0.28, 0.18)]
SHIRTS = [(0.85, 0.15, 0.15), (0.15, 0.45, 0.9), (0.15, 0.65, 0.3), (0.95, 0.75, 0.1), (0.55, 0.25, 0.85),
          (0.95, 0.45, 0.1), (0.9, 0.9, 0.92), (0.1, 0.1, 0.12), (0.95, 0.4, 0.65), (0.1, 0.7, 0.75)]
PANTS = [(0.12, 0.18, 0.4), (0.15, 0.15, 0.17), (0.35, 0.25, 0.15), (0.2, 0.45, 0.25), (0.45, 0.45, 0.5)]


def _cmat(rgb, rough=0.55):
    key = "Av_%d_%d_%d" % tuple(int(c * 255) for c in rgb)
    return bpy.data.materials.get(key) or _mat(key, rgb, rough=rough)


def _limb(col, name, size, pivot, offset, mat, root, bevel=0.07):
    o = box(name, size, (0, 0, 0), col)
    o.data.transform(Matrix.Translation(Vector(offset)))
    m = o.modifiers.new("Bevel", "BEVEL")
    m.width = bevel
    m.segments = 3
    o.parent = root
    o.location = pivot
    _assign(o, mat)
    return o


def character(col, pos, facing=0.0, look=None, pose=None, scale=1.0):
    look = look or {}
    pose = pose or {}
    root = bpy.data.objects.new("Avatar", None)
    col.objects.link(root)
    root.location = pos
    root.rotation_euler = (0, 0, facing)
    root.scale = (scale, scale, scale)
    skin = _cmat(look.get("skin", SKINS[0]))
    shirt = _cmat(look.get("shirt", SHIRTS[1]))
    pants = _cmat(look.get("pants", PANTS[0]))
    _limb(col, "Torso", (2, 1, 2), (0, 0, 3), (0, 0, 0), shirt, root)
    sleeves = look.get("sleeves", True)
    for side, key in ((-1, "armL"), (1, "armR")):
        a = _limb(col, "Arm", (1, 1, 2), (side * 1.5, 0, 3.5), (0, 0, -0.5), shirt if sleeves else skin, root)
        x, y = pose.get(key, (0, 0))
        a.rotation_euler = (math.radians(x), math.radians(side * y), 0)
        if sleeves:  # the hands, skin coloured, at the arm's end
            h = _limb(col, "Hand", (0.98, 0.98, 0.5), (0, 0, -1.25), (0, 0, 0), skin, a, bevel=0.06)
            h.parent = a
    for side, key in ((-1, "legL"), (1, "legR")):
        l = _limb(col, "Leg", (1, 1, 2), (side * 0.5, 0, 2), (0, 0, -1), pants, root)
        l.rotation_euler = (math.radians(pose.get(key, 0)), 0, 0)
    # the head: a rounded cylinder, with a simple face on its -Y side
    head = lathe("Head", [(0, 0), (0.56, 0), (0.62, 0.08), (0.64, 0.25), (0.64, 0.85), (0.62, 1.02), (0.56, 1.1), (0, 1.1)], col, seg=32)
    for poly in head.data.polygons:
        poly.use_smooth = True
    head.parent = root
    head.location = (0, 0, 4.02)
    _assign(head, skin)
    ink = _cmat((0.05, 0.04, 0.04), rough=0.3)
    for side in (-1, 1):
        e = sphere("Eye", 1.0, (side * 0.2, -0.6, 0.67), col, seg=12, ring=8)
        e.scale = (0.075, 0.04, 0.13)
        e.parent = head
        _assign(e, ink)
    pts = [Vector((math.sin(t) * 0.26, -0.63 + abs(math.sin(t)) * 0.04, 0.38 - math.cos(t) * 0.1)) for t in
           [(-1.1 + 2.2 * i / 10) for i in range(11)]]
    cu = bpy.data.curves.new("Smile", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.035
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p.x, p.y, p.z, 1)
    smile = bpy.data.objects.new("Smile", cu)
    col.objects.link(smile)
    smile.parent = head
    smile.data.materials.append(ink)
    if look.get("hat"):
        hat_m = _cmat(look["hat"])
        brim = lathe("Brim", [(0, 0), (0.72, 0), (0.72, 0.06), (0, 0.06)], col, seg=32)
        brim.parent = head
        brim.location = (0, -0.05, 1.02)
        _assign(brim, hat_m)
        crown = lathe("Cap", [(0, 0), (0.66, 0), (0.6, 0.35), (0.3, 0.5), (0, 0.52)], col, seg=32)
        crown.parent = head
        crown.location = (0, 0, 1.05)
        _assign(crown, hat_m)
    return root


def _trophy_model(col, loc, s):
    gold = _mat("TrophyGold", (1.0, 0.72, 0.22), rough=0.18, metal=1.0)
    cup = lathe("Cup", [(0, 0), (0.45, 0), (0.45, 0.1), (0.18, 0.2), (0.13, 0.55), (0.25, 0.7), (0.62, 0.9),
                        (0.78, 1.35), (0.82, 1.8), (0.75, 1.85), (0, 1.85)], col)
    for poly in cup.data.polygons:
        poly.use_smooth = True
    cup.location = loc
    cup.scale = (s, s, s)
    _assign(cup, gold)
    for side in (-1, 1):
        _torus(col, "Handle", tuple(Vector(loc) + Vector((side * 0.85 * s, 0, 1.45 * s))), (math.radians(90), 0, 0),
               0.28 * s, 0.06 * s, gold, scale=(0.8, 1.2, 1))
    king = classic_k(col)
    _assign(king, _mat("TrophyIvory", (0.95, 0.93, 0.88), rough=0.25, coat=0.6))
    king.location = Vector(loc) + Vector((0, 0, 1.85 * s))
    king.scale = (s * 0.8, s * 0.8, s * 0.8)


def make_crowd():
    """Thumbnail 4: the champion on a gold podium, trophy held high; a cheering crowd in front of it
    (their backs to us, arms up), confetti, spotlights, a purple backdrop."""
    col = _start("Crowd")
    floor = box("Floor", (80, 60, 0.2), (0, 0, -0.1), col)
    _assign(floor, _mat("CrowdFloor", (0.08, 0.06, 0.12), rough=0.6))
    gold = _mat("PodiumGold", (1.0, 0.72, 0.22), rough=0.25, metal=1.0)
    podium = box("Podium", (6, 4, 4.5), (0, 5, 2.25), col)
    bev = podium.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.15
    bev.segments = 3
    _assign(podium, _mat("PodiumNavy", (0.12, 0.14, 0.4), rough=0.4, coat=0.5))
    band = box("PodiumBand", (6.1, 4.1, 0.4), (0, 5, 4.1), col)
    _assign(band, gold)
    one = box("One", (1.2, 0.1, 2.0), (0, 2.96, 2.0), col)
    _assign(one, gold)
    # the champion: arms up, the trophy over the head
    character(col, (0, 5, 4.5), 0.0, {"skin": SKINS[0], "shirt": (0.95, 0.75, 0.1), "pants": PANTS[1], "hat": (0.85, 0.12, 0.15)},
              {"armL": (150, 35), "armR": (180, 0)})  # left arm waving, right arm straight up
    _trophy_model(col, (1.5, 5, 9.55), 1.0)  # raised in the right hand, resting on it
    # the crowd: three rows, backs to the camera, cheering
    rnd = random.Random(21)
    poses = [{"armL": (165, 20), "armR": (165, 20)}, {"armL": (0, 5), "armR": (160, 25)}, {"armL": (150, 30), "armR": (0, 5)},
             {"armL": (175, 8), "armR": (175, 8)}, {"armL": (130, 40), "armR": (130, 40)}]
    for row, (y, n, x0) in enumerate(((-1.5, 7, -10.2), (-5.0, 8, -12.0))):
        for i in range(n):
            x = x0 + i * 3.4 + rnd.uniform(-0.5, 0.5)
            if row == 0 and abs(x) < 2.5:
                continue  # keep the champion in view
            look = {"skin": rnd.choice(SKINS), "shirt": rnd.choice(SHIRTS), "pants": rnd.choice(PANTS)}
            if rnd.random() < 0.25:
                look["hat"] = rnd.choice(SHIRTS)
            character(col, (x, y + rnd.uniform(-0.5, 0.5), 0), math.pi + rnd.uniform(-0.35, 0.35), look, rnd.choice(poses))
    # confetti
    colours = [(1, 0.3, 0.35), (0.35, 0.8, 1), (1, 0.85, 0.25), (0.45, 0.95, 0.5), (0.85, 0.5, 1)]
    for i in range(160):
        c = colours[i % len(colours)]
        m = _mat("Confetti%d" % (i % len(colours)), c, rough=0.4, emit=c, strength=0.6)
        pc = box("Confetti", (0.3, 0.12, 0.01), (rnd.uniform(-16, 16), rnd.uniform(-8, 10), rnd.uniform(4, 16)), col,
                 rot=(rnd.uniform(0, 6.3), rnd.uniform(0, 6.3), rnd.uniform(0, 6.3)))
        _assign(pc, m)
    _backdrop(col, (0.35, 0.15, 0.75), loc=(0, 20, 8), size=(120, 60), centre=(0.5, 0.45), strength=1.4)
    cam = _camera(col, (0, -22, 8.5), (0, 4, 8.0), 36)
    _lights(col, rim=(1.0, 0.8, 0.4))
    for side in (-1, 0, 1):
        sl = bpy.data.objects.new("Spot", bpy.data.lights.new("Spot", "SPOT"))
        col.objects.link(sl)
        sl.data.energy = 0 if side == 0 else 1800  # (the centre one is the WinnerSpot below)
        sl.data.spot_size = math.radians(22 if side == 0 else 35)
        sl.data.spot_blend = 0.4
        sl.data.color = (1.0, 0.92, 0.75) if side == 0 else (0.75, 0.6, 1.0)
        sl.location = (side * 9, -6, 18)
        sl.rotation_euler = (Vector((side * 1.5, 5 if side == 0 else -2, 5)) - sl.location).to_track_quat("-Z", "Y").to_euler()
    w = bpy.context.scene.world
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.35, 0.65, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.2
    # the winner's spotlight: a hard white spot straight down on the podium, a soft visible beam cone,
    # and a bright pool of light on the podium top
    hero_spot = bpy.data.objects.new("WinnerSpot", bpy.data.lights.new("WinnerSpot", "SPOT"))
    col.objects.link(hero_spot)
    hero_spot.data.energy = 16000
    hero_spot.data.spot_size = math.radians(16)
    hero_spot.data.spot_blend = 0.25
    hero_spot.data.color = (1.0, 0.97, 0.88)
    hero_spot.location = (0, 3.5, 24)
    hero_spot.rotation_euler = (Vector((0, 5, 6)) - hero_spot.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.mesh.primitive_cone_add(radius1=3.4, radius2=0.25, depth=19.5, location=(0, 4.6, 14.25), vertices=48)
    beam = bpy.context.active_object
    beam.name = "WinnerBeam"
    for c in beam.users_collection:
        c.objects.unlink(beam)
    col.objects.link(beam)
    m = bpy.data.materials.new("WinnerBeam")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1.0, 0.95, 0.8, 1)
    em.inputs["Strength"].default_value = 0.9
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.7
    inv = nt.nodes.new("ShaderNodeInvert")
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 0.35  # faint: a haze, not a solid cone
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    back = nt.nodes.new("ShaderNodeMath")
    back.operation = "MULTIPLY"
    nt.links.new(lw.outputs["Facing"], inv.inputs["Color"])
    nt.links.new(inv.outputs["Color"], mul.inputs[0])
    # only the cone's far wall glows (its back faces), so the light sits behind the winner, not over him
    nt.links.new(mul.outputs[0], back.inputs[0])
    nt.links.new(geo.outputs["Backfacing"], back.inputs[1])
    nt.links.new(back.outputs[0], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    beam.data.materials.append(m)
    m.use_backface_culling = False
    em.inputs["Strength"].default_value = 1.6
    mul.inputs[1].default_value = 0.55
    # a soft warm fill from the front so the champion's face reads
    fl = bpy.data.objects.new("WinnerFill", bpy.data.lights.new("WinnerFill", "AREA"))
    col.objects.link(fl)
    fl.data.energy = 900
    fl.data.size = 4
    fl.data.color = (1.0, 0.92, 0.8)
    fl.location = (0, -6, 9)
    fl.rotation_euler = (Vector((0, 5, 7)) - fl.location).to_track_quat("-Z", "Y").to_euler()
    pool = _emission_plane("WinnerPool", (5.2, 5.2), (0, 5, 4.53), (0, 0, 0), col, (1.0, 0.95, 0.8), 2.5,
                           image=os.path.join(VFX, "glow.png"))


def make_table_match():
    """Thumbnail 5: two avatars playing at a park table (as in the lobby), seen from the side; a little
    robot head floating by for 'or bots'."""
    col = _start("Match")
    G0 = -3.4  # the ground (the table top, with the board, is at 0)
    lawn = box("Lawn", (120, 120, 0.2), (0, 0, G0 - 0.1), col)
    _assign(lawn, _mat("MatchLawn", (0.3, 0.55, 0.2), rough=0.8))
    plaza = box("Plaza", (40, 40, 0.2), (0, 0, G0 - 0.05), col)
    _assign(plaza, _mat("MatchPlaza", (0.86, 0.78, 0.62), rough=0.7))
    _board(col, (0.86, 0.86, 0.72), (0.27, 0.42, 0.18), rough=0.35, coat=0.3, frame=(0.27, 0.42, 0.18))
    top = box("TableTop", (15, 15, 0.8), (0, 0, -0.55), col)
    _assign(top, _mat("MatchWood", (0.72, 0.52, 0.32), rough=0.45, coat=0.3))
    white = _mat("MatchWhite", (0.96, 0.96, 0.95), rough=0.4)
    for x in (-6.3, 6.3):
        for y in (-6.3, 6.3):
            leg = box("Leg", (1, 1, 2.6), (x, y, G0 + 1.3), col)
            _assign(leg, white)
    seat_m = _mat("MatchSeat", (0.42, 0.66, 0.31), rough=0.5)
    for side in (-1, 1):
        y = side * 10
        seat = box("Seat", (3, 3, 0.6), (0, y, G0 + 1.9), col)
        _assign(seat, seat_m)
        back = box("Back", (3, 0.4, 3.4), (0, y + side * 1.7, G0 + 3.9), col)
        _assign(back, white)
    # the pieces, mid-game
    ivory = _mat("VsIvory", (0.95, 0.93, 0.88), rough=0.25, coat=0.6)
    ebony = _mat("VsEbony", (0.035, 0.033, 0.035), rough=0.25, coat=0.8)
    for fn, f, r, c in ((classic_k, 6, 0, "w"), (classic_q, 3, 2, "w"), (classic_n, 5, 2, "w"), (classic_p, 4, 3, "w"),
                        (classic_p, 1, 1, "w"), (classic_b, 2, 3, "w"), (classic_k, 6, 7, "b"), (classic_r, 0, 7, "b"),
                        (classic_p, 3, 4, "b"), (classic_n, 5, 5, "b"), (classic_p, 6, 6, "b"), (classic_b, 1, 4, "b")):
        o = fn(col)
        o.location = _sq(f, r)
        _assign(o, ivory if c == "w" else ebony)
    # White sits at -Y (rank 1 side), Black at +Y. Seated: legs forward, the seat top at G0 + 2.2.
    seat_top = G0 + 2.2
    character(col, (0, -10.2, seat_top - 1.5), math.pi,
              {"skin": SKINS[0], "shirt": (0.15, 0.45, 0.9), "pants": PANTS[0], "hat": (0.9, 0.2, 0.2)},
              {"legL": -90, "legR": -90, "armL": (-55, 0), "armR": (-95, -8)})  # reaching for the knight
    character(col, (0, 10.2, seat_top - 1.5), 0.0,
              {"skin": SKINS[3], "shirt": (0.55, 0.25, 0.85), "pants": PANTS[1]},
              {"legL": -90, "legR": -90, "armL": (-150, -18), "armR": (-60, 0)})  # a hand to the chin, thinking
    # the robot head, floating by the black side
    head = box("RobotHead", (1.8, 1.4, 1.4), (-1, 8.2, 5.2), col)
    bev = head.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.22
    bev.segments = 4
    _assign(head, _mat("RobotMetal", (0.55, 0.62, 0.72), rough=0.3, metal=0.6))
    eye = _mat("RobotEye", (0.3, 0.9, 1), emit=(0.3, 0.9, 1.0), strength=8)
    for s in (-1, 1):  # (its face towards the camera, +X)
        e = sphere("Eye", 0.18, tuple(head.location + Vector((0.72, s * 0.38, 0.1))), col, seg=12, ring=6)
        _assign(e, eye)
    ant = cyl("Antenna", 0.04, tuple(head.location + Vector((0, 0, 0.55))), tuple(head.location + Vector((0, 0, 1.1))), col)
    _assign(ant, bpy.data.materials["RobotMetal"])
    tipb = sphere("AntennaTip", 0.12, tuple(head.location + Vector((0, 0, 1.15))), col, seg=12, ring=6)
    _assign(tipb, _mat("RobotTip", (1, 0.3, 0.3), emit=(1.0, 0.3, 0.3), strength=6))
    # trees and sky
    for (x, y, s) in ((-22, 26, 1.3), (12, 30, 1.1), (30, 18, 1.2), (-34, 8, 1.0)):
        tr = cyl("Trunk", 0.8 * s, (x, y, G0), (x, y, G0 + 8 * s), col, seg=12)
        _assign(tr, _mat("Trunk", (0.45, 0.3, 0.2), rough=0.8))
        for off, r in (((0, 0, 9.5), 4.5), ((2.4, 0.5, 8.2), 3.2), ((-2.2, -0.6, 8.6), 3.4)):
            b = sphere("Leaves", r * s, (x + off[0] * s, y + off[1] * s, G0 + off[2] * s), col, seg=20, ring=12)
            _assign(b, _mat("Leaves", (0.35, 0.65, 0.25), rough=0.8))
    cam = _camera(col, (17, 0, 7.0), (0, 0, 0.3), 24)  # side-on: White left, Black right
    _lights(col, rim=(1.0, 0.95, 0.85))
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    col.objects.link(sun)
    sun.data.energy = 5.0
    sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(40))
    w = bpy.context.scene.world  # a sky the camera sees past the backdrop
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.7, 1.0, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.3
    for o in col.objects:
        if o.name.startswith(("Leaves", "Trunk")):
            for poly in o.data.polygons:
                poly.use_smooth = True


def render_thumb(name, samples=96, scale=100):
    scene = bpy.context.scene
    _setup_look(samples)
    scene.render.film_transparent = False
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
    scene.render.resolution_percentage = scale
    scene.render.filepath = os.path.join(OUT, "thumb_%s_render.png" % name)
    bpy.ops.render.render(write_still=True)
    return scene.render.filepath


def render_thumbs(samples=96, scale=100):
    out = []
    make_passant()
    out.append(render_pass("passant", 1024, 64))
    for name, fn in (("dodge", make_dodge), ("trophy", make_crowd), ("versus", make_table_match)):
        fn()
        out.append(render_thumb(name, samples, scale))
    return out
