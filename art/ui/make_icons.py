"""Chess UI icon set (see the vault's Design/UI Style.md).

Writes one SVG per icon into art/ui/svg/ on a 512x512 artboard. Illustrator then opens each one,
saves the .ai master and exports the 256 px PNG (art/ui/illustrator_export.jsx).

House style (the "simulator" look): a chunky ink outline around the whole silhouette, flat colours
with a soft top-to-bottom gradient, ink detail lines, and a white shine. Each icon is a list of
items:
  ("shape", svg, colour)   outlined silhouette part, filled with the colour's gradient
  ("band", svg, colour, w)  a thick stroke (arcs, arrows, handles), outlined
  ("detail", svg, colour)  fill only, no outline (eyes, inner panels)
  ("line", svg, w)         an ink line (inner details)
  ("shine", svg)           white highlight at 40%
Run: python art/ui/make_icons.py
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "svg")
INK = "#0C140C"
OUTLINE = 40  # total outline stroke width (half of it shows outside the shape)

C = {
    "green": "#5BC236", "greenDark": "#3E9A22", "gold": "#FFC83D", "goldDark": "#E09A1A",
    "red": "#E8463A", "blue": "#3498DB", "purple": "#B03AA0", "pink": "#FF6FB5",
    "cream": "#F6F1DE", "white": "#FFFFFF", "grey": "#B8C2CC", "steel": "#DDE6EE",
    "brown": "#9A6232", "brownDark": "#6B3F1D", "black": "#3A3F47", "teal": "#26A69A",
    "yellow": "#FFD43B", "orange": "#FF8A3D", "sky": "#8FC9F2", "board": "#76964F",
}


def shade(hexc, k):
    r, g, b = int(hexc[1:3], 16), int(hexc[3:5], 16), int(hexc[5:7], 16)
    if k >= 1:
        r, g, b = (int(c + (255 - c) * (k - 1)) for c in (r, g, b))
    else:
        r, g, b = (int(c * k) for c in (r, g, b))
    return "#%02X%02X%02X" % (r, g, b)


def svg_for(items):
    grads, outline, fill, top = {}, [], [], []
    for it in items:
        kind = it[0]
        if kind == "shape":
            _, el, col = it
            gid = "g" + col[1:]
            grads[gid] = col
            outline.append(el.replace("/>", f' fill="{INK}" stroke="{INK}" stroke-width="{OUTLINE}" stroke-linejoin="round" stroke-linecap="round"/>'))
            fill.append(el.replace("/>", f' fill="url(#{gid})" stroke="{col}" stroke-width="6" stroke-linejoin="round"/>'))
        elif kind == "band":
            _, el, col, w = it
            outline.append(el.replace("/>", f' fill="none" stroke="{INK}" stroke-width="{w + OUTLINE}" stroke-linejoin="round" stroke-linecap="round"/>'))
            fill.append(el.replace("/>", f' fill="none" stroke="{col}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"/>'))
        elif kind == "detail":
            _, el, col = it
            fill.append(el.replace("/>", f' fill="{col}"/>'))
        elif kind == "line":
            _, el, w = it
            fill.append(el.replace("/>", f' fill="none" stroke="{INK}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"/>'))
        elif kind == "shine":
            top.append(it[1].replace("/>", ' fill="#FFFFFF" fill-opacity="0.45"/>'))
        elif kind == "inkfill":
            fill.append(it[1].replace("/>", f' fill="{INK}"/>'))
    defs = "".join(
        f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{shade(col, 1.25)}"/><stop offset="1" stop-color="{shade(col, 0.82)}"/></linearGradient>'
        for gid, col in grads.items())
    body = "".join(outline) + "".join(fill) + "".join(top)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">'
            f'<defs>{defs}</defs>{body}</svg>')


def poly(pts):
    return '<polygon points="' + " ".join(f"{x:.1f},{y:.1f}" for x, y in pts) + '"/>'


def star(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def gear(cx, cy, r_out, r_in, teeth):
    pts = []
    for i in range(teeth):
        base = i * 360 / teeth
        for da, r in ((-13, r_in), (-7, r_out), (7, r_out), (13, r_in)):
            a = math.radians(base + da)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def pawn(cx, base_y, s, col):
    """A chess pawn (s = scale, 1 = full icon size), bottom of the base at base_y."""
    def p(x, y):
        return f"{cx + x * s:.1f},{base_y + y * s:.1f}"
    body = (f'<path d="M{p(-62, -40)} C{p(-60, -110)} {p(-30, -150)} {p(-22, -190)} '
            f'L{p(22, -190)} C{p(30, -150)} {p(60, -110)} {p(62, -40)} Z"/>')
    return [
        ("shape", f'<rect x="{cx - 120 * s:.1f}" y="{base_y - 60 * s:.1f}" width="{240 * s:.1f}" height="{60 * s:.1f}" rx="{20 * s:.1f}"/>', col),
        ("shape", body, col),
        ("shape", f'<ellipse cx="{cx:.1f}" cy="{base_y - 195 * s:.1f}" rx="{58 * s:.1f}" ry="{18 * s:.1f}"/>', col),
        ("shape", f'<circle cx="{cx:.1f}" cy="{base_y - 262 * s:.1f}" r="{62 * s:.1f}"/>', col),
        ("shine", f'<ellipse cx="{cx - 22 * s:.1f}" cy="{base_y - 282 * s:.1f}" rx="{18 * s:.1f}" ry="{26 * s:.1f}"/>'),
    ]


def face(col):
    return [("shape", '<circle cx="256" cy="262" r="190"/>', col),
            ("shine", '<ellipse cx="180" cy="150" rx="56" ry="34" transform="rotate(-30 180 150)"/>')]


ICONS = {}

ICONS["play"] = [
    ("shape", '<path d="M176 96 Q150 96 150 124 L150 388 Q150 416 176 416 L410 282 Q440 256 410 230 Z"/>', C["green"]),
    ("shine", '<ellipse cx="215" cy="200" rx="22" ry="48" transform="rotate(-30 215 200)"/>'),
]

ICONS["bot"] = [
    ("band", '<line x1="256" y1="70" x2="256" y2="140"/>', C["grey"], 22),
    ("shape", '<circle cx="256" cy="66" r="30"/>', C["red"]),
    ("shape", '<rect x="86" y="230" width="44" height="110" rx="16"/>', C["grey"]),
    ("shape", '<rect x="382" y="230" width="44" height="110" rx="16"/>', C["grey"]),
    ("shape", '<rect x="110" y="140" width="292" height="270" rx="60"/>', C["sky"]),
    ("detail", '<rect x="150" y="190" width="212" height="110" rx="40" fill-opacity="1"/>', "#24354A"),
    ("detail", '<circle cx="208" cy="245" r="30"/>', "#7CF2FF"),
    ("detail", '<circle cx="304" cy="245" r="30"/>', "#7CF2FF"),
    ("detail", '<rect x="186" y="330" width="140" height="40" rx="14"/>', C["white"]),
    ("line", '<path d="M220 330 L220 370 M256 330 L256 370 M292 330 L292 370"/>', 10),
    ("shine", '<ellipse cx="160" cy="175" rx="16" ry="26" transform="rotate(30 160 175)"/>'),
]


def sword(angle):
    t = f' transform="rotate({angle} 256 256)"'
    return [
        ("shape", f'<path d="M222 76 L256 22 L290 76 L290 322 L222 322 Z"{t}/>', C["steel"]),
        ("shape", f'<rect x="160" y="312" width="192" height="44" rx="18"{t}/>', C["gold"]),
        ("shape", f'<rect x="234" y="350" width="44" height="92" rx="14"{t}/>', C["brown"]),
        ("shape", f'<circle cx="256" cy="458" r="30"{t}/>', C["gold"]),
    ]


ICONS["pvp"] = sword(-40) + sword(40) + [
    ("line", '<line x1="256" y1="80" x2="256" y2="300" transform="rotate(-40 256 256)"/>', 6),
    ("line", '<line x1="256" y1="80" x2="256" y2="300" transform="rotate(40 256 256)"/>', 6),
]

# tables: a little chessboard
board = [("shape", '<rect x="76" y="76" width="360" height="360" rx="34"/>', C["brownDark"])]
for r in range(4):
    for f in range(4):
        col = C["cream"] if (r + f) % 2 == 0 else C["board"]
        board.append(("detail", f'<rect x="{100 + f * 78}" y="{100 + r * 78}" width="78" height="78"/>', col))
board.append(("shine", '<rect x="100" y="100" width="312" height="40" rx="14"/>'))
ICONS["tables"] = board

ICONS["stats"] = ICONS["win"] = [
    ("band", '<path d="M150 150 C60 150 70 290 180 290"/>', C["gold"], 34),
    ("band", '<path d="M362 150 C452 150 442 290 332 290"/>', C["gold"], 34),
    ("shape", '<path d="M140 90 L372 90 L360 230 C350 320 300 350 256 350 C212 350 162 320 152 230 Z"/>', C["gold"]),
    ("shape", '<rect x="226" y="340" width="60" height="60" rx="10"/>', C["goldDark"]),
    ("shape", '<rect x="150" y="390" width="212" height="56" rx="18"/>', C["brown"]),
    ("detail", star(256, 210, 64, 28), C["white"]),
    ("shine", '<ellipse cx="185" cy="160" rx="18" ry="50" transform="rotate(10 185 160)"/>'),
]

ICONS["settings"] = [
    ("shape", gear(256, 256, 200, 160, 8), C["grey"]),
    ("detail", '<circle cx="256" cy="256" r="74"/>', "#5D6873"),
    ("detail", '<circle cx="256" cy="256" r="44"/>', C["steel"]),
    ("shine", '<ellipse cx="170" cy="150" rx="40" ry="22" transform="rotate(-40 170 150)"/>'),
]

ICONS["leave"] = [
    ("shape", '<rect x="96" y="60" width="250" height="400" rx="20"/>', C["brownDark"]),
    ("detail", '<rect x="126" y="92" width="190" height="340" rx="10"/>', "#2A1A0C"),
    ("shape", '<path d="M126 92 L270 120 L270 420 L126 432 Z"/>', C["brown"]),
    ("detail", '<circle cx="240" cy="270" r="16"/>', C["gold"]),
    ("shape", '<path d="M300 220 L380 220 L380 170 L470 256 L380 342 L380 292 L300 292 Z"/>', C["green"]),
    ("shine", '<rect x="146" y="120" width="26" height="160" rx="12"/>'),
]

ICONS["clock"] = [
    ("shape", '<rect x="226" y="40" width="60" height="50" rx="12"/>', C["red"]),
    ("shape", '<rect x="358" y="96" width="44" height="60" rx="12" transform="rotate(45 380 126)"/>', C["red"]),
    ("shape", '<circle cx="256" cy="280" r="190"/>', C["red"]),
    ("detail", '<circle cx="256" cy="280" r="148"/>', C["cream"]),
    ("line", '<path d="M256 280 L256 170 M256 280 L330 320"/>', 26),
    ("detail", '<circle cx="256" cy="280" r="22"/>', INK),
    ("line", '<path d="M256 148 L256 172 M388 280 L364 280 M256 412 L256 388 M124 280 L148 280"/>', 14),
    ("shine", '<ellipse cx="160" cy="170" rx="30" ry="16" transform="rotate(-40 160 170)"/>'),
]

ICONS["Classic"] = pawn(256, 482, 1.3, C["cream"])

ICONS["Abilities"] = [
    ("shape", star(240, 270, 200, 60, 4, -90), C["purple"]),
    ("shape", star(410, 110, 70, 22, 4, -90), C["pink"]),
    ("shape", star(410, 420, 50, 16, 4, -90), C["gold"]),
    ("shine", '<ellipse cx="215" cy="210" rx="16" ry="40" transform="rotate(20 215 210)"/>'),
]

ICONS["draw"] = pawn(158, 474, 0.9, C["cream"]) + pawn(354, 474, 0.9, C["black"])

ICONS["resign"] = [
    ("band", '<line x1="140" y1="60" x2="140" y2="460"/>', C["brown"], 30),
    ("shape", '<path d="M150 80 C230 50 300 120 410 80 L410 280 C300 320 230 250 150 280 Z"/>', C["white"]),
    ("shine", '<ellipse cx="220" cy="120" rx="40" ry="14" transform="rotate(-10 220 120)"/>'),
]

ICONS["snipe"] = [
    ("band", '<circle cx="256" cy="256" r="160"/>', C["red"], 40),
    ("band", '<path d="M256 40 L256 150 M256 362 L256 472 M40 256 L150 256 M362 256 L472 256"/>', C["red"], 34),
    ("shape", '<circle cx="256" cy="256" r="40"/>', C["red"]),
    ("shine", '<ellipse cx="165" cy="150" rx="12" ry="40" transform="rotate(45 165 150)"/>'),
]

ICONS["rematch"] = [
    ("band", '<path d="M110 250 A146 146 0 0 1 360 150"/>', C["green"], 52),
    ("shape", poly([(410, 80), (420, 220), (290, 180)]), C["green"]),
    ("band", '<path d="M402 262 A146 146 0 0 1 152 362"/>', C["green"], 52),
    ("shape", poly([(102, 432), (92, 292), (222, 332)]), C["green"]),
]

ICONS["review"] = [
    ("shape", '<rect x="80" y="260" width="90" height="170" rx="16"/>', C["blue"]),
    ("shape", '<rect x="211" y="170" width="90" height="260" rx="16"/>', C["gold"]),
    ("shape", '<rect x="342" y="80" width="90" height="350" rx="16"/>', C["green"]),
    ("band", '<line x1="60" y1="450" x2="452" y2="450"/>', C["grey"], 20),
    ("shine", '<rect x="95" y="275" width="18" height="70" rx="9"/>'),
    ("shine", '<rect x="226" y="185" width="18" height="90" rx="9"/>'),
    ("shine", '<rect x="357" y="95" width="18" height="110" rx="9"/>'),
]

ICONS["copy"] = [
    ("shape", '<rect x="96" y="80" width="320" height="380" rx="30"/>', C["brown"]),
    ("detail", '<rect x="136" y="130" width="240" height="300" rx="14"/>', C["white"]),
    ("shape", '<rect x="186" y="50" width="140" height="70" rx="20"/>', C["grey"]),
    ("line", '<path d="M176 200 L336 200 M176 260 L336 260 M176 320 L290 320"/>', 18),
]

ICONS["lock"] = [
    ("band", '<path d="M166 240 L166 170 A90 90 0 0 1 346 170 L346 240"/>', C["grey"], 44),
    ("shape", '<rect x="96" y="220" width="320" height="250" rx="40"/>', C["gold"]),
    ("detail", '<circle cx="256" cy="320" r="30"/>', INK),
    ("detail", '<rect x="242" y="320" width="28" height="70" rx="10"/>', INK),
    ("shine", '<rect x="120" y="240" width="200" height="30" rx="15"/>'),
]

ICONS["vip"] = ICONS["queen"] = [
    ("shape", '<path d="M80 380 L60 150 L170 250 L256 90 L342 250 L452 150 L432 380 Z"/>', C["gold"]),
    ("shape", '<rect x="80" y="370" width="352" height="80" rx="20"/>', C["goldDark"]),
    ("shape", '<circle cx="60" cy="140" r="30"/>', C["gold"]),
    ("shape", '<circle cx="256" cy="80" r="32"/>', C["gold"]),
    ("shape", '<circle cx="452" cy="140" r="30"/>', C["gold"]),
    ("detail", '<circle cx="256" cy="300" r="34"/>', C["red"]),
    ("detail", '<circle cx="156" cy="320" r="22"/>', C["blue"]),
    ("detail", '<circle cx="356" cy="320" r="22"/>', C["green"]),
    ("shine", '<ellipse cx="160" cy="300" rx="14" ry="40"/>'),
]

ICONS["lose"] = face(C["yellow"]) + [
    ("detail", '<ellipse cx="190" cy="230" rx="24" ry="32"/>', INK),
    ("detail", '<ellipse cx="322" cy="230" rx="24" ry="32"/>', INK),
    ("line", '<path d="M180 360 Q256 300 332 360"/>', 22),
    ("shape", '<path d="M340 280 C320 320 320 350 340 360 C360 350 360 320 340 280 Z"/>', C["sky"]),
]

ICONS["yes"] = [
    ("band", '<path d="M90 270 L210 390 L430 130"/>', C["green"], 80),
]
ICONS["no"] = [
    ("band", '<path d="M120 120 L392 392 M392 120 L120 392"/>', C["red"], 80),
]

ICONS["Beginner"] = [
    ("shape", '<ellipse cx="256" cy="290" rx="180" ry="170"/>', C["yellow"]),
    ("shape", '<path d="M190 110 Q256 40 290 110"/>', C["yellow"]),
    ("detail", '<circle cx="200" cy="260" r="22"/>', INK),
    ("detail", '<circle cx="312" cy="260" r="22"/>', INK),
    ("shape", poly([(226, 300), (286, 300), (256, 345)]), C["orange"]),
    ("detail", '<path d="M80 360 L130 330 L170 370 L210 330 L256 370 L302 330 L342 370 L382 330 L432 360 L432 460 L80 460 Z"/>', C["cream"]),
    ("line", '<path d="M80 360 L130 330 L170 370 L210 330 L256 370 L302 330 L342 370 L382 330 L432 360"/>', 12),
    ("shine", '<ellipse cx="170" cy="170" rx="40" ry="20" transform="rotate(-30 170 170)"/>'),
]
ICONS["Casual"] = face(C["yellow"]) + [
    ("detail", '<ellipse cx="190" cy="220" rx="22" ry="30"/>', INK),
    ("detail", '<ellipse cx="322" cy="220" rx="22" ry="30"/>', INK),
    ("line", '<path d="M160 310 Q256 400 352 310"/>', 24),
]
ICONS["Club"] = face(C["yellow"]) + [
    ("detail", '<path d="M90 190 L422 190 L410 230 C400 290 300 290 290 235 L266 220 L246 220 L222 235 C212 290 112 290 102 230 Z"/>', INK),
    ("line", '<path d="M200 330 Q256 370 312 330"/>', 22),
]
ICONS["Strong"] = [
    ("shape", '<path d="M256 470 C130 470 90 380 110 300 C125 240 170 220 170 160 C220 190 230 230 226 260 C260 210 250 120 220 50 C330 90 420 200 410 320 C400 420 340 470 256 470 Z"/>', C["orange"]),
    ("detail", '<path d="M256 450 C190 450 170 400 185 360 C200 330 225 320 230 290 C260 320 280 340 300 300 C330 340 330 380 320 410 C305 440 285 450 256 450 Z"/>', C["yellow"]),
]

ICONS["view2D"] = [
    ("shape", '<rect x="96" y="96" width="320" height="320" rx="24"/>', C["brownDark"]),
] + [("detail", f'<rect x="{116 + f * 70}" y="{116 + r * 70}" width="70" height="70"/>', C["cream"] if (r + f) % 2 == 0 else C["board"]) for r in range(4) for f in range(4)]
ICONS["view3D"] = [
    ("shape", poly([(256, 70), (436, 160), (256, 250), (76, 160)]), C["board"]),
    ("shape", poly([(76, 160), (256, 250), (256, 450), (76, 360)]), C["greenDark"]),
    ("shape", poly([(436, 160), (256, 250), (256, 450), (436, 360)]), "#2E6B1A"),
    ("shine", poly([(256, 100), (380, 160), (256, 220), (132, 160)])),
]
ICONS["tilt"] = [
    ("shape", poly([(150, 140), (362, 140), (452, 400), (60, 400)]), C["brownDark"]),
    ("detail", poly([(170, 160), (342, 160), (420, 380), (92, 380)]), C["cream"]),
    ("line", '<path d="M213 160 L174 380 M256 160 L256 380 M299 160 L338 380 M140 230 L372 230 M120 300 L392 300"/>', 8),
]
ICONS["moves"] = [
    ("shape", '<rect x="120" y="70" width="290" height="372" rx="20"/>', C["cream"]),
    ("shape", '<rect x="90" y="50" width="70" height="140" rx="35"/>', C["goldDark"]),
    ("shape", '<rect x="370" y="340" width="70" height="130" rx="35"/>', C["goldDark"]),
    ("line", '<path d="M190 150 L350 150 M190 210 L350 210 M190 270 L350 270 M190 330 L300 330"/>', 18),
]
ICONS["theme"] = [
    ("shape", '<path d="M256 60 C380 60 460 150 450 250 C440 330 370 330 340 320 C300 310 280 350 300 390 C320 440 280 460 240 455 C130 445 60 360 60 250 C60 140 150 60 256 60 Z"/>', C["cream"]),
    ("detail", '<circle cx="170" cy="190" r="34"/>', C["red"]),
    ("detail", '<circle cx="270" cy="140" r="34"/>', C["gold"]),
    ("detail", '<circle cx="370" cy="200" r="34"/>', C["blue"]),
    ("detail", '<circle cx="150" cy="310" r="34"/>', C["green"]),
]


def speaker(extra):
    return [
        ("shape", '<path d="M70 200 L150 200 L250 110 L250 402 L150 312 L70 312 Z"/>', C["grey"]),
    ] + extra


ICONS["soundOn"] = speaker([
    ("band", '<path d="M310 190 Q350 256 310 322"/>', C["blue"], 30),
    ("band", '<path d="M370 140 Q450 256 370 372"/>', C["blue"], 30),
])
ICONS["soundOff"] = speaker([
    ("band", '<path d="M320 190 L440 322 M440 190 L320 322"/>', C["red"], 36),
])
ICONS["best"] = [
    ("shape", '<path d="M256 50 C360 50 420 130 410 210 C400 280 340 300 330 360 L182 360 C172 300 112 280 102 210 C92 130 152 50 256 50 Z"/>', C["yellow"]),
    ("shape", '<rect x="180" y="350" width="152" height="90" rx="24"/>', C["grey"]),
    ("line", '<path d="M190 385 L322 385 M190 415 L322 415"/>', 10),
    ("line", '<path d="M220 300 L220 230 Q256 200 292 230 L292 300"/>', 12),
    ("shine", '<ellipse cx="190" cy="140" rx="24" ry="44" transform="rotate(30 190 140)"/>'),
]
ICONS["key"] = [
    ("shape", star(256, 270, 210, 95), C["gold"]),
    ("shine", '<ellipse cx="210" cy="220" rx="16" ry="36" transform="rotate(30 210 220)"/>'),
]
ICONS["back"] = [
    ("band", '<path d="M180 190 L330 190 A110 110 0 0 1 330 410 L200 410"/>', C["blue"], 60),
    ("shape", poly([(200, 90), (200, 290), (60, 190)]), C["blue"]),
]
ICONS["random"] = [
    ("shape", '<rect x="80" y="80" width="352" height="352" rx="70"/>', C["red"]),
] + [("detail", f'<circle cx="{x}" cy="{y}" r="36"/>', C["white"]) for x, y in ((170, 170), (256, 256), (342, 342), (342, 170), (170, 342))] + [
    ("shine", '<rect x="110" y="100" width="200" height="30" rx="15"/>')]
ICONS["white"] = [("shape", '<circle cx="256" cy="256" r="180"/>', C["cream"]), ("shine", '<ellipse cx="190" cy="180" rx="40" ry="24" transform="rotate(-30 190 180)"/>')]
ICONS["black"] = [("shape", '<circle cx="256" cy="256" r="180"/>', C["black"]), ("shine", '<ellipse cx="190" cy="180" rx="40" ry="24" transform="rotate(-30 190 180)"/>')]
ICONS["waiting"] = [
    ("shape", '<rect x="100" y="50" width="312" height="50" rx="20"/>', C["brown"]),
    ("shape", '<rect x="100" y="412" width="312" height="50" rx="20"/>', C["brown"]),
    ("shape", '<path d="M140 100 L372 100 C372 200 290 230 290 256 C290 282 372 312 372 412 L140 412 C140 312 222 282 222 256 C222 230 140 200 140 100 Z"/>', C["sky"]),
    ("detail", '<path d="M180 400 C180 340 256 320 256 300 C256 320 332 340 332 400 Z"/>', C["gold"]),
    ("detail", '<path d="M200 150 L312 150 C300 190 256 200 256 215 C256 200 212 190 200 150 Z"/>', C["gold"]),
]
ICONS["user"] = [
    ("shape", '<path d="M96 450 Q96 300 256 300 Q416 300 416 450 Z"/>', C["blue"]),
    ("shape", '<circle cx="256" cy="180" r="100"/>', C["cream"]),
    ("shine", '<ellipse cx="215" cy="130" rx="30" ry="18" transform="rotate(-30 215 130)"/>'),
    ("shine", '<ellipse cx="170" cy="360" rx="34" ry="16" transform="rotate(-30 170 360)"/>'),
]

ICONS["save"] = [
    ("shape", '<path d="M130 60 L382 60 Q402 60 402 80 L402 460 L256 360 L110 460 L110 80 Q110 60 130 60 Z"/>', C["red"]),
    ("shape", star(256, 200, 80, 34), C["gold"]),
    ("shine", '<rect x="140" y="84" width="40" height="150" rx="20"/>'),
]

ICONS["gamepad"] = [
    ("shape", '<path d="M150 150 L362 150 Q450 150 466 260 L480 360 Q488 430 430 430 Q396 430 370 390 L340 340 L172 340 L142 390 Q116 430 82 430 Q24 430 32 360 L46 260 Q62 150 150 150 Z"/>', C["black"]),
    ("band", '<path d="M150 210 L150 290 M110 250 L190 250"/>', C["steel"], 26),
    ("detail", '<circle cx="356" cy="220" r="24"/>', C["green"]),
    ("detail", '<circle cx="404" cy="268" r="24"/>', C["red"]),
    ("detail", '<circle cx="308" cy="268" r="24"/>', C["blue"]),
    ("detail", '<circle cx="356" cy="316" r="24"/>', C["gold"]),
    ("shine", '<ellipse cx="140" cy="180" rx="40" ry="14"/>'),
]

ICONS["target"] = [
    ("shape", '<circle cx="256" cy="256" r="190"/>', C["white"]),
    ("detail", '<circle cx="256" cy="256" r="140"/>', C["red"]),
    ("detail", '<circle cx="256" cy="256" r="95"/>', C["white"]),
    ("detail", '<circle cx="256" cy="256" r="50"/>', C["red"]),
    ("shine", '<ellipse cx="170" cy="150" rx="40" ry="20" transform="rotate(-35 170 150)"/>'),
]

ICONS["coin"] = [
    ("shape", '<ellipse cx="256" cy="282" rx="196" ry="190"/>', C["goldDark"]),
    ("shape", '<circle cx="256" cy="252" r="190"/>', C["gold"]),
    ("detail", '<circle cx="256" cy="252" r="138"/>', C["goldDark"]),
    ("detail", '<circle cx="256" cy="262" r="130"/>', C["gold"]),
    ("shape", star(256, 258, 92, 40), C["yellow"]),
    ("shine", '<ellipse cx="170" cy="150" rx="46" ry="22" transform="rotate(-35 170 150)"/>'),
]

ICONS["shop"] = [
    ("band", '<path d="M36 112 L104 112 L160 340 L420 340"/>', C["steel"], 34),
    ("shape", poly([(112, 150), (476, 150), (432, 300), (150, 300)]), C["white"]),
    ("line", '<path d="M190 182 L206 280 M262 182 L266 280 M334 182 L326 280 M406 182 L386 280"/>', 14),
    ("shape", '<circle cx="196" cy="418" r="40"/>', C["black"]),
    ("shape", '<circle cx="384" cy="418" r="40"/>', C["black"]),
    ("detail", '<circle cx="196" cy="418" r="14"/>', C["steel"]),
    ("detail", '<circle cx="384" cy="418" r="14"/>', C["steel"]),
    ("shine", '<rect x="150" y="166" width="120" height="22" rx="11"/>'),
]

ICONS["steal"] = [
    ("band", '<path d="M150 120 L150 290 A106 106 0 0 0 362 290 L362 120"/>', C["red"], 96),
    ("shape", '<rect x="96" y="70" width="108" height="86" rx="14"/>', C["steel"]),
    ("shape", '<rect x="308" y="70" width="108" height="86" rx="14"/>', C["steel"]),
    ("shine", '<rect x="116" y="180" width="24" height="100" rx="12"/>'),
]

ICONS["fire"] = ICONS["Strong"]
ICONS["new"] = ICONS["Abilities"]
ICONS["close"] = ICONS["no"]
ICONS["ready"] = ICONS["yes"]
ICONS["cancel"] = ICONS["no"]
ICONS["start"] = ICONS["play"]
ICONS["tie"] = ICONS["draw"]

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, items in ICONS.items():
        with open(os.path.join(OUT, f"chess_ui_{name}.svg"), "w", encoding="utf-8") as f:
            f.write(svg_for(items))
    print(len(ICONS), "icons ->", OUT)
