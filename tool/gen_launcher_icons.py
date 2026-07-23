#!/usr/bin/env python3
"""Generate Android launcher icon mipmaps from assets/icon/app_icon_master_1024.png.

Usage: python3 tool/gen_launcher_icons.py  (from repo root)
High-quality Lanczos downscale; overwrites ic_launcher.png in every mipmap dir.
"""
import os
from PIL import Image

SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "icon", "app_icon_master_1024.png")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

master = Image.open(SRC).convert("RGBA")
assert master.size == (1024, 1024), f"master is {master.size}, expected 1024x1024"

for d, px in SIZES.items():
    out_dir = os.path.join(RES, d)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "ic_launcher.png")
    master.resize((px, px), Image.LANCZOS).save(out, optimize=True)
    print(f"wrote {out} ({px}x{px})")
