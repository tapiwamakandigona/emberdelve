#!/usr/bin/env python3
"""tool/build_weapon_sprites.py — AKP-4a: split the baked-in sword out of the
player sheets and generate per-weapon overlay sheets.

The base knight (Royal Knight Platformer by pixivan, CC0 — PROVENANCE.md)
has an ivory blade (#fffff2) baked into every animation, including the big
swing crescents in the attack sheets. That exact color is used ONLY by the
blade + swing FX (verified: helmet highlights are #e5e3e0, armor #b6b2a8),
so the split is a lossless color-key extraction:

  assets/images/player/*.png            (input, untouched: bladed originals)
  assets/images/player/body/*.png       (output: bladeless body sheets)
  assets/images/player/weapons/<id>/*.png (output: per-weapon overlays)

Per-weapon identity = a deterministic recolor of the extracted blade mask as
a hilt->blade->tip gradient measured from the grip (the mask pixel nearest
the body centroid), plus a 1px head dilation for the axe/hammer so their
silhouette actually reads chunkier. Dilation only ever fills pixels that are
transparent in the original frame — it can never paint over the body. Swing
crescents (large masks) get the same gradient, which lands the weapon's tint
on the baked swing FX for free (AKP-4b swing identity).

Run: python3 tool/build_weapon_sprites.py   (idempotent, no args)
After changing body sheets, re-run tool/build_skins.py (it recolors the
bladeless body sheets into the shop skins).
"""
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "assets" / "images" / "player"
BODY = SRC / "body"
WEAPONS = SRC / "weapons"

IVORY = (255, 255, 242)

# anim -> (frame_w, frame_h, frames)
ANIMS = {
    "idle": (22, 24, 5),
    "run": (22, 24, 6),
    "jump": (22, 24, 4),
    "fall": (22, 24, 4),
    "hit": (22, 24, 6),
    "roll": (22, 24, 11),
    "attack1": (40, 30, 10),
    "attack2": (40, 30, 12),
    "attack3": (40, 30, 8),
}

# weapon id -> dict(hilt, blade, tip, head_dilate)
# Colors picked to match the catalog fantasy + the AKP-3b arc tints
# (player_component._specialTints) so arc and weapon read as one object.
WEAPONS_DEF = {
    # Baseline: the original ivory sword, untouched.
    "squire_blade": dict(hilt=IVORY, blade=IVORY, tip=IVORY, head_dilate=0),
    # Steel axe head on a timber haft; chunkier silhouette.
    "woodsman_axe": dict(hilt=(122, 82, 48), blade=(207, 212, 217),
                         tip=(238, 242, 245), head_dilate=1),
    # Ember-forged fang: dark grip, hot amber blade, glowing tip.
    "ember_fang": dict(hilt=(74, 44, 32), blade=(242, 162, 75),
                       tip=(255, 210, 127), head_dilate=0),
    # Warden blade: gold guard, blue-steel blade, bright core.
    "warden_blade": dict(hilt=(223, 178, 91), blade=(185, 199, 217),
                         tip=(232, 238, 247), head_dilate=0),
    # Skypiercer: pale sky steel, white-hot tip.
    "skypiercer": dict(hilt=(207, 216, 232), blade=(169, 209, 247),
                       tip=(255, 255, 255), head_dilate=0),
    # Wind God's Hammer: dark haft, slate-green head, mossy glint.
    "wind_gods_hammer": dict(hilt=(92, 74, 51), blade=(111, 122, 106),
                             tip=(191, 232, 169), head_dilate=1),
}

# Masks bigger than this are blade+swing-crescent blobs: skip head dilation
# there so FX frames never get fattened.
CRESCENT_PX = 80


def frames(im, fw, fh, n):
    return [im.crop((i * fw, 0, (i + 1) * fw, fh)) for i in range(n)]


def split_frame(frame):
    """Return (body_frame, mask_pixels, grip) for one frame."""
    fw, fh = frame.size
    body = frame.copy()
    mask, solids = [], []
    px = frame.load()
    bpx = body.load()
    for y in range(fh):
        for x in range(fw):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if (r, g, b) == IVORY:
                mask.append((x, y))
                bpx[x, y] = (0, 0, 0, 0)
            else:
                solids.append((x, y))
    if not mask:
        return body, [], None
    if solids:
        cx = sum(p[0] for p in solids) / len(solids)
        cy = sum(p[1] for p in solids) / len(solids)
    else:  # pathological: no body pixels — anchor at frame centre
        cx, cy = fw / 2, fh / 2
    grip = min(mask, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
    return body, mask, grip


def weapon_frame(frame, mask, grip, spec):
    """Recolored weapon overlay for one frame (transparent elsewhere)."""
    fw, fh = frame.size
    out = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    if not mask:
        return out
    opx = out.load()
    fpx = frame.load()
    dmax = max(
        ((p[0] - grip[0]) ** 2 + (p[1] - grip[1]) ** 2) ** 0.5 for p in mask
    ) or 1.0
    head = set()
    for x, y in mask:
        d = ((x - grip[0]) ** 2 + (y - grip[1]) ** 2) ** 0.5 / dmax
        if d < 0.30:
            c = spec["hilt"]
        elif d > 0.82:
            c = spec["tip"]
        else:
            c = spec["blade"]
        opx[x, y] = (*c, 255)
        if 0.45 < d <= 0.95:
            head.add((x, y))
    # Head dilation: only into pixels transparent in the ORIGINAL frame.
    if spec["head_dilate"] and len(mask) <= CRESCENT_PX:
        grow = set()
        for x, y in head:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < fw and 0 <= ny < fh and fpx[nx, ny][3] == 0 \
                        and out.getpixel((nx, ny))[3] == 0:
                    grow.add((nx, ny))
        for x, y in grow:
            opx[x, y] = (*spec["blade"], 255)
    return out


def main():
    BODY.mkdir(parents=True, exist_ok=True)
    for wid in WEAPONS_DEF:
        (WEAPONS / wid).mkdir(parents=True, exist_ok=True)
    for anim, (fw, fh, n) in ANIMS.items():
        sheet = Image.open(SRC / f"{anim}.png").convert("RGBA")
        fs = frames(sheet, fw, fh, n)
        splits = [split_frame(f) for f in fs]
        body_sheet = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
        for i, (body, _, _) in enumerate(splits):
            body_sheet.paste(body, (i * fw, 0))
        body_sheet.save(BODY / f"{anim}.png")
        for wid, spec in WEAPONS_DEF.items():
            wsheet = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
            for i, (f, (_, mask, grip)) in enumerate(zip(fs, splits)):
                wsheet.paste(weapon_frame(f, mask, grip, spec), (i * fw, 0))
            wsheet.save(WEAPONS / wid / f"{anim}.png")
        print(f"{anim}: body + {len(WEAPONS_DEF)} weapon overlays")
    print("done. now run: python3 tool/build_skins.py")


if __name__ == "__main__":
    main()
