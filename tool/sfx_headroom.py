#!/usr/bin/env python3
"""Offline mix-bus headroom check for layered SFX (see docs/improvements/).

Why this exists
---------------
v0.3.15 gave hot SFX ids several resident voices so a re-trigger LAYERS instead
of cutting the previous one off. Unit tests cover *which* voice is picked; they
cannot tell you whether four overlapping dice or three simultaneous coins push
the mix bus into clipping. This tool answers that part objectively: it rebuilds
the worst-case cascades offline from the shipped .ogg assets, honouring the real
voice caps and the per-call volume trims, and measures sample peak, true peak
(inter-sample, EBU R128) and integrated loudness of each cascade.

What it does NOT answer: whether a cascade sounds *good*. That stays an ear call.

Usage
-----
    python3 tool/sfx_headroom.py                  # check, prints markdown table
    python3 tool/sfx_headroom.py --write-clips out/   # also render wav/mp3 to listen

Exit code is non-zero if any cascade exceeds the true-peak ceiling, so this can
run in CI as a regression guard when SFX assets or voice caps change.

Requires: ffmpeg (decoding + EBU R128 measurement), numpy (mixing).
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parent.parent
SFX_DIR = REPO / "assets" / "audio" / "sfx"
AUDIO_SERVICE = REPO / "lib" / "audio" / "audio_service.dart"

SR = 48000
CHANNELS = 2

# Worst case the player can actually reach: the SFX slider at maximum.
MASTER_SFX = 1.0

# A cascade fails if its inter-sample (true) peak exceeds this. 0.0 dBTP is the
# digital ceiling; anything above it clips on playback/after lossy re-encoding.
TRUE_PEAK_FAIL_DBTP = 0.0
# Below the ceiling but this close to it we flag as thin headroom, not a failure.
TRUE_PEAK_WARN_DBTP = -1.0


@dataclass
class Trigger:
    """One playSfx() call: id, when it fires, and the call-site volume trim."""

    sfx_id: str
    at_ms: int
    volume: float = 1.0


@dataclass
class Scenario:
    key: str
    what: str
    triggers: list[Trigger] = field(default_factory=list)
    # Reachable scenarios gate the exit code. Unreachable ones are kept as
    # ceiling references: they show what the mix WOULD do if the guard that
    # makes them impossible (see `why`) were ever removed.
    reachable: bool = True
    why: str = ""


def scenarios() -> list[Scenario]:
    """Worst-case cascades that real play can produce.

    Volumes mirror the call sites in lib/ui/screens/combat_screen.dart and
    lib/ui/widgets.dart; timings are the tightest spacing the UI allows.
    """
    return [
        Scenario(
            "die_assign_3x_same_frame",
            "three dice assigned in the SAME frame, perfectly phase-aligned",
            [Trigger("die_assign", 0), Trigger("die_assign", 0), Trigger("die_assign", 0)],
            reachable=False,
            why="AudioService.handleEvents de-dupes ids within an event batch, and "
            "each assign needs its own tap — two identical voices cannot start on "
            "the same sample",
        ),
        Scenario(
            "die_assign_4x_fast",
            "four dice assigned in ~0.3 s — 4th steals the oldest voice",
            [Trigger("die_assign", t) for t in (0, 90, 180, 270)],
        ),
        Scenario(
            "roll_then_assigns",
            "roll the hand, then assign three dice on top of the roll tail",
            [
                Trigger("dice_roll", 0),
                Trigger("die_assign", 260),
                Trigger("die_assign", 380),
                Trigger("die_assign", 500),
            ],
        ),
        Scenario(
            "coin_3x_simultaneous",
            "three coin payouts in the SAME frame, perfectly phase-aligned",
            [Trigger("coin", 0), Trigger("coin", 0), Trigger("coin", 0)],
            reachable=False,
            why="gold_gained/gold_spent/bought all map to 'coin' and handleEvents "
            "plays each id at most once per batch",
        ),
        Scenario(
            "coin_3x_spaced",
            "three coin payouts across three batches (shop spree), 110 ms apart",
            [Trigger("coin", t) for t in (0, 110, 220)],
        ),
        Scenario(
            "enemy_hit_3x_multihit",
            "multi-hit verb: three enemy_hit at the combat trim (0.5)",
            [Trigger("enemy_hit", t, 0.5) for t in (0, 70, 140)],
        ),
        Scenario(
            "full_attack_turn",
            "worst realistic turn: whoosh + 3 hits + ember gain + 3 coins",
            [
                Trigger("whoosh", 0),
                Trigger("enemy_hit", 120, 0.5),
                Trigger("enemy_hit", 190, 0.5),
                Trigger("enemy_hit", 260, 0.5),
                Trigger("ember_gain", 300),
                Trigger("coin", 380),
                Trigger("coin", 430),
                Trigger("coin", 480),
            ],
        ),
        Scenario(
            "enemy_turn_block_stack",
            "enemy turn: two player_hit and two block overlapping",
            [
                Trigger("player_hit", 0),
                Trigger("block", 60, 0.55),
                Trigger("player_hit", 150),
                Trigger("block", 210, 0.5),
            ],
        ),
        Scenario(
            "ui_tap_over_cascade",
            "player taps a button while the dice cascade is still ringing",
            [
                Trigger("dice_roll", 0),
                Trigger("die_assign", 200),
                Trigger("die_assign", 300),
                Trigger("ui_tap", 340, 0.8),
                Trigger("die_assign", 400),
            ],
        ),
    ]


def read_voice_caps() -> dict[str, int]:
    """Parse AudioService.sfxVoices so this tool can never drift from the app."""
    src = AUDIO_SERVICE.read_text()
    block = re.search(
        r"static const Map<String, int> sfxVoices = \{(.*?)\};", src, re.S
    )
    if not block:
        raise SystemExit("could not find sfxVoices in lib/audio/audio_service.dart")
    caps = {
        m.group(1): int(m.group(2))
        for m in re.finditer(r"'([a-z_]+)'\s*:\s*(\d+)", block.group(1))
    }
    if not caps:
        raise SystemExit("sfxVoices parsed empty — check the table format")
    return caps


def decode(path: Path) -> np.ndarray:
    """Decode an asset to float32 [samples, CHANNELS] at SR."""
    out = subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(path),
            "-f", "f32le", "-acodec", "pcm_f32le",
            "-ac", str(CHANNELS), "-ar", str(SR), "-",
        ],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(out, dtype=np.float32).reshape(-1, CHANNELS).copy()


def render(scenario: Scenario, caps: dict[str, int], clips: dict[str, np.ndarray]) -> np.ndarray:
    """Mix a scenario, modelling the real voice pool.

    An id with N voices can have at most N copies sounding at once; the N+1th
    trigger steals the oldest voice, which means that copy is CUT at the moment
    of the steal (that is exactly what the AudioPlayer does on replay).
    """
    voices: dict[str, list[int]] = {}  # id -> start sample of each live voice, oldest first
    placed: list[tuple[int, np.ndarray]] = []
    cuts: dict[int, int] = {}  # index into placed -> cut at sample

    for trig in scenario.triggers:
        clip = clips[trig.sfx_id]
        start = int(trig.at_ms * SR / 1000)
        cap = caps.get(trig.sfx_id, 1)
        live = voices.setdefault(trig.sfx_id, [])
        # Retire voices that have already finished before this trigger.
        live[:] = [i for i in live if placed[i][0] + len(placed[i][1]) > start]
        if len(live) >= cap:
            stolen = live.pop(0)
            cuts[stolen] = min(cuts.get(stolen, 10**9), start)
        placed.append((start, clip * (trig.volume * MASTER_SFX)))
        live.append(len(placed) - 1)

    tail = max(start + len(clip) for start, clip in placed)
    bus = np.zeros((tail + SR // 2, CHANNELS), dtype=np.float32)
    for idx, (start, clip) in enumerate(placed):
        end = start + len(clip)
        if idx in cuts:
            end = min(end, cuts[idx])
        seg = clip[: end - start]
        bus[start:end] += seg
    return bus


def write_wav(bus: np.ndarray, path: Path) -> None:
    subprocess.run(
        [
            "ffmpeg", "-v", "error", "-y",
            "-f", "f32le", "-ar", str(SR), "-ac", str(CHANNELS), "-i", "-",
            "-c:a", "pcm_f32le", str(path),
        ],
        input=bus.astype(np.float32).tobytes(), check=True,
    )


def measure(path: Path) -> dict[str, float]:
    """True peak + integrated loudness via ffmpeg's EBU R128 meter."""
    proc = subprocess.run(
        ["ffmpeg", "-v", "info", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"],
        capture_output=True, text=True, check=True,
    )
    log = proc.stderr
    def grab(label: str) -> float:
        m = re.search(rf"{label}:\s*(-?\d+\.?\d*)", log)
        return float(m.group(1)) if m else float("nan")
    tail = log[log.rfind("Summary:") :] if "Summary:" in log else log
    def grab_tail(label: str) -> float:
        m = re.search(rf"{label}:\s*\n?\s*(-?\d+\.?\d*|-inf)", tail)
        if not m or m.group(1) == "-inf":
            return float("-inf")
        return float(m.group(1))
    return {
        "true_peak_dbtp": grab_tail("Peak"),
        "lufs_i": grab_tail("I"),
    }


LAST_ROWS: list[dict] = []


def check(write_clips: Path | None) -> int:
    if shutil.which("ffmpeg") is None:
        raise SystemExit(
            "ffmpeg not found — it does the decoding and the EBU R128 measurement.\n"
            "  Ubuntu/Debian: sudo apt-get install ffmpeg"
        )
    caps = read_voice_caps()
    needed = {t.sfx_id for s in scenarios() for t in s.triggers}
    clips = {sid: decode(SFX_DIR / f"{sid}.ogg") for sid in sorted(needed)}

    rows = []
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        for scenario in scenarios():
            bus = render(scenario, caps, clips)
            sample_peak = float(np.max(np.abs(bus))) if bus.size else 0.0
            clipped = int(np.count_nonzero(np.abs(bus) > 1.0))
            wav = Path(tmp) / f"{scenario.key}.wav"
            write_wav(bus, wav)
            m = measure(wav)
            peak_db = 20 * np.log10(sample_peak) if sample_peak > 0 else float("-inf")
            over = m["true_peak_dbtp"] > TRUE_PEAK_FAIL_DBTP
            if not scenario.reachable:
                verdict = "over ceiling (unreachable)" if over else "clear (unreachable)"
            elif over:
                verdict = "FAIL"
                failures.append(scenario.key)
            elif m["true_peak_dbtp"] > TRUE_PEAK_WARN_DBTP:
                verdict = "TIGHT"
            else:
                verdict = "PASS"
            rows.append(
                {
                    "scenario": scenario.key,
                    "what": scenario.what,
                    "voices": len(scenario.triggers),
                    "sample_peak_dbfs": round(float(peak_db), 2),
                    "true_peak_dbtp": round(m["true_peak_dbtp"], 2),
                    "lufs_i": round(m["lufs_i"], 1),
                    "clipped_samples": clipped,
                    "reachable": scenario.reachable,
                    "why_unreachable": scenario.why,
                    "verdict": verdict,
                }
            )
            if write_clips:
                write_clips.mkdir(parents=True, exist_ok=True)
                subprocess.run(
                    ["ffmpeg", "-v", "error", "-y", "-i", str(wav),
                     "-b:a", "192k", str(write_clips / f"{scenario.key}.mp3")],
                    check=True,
                )

    LAST_ROWS[:] = rows
    print(f"SFX mix-bus headroom — sfx slider at max ({MASTER_SFX:.1f}), voice caps {caps}\n")
    print("| scenario | layers | sample peak | true peak | LUFS-I | clipped | verdict |")
    print("|---|---|---|---|---|---|---|")
    for r in rows:
        print(
            f"| `{r['scenario']}` | {r['voices']} | {r['sample_peak_dbfs']:.2f} dBFS | "
            f"{r['true_peak_dbtp']:.2f} dBTP | {r['lufs_i']:.1f} | {r['clipped_samples']} | {r['verdict']} |"
        )
    print(f"\nceiling: FAIL above {TRUE_PEAK_FAIL_DBTP:.1f} dBTP, TIGHT above {TRUE_PEAK_WARN_DBTP:.1f} dBTP")
    for r in rows:
        if not r["reachable"]:
            print(f"\n(unreachable) `{r['scenario']}`: {r['why_unreachable']}.")
    if failures:
        print(f"\nFAILED: {', '.join(failures)}")
        return 1
    print("\nEvery reachable cascade clears the ceiling.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--write-clips", type=Path, help="also render each cascade as mp3 here")
    ap.add_argument("--json", type=Path, help="write the raw results as JSON here")
    args = ap.parse_args()
    code = check(args.write_clips)
    if args.json:
        args.json.write_text(json.dumps({"ok": code == 0, "rows": LAST_ROWS}, indent=2))
    return code


if __name__ == "__main__":
    sys.exit(main())
