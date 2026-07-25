#!/usr/bin/env python3
"""tool/build_music_v3.py — master the music beds for phone speakers + add World 2.

Measured problem (2026-07-25): the synthesized v2 tracks carry 88-91 % of
their energy below 300 Hz (combat 88.3 %, boss_combat 89.2 %, map 91.0 %) —
a phone loudspeaker plays almost none of that, so on the shipping device the
score reads as a muffled rumble with the melody missing. And every one of the
twelve levels played the SAME `combat` track: `boss_combat.ogg` shipped in
the APK but no level ever referenced it.

This script:
  * re-masters each existing track (originals in tool/music_src/) with a
    tilt toward the band a phone can project, harmonic excitation so the
    melody survives the speaker's roll-off, and a consistent loudness target
  * adds `cave_combat.ogg` for World 2 (Crystal Cave, cynicmusic, CC0 —
    PROVENANCE.md), so the two worlds and the boss fights no longer share
    one loop

Usage: python3 tool/build_music_v3.py [--src DIR]
"""
import argparse
import json
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "audio" / "music"
MIX_REPORT = REPO / "tool" / "audio_mix.json"
TARGET_PHONE_RMS = -26.0  # music sits under the SFX (-22) by ~4 dB
PEAK_CEILING = -2.0


def run(args):
    p = subprocess.run(args, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"ffmpeg failed:\n{p.stderr[-800:]}")


def phone_rms_db(path: Path) -> float:
    p = subprocess.run(["ffmpeg", "-v", "info", "-i", str(path), "-af",
                        "highpass=f=500,volumedetect", "-f", "null", "-"],
                       capture_output=True, text=True)
    for line in p.stderr.splitlines():
        if "mean_volume:" in line:
            return float(line.split("mean_volume:")[1].split("dB")[0])
    return -99.0


def peak_db(path: Path) -> float:
    p = subprocess.run(["ffmpeg", "-v", "info", "-i", str(path), "-af",
                        "volumedetect", "-f", "null", "-"],
                       capture_output=True, text=True)
    for line in p.stderr.splitlines():
        if "max_volume:" in line:
            return float(line.split("max_volume:")[1].split("dB")[0])
    return -99.0


CHAIN = ",".join([
    "highpass=f=95",                       # sub the speaker can never play
    "equalizer=f=180:t=q:w=1.0:g=-4",      # tame the mud that dominated v2
    "equalizer=f=900:t=q:w=1.1:g=3",       # body of the melody
    "equalizer=f=2400:t=q:w=1.2:g=4",      # presence: what a phone projects
    "equalizer=f=5000:t=q:w=1.4:g=2",      # air
    "aexciter=level_in=1:level_out=1:amount=1:drive=4:blend=0:freq=2200",
    # The v2 tracks are nearly pure sub-bass, so excitation is doing a lot of
    # work up top; cap it so the result reads warm, not hissy.
    "lowpass=f=11000",
    "equalizer=f=9000:t=q:w=1.0:g=-4",
])


def master(src: Path, out: Path, loop_trim: str | None = None):
    tmp = Path("/tmp/embermusic"); tmp.mkdir(exist_ok=True)
    stage = tmp / (out.stem + ".wav")
    filters = ([f"atrim={loop_trim}"] if loop_trim else []) + [CHAIN]
    run(["ffmpeg", "-v", "quiet", "-y", "-i", str(src), "-ac", "1", "-ar", "44100",
         "-af", ",".join(filters), str(stage)])
    gain = TARGET_PHONE_RMS - phone_rms_db(stage)
    for _ in range(4):
        norm = stage.with_suffix(".norm.wav")
        run(["ffmpeg", "-v", "quiet", "-y", "-i", str(stage), "-af",
             f"volume={gain:.2f}dB,alimiter=limit=0.79:level=false", str(norm)])
        trim = min(0.0, PEAK_CEILING - peak_db(norm))
        run(["ffmpeg", "-v", "quiet", "-y", "-i", str(norm), "-af",
             f"volume={trim:.2f}dB", "-c:a", "libvorbis", "-q:a", "4", str(out)])
        err = TARGET_PHONE_RMS - phone_rms_db(out)
        if abs(err) <= 0.8:
            break
        gain += err
    rms, pk = phone_rms_db(out), peak_db(out)
    print(f"{out.name:20} phoneRMS {rms:6.1f} dB  peak {pk:5.1f} dB")
    return {"phoneRms": round(rms, 1), "peak": round(pk, 1)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=str(REPO / "tool" / "music_src"))
    args = ap.parse_args()
    src = Path(args.src)
    OUT.mkdir(parents=True, exist_ok=True)
    mix = json.loads(MIX_REPORT.read_text()) if MIX_REPORT.exists() else {}
    mix.setdefault("sfx", {})
    mix["music"] = {}
    for name in ["title_menu", "map", "combat", "boss_combat", "victory", "defeat"]:
        s = src / f"{name}.ogg"
        if s.exists():
            mix["music"][name] = master(s, OUT / f"{name}.ogg")
        else:
            print(f"skip {name}: no source at {s}")
    cave = src / "cave_combat_src.mp3"
    if cave.exists():
        mix["music"]["cave_combat"] = master(cave, OUT / "cave_combat.ogg")
    MIX_REPORT.write_text(json.dumps(mix, indent=1, sort_keys=True) + "\n")
    print("wrote", MIX_REPORT)


if __name__ == "__main__":
    main()
