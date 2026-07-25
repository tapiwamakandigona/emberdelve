#!/usr/bin/env python3
"""tool/build_cave_assets.py — World 2 "Cinder Depths" environment art.

Deterministic recolors of already-shipped CC0 Sunny Land art (see
PROVENANCE.md) — same technique as build_skins.py, no new sources:

  - assets/images/tiles/tileset_cave.png  <- tiles/tileset.png
      greens (moss/grass) -> cold ash gray; warm browns (dirt) -> dark
      basalt; overall darkened, with a faint ember warmth kept in shadows.
  - assets/images/bg/cave_{back,middle,lights,front}.png <- bg/forest_*
      darkened + desaturated toward deep violet-gray; the "lights" layer is
      instead pushed to ember orange so the depths glow.

Run: python3 tool/build_cave_assets.py   (idempotent, no args)
"""
import colorsys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
IMG = REPO / "assets" / "images"


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


def cave_tiles(h, s, v):
    deg = h * 360
    if 50 <= deg <= 170:  # moss/grass greens -> cold ash
        return (250 / 360, s * 0.25, v * 0.72)
    if 10 <= deg < 50:  # warm dirt browns -> dark basalt with ember warmth
        return (18 / 360, s * 0.55, v * 0.62)
    return (h, s * 0.7, v * 0.75)


def cave_bg(h, s, v):
    # Deep violet-gray dusk.
    return (265 / 360, 0.25 + s * 0.2, v * 0.45)


def cave_lights(h, s, v):
    # Ember glow layer.
    return (22 / 360, 0.7, v * 0.55)


def main():
    remap(Image.open(IMG / "tiles" / "tileset.png"), cave_tiles).save(
        IMG / "tiles" / "tileset_cave.png")
    print("tiles/tileset_cave.png")
    for layer in ["back", "middle", "front"]:
        remap(Image.open(IMG / "bg" / f"forest_{layer}.png"), cave_bg).save(
            IMG / "bg" / f"cave_{layer}.png")
        print(f"bg/cave_{layer}.png")
    remap(Image.open(IMG / "bg" / "forest_lights.png"), cave_lights).save(
        IMG / "bg" / "cave_lights.png")
    print("bg/cave_lights.png")
    print("done.")


if __name__ == "__main__":
    main()
