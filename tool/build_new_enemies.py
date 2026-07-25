#!/usr/bin/env python3
"""tool/build_new_enemies.py — Stage 2 enemy sprites (owner-directed
2026-07-25: "more enemies").

Deterministic recolors of already-shipped Sunny Land CC0 enemy sheets,
same technique/precedent as tool/build_w2_enemies.py:

  - enemies/pyre_wisp.png  <- ashbat.png (eagle flyer):
      plumage -> bright pyre gold with a hot white core; reads as a glowing
      spirit, clearly distinct from the dark cinder_diver recolor.
  - enemies/slag_hound.png       <- hopper_idle.png (frog walker) and
    enemies/slag_hound_charge.png <- hopper_jump.png:
      greens -> molten orange/black crust; the jump strip becomes the
      lunging charge pose.

Run: python3 tool/build_new_enemies.py   (idempotent, no args)
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


def pyre_wisp(h, s, v):
    """Everything glows: hue -> pyre gold, bright pixels wash toward white."""
    if v > 0.75:
        return (46 / 360, s * 0.35, min(1.0, v * 1.25))  # hot core
    return (38 / 360, min(1.0, s * 1.1 + 0.2), min(1.0, v * 1.3 + 0.1))


def slag_hound(h, s, v):
    deg = h * 360
    if 60 <= deg <= 180 and s > 0.2:  # green body -> charred crust
        return (15 / 360, s * 0.55, v * 0.45)
    if v > 0.6:  # highlights -> molten seams
        return (24 / 360, min(1.0, s * 1.3 + 0.25), min(1.0, v * 1.15))
    return (18 / 360, s * 0.8, v * 0.7)


def main():
    remap(Image.open(ENEMIES / "ashbat.png"), pyre_wisp).save(
        ENEMIES / "pyre_wisp.png")
    print("pyre_wisp.png  (<- ashbat.png)")
    remap(Image.open(ENEMIES / "hopper_idle.png"), slag_hound).save(
        ENEMIES / "slag_hound.png")
    remap(Image.open(ENEMIES / "hopper_jump.png"), slag_hound).save(
        ENEMIES / "slag_hound_charge.png")
    print("slag_hound.png + slag_hound_charge.png  (<- hopper strips)")


if __name__ == "__main__":
    main()
