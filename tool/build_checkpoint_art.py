#!/usr/bin/env python3
"""tool/build_checkpoint_art.py — original CC0 campfire checkpoint sprites.

Draws two 16x16 pixel-art frames in the Emberdelve palette:
  props/campfire_out.png  — cold logs + ash ring (unlit checkpoint)
  props/campfire_lit.png  — same logs with an ember bed and flame

No external assets: every pixel is placed by this script, so the output is
original work and needs no attribution (PROVENANCE.md "original" table).
Run: python3 tool/build_checkpoint_art.py
"""
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "images" / "props"

# palette (matches the existing prop/tile art)
ASH = (74, 66, 62, 255)
ASH_L = (104, 94, 88, 255)
LOG = (108, 74, 46, 255)
LOG_D = (74, 50, 32, 255)
LOG_L = (140, 100, 62, 255)
EMBER = (232, 106, 23, 255)
EMBER_D = (176, 62, 16, 255)
FLAME = (242, 193, 78, 255)
FLAME_H = (255, 232, 160, 255)
CLEAR = (0, 0, 0, 0)


def base(img):
    px = img.load()
    # ash ring
    for x in range(3, 13):
        px[x, 14] = ASH
    for x in range(4, 12):
        px[x, 13] = ASH_L
    # crossed logs
    for i in range(8):
        px[3 + i, 12 - (i // 3)] = LOG
        px[3 + i, 13 - (i // 3)] = LOG_D
    for i in range(8):
        px[12 - i, 12 - (i // 3)] = LOG_L
    px[7, 12] = LOG_D
    px[8, 12] = LOG_D


def make(lit: bool, path: Path):
    img = Image.new("RGBA", (16, 16), CLEAR)
    base(img)
    px = img.load()
    if lit:
        # ember bed
        for x in range(5, 11):
            px[x, 12] = EMBER_D
        for x in range(6, 10):
            px[x, 11] = EMBER
        # flame body
        flame = [
            (7, 10), (8, 10), (6, 9), (7, 9), (8, 9), (9, 9),
            (7, 8), (8, 8), (9, 8), (7, 7), (8, 7), (8, 6), (7, 5),
        ]
        for x, y in flame:
            px[x, y] = EMBER
        for x, y in [(7, 9), (8, 8), (8, 7), (7, 6)]:
            px[x, y] = FLAME
        px[8, 6] = FLAME_H
        px[7, 7] = FLAME_H
    else:
        # cold: a couple of grey ash flecks only
        px[7, 12] = ASH_L
        px[9, 12] = ASH
    img.save(path)
    print("wrote", path)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    make(False, OUT / "campfire_out.png")
    make(True, OUT / "campfire_lit.png")


if __name__ == "__main__":
    main()
