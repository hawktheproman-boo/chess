"""Finishes CHESS?? thumbnails 2-5 (1920 x 1080) from the Blender renders (make_thumbs.py, make_passes.py):
  thumb_abilities.png  2: four panels (Any Passant, Double Jump, Battering Ram, Royal Escape), each the
                       piece render on its ability colour with rays, its name and rarity; a centre title
  thumb_dodge.png      3: "THE KING DODGED?!" and a red MISS stamp by the afterimage
  thumb_trophy.png     4: "TOURNAMENTS" / "WIN THE CROWN!" over the champion and the cheering crowd
  thumb_versus.png     5: "PLAY FRIENDS" / "OR BOTS!"
plus thumbs_preview.png (all five, small, as the game page shows them).

Run: python art/store/finish_thumbs.py   (the title style is finish_hero.py's)
"""
import importlib.util
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
_spec = importlib.util.spec_from_file_location("finish_hero", os.path.join(HERE, "finish_hero.py"))
hero = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(hero)
FONT, title, INK, WHITE, RED = hero.FONT, hero.title, hero.INK, hero.WHITE, hero.RED
W, H = 1920, 1080
GOLD = (255, 205, 70)
TEAL = (90, 230, 210)

PANELS = [  # render, name, rarity, rarity colour, panel colour
    ("pass_passant_render.png", "ANY PASSANT", "COMMON", (56, 172, 236), (24, 120, 110)),
    ("pass_jump_render.png", "DOUBLE JUMP", "EPIC", (196, 168, 255), (40, 70, 190)),
    ("pass_ram_render.png", "BATTERING RAM", "UNCOMMON", (70, 200, 90), (210, 105, 25)),
    ("pass_escape_render.png", "ROYAL ESCAPE", "COMMON", (56, 172, 236), (70, 140, 230)),
]


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def wash(img, box, alpha=160, blur=120):
    """A soft dark area (under a title)."""
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).ellipse(box, fill=alpha)
    m = m.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(Image.merge("RGBA", (Image.new("L", img.size, 0),) * 3 + (m,)))


def panel(render, name, rarity, rcol, colour, w, h):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    light, dark = shade(colour, 1.3), shade(colour, 0.45)
    for y in range(h):
        for x in range(w):
            t = min(1.0, math.hypot(x - w * 0.62, y - h * 0.48) / (w * 0.62))
            px[x, y] = tuple(int(light[i] + (dark[i] - light[i]) * t) for i in range(3)) + (255,)
    # rays from behind the piece
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = w * 0.62, h * 0.48
    for i in range(18):
        a = i / 18 * math.tau
        k = 0.05 + 0.03 * (i % 3)
        d.polygon([(cx, cy), (cx + math.cos(a - k) * w, cy + math.sin(a - k) * w), (cx + math.cos(a + k) * w, cy + math.sin(a + k) * w)],
                  fill=(255, 255, 255, 38))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(6)))
    s = Image.open(os.path.join(OUT, render)).convert("RGBA")
    s = s.crop(s.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox())
    k = min(h * 0.86 / s.height, w * 0.6 / s.width)
    s = s.resize((int(s.width * k), int(s.height * k)), Image.LANCZOS)
    img.alpha_composite(s, (int(w * 0.62 - s.width / 2), int(h * 0.5 - s.height / 2)))
    # the name and the rarity, bottom left
    title(img, [(name, WHITE)], int(w * 0.04), int(h * 0.7), int(h * 0.13))
    font = ImageFont.truetype(FONT, int(h * 0.07))
    dd = ImageDraw.Draw(img)
    l, t, r, b = dd.textbbox((0, 0), rarity, font=font)
    x0, y0 = int(w * 0.045), int(h * 0.58)
    dd.rounded_rectangle((x0, y0, x0 + (r - l) + 36, y0 + (b - t) + 22), radius=18, fill=INK + (220,), outline=rcol, width=4)
    dd.text((x0 + 18 - l, y0 + 11 - t), rarity, font=font, fill=rcol)
    return img


def abilities():
    img = Image.new("RGBA", (W, H), INK + (255,))
    gap = 10
    pw, ph = (W - gap) // 2, (H - gap) // 2
    for i, p in enumerate(PANELS):
        img.alpha_composite(panel(*p, pw, ph), ((i % 2) * (pw + gap), (i // 2) * (ph + gap)))
    # the centre title on a dark pill
    font = ImageFont.truetype(FONT, 104)
    text = "CHESS... WITH ABILITIES!"
    d = ImageDraw.Draw(img)
    l, t, r, b = d.textbbox((0, 0), text, font=font, stroke_width=10)
    tw, th = r - l, b - t
    box = (W // 2 - tw // 2 - 50, H // 2 - th // 2 - 34, W // 2 + tw // 2 + 50, H // 2 + th // 2 + 34)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((box[0] + 8, box[1] + 14, box[2] + 8, box[3] + 14), radius=60, fill=(0, 0, 0, 170))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=60, fill=(30, 22, 30), outline=GOLD, width=8)
    title(img, [("CHESS", WHITE), ("...", WHITE), (" WITH ABILITIES!", GOLD)], box[0] + 50, box[1] + 26 - t // 2, 104)
    return img


def stamp(img, text, xy, size, angle, colour=RED):
    """A slammed-in word: a thick dark outline, a white inner line, tilted."""
    font = ImageFont.truetype(FONT, size)
    tmp = Image.new("RGBA", (int(size * len(text) * 0.9) + 200, size * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    d.text((60, size // 3), text, font=font, fill=WHITE, stroke_width=size // 6, stroke_fill=INK)
    d.text((60, size // 3), text, font=font, fill=colour, stroke_width=size // 20, stroke_fill=WHITE)
    tmp = tmp.rotate(angle, resample=Image.BICUBIC, expand=True)
    tmp = tmp.crop(tmp.getbbox())
    img.alpha_composite(tmp, (int(xy[0] - tmp.width / 2), int(xy[1] - tmp.height / 2)))


def dodge():
    img = Image.open(os.path.join(OUT, "thumb_dodge_render.png")).convert("RGBA")
    wash(img, (-W * 0.3, -H * 0.5, W * 0.62, H * 0.5))
    title(img, [("THE KING", WHITE)], 80, 50, 170)
    title(img, [("DODGED", WHITE), ("?!", RED)], 80, 245, 170)
    stamp(img, "MISS", (W * 0.36, H * 0.62), 190, 12)
    return img


def trophy():
    img = Image.open(os.path.join(OUT, "thumb_trophy_render.png")).convert("RGBA")
    # the title across the top (the crowd fills the bottom); the champion stays clear in the middle
    wash(img, (-W * 0.3, -H * 0.55, W * 0.5, H * 0.32), alpha=150)
    title(img, [("TOURNAMENTS", GOLD)], 70, 40, 150)
    title(img, [("WIN THE CROWN!", WHITE)], 78, 205, 84)
    return img


def versus():
    img = Image.open(os.path.join(OUT, "thumb_versus_render.png")).convert("RGBA")
    # centred across the top, clear of the two players at the sides
    wash(img, (W * 0.15, -H * 0.5, W * 0.85, H * 0.36), alpha=120)
    d = ImageDraw.Draw(img)
    for text_parts, y, size in (([("PLAY FRIENDS", WHITE)], 40, 150), ([("OR ", WHITE), ("BOTS!", (110, 220, 255))], 210, 150)):
        font = ImageFont.truetype(FONT, size)
        tw = sum(d.textlength(t, font=font) for t, _ in text_parts) + size // 30 * (len(text_parts) - 1)
        title(img, text_parts, int(W / 2 - tw / 2), y, size)
    return img


def main():
    outs = {"abilities": abilities(), "dodge": dodge(), "trophy": trophy(), "versus": versus()}
    for name, im in outs.items():
        im.convert("RGB").save(os.path.join(OUT, "thumb_%s.png" % name))
    order = ["hero", "abilities", "dodge", "trophy", "versus"]
    sheet = Image.new("RGB", (3 * 480 + 40, 2 * 270 + 30), (34, 38, 46))
    for i, name in enumerate(order):
        im = Image.open(os.path.join(OUT, "thumb_%s.png" % name)).convert("RGB").resize((480, 270), Image.LANCZOS)
        sheet.paste(im, (10 + (i % 3) * 490, 10 + (i // 3) * 280))
    sheet.save(os.path.join(OUT, "thumbs_preview.png"))
    print("wrote", ", ".join("thumb_%s.png" % n for n in outs))


if __name__ == "__main__":
    main()
