#!/usr/bin/env python3
"""Assemble labelled review artifacts without repainting any game pixels.

Art-workstation only: Pillow + ffmpeg/ffprobe, no application dependency.
First run `flutter test tool/roster_review_test.dart`. Supply an extracted
#105 assets directory with --before-root; its sprite hashes are recorded.
All captures remain in build/roster_review; curated evidence is public.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CAPTURES = ROOT / "build/roster_review"
OUT = ROOT / "docs/roster-sep18/evidence"
BASE = "8a5478447a209e764d963ea8fe05f38202d0d2fc"
META = json.loads((ROOT / "assets/images/sprite_meta.json").read_text())
IDS = [c["id"] for c in META["characters"]]
FAMILIES = {
    "hedger": "CUT", "bearer": "CRUSH", "gambler": "STAB",
    "runesmith": "STAMP", "peddler": "HOOK", "flintwright": "PICK",
}
# Exact shipped brand tokens; this is a technical layout, not generated art.
BG, SURFACE, LINE = "#141019", "#1E1826", "#3A3148"
TEXT, DIM, EMBER, GOLD = "#EDE6DA", "#9A8FA0", "#F08A2C", "#E8C24A"
FONT = ROOT / "assets/fonts/Inter-Regular.ttf"
DISPLAY = ROOT / "assets/fonts/Cinzel-Variable.ttf"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def font(size, display=False):
    return ImageFont.truetype(str(DISPLAY if display else FONT), size)


def roster_comparison(before):
    width, margin, gap, cw, ch = 1600, 32, 16, 372, 240
    canvas = Image.new("RGB", (width, 1712), BG)
    d = ImageDraw.Draw(canvas)
    d.text((margin, 24), "EMBERDELVE", font=font(34, True), fill=EMBER)
    d.text((margin, 76), "The whole company", font=font(26, True), fill=TEXT)
    d.text((margin, 116),
           "22 playable delvers  /  source idle frames at 3x nearest-neighbour",
           font=font(16), fill=DIM)
    source_hashes = {}
    for i, character in enumerate(IDS):
        x = margin + i % 4 * (cw + gap)
        y = 160 + i // 4 * (ch + gap)
        d.rectangle((x, y, x + cw - 1, y + ch - 1), fill=SURFACE, outline=LINE)
        d.text((x + 16, y + 12), character.title(),
               font=font(20, True), fill=TEXT)
        paths = [before / f"{character}.png",
                 ROOT / f"assets/images/characters/{character}.png"]
        source_hashes[character] = {}
        for col, (label, path) in enumerate(zip(["PR #105", "THIS PASS"], paths)):
            source_hashes[character][label] = digest(path)
            sprite = Image.open(path).convert("RGBA").crop((0, 0, 32, 40))
            sprite = sprite.resize((96, 120), Image.Resampling.NEAREST)
            sx = x + 40 + col * 180
            canvas.paste(sprite, (sx, y + 72), sprite)
            d.text((sx + 48, y + 48), label, anchor="mm",
                   font=font(11), fill=DIM if col == 0 else GOLD)
        footer = "RETAINED DESIGN" if i < 2 else "REDESIGNED + ARTICULATED"
        d.text((x + 16, y + 216), footer, font=font(11), fill=DIM)
    # Last two cells carry the review's scope instead of inventing characters.
    x, y = margin + 2 * (cw + gap), 160 + 5 * (ch + gap)
    d.text((x + 16, y + 32), "Same people. Clearer roles.",
           font=font(20, True), fill=TEXT)
    for n, line in enumerate([
        "No kit, unlock or balance changes.",
        "All 22 hold their runtime signature tools.",
        "Actual game renders are supplied separately.",
        "Generated source + native conversion;",
        "not a claim of human aesthetic approval.",
    ]):
        d.text((x + 16, y + 80 + n * 24), line, font=font(16), fill=DIM)
    canvas.save(OUT / "whole-roster-before-after.png", optimize=True)
    return source_hashes


def phone_plate():
    scenarios = [("gambler", 320), ("bearer", 360), ("mender", 412)]
    plate = Image.new("RGB", (1220, 1100), BG)
    d = ImageDraw.Draw(plate)
    d.text((24, 20), "ACTUAL FLUTTER / THREE PHONE WIDTHS",
           fill=EMBER, font=font(26, True))
    d.text((24, 64), "Natural encounter entry; rendered at logical phone size.",
           fill=DIM, font=font(16))
    x = 24
    for character, width in scenarios:
        image = Image.open(CAPTURES / f"{character}-{width}-natural-ready.png")
        image = image.resize((image.width // 2, image.height // 2),
                             Image.Resampling.LANCZOS)
        d.text((x, 104), f"{character.title()} / {width}px", fill=TEXT, font=font(20))
        plate.paste(image, (x, 144))
        x += width + 24
    d.text((24, 1072), "Headless captures — not physical-device FPS or touch validation.",
           fill=DIM, font=font(13))
    plate.save(OUT / "three-phone-widths.png", optimize=True)


def encode_clips():
    records = {}
    for character, family in FAMILIES.items():
        frames = sorted((CAPTURES / f"{character}-360").glob("[0-9]*.png"))
        assert len(frames) == 190, (character, len(frames))
        assert [int(p.name.split("-")[0]) for p in frames] == list(range(190))
        command = [
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-framerate", "25", "-pattern_type", "glob",
            "-i", str(CAPTURES / f"{character}-360/[0-9]*.png"),
            "-c:v", "libx264", "-preset", "medium", "-crf", "18",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart",
            str(OUT / f"{character}-{family.lower()}.mp4"),
        ]
        subprocess.run(command, check=True, cwd=ROOT)
        path = OUT / f"{character}-{family.lower()}.mp4"
        raw = subprocess.check_output([
            "ffprobe", "-v", "error", "-select_streams", "v:0",
            "-show_entries", "stream=width,height,r_frame_rate,nb_frames,duration",
            "-of", "json", str(path),
        ], text=True)
        info = json.loads(raw)["streams"][0]
        assert info["nb_frames"] == "190" and info["r_frame_rate"] == "25/1"
        assert float(info["duration"]) == 7.6
        records[path.name] = {
            **info, "bytes": path.stat().st_size, "sha256": digest(path),
            "family": family.lower(),
            "sampling": "40ms simulated intervals; NOT device FPS",
            "edit": "low/high action segments joined; intervening roll/setup omitted",
        }
    # Six-family comparison: each actual capture shown at 360x640 logical size.
    # A deterministic layout places, labels and encodes screenshots; it never
    # generates/repaints the body art or replaces game UI.
    frame_dir = ROOT / "build/roster_montage"
    frame_dir.mkdir(parents=True, exist_ok=True)
    for frame in range(190):
        plate = Image.new("RGB", (1152, 1568), BG)
        d = ImageDraw.Draw(plate)
        d.text((24, 16), "EMBERDELVE / SIX WAYS TO STRIKE",
               font=font(26, True), fill=EMBER)
        d.text((24, 56),
               f'{"LOW" if frame < 95 else "HIGH"} DIE / selected, attack, guard, incoming hit',
               font=font(16), fill=TEXT)
        for i, (character, family) in enumerate(FAMILIES.items()):
            x, y = i % 3 * 384 + 12, 96 + i // 3 * 704
            d.text((x, y), f"{family} / {character.title()}",
                   font=font(20), fill=GOLD)
            files = list((CAPTURES / f"{character}-360").glob(f"{frame:03d}-*.png"))
            assert len(files) == 1
            image = Image.open(files[0]).resize((360, 640), Image.Resampling.LANCZOS)
            plate.paste(image, (x, y + 40))
        d.text((24, 1512), "Controlled visual fixtures / 40ms samples / NOT device FPS",
               font=font(16), fill=DIM)
        d.text((24, 1540), "Original kits; enemy HP extended; low/high action segments joined.",
               font=font(13), fill=DIM)
        plate.save(frame_dir / f"{frame:03d}.png")
    path = OUT / "six-tool-families.mp4"
    subprocess.run([
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-framerate", "25", "-i", str(frame_dir / "%03d.png"),
        "-c:v", "libx264", "-preset", "medium", "-crf", "18",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(path),
    ], check=True, cwd=ROOT)
    info = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=width,height,r_frame_rate,nb_frames,duration",
        "-of", "json", str(path),
    ], text=True))["streams"][0]
    assert info["nb_frames"] == "190" and float(info["duration"]) == 7.6
    records[path.name] = {**info, "bytes": path.stat().st_size,
                          "sha256": digest(path)}
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before-root", type=Path, required=True,
                        help="Directory of unchanged #105 character PNGs.")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    scenarios, observations, inventory = [], [], {}
    for path in sorted(CAPTURES.glob("*/observations.json")):
        data = json.loads(path.read_text())
        assert len(data["frames"]) == 190
        assert data["character"] in IDS
        observations += data["frames"]
        scenarios.append({
            "character": data["character"], "viewport": data["viewport"],
            "samples": len(data["frames"]),
            "png_frames": len(list(path.parent.glob("*.png"))),
            "max_grip_error_logical_px":
                max(f["grip_error_logical_px"] for f in data["frames"]),
            "forced_attack_faces": data["forced_attack_faces"],
        })
    assert len(scenarios) == 66 and len(observations) == 12540
    assert {s["character"] for s in scenarios} == set(IDS)
    for path in sorted(CAPTURES.rglob("*")):
        if path.is_file():
            inventory[str(path.relative_to(CAPTURES))] = {
                "bytes": path.stat().st_size, "sha256": digest(path)}
    (OUT / "capture-inventory.json").write_text(
        json.dumps(inventory, indent=2) + "\n")
    source_hashes = roster_comparison(args.before_root)
    phone_plate()
    clips = encode_clips()
    # All 22 actual native-height figures in one representative pose group.
    for group in range(4):
        for pose in ["raise", "swing", "fatigue"]:
            name = f"native-104-group-{group}-{pose}.png"
            shutil.copyfile(CAPTURES / name, OUT / name)
    for character in IDS:
        shutil.copyfile(CAPTURES / f"picker-360-{character}.png",
                        OUT / f"picker-360-{character}.png")
    report = {
        "base": BASE,
        "claim": "Actual Flutter renders, not device FPS or human aesthetic approval.",
        "scenarios": scenarios,
        "samples": len(observations),
        "max_grip_error_logical_px": max(
            f["grip_error_logical_px"] for f in observations),
        "rendered_figure_copies": dict(Counter(
            f["rendered_figure_copies_checked"] for f in observations)),
        "native_plates": len(list(CAPTURES.glob("native-*.png"))),
        "picker_captures": len(list(CAPTURES.glob("picker-*.png"))),
        "png_captures": len(list(CAPTURES.rglob("*.png"))),
        "source_comparison_sha256": source_hashes,
        "clips": clips,
        "fixtures": (
            "Seed1, easy, boon0, node2 Flue Crawler. Natural entry captured "
            "before synthetic state. Enemy HP/max999; raw attack faces 1/sides-1 "
            "with original die/relic floors and matching combo flags/burn; "
            "incoming7; HP restored between turns; fatigue20%; other natural "
            "roll-triggered effects retained. Not a balance/playthrough demo."
        ),
        "limits": [
            "Capture samples are 40ms simulated steps, not measured device FPS.",
            "Low/high clips join action segments; roll/setup gaps omitted.",
            "All portrait unlocks are a test-only meta fixture.",
            "Aesthetic approval and physical-phone touch/FPS remain unverified.",
        ],
    }
    (OUT / "render-manifest.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in [
        "samples", "max_grip_error_logical_px", "native_plates",
        "picker_captures", "png_captures"]}, indent=2))


if __name__ == "__main__":
    main()
