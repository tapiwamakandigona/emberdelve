#!/usr/bin/env python3
"""HUD extras for the AK-parity control pass (AKP-2a/2c/5).

Unlike build_assets.py this needs NO staging download — everything derives
from assets already in the repo:

  hud/btn_down.png   btn_left.png (Kenney Mobile Controls, CC0) rotated 90°
                     counter-clockwise so the arrow points down.
  hud/icon_dash.png  original 48x48 double-chevron ">>" glyph drawn here in
                     the Kenney icon style (white, chunky, centered). CC0.

Run from anywhere: python3 tool/build_hud_extras.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
HUD = REPO / "assets/images/hud"


def build_btn_down():
    src = Image.open(HUD / "btn_left.png")
    # PIL rotate() is counter-clockwise: a left-pointing arrow becomes
    # down-pointing.
    out = src.rotate(90)
    out.save(HUD / "btn_down.png")
    print(f"btn_down.png   {out.size[0]}x{out.size[1]} (btn_left rotated 90 CCW)")


def build_icon_dash():
    size = 48
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    white = (255, 255, 255, 255)
    # Two chunky right-pointing chevrons (">>"), the AK dash glyph.
    # Each chevron: two 8px-thick strokes meeting at a point.
    t = 8  # stroke thickness
    h = 30  # chevron height
    cy = size // 2
    # Glyph extent: leftmost pixel = x0_first - t, rightmost = x0_last + 12.
    # With x0 in (14, 30): spans 6..42 — dead-centered in the 48px canvas.
    # (The original (7, 23) spanned -1..35, leaving the glyph 6px left of
    # center — visibly off inside the round button. Owner-reported 2026-07-25.)
    for x0 in (14, 30):
        pts_up = [(x0, cy - h // 2), (x0 + 12, cy), (x0 + 12 - t, cy),
                  (x0 - t, cy - h // 2)]
        pts_dn = [(x0, cy + h // 2), (x0 + 12, cy), (x0 + 12 - t, cy),
                  (x0 - t, cy + h // 2)]
        d.polygon(pts_up, fill=white)
        d.polygon(pts_dn, fill=white)
    im.save(HUD / "icon_dash.png")
    print(f"icon_dash.png  {size}x{size} (original, CC0)")


if __name__ == "__main__":
    build_btn_down()
    build_icon_dash()
