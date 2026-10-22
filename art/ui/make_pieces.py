"""2D chess piece set for the flat board and the review (same house style as make_icons.py).

Writes svg/chess_piece_<w|b><K|Q|R|B|N|P>.svg on a 512 artboard; illustrator_export.jsx exports
them (with the icons) to ai/ and png/ at 256 px. All pieces share one base (y 400..452) so they sit
on the same line on the board.
Run: python art/ui/make_pieces.py
"""
import os

from make_icons import OUT, poly, svg_for

COLORS = {"w": "#F6F1DE", "b": "#3D434C"}
DETAIL = {"w": "#C9BFA0", "b": "#22262C"}


def base():
    return [
        ("shape", '<rect x="116" y="408" width="280" height="56" rx="20"/>', None),
        ("shape", '<rect x="146" y="372" width="220" height="48" rx="16"/>', None),
    ]


PIECES = {}

PIECES["P"] = base() + [
    ("shape", '<path d="M196 382 C196 320 214 290 230 262 L282 262 C298 290 316 320 316 382 Z"/>', None),
    ("shape", '<ellipse cx="256" cy="262" rx="64" ry="18"/>', None),
    ("shape", '<circle cx="256" cy="196" r="66"/>', None),
    ("shine", '<ellipse cx="232" cy="172" rx="16" ry="26"/>'),
]

PIECES["R"] = base() + [
    ("shape", '<path d="M178 382 L192 210 L320 210 L334 382 Z"/>', None),
    ("shape", '<rect x="160" y="190" width="192" height="40" rx="10"/>', None),
    ("shape", '<path d="M160 200 L160 92 L206 92 L206 132 L234 132 L234 92 L278 92 L278 132 L306 132 L306 92 L352 92 L352 200 Z"/>', None),
    ("line", '<path d="M190 300 L322 300"/>', 10),
    ("shine", '<rect x="178" y="108" width="14" height="70" rx="7"/>'),
]

PIECES["B"] = base() + [
    ("shape", '<path d="M200 382 C200 330 220 300 236 280 L276 280 C292 300 312 330 312 382 Z"/>', None),
    ("shape", '<ellipse cx="256" cy="280" rx="70" ry="18"/>', None),
    ("shape", '<path d="M256 74 C330 120 346 190 320 236 C306 258 206 258 192 236 C166 190 182 120 256 74 Z"/>', None),
    ("shape", '<circle cx="256" cy="66" r="24"/>', None),
    ("line", '<path d="M262 150 L296 116"/>', 14),
    ("shine", '<ellipse cx="222" cy="160" rx="14" ry="38" transform="rotate(15 222 160)"/>'),
]

PIECES["Q"] = base() + [
    ("shape", '<path d="M186 382 L160 140 L210 230 L232 120 L256 220 L280 120 L302 230 L352 140 L326 382 Z"/>', None),
    ("shape", '<ellipse cx="256" cy="300" rx="80" ry="18"/>', None),
    ("shape", '<circle cx="160" cy="128" r="20"/>', None),
    ("shape", '<circle cx="232" cy="106" r="20"/>', None),
    ("shape", '<circle cx="280" cy="106" r="20"/>', None),
    ("shape", '<circle cx="352" cy="128" r="20"/>', None),
    ("shape", '<circle cx="256" cy="74" r="22"/>', None),
    ("shine", '<ellipse cx="212" cy="320" rx="12" ry="40"/>'),
]

PIECES["K"] = base() + [
    ("shape", '<path d="M186 382 C186 300 176 240 170 190 L342 190 C336 240 326 300 326 382 Z"/>', None),
    ("shape", '<rect x="160" y="176" width="192" height="40" rx="14"/>', None),
    ("shape", '<path d="M238 40 L274 40 L274 84 L314 84 L314 118 L274 118 L274 180 L238 180 L238 118 L198 118 L198 84 L238 84 Z"/>', None),
    ("line", '<path d="M196 300 L316 300"/>', 10),
    ("shine", '<rect x="200" y="226" width="16" height="120" rx="8"/>'),
]

# knight: a horse head facing left
PIECES["N"] = base() + [
    ("shape", '<path d="M174 384 C168 330 196 300 214 282 C186 280 150 296 128 290 C100 282 92 248 112 222 '
              'C140 184 170 150 196 116 L188 70 L236 98 C330 100 372 180 368 260 C366 320 352 360 340 384 Z"/>', None),
    ("detail", '<circle cx="214" cy="172" r="16"/>', "INK"),
    ("line", '<path d="M262 116 C318 136 346 200 340 282"/>', 12),
    ("line", '<path d="M140 268 L170 262"/>', 10),
    ("shine", '<ellipse cx="250" cy="150" rx="12" ry="30" transform="rotate(-40 250 150)"/>'),
]

if __name__ == "__main__":
    import make_icons
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for color, fill in COLORS.items():
        for kind, items in PIECES.items():
            painted = []
            for it in items:
                if it[0] == "shape":
                    painted.append(("shape", it[1], fill))
                elif it[0] == "detail":
                    painted.append(("detail", it[1], make_icons.INK if it[2] == "INK" else it[2]))
                elif it[0] == "line" and color == "b":
                    # lighter detail lines on black pieces so they show
                    painted.append(("detail_line", it[1], it[2]))
                else:
                    painted.append(it)
            svg = svg_for([p for p in painted if p[0] != "detail_line"])
            # black pieces: detail lines in a soft grey instead of ink
            if color == "b":
                extra = "".join(p[1].replace("/>", f' fill="none" stroke="#8A919C" stroke-width="{p[2]}" stroke-linecap="round"/>')
                                for p in painted if p[0] == "detail_line")
                svg = svg.replace("</svg>", extra + "</svg>")
            with open(os.path.join(OUT, f"chess_piece_{color}{kind}.svg"), "w", encoding="utf-8") as f:
                f.write(svg)
            n += 1
    print(n, "pieces ->", OUT)
