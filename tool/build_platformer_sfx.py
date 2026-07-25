#!/usr/bin/env python3
"""tool/build_platformer_sfx.py — build the platformer SFX set (v2 audio pass).

Replaces the dice-era leftovers with sounds for the platformer verbs:
jump / double_jump / land / swing1-3 / chest_open / feather / secret / medal.

Sources (all verified CC0 / CC-BY, full rows in PROVENANCE.md):
  - rubberduck "100 CC0 SFX #2" (sfx100v2_*.ogg)            — CC0
  - artisticdude "RPG Sound Pack" (battle/swing*.wav)       — CC0
  - Kenney "Impact Sounds" (impactSoft_*.ogg)               — CC0
  - Kenney "Interface Sounds" (confirmation_*.ogg)          — CC0
  - Original procedural synthesis in this script (numpy)    — CC0

Run: python3 tool/build_platformer_sfx.py <staging_dir>
  where <staging_dir> contains: sfx100/ , rpg/"RPG Sound Pack"/ , kimp/Audio/ ,
  kint/Audio/ (unzipped packs).

Pipeline per file: mono 44.1 kHz -> trim -> gentle highpass 40 Hz ->
peak-normalize to -1.5 dBFS -> 5 ms anti-click edge fades -> OGG Vorbis q5.
Idempotent; outputs into assets/audio/sfx/.
"""
import math
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "assets" / "audio" / "sfx"
SR = 44100


def write_wav(path: Path, samples: np.ndarray):
    """Write float [-1,1] mono samples as 16-bit WAV."""
    pcm = np.clip(samples, -1.0, 1.0)
    pcm = (pcm * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def encode(src: Path, out: Path, *, gain_db: float = 0.0, atrim: str | None = None,
           asetrate: float | None = None, extra: list[str] | None = None):
    """ffmpeg: mono 44.1k, optional trim/pitch, highpass, normalize, fades, ogg q5."""
    filters = []
    if atrim:
        filters.append(f"atrim={atrim}")
    if asetrate:
        # Pitch shift by resample trick, then bring the rate back.
        filters.append(f"asetrate={int(SR * asetrate)},aresample={SR}")
    filters += [
        "highpass=f=40",
        f"volume={gain_db}dB",
        # Cap peaks ~-2.2 dBFS (vorbis ringing overshoots ~0.5 dB; repo
        # convention is decoded peak <= -1.3 dBFS).
        "alimiter=limit=0.78:level=false",
        "afade=t=in:st=0:d=0.005",
    ]
    if extra:
        filters += extra
    # Measure duration for the tail fade.
    probe = subprocess.run(
        ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
         "-of", "csv=p=0", str(src)], capture_output=True, text=True)
    try:
        dur = float(probe.stdout.strip())
    except ValueError:
        dur = 1.0
    if atrim and "end=" in atrim:
        dur = min(dur, float(atrim.split("end=")[1].split(":")[0]))
    filters.append(f"afade=t=out:st={max(dur - 0.012, 0):.3f}:d=0.012")

    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", str(src),
         "-af", ",".join(filters),
         "-ac", "1", "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "5",
         str(out)], check=True)
    kb = out.stat().st_size / 1024
    print(f"sfx  {out.relative_to(REPO)}  {kb:.1f} KB")


# -- procedural synths (original work, CC0) -----------------------------------

def synth_jump(f0=170.0, f1=430.0, dur=0.11, breath=0.05):
    """Soft retro 'hup': triangle sweep + a puff of filtered noise."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    # Exponential sweep f0 -> f1.
    freq = f0 * (f1 / f0) ** (t / dur)
    phase = 2 * math.pi * np.cumsum(freq) / SR
    tri = 2 / math.pi * np.arcsin(np.sin(phase))  # triangle
    env = np.exp(-t * 26)
    sig = tri * env * 0.8
    # Breath layer: short lowpassed noise.
    rng = np.random.default_rng(7)
    noise = rng.standard_normal(n)
    # cheap one-pole lowpass
    lp = np.empty(n)
    acc = 0.0
    for i, x in enumerate(noise):
        acc += 0.12 * (x - acc)
        lp[i] = acc
    sig += lp * np.exp(-t * 40) * breath
    return sig * 0.9


def synth_secret(base=659.25, dur=0.85):
    """Sparkle arpeggio: E5-A5-C#6-E6 sines w/ 2nd harmonic shimmer + tail."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    ratios = [1.0, 1.5, 2.0, 2.52]  # ~E5, B5, E6, ~G#6
    for i, r in enumerate(ratios):
        start = 0.09 * i
        idx = t >= start
        tt = t[idx] - start
        note = (np.sin(2 * math.pi * base * r * tt)
                + 0.35 * np.sin(2 * math.pi * base * r * 2 * tt))
        sig[idx] += note * np.exp(-tt * 6.5) * 0.32
    return sig


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    stg = Path(sys.argv[1])
    sfx100 = stg / "sfx100"
    rpg = stg / "rpg" / "RPG Sound Pack"
    kimp = stg / "kimp" / "Audio"
    kint = stg / "kint" / "Audio"

    with tempfile.TemporaryDirectory() as td:
        td = Path(td)

        # Synth: jump / double_jump / secret (original, CC0).
        write_wav(td / "jump.wav", synth_jump())
        encode(td / "jump.wav", OUT / "jump.ogg")
        write_wav(td / "double_jump.wav", synth_jump(f0=240.0, f1=620.0, dur=0.10, breath=0.04))
        encode(td / "double_jump.wav", OUT / "double_jump.ogg")
        write_wav(td / "secret.wav", synth_secret())
        encode(td / "secret.wav", OUT / "secret.ogg")

        # Land: Kenney impactSoft_medium_002, softened.
        encode(kimp / "impactSoft_medium_002.ogg", OUT / "land.ogg", gain_db=-4)

        # Swings: artisticdude RPG pack, slight per-hit pitch stagger so the
        # 3-hit combo reads as a phrase (1 neutral, 2 up, 3 down+heavier).
        encode(rpg / "battle" / "swing.wav", OUT / "swing1.ogg", gain_db=-5)
        encode(rpg / "battle" / "swing2.wav", OUT / "swing2.ogg", asetrate=1.06, gain_db=-5)
        encode(rpg / "battle" / "swing3.wav", OUT / "swing3.ogg", asetrate=0.94, gain_db=-4)

        # Chest open: lock_open + the repo's existing coin jingle layered in.
        chest_mix = td / "chest_mix.wav"
        subprocess.run(
            ["ffmpeg", "-y", "-v", "error",
             "-i", str(sfx100 / "sfx100v2_lock_open_01.ogg"),
             "-i", str(REPO / "assets" / "audio" / "sfx" / "coin.ogg"),
             "-filter_complex",
             "[1:a]adelay=90,volume=-7dB[c];[0:a][c]amix=inputs=2:duration=longest:normalize=0",
             "-ac", "1", "-ar", str(SR), str(chest_mix)], check=True)
        encode(chest_mix, OUT / "chest_open.ogg", atrim="start=0:end=1.1")

        # Feather: airy pickup — sfx100 air_02 pitched up, short and quiet.
        encode(sfx100 / "sfx100v2_air_02.ogg", OUT / "feather.ogg",
               asetrate=1.5, atrim="start=0:end=0.5", gain_db=-3)

        # Medal pop: Kenney Interface confirmation, bright and tiny.
        encode(kint / "confirmation_001.ogg", OUT / "medal.ogg", atrim="start=0:end=0.6")

        # Footsteps: two alternating soft grass steps, heavily attenuated —
        # they run at cadence under gameplay and must never grate on phone
        # speakers (played at ~0.25 volume on top of this).
        encode(sfx100 / "sfx100v2_footstep_01.ogg", OUT / "step1.ogg",
               gain_db=-8, atrim="start=0:end=0.22")
        encode(sfx100 / "sfx100v2_footstep_02.ogg", OUT / "step2.ogg",
               gain_db=-8, atrim="start=0:end=0.22", asetrate=0.96)

    print("done.")


if __name__ == "__main__":
    main()
