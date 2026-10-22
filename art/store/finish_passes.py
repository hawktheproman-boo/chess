"""Finishes the CHESS?? gamepass / developer-product icons: each transparent Blender render
(out/pass_<kind>_render.png, from make_passes.py) goes on a coloured disc with a rarity-coloured ring,
auto-fitted inside the circle Roblox shows (the corners are cut off), plus a few 2D extras:
  snipe  a red scope crosshair behind the bishop      ram  orange speed lines behind the rook
  vip    a gold "VIP" ribbon                          steal  a red "!?" tag
Writes out/pass_<kind>.png (512 x 512, the upload) and out/passes_preview.png (the set at 512 and 100 px).

Run: python art/store/finish_passes.py
"""
import glob
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\FredokaOne-Regular.ttf")))[-1]
N = 1024  # work size; the upload is 512
INK = (22, 10, 12)

# the rarity rings (Shared/Shop.lua RARITIES) and each ability's card colour (AbilityBar.CARDS)
EPIC, UNCOMMON, COMMON = (196, 168, 255), (70, 200, 90), (56, 172, 236)
GOLD = (255, 200, 61)
PASSES = {
    "jump": {"ring": EPIC, "bg": (40, 70, 190), "title": "Double Jump"},  # deep blue, so the energy glows
    "snipe": {"ring": EPIC, "bg": (232, 70, 58), "title": "Snipe"},
    "ram": {"ring": UNCOMMON, "bg": (240, 130, 40), "title": "Battering Ram"},
    "escape": {"ring": COMMON, "bg": (95, 165, 245), "title": "Royal Escape"},  # a heavenly sky
    "vip": {"ring": GOLD, "bg": (120, 60, 200), "title": "VIP"},
    "steal": {"ring": GOLD, "bg": (170, 28, 40), "title": "Steal a Piece"},
}


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def disc(colour):
    """The circle: a radial gradient of the ability's colour (light centre, dark edge)."""
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    grad = Image.new("RGBA", (N, N))
    px = grad.load()
    light, dark = shade(colour, 1.25), shade(colour, 0.42)
    c = N / 2
    for y in range(N):
        for x in range(N):
            t = min(1.0, math.hypot(x - c, (y - c * 0.85)) / (N * 0.62))
            px[x, y] = tuple(int(light[i] + (dark[i] - light[i]) * t) for i in range(3)) + (255,)
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, N - 1, N - 1), fill=255)
    img.paste(grad, mask=mask)
    return img


def ring(img, colour):
    d = ImageDraw.Draw(img)
    w = N // 20
    d.ellipse((0, 0, N - 1, N - 1), outline=INK, width=w + N // 70)
    d.ellipse((N // 140, N // 140, N - 1 - N // 140, N - 1 - N // 140), outline=colour, width=w)
    # a thin highlight on the ring's upper inner edge
    d.arc((w, w, N - 1 - w, N - 1 - w), 200, 340, fill=shade(colour, 1.35), width=N // 120)


def fit(subject, box_frac=0.7, lift=0.03, radius=0.4):
    """Crops the render to its visible pixels, scales it into the circle's central box, then shrinks
    it until every visible pixel is within `radius` x N of the centre (inside the ring)."""
    alpha = subject.getchannel("A").point(lambda a: 255 if a > 24 else 0)
    bbox = alpha.getbbox()
    s, a = subject.crop(bbox), alpha.crop(bbox)
    k = (N * box_frac) / max(s.width, s.height)
    for _ in range(12):
        w, h = max(1, int(s.width * k)), max(1, int(s.height * k))
        at = ((N - w) // 2, (N - h) // 2 - int(N * lift))
        small = a.resize((max(1, w // 8), max(1, h // 8)))
        far = 0.0
        px = small.load()
        for y in range(small.height):
            for x in range(small.width):
                if px[x, y]:
                    far = max(far, math.hypot(at[0] + x * 8 + 4 - N / 2, at[1] + y * 8 + 4 - N / 2))
        if far <= radius * N:
            break
        k *= (radius * N) / far
    s = s.resize((w, h), Image.LANCZOS)
    return s, at


def crosshair(img):
    d = ImageDraw.Draw(img)
    c, r = N // 2, int(N * 0.36)
    red = (255, 60, 50, 170)
    d.ellipse((c - r, c - r, c + r, c + r), outline=red, width=N // 90)
    for a, b in (((c - r - 40, c), (c - r * 0.35, c)), ((c + r * 0.35, c), (c + r + 40, c)),
                 ((c, c - r - 40), (c, c - r * 0.35)), ((c, c + r * 0.35), (c, c + r + 40))):
        d.line((a, b), fill=red, width=N // 110)


def speed_lines(img, colour):
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = N / 2
    for i in range(28):
        a = i / 28 * math.tau + (i % 3) * 0.05
        r0, r1 = N * (0.28 + (i % 4) * 0.03), N * 0.6
        d.line(((c + math.cos(a) * r0, c + math.sin(a) * r0), (c + math.cos(a) * r1, c + math.sin(a) * r1)),
               fill=colour + (110,), width=N // 90 + (i % 3) * 3)
    img.alpha_composite(layer)


def rays(img, colour, n=18, alpha=90, centre=(0.5, 0.42), width=0.07):
    """Wedges of light fanning out from a point (anime 'epic' rays / heavenly light)."""
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = centre[0] * N, centre[1] * N
    for i in range(n):
        a = i / n * math.tau
        w = width * (0.6 + 0.8 * ((i * 7) % 5) / 4)
        r = N
        d.polygon([(cx, cy), (cx + math.cos(a - w) * r, cy + math.sin(a - w) * r), (cx + math.cos(a + w) * r, cy + math.sin(a + w) * r)],
                  fill=colour + (alpha,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(N // 120)))


def sparkle(img, xy, size, colour=(255, 240, 180)):
    """A four-pointed star with a soft glow."""
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = xy
    w = size * 0.16
    d.polygon([(x, y - size), (x + w, y - w), (x + size, y), (x + w, y + w), (x, y + size), (x - w, y + w), (x - size, y), (x - w, y - w)],
              fill=colour + (255,))
    glow = layer.filter(ImageFilter.GaussianBlur(size * 0.35))
    img.alpha_composite(glow)
    img.alpha_composite(layer)


def label(img, text, fill, xy, size, angle=0, box_fill=None):
    font = ImageFont.truetype(FONT, size)
    stroke = max(3, size // 9)
    tmp = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    l, t, r, b = d.textbbox((0, 0), text, font=font, stroke_width=stroke)
    pad = size // 4
    w, h = r - l + 2 * pad, b - t + 2 * pad
    tag = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    td = ImageDraw.Draw(tag)
    if box_fill:
        td.rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 3, fill=INK)
        td.rounded_rectangle((stroke // 2, stroke // 2, w - 1 - stroke // 2, h - 1 - stroke // 2 - size // 14), radius=h // 3, fill=box_fill)
    td.text((pad - l, pad - t - (size // 20 if box_fill else 0)), text, font=font, fill=fill, stroke_width=stroke, stroke_fill=INK)
    tag = tag.rotate(angle, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(tag, (int(xy[0] - tag.width / 2), int(xy[1] - tag.height / 2)))


def make(kind):
    spec = PASSES[kind]
    img = disc(spec["bg"])
    if kind == "snipe":
        crosshair(img)
    if kind == "ram":
        speed_lines(img, (255, 230, 180))
    if kind == "jump":
        rays(img, (140, 200, 255), n=20, alpha=70, centre=(0.55, 0.36))
    if kind == "escape":
        rays(img, (255, 236, 170), n=14, alpha=120, centre=(0.5, 0.05), width=0.05)  # golden light from above
    subject = Image.open(os.path.join(OUT, "pass_%s_render.png" % kind)).convert("RGBA")
    box = {"snipe": 0.82, "ram": 0.8, "jump": 0.84, "escape": 0.86, "vip": 0.74, "steal": 0.8}[kind]
    s, at = fit(subject, box)
    # a soft dark shadow under the subject so it lifts off the disc
    sh = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    sh.alpha_composite(Image.merge("RGBA", (Image.new("L", s.size, 0),) * 3 + (s.getchannel("A").point(lambda a: a * 0.55),)),
                       (at[0] + N // 60, at[1] + N // 40))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(N // 50)))
    img.alpha_composite(s, at)
    if kind == "vip":
        for (x, y, r) in ((0.24, 0.32, 0.06), (0.76, 0.32, 0.06), (0.17, 0.55, 0.04), (0.83, 0.55, 0.04),
                          (0.3, 0.17, 0.035), (0.7, 0.17, 0.035)):
            sparkle(img, (x * N, y * N), r * N)
        label(img, "VIP", (255, 236, 150), (N * 0.5, N * 0.82), int(N * 0.13), angle=-6, box_fill=(150, 60, 220))
    if kind == "steal":
        label(img, "!?", (255, 255, 255), (N * 0.79, N * 0.3), int(N * 0.13), angle=10, box_fill=(226, 38, 38))
    # keep everything inside the circle, then the ring on top
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, N - 1, N - 1), fill=255)
    clipped = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    clipped.paste(img, mask=mask)
    ring(clipped, spec["ring"])
    out = clipped.resize((512, 512), Image.LANCZOS)
    out.save(os.path.join(OUT, "pass_%s.png" % kind))
    return out


def main():
    icons = [make(k) for k in PASSES]
    sheet = Image.new("RGBA", (6 * 270 + 20, 270 + 140), (34, 38, 46, 255))
    for i, im in enumerate(icons):
        sheet.alpha_composite(im.resize((250, 250), Image.LANCZOS), (20 + i * 270, 10))
        sheet.alpha_composite(im.resize((100, 100), Image.LANCZOS), (95 + i * 270, 285))
    sheet.save(os.path.join(OUT, "passes_preview.png"))
    print("wrote", len(icons), "icons")


if __name__ == "__main__":
    main()
