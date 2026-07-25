#!/usr/bin/env python3
"""tool/build_shop_icons.py — pixel-styled shop icons for weapons + abilities.

Sources: game-icons.net SVGs (CC BY 3.0 — Lorc / Delapouite; credited in
CREDITS.md, per-file rows in PROVENANCE.md), same pack family the dice-era UI
used. Pipeline per icon: rasterize SVG at 512px (cairosvg) -> alpha-only glyph
-> two-tone ember tint (bright core + darker edge via alpha threshold) ->
downscale to 20x20 nearest (pixelation) -> upscale x4 nearest -> 80x80 PNG.

Run: python3 tool/build_shop_icons.py <svg_dir>   (needs cairosvg + pillow)
Outputs: assets/images/shop/<id>.png
"""
import io
import sys
from pathlib import Path

import cairosvg
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "images" / "shop"

# icon id -> (svg file, (bright RGB, dark RGB))
GOLD = ((242, 193, 78), (168, 116, 34))
STEEL = ((196, 202, 212), (110, 118, 134))
EMBER = ((232, 106, 23), (146, 56, 12))
GREEN = ((142, 190, 82), (74, 116, 44))
BLUE = ((110, 160, 220), (54, 88, 138))

ICONS = {
    # weapons
    "weapon_squire_blade": ("pointy-sword.svg", STEEL),
    "weapon_woodsman_axe": ("battered-axe.svg", STEEL),
    "weapon_ember_fang": ("curvy-knife.svg", EMBER),
    "weapon_warden_blade": ("broadsword.svg", GOLD),
    "weapon_skypiercer": ("barbed-spear.svg", BLUE),
    "weapon_wind_gods_hammer": ("flat-hammer.svg", GOLD),
    # abilities
    "ability_coin_magnet": ("magnet.svg", GOLD),
    "ability_apple_pouch": ("shiny-apple.svg", GREEN),
    "ability_haggler": ("price-tag.svg", GOLD),
    "ability_chest_radar": ("radar-sweep.svg", BLUE),
}

PIX = 20  # pixelation grid
SCALE = 4  # final = 80x80


def build(svg: Path, bright, dark) -> Image.Image:
    png = cairosvg.svg2png(url=str(svg), output_width=512, output_height=512)
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    # game-icons ship a black square background layer + white glyph on some
    # icons, or a plain black glyph on transparent. Normalize: treat any
    # opaque pixel's luminance as the glyph mask (white=glyph if bg present).
    px = im.load()
    w, h = im.size
    corner_opaque = px[2, 2][3] > 200
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            lum = (r + g + b) // 3
            mp[x, y] = lum if corner_opaque else 255
    small = mask.resize((PIX, PIX), Image.LANCZOS)
    out = Image.new("RGBA", (PIX, PIX), (0, 0, 0, 0))
    op = out.load()
    sp = small.load()
    for y in range(PIX):
        for x in range(PIX):
            v = sp[x, y]
            if v < 48:
                continue
            # Edge pixels (weaker coverage) get the dark tone -> crisp rim.
            op[x, y] = (*(bright if v > 150 else dark), 255)
    return out.resize((PIX * SCALE, PIX * SCALE), Image.NEAREST)


def main():
    svg_dir = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    for icon_id, (svg, (bright, dark)) in ICONS.items():
        build(svg_dir / svg, bright, dark).save(OUT / f"{icon_id}.png")
        print(f"icon {icon_id}.png")
    print("done.")


if __name__ == "__main__":
    main()
