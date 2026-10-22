"""Anime-style VFX textures for the cutscenes (white on transparent; the game tints them).

python art/vfx/make_textures.py  ->  art/vfx/*.png
Uploaded to Roblox with the Studio MCP (upload_image); the ids live in VfxKit.lua.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.dirname(os.path.abspath(__file__))
random.seed(7)


def save(name, alpha, rgb=(255, 255, 255)):
    a = np.clip(alpha, 0, 1)
    img = np.zeros(a.shape + (4,), np.uint8)
    img[..., 0], img[..., 1], img[..., 2] = rgb
    img[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name + ".png"))


def grid(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    c = (n - 1) / 2
    dx, dy = (x - c) / c, (y - c) / c
    return dx, dy, np.hypot(dx, dy), np.arctan2(dy, dx)


def layer(n, draw_fn, blur=0):
    im = Image.new("L", (n, n), 0)
    draw_fn(ImageDraw.Draw(im))
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(im, np.float32) / 255


# soft round glow (orbs, lights, flash cores)
def glow(n=256):
    _, _, r, _ = grid(n)
    save("glow", np.exp(-(r / 0.42) ** 2) * (r < 1))


# a spark streak, long along Y (particles with VelocityParallel orientation)
def spark(n=256):
    dx, dy, _, _ = grid(n)
    width = 0.06 * (1 - np.abs(dy)) ** 0.7
    core = np.clip(1 - np.abs(dx) / np.maximum(width, 1e-3), 0, 1)
    save("spark", core ** 1.5 * (np.abs(dy) < 1))


# impact star: 4 long sharp spikes, 4 short ones, a hot core
def star(n=512):
    _, _, r, t = grid(n)
    a = np.zeros_like(r)
    for k, (length, sharp) in enumerate([(1.0, 40), (0.55, 30)]):
        ang = (t - k * math.pi / 4) % (math.pi / 2) - math.pi / 4
        spike = np.exp(-(np.abs(ang) * sharp) ** 1.3) * np.clip(1 - r / length, 0, 1) ** 1.2
        a = np.maximum(a, spike)
    a = np.maximum(a, np.exp(-(r / 0.16) ** 2))
    save("star", a)


# shockwave ring: a sharp bright edge fading inwards, slightly jagged like hand-drawn anime rings
def ring(n=512):
    _, _, r, t = grid(n)
    wob = 0.006 * np.sin(t * 9) + 0.004 * np.sin(t * 23 + 1)
    edge = 0.9 + wob
    outer = np.clip(1 - (r - edge) / 0.03, 0, 1) * (r > edge - 0.0)
    inner = np.clip((r - (edge - 0.28)) / 0.28, 0, 1) ** 2.2 * (r <= edge)
    save("ring", np.where(r <= edge, inner, outer * (r < 1)))


# radial anime speed lines: thin wedges from the edge, clear in the middle
def speedlines(n=1024):
    c = n / 2

    def draw(d):
        for _ in range(140):
            ang = random.uniform(0, 2 * math.pi)
            inner = random.uniform(0.42, 0.75) * c
            w = random.uniform(0.004, 0.014)
            far = c * 1.6
            pts = [(c + math.cos(ang) * inner, c + math.sin(ang) * inner),
                   (c + math.cos(ang - w) * far, c + math.sin(ang - w) * far),
                   (c + math.cos(ang + w) * far, c + math.sin(ang + w) * far)]
            d.polygon(pts, fill=255)
    save("speedlines", layer(n, draw, blur=1))


# ground crack: jagged branches out from the centre
def crack(n=512):
    c = n / 2

    def branch(d, x, y, ang, length, width, depth):
        steps = 6
        for _ in range(steps):
            nx = x + math.cos(ang) * length / steps
            ny = y + math.sin(ang) * length / steps
            d.line([(x, y), (nx, ny)], fill=255, width=max(1, int(width)))
            x, y = nx, ny
            ang += random.uniform(-0.45, 0.45)
            width *= 0.85
            if depth < 2 and random.random() < 0.25:
                branch(d, x, y, ang + random.choice([-1, 1]) * random.uniform(0.5, 1.0), length * 0.45, width, depth + 1)

    def draw(d):
        for i in range(7):
            branch(d, c, c, i * 2 * math.pi / 7 + random.uniform(-0.3, 0.3), c * random.uniform(0.6, 0.95), 9, 0)
        d.ellipse([c - 18, c - 18, c + 18, c + 18], fill=255)
    save("crack", layer(n, draw, blur=0.6))


# beam texture: streaky energy, tiles along X (Beam TextureMode Wrap)
def energy(w=512, h=128):
    y = np.linspace(-1, 1, h)[:, None]
    x = np.linspace(0, 1, w)[None, :]
    a = np.exp(-(y / 0.35) ** 2) * 0.55
    for _ in range(14):
        yy = random.uniform(-0.6, 0.6)
        th = random.uniform(0.02, 0.07)
        k = random.randint(1, 4)
        ph = random.uniform(0, 2 * math.pi)
        streak = np.exp(-((y - yy) / th) ** 2) * (0.5 + 0.5 * np.sin(2 * math.pi * k * x + ph)) ** 3
        a = np.maximum(a, streak)
    a = np.maximum(a, np.exp(-(y / 0.08) ** 2))
    save("energy", np.broadcast_to(a, (h, w)).copy())


# crescent slash
def slash(n=512):
    dx, dy, r, t = grid(n)
    band = np.clip(1 - np.abs(r - 0.78) / (0.16 * np.clip(np.cos(t + math.pi / 2), 0, 1) + 1e-3), 0, 1)
    save("slash", band * (dy < 0.2) * (r < 1))


if __name__ == "__main__":
    for fn in (glow, spark, star, ring, speedlines, crack, energy, slash):
        fn()
    print(sorted(f for f in os.listdir(OUT) if f.endswith(".png")))
