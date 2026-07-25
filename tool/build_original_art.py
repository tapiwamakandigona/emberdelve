#!/usr/bin/env python3
"""tool/build_original_art.py — original, studio-owned pixel art.

Replaces the remaining CC-BY art so the shipped game carries ZERO
legally-required attributions (see docs/original-assets.md):

  assets/images/items/chest.png   (was: dustdfg treasure chest, CC-BY 4.0)
  assets/icon/app_icon_master_1024.png + android mipmaps
                                  (was: incorporated game-icons.net
                                   "dice-six-faces-six" by Delapouite,
                                   CC-BY 3.0 — also dice-era branding that
                                   no longer matches the platformer)

Both pieces are drawn from scratch, per-pixel, by this script — no traced,
sampled, or derived third-party artwork. Designs are deliberately our own:
dark-oak chest with ash-iron banding and an ember-rune glow (not dustdfg's
maroon/gold chest, not Apple Knight's chest), and an "ember in the deep"
flame-over-cave mark for the launcher icon. (c) Tsoro Studios, dedicated
CC0 1.0 in PROVENANCE.md.

Run: python3 tool/build_original_art.py    (idempotent)
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------- palette
OUTLINE = (24, 16, 14, 255)          # near-black warm outline
WOOD_D = (61, 39, 27, 255)           # dark oak
WOOD_M = (89, 57, 38, 255)           # mid oak
WOOD_L = (117, 78, 50, 255)          # lit oak edge
IRON_D = (58, 62, 74, 255)           # ash-iron dark
IRON_M = (94, 100, 115, 255)         # ash-iron
IRON_L = (142, 149, 166, 255)        # ash-iron highlight
EMBER_D = (191, 66, 14, 255)         # deep ember
EMBER_M = (240, 122, 26, 255)        # ember orange
EMBER_L = (255, 196, 66, 255)        # hot yellow
GOLD_D = (166, 114, 26, 255)
GOLD_M = (222, 168, 44, 255)
GOLD_L = (255, 222, 120, 255)
T = (0, 0, 0, 0)


class Px:
    def __init__(self, w, h):
        self.im = Image.new("RGBA", (w, h), T)
        self.p = self.im.load()
        self.w, self.h = w, h

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[x, y] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def outline_content(self, c=OUTLINE):
        """1px outline around every non-transparent region."""
        src = self.im.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and src[nx, ny][3] != 0:
                        self.set(x, y, c)
                        break


# ---------------------------------------------------------------- chest

def _chest_body(px: Px, ox: int, top: int):
    """Lower box of the chest: x in [ox+5, ox+42], y in [top, 43]."""
    x0, x1, y1 = ox + 5, ox + 42, 43
    px.rect(x0, top, x1, y1, WOOD_M)
    # plank shading: vertical grain lines + darker bottom
    for x in range(x0 + 1, x1, 5):
        px.vline(x, top + 1, y1 - 1, WOOD_D)
    px.hline(x0, x1, y1, WOOD_D)
    px.hline(x0, x1, top, WOOD_L)
    # iron corner brackets
    for bx in (x0, x1 - 3):
        px.rect(bx, top, bx + 3, top + 2, IRON_M)
        px.rect(bx, y1 - 2, bx + 3, y1, IRON_M)
        px.set(bx + 1, top + 1, IRON_L)
    # iron feet
    px.rect(x0 + 1, y1 + 1, x0 + 5, y1 + 3, IRON_D)
    px.rect(x1 - 5, y1 + 1, x1 - 1, y1 + 3, IRON_D)
    # central iron band + hasp
    cx = ox + 24
    px.rect(cx - 2, top, cx + 1, y1, IRON_M)
    px.vline(cx - 2, top, y1, IRON_D)
    px.vline(cx + 1, top, y1, IRON_D)


def _chest_lid_closed(px: Px, ox: int):
    """Domed lid, y in [14, 27]."""
    x0, x1 = ox + 5, ox + 42
    px.rect(x0 + 2, 14, x1 - 2, 16, WOOD_L)      # crown
    px.rect(x0 + 1, 17, x1 - 1, 19, WOOD_M)
    px.rect(x0, 20, x1, 27, WOOD_M)
    for x in range(x0 + 1, x1, 5):
        px.vline(x, 18, 26, WOOD_D)
    px.hline(x0, x1, 27, WOOD_D)                 # lid rim
    cx = ox + 24
    px.rect(cx - 2, 14, cx + 1, 27, IRON_M)      # band over lid
    px.vline(cx - 2, 15, 27, IRON_D)
    px.vline(cx + 1, 15, 27, IRON_D)
    # ember-rune lock plate on the band (our signature detail)
    px.rect(cx - 3, 24, cx + 2, 30, IRON_L)
    px.rect(cx - 2, 25, cx + 1, 29, IRON_D)
    px.set(cx - 1, 26, EMBER_M)
    px.set(cx, 26, EMBER_L)
    px.set(cx - 1, 27, EMBER_L)
    px.set(cx, 27, EMBER_M)
    px.set(cx - 1, 28, EMBER_D)
    px.set(cx, 28, EMBER_D)


def _chest_lid_open(px: Px, ox: int, lift: int):
    """Lid tilted back behind the box; lift = how far up (px)."""
    x0, x1 = ox + 7, ox + 40
    y0 = 6 - lift
    px.rect(x0, y0 + 4, x1, y0 + 9, WOOD_M)      # underside facing viewer
    px.rect(x0 + 1, y0 + 1, x1 - 1, y0 + 3, WOOD_D)
    px.hline(x0, x1, y0 + 9, WOOD_L)
    cx = ox + 24
    px.rect(cx - 2, y0 + 1, cx + 1, y0 + 9, IRON_D)


def _treasure(px: Px, ox: int, top: int, hot: bool):
    """Glowing ember-gold pile spilling over the box rim at y=top."""
    import random
    rnd = random.Random(7)
    x0, x1 = ox + 7, ox + 40
    # mound
    for x in range(x0, x1 + 1):
        d = min(x - x0, x1 - x) / (x1 - x0) * 2
        h = int(2 + 4 * d)
        for y in range(top - h, top + 2):
            px.set(x, y, GOLD_M)
    # sparkle + ember dithering
    for _ in range(46):
        x = rnd.randint(x0, x1)
        y = rnd.randint(top - 5, top + 1)
        if px.p[x, y][3]:
            px.set(x, y, rnd.choice([GOLD_L, GOLD_D, EMBER_M if hot else GOLD_M]))
    if hot:
        # rising sparks
        for (sx, sy, c) in [(x0 + 6, top - 9, EMBER_L), (x0 + 14, top - 12, EMBER_M),
                            (x0 + 22, top - 8, EMBER_L), (x0 + 28, top - 13, EMBER_D)]:
            px.set(sx, sy, c)


def build_chest(out: Path):
    """144x48: 3 frames of 48x48 — closed / opening / open (engine contract:
    lib/game/components/items_component.dart reads frame*48 rects)."""
    px = Px(144, 48)
    # frame 0 — closed
    _chest_body(px, 0, 28)
    _chest_lid_closed(px, 0)
    # frame 1 — opening: lid lifting, thin hot gap
    _chest_body(px, 48, 28)
    _chest_lid_open(px, 48, 2)
    px.hline(48 + 7, 48 + 40, 27, EMBER_M)       # glow gap
    px.hline(48 + 9, 48 + 38, 26, EMBER_D)
    _treasure(px, 48, 27, hot=False)
    # frame 2 — open: lid fully back, treasure blazing
    _chest_body(px, 96, 28)
    _chest_lid_open(px, 96, 6)
    _treasure(px, 96, 26, hot=True)
    px.outline_content()
    px.im.save(out)
    print(f"wrote {out} {px.im.size}")


# ---------------------------------------------------------------- app icon

def build_icon(master_out: Path, res_dir: Path):
    """64x64 pixel mark, nearest-upscaled to 1024 master + android mipmaps.

    Design: "the ember in the delve" — a hot pixel flame rising out of a
    dark cave mouth, on a deep charcoal field with a subtle arch. Original
    design; replaces the dice-era icon that incorporated a CC-BY glyph.
    """
    s = 64
    px = Px(s, s)
    BG0 = (26, 22, 26, 255)
    BG1 = (30, 26, 30, 255)
    ARCH = (54, 44, 46, 255)
    CAVE = (14, 11, 13, 255)

    # background field with corner rounding (radius 6)
    r = 6
    for y in range(s):
        for x in range(s):
            cx = min(x, s - 1 - x)
            cy = min(y, s - 1 - y)
            if cx < r and cy < r and (r - cx) ** 2 + (r - cy) ** 2 > r * r + r:
                continue  # transparent rounded corner
            px.set(x, y, BG1 if (x + y) % 2 else BG0)

    # cave arch: dark opening bottom-center with stone rim
    def arch_half_w(y):  # y from 30..63
        t = (y - 30) / 33
        return int(10 + 12 * t)

    for y in range(30, s):
        hw = arch_half_w(y)
        for x in range(32 - hw, 32 + hw):
            px.set(x, y, CAVE)
        px.set(32 - hw - 1, y, ARCH)
        px.set(32 + hw, y, ARCH)
        px.set(32 - hw - 2, y, BG0)
        px.set(32 + hw + 1, y, BG0)

    # soft ember glow radiating from the cave mouth
    GLOW1 = (48, 32, 26, 255)
    GLOW2 = (70, 40, 24, 255)
    for y in range(s):
        for x in range(s):
            c = px.p[x, y]
            if c[3] == 0 or c not in (BG0, BG1):
                continue
            d2 = (x - 32) ** 2 + (y - 46) ** 2
            if d2 < 20 ** 2:
                px.set(x, y, GLOW2)
            elif d2 < 28 ** 2:
                px.set(x, y, GLOW1)

    # flame: layered teardrop shapes (deep -> orange -> hot core)
    def blob(cx, cy, w, h, c, sway=0.0):
        for y in range(cy - h, cy + h // 2 + 1):
            t = (cy + h // 2 - y) / (h * 1.5)        # 0 bottom -> 1 tip
            hw = max(1, int(w * (1 - t) ** 0.8))
            off = int(sway * (t ** 2) * w)
            for x in range(cx - hw + off, cx + hw + off):
                px.set(x, y, c)

    blob(32, 44, 12, 24, EMBER_D, sway=0.35)
    blob(32, 45, 9, 20, EMBER_M, sway=0.30)
    blob(31, 46, 5, 13, EMBER_L, sway=0.25)
    blob(31, 47, 2, 6, (255, 244, 190, 255), sway=0.2)
    # sparks
    for (sx, sy, c) in [(22, 20, EMBER_M), (43, 16, EMBER_D), (38, 12, EMBER_L),
                        (26, 12, EMBER_D), (46, 26, EMBER_M)]:
        px.set(sx, sy, c)
    # ember glow on the cave rim
    for y in range(46, s, 3):
        hw = arch_half_w(y)
        px.set(32 - hw, y, EMBER_D)
        px.set(32 + hw - 1, y, EMBER_D)

    master = px.im.resize((1024, 1024), Image.NEAREST)
    master.save(master_out)
    print(f"wrote {master_out} {master.size}")

    sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for name, sz in sizes.items():
        d = res_dir / f"mipmap-{name}"
        if not d.exists():
            continue
        # launcher icons must be opaque-friendly: composite on charcoal
        base = Image.new("RGBA", (s, s), (26, 22, 26, 255))
        base.alpha_composite(px.im)
        base.resize((sz, sz), Image.NEAREST).save(d / "ic_launcher.png")
        print(f"wrote {d / 'ic_launcher.png'} ({sz}x{sz})")


def main():
    build_chest(REPO / "assets" / "images" / "items" / "chest.png")
    build_icon(REPO / "assets" / "icon" / "app_icon_master_1024.png",
               REPO / "android" / "app" / "src" / "main" / "res")


if __name__ == "__main__":
    sys.exit(main())
