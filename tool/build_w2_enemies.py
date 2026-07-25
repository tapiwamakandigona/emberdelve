#!/usr/bin/env python3
"""tool/build_w2_enemies.py — World 2 enemy sprites (Cinder Depths).

Deterministic recolors of already-shipped Sunny Land CC0 enemy sheets
(same technique/precedent as build_skins.py / the moss-tinted boss):

  - enemies/soot_creeper.png <- thornling.png (opossum walker):
      cool blues -> soot black-gray, warm accents -> ember orange.
  - enemies/cinder_diver.png <- ashbat.png (eagle flyer):
      plumage -> dark ash, beak/talons -> hot ember.

Run: python3 tool/build_w2_enemies.py   (idempotent, no args)
"""
import colorsys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
ENEMIES = REPO / "assets" / "images" / "enemies"


def remap(im, fn):
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            h, s, v = fn(h, s, v)
            nr, ng, nb = colorsys.hsv_to_rgb(h % 1.0, min(1, max(0, s)),
                                             min(1, max(0, v)))
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return im


def soot_creeper(h, s, v):
    deg = h * 360
    if 170 <= deg <= 280 and s > 0.2:  # blue fur -> soot
        return (270 / 360, s * 0.18, v * 0.55)
    if (deg < 60 or deg > 330) and s > 0.3:  # warm accents -> ember
        return (20 / 360, min(1.0, s * 1.2), min(1.0, v * 1.1))
    return (h, s * 0.5, v * 0.7)


def cinder_diver(h, s, v):
    deg = h * 360
    if 25 <= deg <= 70 and s > 0.35 and v > 0.4:  # beak/talons -> hot ember
        return (16 / 360, 0.95, min(1.0, v * 1.15))
    # plumage -> dark ash with a violet cast
    return (275 / 360, 0.15 + s * 0.15, v * 0.6)


def main():
    remap(Image.open(ENEMIES / "thornling.png"), soot_creeper).save(
        ENEMIES / "soot_creeper.png")
    print("enemies/soot_creeper.png")
    remap(Image.open(ENEMIES / "ashbat.png"), cinder_diver).save(
        ENEMIES / "cinder_diver.png")
    print("enemies/cinder_diver.png")
    print("done.")


if __name__ == "__main__":
    main()
