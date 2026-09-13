#!/usr/bin/env python3
"""Package exact Flutter renders; no generated art or motion interpolation.

Run tool/art_depth_review_test.dart and tool/depth_review_probe.dart first.
Requires ffmpeg on PATH. Does not alter application source or assets.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CHARACTERS = ("kindler", "warden", "gambler", "runesmith")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "docs/reviews/blood-toggle-2026-09-13",
    )
    args = parser.parse_args()
    raw = ROOT / "build/art_depth_review"
    dest = args.output.resolve()
    dest.mkdir(parents=True, exist_ok=True)
    summary = {}
    with tempfile.TemporaryDirectory(prefix="ember-review-") as scratch:
        for character in CHARACTERS:
            source = raw / character / "observations.json"
            observations = json.loads(source.read_text())
            rows = observations["frames"]
            assert len(rows) == 175, "Expected all seven seconds of sampled frames"
            files = [raw / row["file"] for row in rows]
            assert all(path.is_file() for path in files), character
            listing = Path(scratch) / f"{character}.ffconcat"
            listing.write_text(
                "\n".join(
                    f"file '{path}'\nduration 0.04" for path in files
                ) + f"\nfile '{files[-1]}'\n"
            )
            subprocess.run(
                [
                    "ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0",
                    "-i", str(listing), "-r", "25", "-frames:v", "175",
                    "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p",
                    "-movflags", "+faststart",
                    str(dest / f"{character}-current.mp4"),
                ],
                check=True,
            )
            shutil.copy2(source, dest / f"{character}-observations.json")
            summary[character] = {
                "first_roll": observations["rolled"],
                "initial_enemy_hp": rows[0]["enemy_hp"],
                "final_enemy_hp": rows[-1]["enemy_hp"],
                "low_selection_heat": rows[15]["weapon_charges"],
                "high_selection_heat": rows[55]["weapon_charges"],
                "high_attack_first_sample": rows[60],
            }
        # One exact pre-contact frame and one after contact, not composites.
        for index in (61, 71):
            source = next((raw / "kindler").glob(f"{index:03d}-*.png"))
            shutil.copy2(source, dest / f"kindler-{source.name}")
        for pattern in ("*.png", "settings-*-geometry.json", "depth-report.json"):
            for source in sorted(raw.glob(pattern)):
                shutil.copy2(source, dest / source.name)
    (dest / "runtime-summary.json").write_text(
        json.dumps(summary, indent=2) + "\n"
    )
    print("Packaged four 175-frame/7-second clips plus exact stills and observations.")


if __name__ == "__main__":
    main()
