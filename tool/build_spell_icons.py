#!/usr/bin/env python3
"""tool/build_spell_icons.py — spell shop icons + HUD spell button glyph.

Unlike build_shop_icons.py these need NO downloads: the three spell glyphs
are drawn procedurally here (original art, CC0) on the same 20x20 pixel
grid / two-tone (bright core + darker rim) / x4-nearest pipeline, so they
sit next to the game-icons.net weapon/ability icons without clashing.

Outputs:
  assets/images/shop/spell_ember_burst.png   80x80
  assets/images/shop/spell_stone_veil.png    80x80
  assets/images/shop/spell_hearth_light.png  80x80
  assets/images/hud/icon_spell.png           48x48 white spark (Kenney-style,
                                             optically centered — the HUD
                                             drift-guard test pins this)

Run from anywhere: python3 tool/build_spell_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
SHOP = REPO / "assets/images/shop"
HUD = REPO / "assets/images/hud"

PIX = 20
SCALE = 4

EMBER = ((232, 106, 23), (146, 56, 12))
STEEL = ((196, 202, 212), (110, 118, 134))
GOLD = ((242, 193, 78), (168, 116, 34))


def two_tone(mask: Image.Image, bright, dark) -> Image.Image:
    """Bright fill with a 1px darker rim, from a 20x20 L-mode glyph mask."""
    px = mask.load()
    out = Image.new("RGBA", (PIX, PIX), (0, 0, 0, 0))
    op = out.load()
    for y in range(PIX):
        for x in range(PIX):
            if px[x, y] == 0:
                continue
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < PIX and 0 <= ny < PIX) or px[nx, ny] == 0:
                    edge = True
                    break
            op[x, y] = (*(dark if edge else bright), 255)
    return out.resize((PIX * SCALE, PIX * SCALE), Image.NEAREST)


def mask_ember_burst() -> Image.Image:
    """Ring of flame: circle ring + 8 outward flame spikes."""
    m = Image.new("L", (PIX, PIX), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((5, 5, 14, 14), outline=255, width=2)
    for spike in ((9, 1, 10, 4), (9, 15, 10, 18), (1, 9, 4, 10),
                  (15, 9, 18, 10)):
        d.rectangle(spike, fill=255)
    for spike in ((3, 3, 5, 5), (14, 3, 16, 5), (3, 14, 5, 16),
                  (14, 14, 16, 16)):
        d.rectangle(spike, fill=255)
    return m


def mask_stone_veil() -> Image.Image:
    """Kite shield with a keystone notch."""
    m = Image.new("L", (PIX, PIX), 0)
    d = ImageDraw.Draw(m)
    d.polygon([(9, 1), (10, 1), (17, 4), (17, 10), (10, 18), (9, 18),
               (2, 10), (2, 4)], fill=255)
    d.rectangle((8, 6, 11, 9), fill=0)  # keystone notch
    return m


def mask_hearth_light() -> Image.Image:
    """Heart with rays — warmth that heals."""
    m = Image.new("L", (PIX, PIX), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((4, 5, 9, 10), fill=255)
    d.ellipse((10, 5, 15, 10), fill=255)
    d.polygon([(4, 9), (15, 9), (10, 16), (9, 16)], fill=255)
    for ray in ((9, 1, 10, 3), (1, 6, 2, 7), (17, 6, 18, 7)):
        d.rectangle(ray, fill=255)
    return m


def build_hud_icon():
    """48x48 white 4-point spark, optically centered (drift-guard safe)."""
    size = 48
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    white = (255, 255, 255, 255)
    c = size // 2
    # Four-point star: tall + wide diamonds, plus a small core diamond.
    d.polygon([(c, 6), (c + 5, c), (c, size - 6), (c - 5, c)], fill=white)
    d.polygon([(6, c), (c, c - 5), (size - 6, c), (c, c + 5)], fill=white)
    im.save(HUD / "icon_spell.png")
    print(f"icon_spell.png  {size}x{size} (original, CC0)")


def main():
    for name, mask, tone in (
        ("spell_ember_burst", mask_ember_burst(), EMBER),
        ("spell_stone_veil", mask_stone_veil(), STEEL),
        ("spell_hearth_light", mask_hearth_light(), GOLD),
    ):
        two_tone(mask, *tone).save(SHOP / f"{name}.png")
        print(f"{name}.png  {PIX * SCALE}x{PIX * SCALE} (original, CC0)")
    build_hud_icon()


if __name__ == "__main__":
    main()
