#!/usr/bin/env python3
"""tool/build_audio_v3.py — rebuild the whole SFX set for PHONE SPEAKERS.

Why this exists (measured 2026-07-25, alpha.4):
    The previous synthesized set put nearly all of its energy below 300 Hz —
    land.ogg 100 %, player_hit 99.4 %, enemy_death 99.8 %, jump 96.6 %,
    danger_loop 100 %. A phone loudspeaker reproduces almost nothing under
    ~400-500 Hz, so those cues were effectively silent on the device the game
    ships to, while the few bright sounds (feather, unlock, medal) were 20+ dB
    louder in the audible band. That is what "the sound effects are bad" is.

What this does:
    * sources real recorded/CC0 sounds per verb (see SOURCES below)
    * masters every file through one chain:
        mono 44.1 kHz -> trim -> 130 Hz high-pass (the sub energy a phone can
        never play, and it only steals headroom) -> gentle presence lift
        -> loudness match measured THROUGH a phone-speaker model (500 Hz HP)
        -> soft limit -> peak <= -1.5 dBFS -> 4 ms edge fades -> OGG q5
    * prints the verification table (test/audio_assets_test.dart pins it)

Usage:  python3 tool/build_audio_v3.py <staging_dir>
  staging_dir holds the unzipped CC0 packs:
    kenney_impact/Audio, kenney_rpg/Audio, kenney_interface/Audio,
    kenney_ui/Audio, kenney_jingles/Audio, oga_rpg/RPG Sound Pack,
    oga_retro512/<Junkala collection>, oga_sfx100v2
All sources are CC0 (rows in PROVENANCE.md).
"""
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "audio" / "sfx"
SR = 44100

# id -> (relative source path, dict of tweaks)
#   pitch: resample factor (>1 higher), trim: "start:end" seconds,
#   gain: extra dB before normalisation, target: phone-band loudness target
SOURCES = {
    # --- movement -----------------------------------------------------------
    "jump":         ("oga_sfx100v2/sfx100v2_air_02.ogg",            {"pitch": 1.35, "trim": "0:0.30"}),
    "double_jump":  ("oga_sfx100v2/sfx100v2_air_03.ogg",            {"pitch": 1.6, "trim": "0:0.28"}),
    "land":         ("kenney_impact/Audio/footstep_grass_001.ogg",  {"pitch": 0.8, "gain": 2}),
    "step1":        ("oga_sfx100v2/sfx100v2_footstep_01.ogg",      {"target": -30}),
    "step2":        ("oga_sfx100v2/sfx100v2_footstep_02.ogg",      {"target": -30}),
    "whoosh":       ("oga_sfx100v2/sfx100v2_air_01.ogg",            {"pitch": 1.25, "trim": "0:0.35"}),
    # --- combat -------------------------------------------------------------
    "swing1":       ("oga_rpg/RPG Sound Pack/battle/swing.wav",     {}),
    "swing2":       ("oga_rpg/RPG Sound Pack/battle/swing2.wav",    {"pitch": 1.12}),
    "swing3":       ("oga_rpg/RPG Sound Pack/battle/swing3.wav",    {"pitch": 0.92, "gain": 1}),
    "enemy_hit":    ("oga_sfx100v2/sfx100v2_hit_03.ogg",            {"pitch": 1.1}),
    "enemy_death":  ("oga_sfx100v2/sfx100v2_wood_hit_03.ogg",       {"pitch": 0.9}),
    "boss_death":   ("oga_retro512/Explosions/Medium Length/sfx_exp_medium1.wav", {"gain": 1}),
    "block":        ("kenney_impact/Audio/impactMetal_light_002.ogg", {}),
    "player_hit":   ("oga_retro512/General Sounds/Simple Damage Sounds/sfx_damage_hit1.wav", {}),
    # --- loot / discovery ---------------------------------------------------
    "coin":         ("oga_retro512/General Sounds/Coins/sfx_coin_single3.wav", {}),
    "chest_open":   ("kenney_rpg/Audio/creak2.ogg",                 {"gain": 2}),
    "feather":      ("kenney_interface/Audio/confirmation_002.ogg", {}),
    "secret":       ("oga_retro512/General Sounds/Positive Sounds/sfx_sounds_powerup1.wav", {}),
    "medal":        ("kenney_interface/Audio/confirmation_001.ogg", {}),
    "heal":         ("oga_retro512/General Sounds/Positive Sounds/sfx_sounds_powerup11.wav", {}),
    "ember_gain":   ("oga_retro512/General Sounds/Interactions/sfx_sounds_interaction12.wav", {}),
    "unlock":       ("kenney_rpg/Audio/metalLatch.ogg",             {"gain": 2}),
    # --- ui / stings --------------------------------------------------------
    "ui_tap":       ("kenney_ui/Audio/click1.ogg",                  {"target": -26}),
    "ui_back":      ("kenney_interface/Audio/back_001.ogg",         {"target": -26}),
    "victory":      ("kenney_jingles/Audio/Steel jingles/jingles_STEEL07.ogg", {}),
    "defeat":       ("kenney_jingles/Audio/Steel jingles/jingles_STEEL11.ogg", {}),
    # --- loops --------------------------------------------------------------
    "danger_loop":  ("oga_retro512/General Sounds/Alarms/Low health Alarms/sfx_lowhealth_alarmloop5.wav",
                     {"loop": True, "target": -32}),
    "ember_ambience_loop": ("oga_sfx100v2/sfx100v2_loop_ambient_01.ogg",
                            {"loop": True, "target": -34, "trim": "0:9"}),
}

# Default phone-band loudness target (dBFS RMS measured after a 500 Hz
# high-pass). One number for the whole set = a mix that stays balanced on a
# phone; per-verb overrides above only push background layers down.
DEFAULT_TARGET = -22.0
PEAK_CEILING = -1.5
# Sounds that are meant to sit under the action (declared, not accidental).
BACKGROUND = {"step1", "step2", "ui_tap", "ui_back", "danger_loop",
              "ember_ambience_loop"}
MIX_REPORT = REPO / "tool" / "audio_mix.json"


def run(args):
    p = subprocess.run(args, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"ffmpeg failed: {' '.join(map(str, args))}\n{p.stderr[-800:]}")
    return p


def phone_rms_db(path: Path) -> float:
    """RMS after a 500 Hz high-pass — 'how loud is this on a phone speaker'."""
    p = subprocess.run(
        ["ffmpeg", "-v", "info", "-i", str(path), "-af",
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


def energy_above_500(path: Path) -> float:
    """Share of total energy above 500 Hz — 'how much a phone can play'."""
    def rms(filters: str) -> float:
        p = subprocess.run(["ffmpeg", "-v", "info", "-i", str(path), "-af",
                            filters, "-f", "null", "-"],
                           capture_output=True, text=True)
        for line in p.stderr.splitlines():
            if "mean_volume:" in line:
                return 10 ** (float(line.split("mean_volume:")[1].split("dB")[0]) / 20)
        return 0.0
    total = rms("volumedetect")
    hi = rms("highpass=f=500,volumedetect")
    return 0.0 if total <= 0 else min(1.0, (hi / total) ** 2)


def build_one(sid: str, src: Path, opts: dict, tmp: Path) -> Path:
    stage = tmp / f"{sid}.wav"
    filters = []
    if opts.get("trim"):
        a, b = opts["trim"].split(":")
        filters.append(f"atrim=start={a}:end={b}")
    if opts.get("pitch"):
        filters.append(f"asetrate={int(SR * opts['pitch'])},aresample={SR}")
    filters += [
        # Everything under 130 Hz is inaudible on the target device and only
        # eats headroom the audible band needs.
        "highpass=f=130",
        # Presence: the band a small speaker actually projects.
        "equalizer=f=2600:t=q:w=1.2:g=3",
        "equalizer=f=5200:t=q:w=1.4:g=2",
    ]
    if opts.get("gain"):
        filters.append(f"volume={opts['gain']}dB")
    if not opts.get("loop"):
        # 4 ms edge fades kill encoder clicks. The tail fade is applied with
        # the reverse trick so it always lands at the actual end of the file
        # (a fixed st= would silence anything shorter than the guess).
        filters += ["afade=t=in:st=0:d=0.004",
                    "areverse", "afade=t=in:st=0:d=0.004", "areverse"]
    run(["ffmpeg", "-v", "quiet", "-y", "-i", str(src), "-ac", "1", "-ar", str(SR),
         "-af", ",".join(filters), str(stage)])
    return stage


def normalise(stage: Path, target: float, out: Path, loop: bool):
    # Closed loop: limiting changes RMS, so measure the RESULT and correct.
    # Three passes land every sound inside ~1 dB of the target or prove the
    # crest factor makes the target unreachable under the peak ceiling.
    gain = target - phone_rms_db(stage)
    tmp2 = stage.with_suffix(".norm.wav")
    for _ in range(4):
        run(["ffmpeg", "-v", "quiet", "-y", "-i", str(stage), "-af",
             f"volume={gain:.2f}dB,alimiter=limit=0.84:level=false", str(tmp2)])
        pk = peak_db(tmp2)
        trim = min(0.0, PEAK_CEILING - pk)
        run(["ffmpeg", "-v", "quiet", "-y", "-i", str(tmp2), "-af",
             f"volume={trim:.2f}dB", "-c:a", "libvorbis", "-q:a", "5", str(out)])
        err = target - phone_rms_db(out)
        if abs(err) <= 0.8:
            break
        gain += err
    return gain


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    staging = Path(sys.argv[1])
    tmp = Path("/tmp/emberaudio")
    tmp.mkdir(exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    missing = []
    mix = {}
    if MIX_REPORT.exists():
        mix = json.loads(MIX_REPORT.read_text())
    mix.setdefault("music", {})
    mix["sfx"] = {}
    print(f"{'id':24} {'phoneRMS':>9} {'peak':>7} {'sec':>6} {'>500Hz':>7}  source")
    for sid, (rel, opts) in SOURCES.items():
        src = staging / rel
        if not src.exists():
            missing.append(rel)
            continue
        stage = build_one(sid, src, opts, tmp)
        out = OUT / f"{sid}.ogg"
        normalise(stage, opts.get("target", DEFAULT_TARGET), out, opts.get("loop", False))
        dur = float(subprocess.run(
            ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
             "-of", "csv=p=0", str(out)], capture_output=True, text=True).stdout or 0)
        rms = phone_rms_db(out)
        above = energy_above_500(out)
        mix["sfx"][sid] = {
            "phoneRms": round(rms, 1),
            "peak": round(peak_db(out), 1),
            "seconds": round(dur, 2),
            "above500": round(above, 3),
            "group": "background" if sid in BACKGROUND else "foreground",
            "source": rel,
        }
        print(f"{sid:24} {rms:9.1f} {peak_db(out):7.1f} {dur:6.2f} "
              f"{above * 100:6.0f}%  {rel}")
    MIX_REPORT.write_text(json.dumps(mix, indent=1, sort_keys=True) + "\n")
    print("wrote", MIX_REPORT)
    if missing:
        print("\nMISSING SOURCES:")
        for m in missing:
            print("  ", m)
        sys.exit(1)


if __name__ == "__main__":
    main()
