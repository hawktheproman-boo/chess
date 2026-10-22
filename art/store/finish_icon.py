"""Finishes the CHESS?? experience icon: takes Blender's render (out/icon_render.png, from
make_store.py's render_icon) and adds the red "??" blunder tag in the top-left corner, in the game's
title font (Fredoka One, white with a dark outline), then writes the 512 x 512 upload.

Run: python art/store/finish_icon.py  ->  art/store/out/icon_512.png (+ icon_1024.png, a preview)
The tag is our own design (a red rounded square), never chess.com's blunder badge.
"""
import glob
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\FredokaOne-Regular.ttf")))[-1]

RED = (226, 38, 38)
RED_EDGE = (120, 10, 14)
INK = (20, 10, 12)


def tag(size):
    """The "??" tag: a red rounded square with a darker edge, a soft drop shadow, white "??"."""
    pad = size // 6
    img = Image.new("RGBA", (size + 2 * pad, size + 2 * pad), (0, 0, 0, 0))
    box = (pad, pad, pad + size, pad + size)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((box[0] + size // 30, box[1] + size // 18, box[2] + size // 30, box[3] + size // 18),
                                             radius=size // 4, fill=(0, 0, 0, 170))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(size // 22)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=size // 4, fill=RED_EDGE)
    inner = (box[0], box[1], box[2], box[3] - size // 14)
    d.rounded_rectangle(inner, radius=size // 4, fill=RED)
    # a soft highlight on the top half
    hl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).rounded_rectangle((box[0] + size // 12, box[1] + size // 14, box[2] - size // 12, box[1] + size // 2.6),
                                         radius=size // 6, fill=(255, 255, 255, 60))
    img = Image.alpha_composite(img, hl)
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, int(size * 0.62))
    text = "??"
    l, t, r, b = d.textbbox((0, 0), text, font=font, stroke_width=size // 22)
    x = box[0] + (size - (r - l)) / 2 - l
    y = inner[1] + (inner[3] - inner[1] - (b - t)) / 2 - t
    d.text((x, y), text, font=font, fill=(255, 255, 255), stroke_width=size // 22, stroke_fill=INK)
    return img


def main():
    base = Image.open(os.path.join(OUT, "icon_render.png")).convert("RGBA")
    w = base.width
    t = tag(int(w * 0.23)).rotate(8, resample=Image.BICUBIC, expand=True)
    # top left, over the dark corner (the bishop's head is top right), inside the safe area: Roblox
    # rounds the icon's corners
    base.alpha_composite(t, (int(w * 0.045), int(w * 0.035)))
    base.convert("RGB").save(os.path.join(OUT, "icon_1024.png"))
    base.convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "icon_512.png"))
    print("wrote", os.path.join(OUT, "icon_512.png"))


if __name__ == "__main__":
    main()
