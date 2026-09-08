#!/usr/bin/env python3
"""Mechanically pack original source art into native-resolution game sheets.

Requires Pillow + numpy on the ART workstation only. No runtime dependency.
Source generation's nominal grid is not trusted: transparent gutters define
the actual rows/columns, verified before cropping so no limbs are cut off.
No HSV remapping or borrowing the old four character silhouettes.

Usage: python3 tool/art/build_delvers.py [--check]
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "tool/art/delvers"
DEST = ROOT / "assets/images/characters"
META = ROOT / "assets/images/sprite_meta.json"
W, H = 32, 40


def spans(active):
    indices = np.flatnonzero(active)
    return [(int(s[0]), int(s[-1]) + 1)
            for s in np.split(indices, np.where(np.diff(indices) > 1)[0] + 1)
            if len(s)]


def frames_from_atlas(path, names):
    src = Image.open(path).convert("RGBA")
    alpha = np.asarray(src)[:, :, 3] > 127
    rows = spans(alpha.sum(axis=1) > 5)
    cols = spans(alpha.sum(axis=0) > 5)
    assert len(rows) == len(names), f"{path.name}: rows {rows}"
    assert len(cols) == 4, f"{path.name}: columns {cols}"
    assert all(b - a > 60 for a, b in rows), "unexpected text or tiny row"
    assert all(b - a > 60 for a, b in cols), "unexpected text or tiny column"
    for name, (top, bottom) in zip(names, rows):
        cuts = []
        for left, right in cols:
            cut = src.crop((left, top, right, bottom))
            a = cut.getchannel("A").point(lambda v: 255 if v > 127 else 0)
            bounds = a.getbbox()
            assert bounds is not None, f"{name}: empty source frame"
            cut.putalpha(a)
            cuts.append(cut.crop(bounds))
        # One scale for all four poses, feet anchored to the same baseline.
        factor = min((W - 4) / max(c.width for c in cuts),
                     (H - 4) / max(c.height for c in cuts))
        frames = []
        for cut in cuts:
            cut = cut.resize((max(1, round(cut.width * factor)),
                              max(1, round(cut.height * factor))),
                             Image.Resampling.NEAREST)
            frame = Image.new("RGBA", (W, H))
            frame.alpha_composite(cut, ((W - cut.width) // 2, H - 2 - cut.height))
            frames.append(frame)
        yield name, frames


def pack(frames):
    sheet = Image.new("RGBA", (W * 2, H * 3))
    for i, frame in enumerate(frames):
        sheet.paste(frame, ((i % 2) * W, (i // 2) * H))
    # Existing renderer choreographs hit with displacement/flash. An explicit
    # hit row retains the braced walking pose without inventing extra timing.
    sheet.paste(frames[2], (0, H * 2))
    # Fixed binary alpha; bounded palette; no expensive scaled-up pixels.
    pixels = np.array(sheet)
    pixels[pixels[:, :, 3] == 0] = 0
    sheet = Image.fromarray(pixels)
    return sheet.quantize(colors=32, method=Image.Quantize.FASTOCTREE)


def entry_for(name):
    return {
        "id": name,
        "source_base": "Original delver model, GPT Image 2 source, native pixel conversion 2026-09-08",
        "frame_w": W, "frame_h": H,
        "rows": [
            {"state": "idle", "frames": 2, "row": 0},
            {"state": "run", "frames": 2, "row": 1},
            {"state": "hit", "frames": 1, "row": 2},
        ],
        "fps": 6, "scale": 1,
    }


def validate(sheets):
    masks = {}
    for name, sheet in sheets.items():
        rgba = sheet.convert("RGBA")
        assert rgba.size == (64, 120), name
        assert set(np.unique(np.asarray(rgba)[:, :, 3])) <= {0, 255}, name
        active = []
        for x, y in [(0, 0), (W, 0), (0, H), (W, H), (0, H * 2)]:
            f = rgba.crop((x, y, x + W, y + H))
            box = f.getbbox()
            assert box and box[0] >= 2 and box[1] >= 2, (name, box)
            assert box[2] <= W - 2 and box[3] <= H - 2, (name, box)
            active.append(np.asarray(f)[:, :, 3] > 0)
        assert not np.array_equal(active[2], active[3]), f"{name}: no walking pose change"
        masks[name] = active[0]
    nearest = (0.0, "", "")
    for (a, am), (b, bm) in itertools.combinations(masks.items(), 2):
        overlap = float((am & bm).sum() / (am | bm).sum())
        assert overlap < 0.93, f"{a}/{b}: effectively the same silhouette {overlap}"
        nearest = max(nearest, (overlap, a, b))
    return nearest


def contact_sheet(sheets):
    # Technical atlas proof, not a substitute for a visual/device playtest.
    cols, cw, ch = 6, 184, 224
    plate = Image.new("RGB", (cols * cw, 4 * ch), "#0E090E")
    draw = ImageDraw.Draw(plate)
    font = ImageFont.truetype(str(ROOT / "assets/fonts/Inter-Regular.ttf"), 15)
    for i, (name, sheet) in enumerate(sheets.items()):
        x, y = (i % cols) * cw, (i // cols) * ch
        frame = sheet.convert("RGBA").crop((0, 0, W, H)).resize((128, 160), Image.Resampling.NEAREST)
        plate.paste(frame, (x + 28, y + 16), frame)
        draw.text((x + cw / 2, y + 190), name.replace("_", " ").title(),
                  fill="#EEE6DC", anchor="mm", font=font)
    return plate


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    sheets = {}
    sources = {}
    for path in sorted(SOURCES.glob("atlas-*.png")):
        info = json.loads(path.with_suffix(".json").read_text())
        sources[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        for name, frames in frames_from_atlas(path, info["characters"]):
            sheets[name] = pack(frames)
    assert len(sheets) == 22, "all existing models required"
    nearest = validate(sheets)
    meta = json.loads(META.read_text())
    assert set(sheets) == {d["id"] for d in meta["characters"]}
    new_meta = dict(meta)
    new_meta["characters"] = [entry_for(d["id"]) for d in meta["characters"]]
    if args.check:
        for name, want in sheets.items():
            have = Image.open(DEST / f"{name}.png").convert("RGBA")
            assert have.size == want.size and have.tobytes() == want.convert("RGBA").tobytes(), name
        assert meta == new_meta, "metadata differs"
    else:
        for name, sheet in sheets.items():
            sheet.save(DEST / f"{name}.png", optimize=True)
        META.write_text(json.dumps(new_meta, indent=2) + "\n")
        preview = ROOT / "docs/visual/2026-09-08"
        preview.mkdir(parents=True, exist_ok=True)
        contact_sheet(sheets).save(preview / "delver-roster.png")
    byte_size = sum((DEST / f"{name}.png").stat().st_size for name in sheets)
    decoded = sum(sheet.width * sheet.height * 4 for sheet in sheets.values())
    assert byte_size <= 100 * 1024, byte_size
    assert decoded <= 1.5 * 1024 * 1024, decoded
    report = {"models": len(sheets), "png_bytes": byte_size, "decoded_rgba_bytes": decoded,
              "nearest_silhouette_iou": round(nearest[0], 4),
              "nearest_pair": nearest[1:], "source_sha256": sources,
              "device_visual_qa": "NOT VERIFIED", "check": "pass"}
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
