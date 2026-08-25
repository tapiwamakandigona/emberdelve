#!/usr/bin/env python3
"""Generate palette-variant enemy sheets from sheets already bundled in the app.

Why this exists
---------------
The v0.5.0 bestiary expansion (17 -> 30 enemies) needs a sheet per enemy, but the
original 0x72 DungeonTilesetII source pack is not vendored in this repo and the
old build_sprites.py is gone. What IS available is the already-recoloured sheets
under assets/images/enemies/, all derived from CC0 source. This script does the
same thing v0.4 already did for `ashen_colossus` and `pyre_matriarch` (recorded
in PROVENANCE.md as "ogre palette swap"): take a bundled sheet and remap its
palette in HSV, pixel for pixel.

Honesty about what this is
--------------------------
These are PALETTE VARIANTS, not new silhouettes. A variant reads as a related
creature, which is a normal roguelite convention (and is why the mapping below
pairs each new enemy with a plausible relative), but it is not the same thing as
original art. Anything shipped from here is placeholder-grade until real sheets
exist. Every generated file is recorded in PROVENANCE.md with its source sheet.

Determinism: pure function of (source pixels, palette), no randomness, so a
re-run reproduces byte-identical output.

Usage:  python3 tool/gen_variant_sprites.py [--check]
        --check verifies existing outputs are up to date without writing.
"""
from __future__ import annotations

import argparse
import colorsys
import json
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
ENEMY_DIR = ROOT / "assets" / "images" / "enemies"
META_PATH = ROOT / "assets" / "images" / "sprite_meta.json"

# new_id -> (source sheet id, hue_shift_degrees, saturation_scale, value_scale,
#            saturation_floor)
#
# A plain hue rotation is invisible on near-grey pixels, which is why the first
# pass produced three variants indistinguishable from their sources (the white
# skeleton, the pale rat, and a red-on-red golem). `saturation_floor` fixes that:
# any visible pixel below the floor is lifted TO the floor before the hue is
# applied, which colourises greys instead of rotating nothing. 0.0 = rotate only.
VARIANTS: dict[str, tuple[str, float, float, float, float]] = {
    # --- early regulars ----------------------------------------------------
    "scoria_tick": ("ember_beetle", 95.0, 0.55, 0.92, 0.00),   # pale grey-green
    "char_sprite": ("cinder_wisp", 250.0, 0.75, 0.95, 0.00),   # violet
    "flue_crawler": ("ash_rat", 28.0, 1.00, 0.82, 0.34),       # dull brown
    "cinder_pup": ("soot_hound", -22.0, 1.30, 1.10, 0.20),     # hot ember
    # --- late regulars -----------------------------------------------------
    "clinker_ogre": ("slag_brute", 200.0, 0.60, 0.85, 0.18),   # slate
    "smoke_stalker": ("ash_reaper", 212.0, 1.00, 0.92, 0.40),  # smoke blue
    "basalt_shell": ("kiln_golem", 232.0, 0.55, 0.72, 0.16),   # dark basalt
    "wick_widow": ("ash_wraith", 80.0, 0.85, 0.95, 0.00),      # green-gold
    # --- elites ------------------------------------------------------------
    "bellows_knight": ("forge_warden", 40.0, 1.10, 1.05, 0.00),  # brass
    "quench_hag": ("ash_wraith", 195.0, 0.90, 0.88, 0.00),       # cold blue
    # --- bosses ------------------------------------------------------------
    "cinder_hierophant": ("pyre_matriarch", 45.0, 0.80, 1.12, 0.00),  # gold-white
    # Brass, deliberately NOT another blue: basalt_shell already recolours this
    # same golem sheet toward blue, and two variants of one source must not read
    # as the same creature.
    "the_bellows": ("kiln_golem", 42.0, 1.25, 1.02, 0.30),
    "ashfall_twins": ("ember_tyrant", 190.0, 0.45, 1.05, 0.22),        # pale ash
    # --- v0.12.0 "New Embers" ----------------------------------------------
    # Same rules as above: each source is paired with a plausible relative,
    # and no two variants of one source share a hue neighbourhood.
    "tinder_mote": ("cinder_wisp", 38.0, 1.15, 1.12, 0.30),      # tinder gold
    "slag_snail": ("ember_beetle", 215.0, 0.70, 0.80, 0.25),     # cooled iron
    "vent_serpent": ("cinder_crawler", 150.0, 0.90, 0.95, 0.30), # vent-gas teal
    "pumice_hulk": ("slag_brute", 40.0, 0.35, 1.15, 0.12),       # pale pumice
    "cinder_marshal": ("pyre_howler", -12.0, 1.15, 0.90, 0.20),  # drill crimson
    # --- v0.22.0 "The Crowned Deep" ------------------------------------------
    # Same rules: plausible relatives, and no two variants of one source in
    # the same hue neighbourhood. Ogre-sheet hues already taken: original red
    # (tyrant), cold ash (colossus), crimson (matriarch), gold-white
    # (hierophant), pale ash (twins). kiln_golem hues taken: blue (basalt),
    # brass (the_bellows).
    "slag_regent": ("ashen_colossus", -50.0, 0.85, 0.90, 0.28),   # verdigris
    "hearthless_king": ("ember_tyrant", 265.0, 0.70, 0.85, 0.24), # cold violet
    "ashglass_sentinel": ("kiln_golem", 160.0, 0.55, 1.10, 0.20), # pale glass-green
    "coal_seam_wyrm": ("cinder_crawler", -8.0, 1.20, 0.62, 0.30), # coal-and-ember
    # --- v0.47.0 "The Answered Blow" ------------------------------------------
    # Same rules. slag_brute hues taken: slate 200 (clinker), pale 40 (pumice).
    # ember_beetle taken: grey-green 95 (scoria), cooled iron 215 (snail).
    # forge_warden taken: brass 40 (bellows_knight).
    "vent_ram": ("slag_brute", 70.0, 1.00, 0.95, 0.28),          # sulfur vent-green
    "cinder_urchin": ("ember_beetle", 285.0, 0.95, 0.85, 0.28),  # cinder-bloom violet
    "magma_lancer": ("forge_warden", -40.0, 1.25, 0.80, 0.30),   # deep magma crimson
}


def remap(img: Image.Image, hue_shift: float, sat: float, val: float,
          sat_floor: float = 0.0) -> Image.Image:
    """HSV remap that preserves alpha and every pixel boundary exactly."""
    src = img.convert("RGBA")
    out = Image.new("RGBA", src.size)
    src_px, out_px = src.load(), out.load()
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    shift = (hue_shift % 360.0) / 360.0
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = src_px[x, y]
            if a == 0:
                out_px[x, y] = (0, 0, 0, 0)
                continue
            key = (r, g, b)
            hit = cache.get(key)
            if hit is None:
                h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                h = (h + shift) % 1.0
                s = max(0.0, min(1.0, s * sat))
                # Lift near-greys so the new hue is actually visible. Pure
                # black/white (v at either extreme) is left alone: outlines and
                # highlights are what keep the pixel art readable.
                if s < sat_floor and 0.06 < v < 0.97:
                    s = sat_floor
                v = max(0.0, min(1.0, v * val))
                nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
                hit = (round(nr * 255), round(ng * 255), round(nb * 255))
                cache[key] = hit
            out_px[x, y] = (hit[0], hit[1], hit[2], a)
    return out


def meta_entry(meta: dict, source_id: str, new_id: str) -> dict:
    """Copy the source's frame geometry verbatim: a palette swap cannot change it."""
    for e in meta["enemies"]:
        if e["id"] == source_id:
            entry = json.loads(json.dumps(e))
            entry["id"] = new_id
            entry["source_base"] = f"{source_id} (palette variant)"  # noqa: v0.5.0/v0.12.0 labels set at gen time
            return entry
    raise SystemExit(f"source {source_id} missing from sprite_meta.json")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="verify outputs exist and match, write nothing")
    args = ap.parse_args()

    meta = json.loads(META_PATH.read_text())
    known = {e["id"] for e in meta["enemies"]}
    added, stale = [], []

    for new_id, (source_id, hue, sat, val, floor) in VARIANTS.items():
        src_path = ENEMY_DIR / f"{source_id}.png"
        dst_path = ENEMY_DIR / f"{new_id}.png"
        if not src_path.exists():
            raise SystemExit(f"missing source sheet {src_path}")
        want = remap(Image.open(src_path), hue, sat, val, floor)
        if args.check:
            if not dst_path.exists():
                stale.append(f"{new_id}: sheet missing")
            else:
                have = Image.open(dst_path).convert("RGBA")
                if have.tobytes() != want.tobytes():
                    stale.append(f"{new_id}: sheet differs from generator")
        else:
            want.save(dst_path)
            added.append(new_id)
        if new_id not in known:
            if args.check:
                stale.append(f"{new_id}: no sprite_meta entry")
            else:
                meta["enemies"].append(meta_entry(meta, source_id, new_id))
                known.add(new_id)

    if args.check:
        for s in stale:
            print("STALE:", s)
        print("check:", "FAIL" if stale else "OK")
        return 1 if stale else 0

    META_PATH.write_text(json.dumps(meta, indent=1) + "\n")
    print(f"wrote {len(added)} sheets: {', '.join(sorted(added))}")
    print(f"sprite_meta.json now has {len(meta['enemies'])} enemies")
    return 0


if __name__ == "__main__":
    sys.exit(main())
