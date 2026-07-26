#!/usr/bin/env python3
"""tool/build_skins.py — generate the shop skins as real sprite sheets.

Recolors the base knight (Royal Knight Platformer by pixivan, CC0 — see
PROVENANCE.md) into the catalog skins by deterministic HSV remap, the same
technique as the dice-era build_sprites.py:

  - red (starter)   = base sheets, untouched, in assets/images/player/
  - ember_monk      = cloth -> ember orange, armor warmed
  - shadow_thief    = cloth -> deep violet, armor darkened
  - hearth_knight   = cloth -> hearth blue, armor gilded
  - grove_sentinel  = cloth -> forest green, armor mossy   (Stage 2, 2026-07-25)
  - ash_wraith      = cloth -> ash grey, armor charcoal    (Stage 2, 2026-07-25)

"Cloth" = saturated red-hue pixels (cape/hat); "armor" = low-saturation
pixels. Outlines, skin tones, shield golds are left alone so the silhouette
stays readable. Outputs assets/images/player/skins/<id>/<anim>.png.

Run: python3 tool/build_skins.py   (idempotent, no args)
"""
import colorsys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "assets" / "images" / "player"
# AKP-4a: skins recolor the BLADELESS body sheets (tool/build_weapon_sprites.py
# splits the baked-in sword out); the equipped weapon is a separate overlay
# sheet drawn on top, so it keeps its identity across every skin.
BODY = SRC / "body"
ANIMS = ["idle", "run", "jump", "fall", "hit", "roll",
         "attack1", "attack2", "attack3"]

# skin id -> (cloth_target_hue_deg, cloth_sat_mul, cloth_val_mul,
#             armor_rgb_multipliers)
SKINS = {
    "ember_monk": (28.0, 1.05, 1.06, (1.10, 1.00, 0.82)),
    "shadow_thief": (275.0, 0.75, 0.72, (0.62, 0.62, 0.74)),
    "hearth_knight": (214.0, 0.95, 0.92, (1.12, 1.02, 0.72)),
    "grove_sentinel": (125.0, 0.85, 0.88, (0.82, 1.02, 0.72)),
    "ash_wraith": (270.0, 0.10, 0.80, (0.55, 0.55, 0.60)),
}


def is_cloth(r, g, b, a):
    """Saturated red-hue pixel (the knight's cape/hat/trim)."""
    if a < 16:
        return False
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return s > 0.45 and (h < 0.05 or h > 0.93) and v > 0.25


def is_armor(r, g, b, a):
    """Low-saturation mid/bright pixel (plate, helmet, boots)."""
    if a < 16:
        return False
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    return s < 0.12 and v > 0.35


def remap(im, hue_deg, s_mul, v_mul, armor_mul):
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if is_cloth(r, g, b, a):
                h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                nr, ng, nb = colorsys.hsv_to_rgb(
                    (hue_deg / 360.0) % 1.0,
                    min(1.0, s * s_mul),
                    min(1.0, v * v_mul))
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
            elif is_armor(r, g, b, a):
                mr, mg, mb = armor_mul
                px[x, y] = (min(255, int(r * mr)), min(255, int(g * mg)),
                            min(255, int(b * mb)), a)
    return im


def main():
    for skin, (hue, s_mul, v_mul, armor) in SKINS.items():
        out_dir = SRC / "skins" / skin
        out_dir.mkdir(parents=True, exist_ok=True)
        for anim in ANIMS:
            src = BODY / f"{anim}.png"
            out = out_dir / f"{anim}.png"
            remap(Image.open(src), hue, s_mul, v_mul, armor).save(out)
        print(f"skin {skin}: {len(ANIMS)} sheets -> "
              f"{out_dir.relative_to(REPO)}")
    print("done.")


if __name__ == "__main__":
    main()
