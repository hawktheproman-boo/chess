"""Preview grid of art/ui/png/*.png on the game's dark green panel colour -> art/ui/contact_sheet.png"""
import glob
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
files = sorted(glob.glob(os.path.join(ROOT, "png", "chess_ui_*.png")))
CELL, ICON, COLS = 150, 112, 9
rows = (len(files) + COLS - 1) // COLS
sheet = Image.new("RGB", (COLS * CELL, rows * CELL), (30, 59, 34))
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("arial.ttf", 14)
except OSError:
    font = ImageFont.load_default()
for i, f in enumerate(files):
    x, y = (i % COLS) * CELL, (i // COLS) * CELL
    if (i // COLS + i % COLS) % 2 == 0:
        draw.rectangle([x, y, x + CELL - 1, y + CELL - 1], fill=(36, 68, 40))
    im = Image.open(f).convert("RGBA").resize((ICON, ICON), Image.LANCZOS)
    sheet.paste(im, (x + (CELL - ICON) // 2, y + 8), im)
    name = os.path.basename(f)[len("chess_ui_"):-4]
    w = draw.textlength(name, font=font)
    draw.text((x + (CELL - w) / 2, y + CELL - 26), name, fill=(242, 248, 236), font=font)
sheet.save(os.path.join(ROOT, "contact_sheet.png"))
print("contact sheet:", len(files), "icons")
