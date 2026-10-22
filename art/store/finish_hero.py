"""Finishes the CHESS?? hero thumbnail: Blender's render (out/hero_render.png, from make_store.py's
render_hero) + the title. "CHESS" in white and "??" in red, Fredoka One (the game's title font) with a
thick dark outline and a drop shadow, big in the top left, over a soft dark wash so it reads on any
screen. Writes art/store/out/thumb_hero.png (1920 x 1080) and a small-size preview.

Run: python art/store/finish_hero.py
"""
import glob
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\FredokaOne-Regular.ttf")))[-1]

WHITE = (255, 255, 255)
RED = (235, 40, 40)
INK = (22, 10, 12)


def title(base, text_parts, x, y, size):
    """Draws [(text, colour), ...] side by side at (x, y): a blurred shadow, a dark outline, the fill."""
    font = ImageFont.truetype(FONT, size)
    stroke = max(4, size // 11)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d, ds = ImageDraw.Draw(layer), ImageDraw.Draw(shadow)
    cx = x
    for text, colour in text_parts:
        ds.text((cx + size // 22, y + size // 14), text, font=font, fill=(0, 0, 0, 200), stroke_width=stroke, stroke_fill=(0, 0, 0, 200))
        d.text((cx, y), text, font=font, fill=colour, stroke_width=stroke, stroke_fill=INK)
        cx += d.textlength(text, font=font) + size // 30
    base.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size // 18)))
    base.alpha_composite(layer)


def main():
    base = Image.open(os.path.join(OUT, "hero_render.png")).convert("RGBA")
    w, h = base.size
    # a soft dark wash in the top-left corner, under the title
    wash = Image.new("L", base.size, 0)
    ImageDraw.Draw(wash).ellipse((-w * 0.35, -h * 0.55, w * 0.62, h * 0.55), fill=150)
    wash = wash.filter(ImageFilter.GaussianBlur(w // 10))
    base.alpha_composite(Image.merge("RGBA", (Image.new("L", base.size, 0),) * 3 + (wash,)))
    title(base, [("CHESS", WHITE), ("??", RED)], int(w * 0.045), int(h * 0.04), int(h * 0.2))
    base.convert("RGB").save(os.path.join(OUT, "thumb_hero.png"))
    # how it reads small (the game page / sort tiles)
    base.convert("RGB").resize((480, 270), Image.LANCZOS).save(os.path.join(OUT, "thumb_hero_small.png"))
    print("wrote", os.path.join(OUT, "thumb_hero.png"))


if __name__ == "__main__":
    main()
