#!/usr/bin/env python3
"""tool/build_original_music.py — original, studio-owned music + ambience.

Replaces every CC-BY audio asset with 100% original work so the shipped game
carries ZERO legally-required attributions (see docs/original-assets.md):

  music/title_menu.ogg   (was: Kevin MacLeod "Ossuary 1", CC-BY 4.0)
  music/map.ogg          (was: Kevin MacLeod "Ossuary 2", CC-BY 4.0)
  music/combat.ogg       (was: Kevin MacLeod "Curse of the Scarab", CC-BY 4.0)
  music/boss_combat.ogg  (was: Kevin MacLeod "Five Armies", CC-BY 4.0)
  music/defeat.ogg       (was: tcarisland "Defeat", CC-BY 4.0)
  sfx/defeat.ogg         (was: tcarisland "Defeat", CC-BY 4.0)
  sfx/ember_ambience_loop.ogg (was: qubodup "Fire Loop", CC-BY 3.0)

Everything here is synthesized from first principles (numpy oscillators,
envelopes, filtered noise). No samples, no soundfonts, no third-party audio
of any kind is read. The compositions (chord progressions, melodies, drum
patterns) are original works written for Emberdelve — same *genre* as the
tracks they replace (dark fantasy / retro action) but never a note-for-note
copy of anything. All outputs (c) Tsoro Studios, dedicated CC0 1.0 in PROVENANCE.md.

Loop seamlessness: loops are rendered twice back-to-back and the SECOND pass
is exported, so envelope releases and delay tails from the end of the loop
are already present at its start (steady-state loop, no edge fades).

Mastering (repo convention, PROVENANCE.md): measured EBU R128 gain toward
-19 LUFS (music) / -18 LUFS (stings), alimiter ceiling, decoded peak
<= -1.3 dBFS, OGG Vorbis q4 stereo (music) / q5 mono (sfx), 44.1 kHz.

Run: python3 tool/build_original_music.py    (idempotent)
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parent.parent
MUSIC = REPO / "assets" / "audio" / "music"
SFX = REPO / "assets" / "audio" / "sfx"
SR = 44100

# ---------------------------------------------------------------- synthesis

def midi2f(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def adsr(n: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    """Linear ADSR over n samples (a/d/r in seconds, s = sustain level)."""
    a_n, d_n, r_n = (max(1, int(x * SR)) for x in (a, d, r))
    if a_n + d_n + r_n > n:  # squeeze for very short notes
        k = n / (a_n + d_n + r_n)
        a_n, d_n, r_n = (max(1, int(x * k)) for x in (a_n, d_n, r_n))
    s_n = max(0, n - a_n - d_n - r_n)
    return np.concatenate([
        np.linspace(0, 1, a_n, endpoint=False),
        np.linspace(1, s, d_n, endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, r_n),
    ])[:n]


def _phase(freq: float, n: int, vib_hz: float = 0.0, vib_amt: float = 0.0):
    t = np.arange(n) / SR
    f = np.full(n, freq)
    if vib_hz:
        f = f * (1.0 + vib_amt * np.sin(2 * np.pi * vib_hz * t))
    return np.cumsum(f) / SR % 1.0


def pulse(freq, n, duty=0.5, vib=(0.0, 0.0)):
    ph = _phase(freq, n, *vib)
    return np.where(ph < duty, 1.0, -1.0)


def tri(freq, n, vib=(0.0, 0.0)):
    ph = _phase(freq, n, *vib)
    return 2.0 * np.abs(2.0 * ph - 1.0) - 1.0


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """One-pole lowpass."""
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):  # numpy has no stateful filter; fine at our sizes
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def _lp(x, cutoff):  # vectorized one-pole via lfilter-equivalent recursion
    from scipy.signal import lfilter
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff / SR)
    return lfilter([a], [1, -(1 - a)], x)


def _hp(x, cutoff):
    return x - _lp(x, cutoff)


RNG = np.random.default_rng(20260725)

# --- melodic instruments: f(freq, n, vel) -> mono float array ---------------

def inst_lead(freq, n, vel):
    body = 0.6 * pulse(freq, n, 0.25, vib=(5.5, 0.006)) \
         + 0.4 * pulse(freq * 1.004, n, 0.25)
    return body * adsr(n, 0.012, 0.09, 0.72, 0.07) * vel


def inst_pluck(freq, n, vel):
    t = np.arange(n) / SR
    body = tri(freq, n) + 0.25 * pulse(freq * 2.0, n, 0.5)
    return body * np.exp(-t * 9.0) * adsr(n, 0.002, 0.02, 1.0, 0.02) * vel


def inst_pad(freq, n, vel):
    body = 0.5 * pulse(freq, n, 0.5) + 0.5 * pulse(freq * 0.5, n, 0.48)
    return _lp(body, 1200) * adsr(n, 0.10, 0.20, 0.8, 0.25) * vel


def inst_bass(freq, n, vel):
    body = 0.7 * tri(freq, n) + 0.5 * np.sin(2 * np.pi * freq * 0.5 *
                                             np.arange(n) / SR)
    return body * adsr(n, 0.006, 0.05, 0.85, 0.05) * vel


def inst_bell(freq, n, vel):
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 3.01 * t)
    return body * np.exp(-t * 5.0) * vel


# --- drums: f(n, vel) --------------------------------------------------------

def drum_kick(n, vel):
    n = max(n, int(0.14 * SR))
    t = np.arange(n) / SR
    f = 110 * np.exp(-t * 26) + 38
    ph = np.cumsum(f) / SR
    return np.sin(2 * np.pi * ph) * np.exp(-t * 22) * vel


def drum_snare(n, vel):
    n = max(n, int(0.16 * SR))
    t = np.arange(n) / SR
    noise = _hp(_lp(RNG.standard_normal(n), 5200), 1300) * np.exp(-t * 26)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 40)
    return (0.8 * noise + 0.5 * tone) * vel


def drum_hat(n, vel):
    n = max(n, int(0.05 * SR))
    t = np.arange(n) / SR
    return _hp(RNG.standard_normal(n), 6500) * np.exp(-t * 70) * 0.6 * vel


DRUMS = {"kick": drum_kick, "snare": drum_snare, "hat": drum_hat}
INSTS = {"lead": inst_lead, "pluck": inst_pluck, "pad": inst_pad,
         "bass": inst_bass, "bell": inst_bell}


# ---------------------------------------------------------------- sequencer

def render(events, bpm, loop_beats, *, seamless=True, delay_beats=0.75,
           delay_mix=0.22, tail_sec=0.0):
    """events: (start_beat, dur_beats, midi|drum-name, inst, vel, pan).

    Seamless mode renders two consecutive loops and returns the second one,
    so releases/delay wrap correctly. Non-loop pieces set seamless=False and
    tail_sec for the final ring-out.
    """
    spb = 60.0 / bpm
    loop_n = int(round(loop_beats * spb * SR))
    if seamless:
        evs = list(events) + [(t + loop_beats, d, p, i, v, pan)
                              for (t, d, p, i, v, pan) in events]
        total_n = loop_n * 2
    else:
        evs = list(events)
        total_n = loop_n + int(tail_sec * SR)

    buses = {name: [np.zeros(total_n), np.zeros(total_n)]
             for name in ("dry", "lead", "drums")}
    for (t, d, p, inst, vel, pan) in evs:
        start = int(round(t * spb * SR))
        if start >= total_n:
            continue
        if inst in DRUMS:
            sig = DRUMS[inst](int(d * spb * SR), vel)
            bus = buses["drums"]
        else:
            n = max(int(d * spb * SR), 32)
            sig = INSTS[inst](midi2f(p), n, vel)
            bus = buses["lead"] if inst == "lead" else buses["dry"]
        end = min(start + len(sig), total_n)
        gl = np.sqrt(0.5 * (1 - pan))
        gr = np.sqrt(0.5 * (1 + pan))
        bus[0][start:end] += sig[: end - start] * gl
        bus[1][start:end] += sig[: end - start] * gr

    # Feedback delay on the lead bus (ping-pong-ish: cross-feed channels).
    dn = int(delay_beats * spb * SR)
    if dn > 0 and delay_mix > 0:
        led = buses["lead"]
        wet = [np.zeros(total_n), np.zeros(total_n)]
        srcL, srcR = led[0].copy(), led[1].copy()
        for k, g in enumerate([0.5, 0.25, 0.125], start=1):
            off = dn * k
            if off >= total_n:
                break
            # swap channels each tap
            a, b = (srcR, srcL) if k % 2 else (srcL, srcR)
            wet[0][off:] += a[: total_n - off] * g
            wet[1][off:] += b[: total_n - off] * g
        led[0] += wet[0] * delay_mix
        led[1] += wet[1] * delay_mix

    mix = [buses["dry"][c] + buses["lead"][c] + 0.9 * buses["drums"][c]
           for c in (0, 1)]
    out = np.stack(mix, axis=1)
    out = np.tanh(out * 0.9)                      # gentle glue/soft clip
    peak = np.max(np.abs(out)) or 1.0
    out *= 0.85 / peak
    if seamless:
        return out[loop_n:]
    return out


def write_wav(path: Path, x: np.ndarray):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(x.shape[1] if x.ndim == 2 else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(np.ascontiguousarray(pcm).tobytes())


# ------------------------------------------------------------- compositions
# Chord helper: name -> midi triad (root octave 3 for pads).
CH = {
    "Am": [57, 60, 64], "F": [53, 57, 60], "C": [48, 52, 55], "G": [55, 59, 62],
    "Dm": [50, 53, 57], "E": [52, 56, 59], "Em": [52, 55, 59], "D": [50, 54, 57],
    "B": [47, 51, 54], "Bb": [46, 50, 53], "Gm": [55, 58, 62], "A": [57, 61, 64],
}


def _arp(ev, chord, bar, inst="pluck", vel=0.5, pan=-0.35, octave=12):
    seq = [chord[0] + octave, chord[2] + octave, chord[1] + octave + 12,
           chord[2] + octave, chord[0] + octave + 12, chord[2] + octave,
           chord[1] + octave + 12, chord[2] + octave]
    for i, m in enumerate(seq):
        ev.append((bar * 4 + i * 0.5, 0.5, m, inst, vel, pan))


def _pad(ev, chord, bar, beats=4, vel=0.30):
    for m in chord:
        ev.append((bar * 4, beats, m + 12, "pad", vel, 0.0))


def _bass8(ev, root, bar, vel=0.55, pattern=None):
    pattern = pattern or [0, 0, 0, 0, 0, 0, -2, 0]  # slight approach note
    for i, off in enumerate(pattern):
        ev.append((bar * 4 + i * 0.5, 0.5, root - 12 + off, "bass", vel, 0.0))


def compose_title():
    """'Delve Below' — 90 BPM, 16 bars, A minor. Calm, mysterious."""
    ev = []
    prog = ["Am", "F", "C", "G", "Am", "F", "Dm", "E"]  # 2 bars each
    for i, name in enumerate(prog):
        c = CH[name]
        for b in (i * 2, i * 2 + 1):
            _pad(ev, c, b)
            _arp(ev, c, b, vel=0.42)
        ev.append((i * 2 * 4, 4, c[0] - 12, "bass", 0.4, 0.0))
        ev.append(((i * 2 + 1) * 4, 4, c[0] - 12, "bass", 0.35, 0.0))
    # Original melody (bars 5-16), long mournful phrases.
    mel = [
        (16, 2, 76), (18, 1, 72), (19, 1, 74), (20, 3, 76), (23, 1, 79),
        (24, 2, 81), (26, 1, 79), (27, 1, 76), (28, 4, 74),
        (32, 2, 72), (34, 1, 74), (35, 1, 76), (36, 3, 77), (39, 1, 76),
        (40, 2, 74), (42, 1, 71), (43, 1, 74), (44, 4, 76),
        (48, 2, 81), (50, 1, 79), (51, 1, 77), (52, 3, 76), (55, 1, 74),
        (56, 2, 72), (58, 1, 74), (59, 1, 71), (60, 4, 69),
    ]
    for (t, d, m) in mel:
        ev.append((t, d, m, "lead", 0.34, 0.2))
    # Sparse low bells for atmosphere.
    for b, m in [(0, 57), (8, 53), (16, 57), (24, 52), (32, 57), (40, 53),
                 (48, 50), (56, 52)]:
        ev.append((b, 3, m + 24, "bell", 0.10, -0.15))
    return render(ev, 90, 64, delay_beats=1.0, delay_mix=0.28)


def compose_map():
    """'Wayfarer's Ledger' — 108 BPM, 16 bars, C major. Light, plucky."""
    ev = []
    prog = ["C", "Am", "F", "G"] * 4
    for b, name in enumerate(prog):
        c = CH[name]
        _pad(ev, c, b, vel=0.20)
        _arp(ev, c, b, vel=0.5, pan=-0.3)
        # Walking-ish bass: root / fifth alternation with passing tone.
        r = c[0]
        for i, off in enumerate([0, 7, 12, 7]):
            ev.append((b * 4 + i, 1, r - 12 + off, "bass", 0.5, 0.0))
        # Light percussion.
        ev.append((b * 4 + 0, 0.3, 0, "kick", 0.5, 0.0))
        ev.append((b * 4 + 2, 0.3, 0, "kick", 0.4, 0.0))
        for i in range(4):
            ev.append((b * 4 + i + 0.5, 0.2, 0, "hat", 0.35, 0.25))
    # Cheerful original tune, bars 5-12.
    mel = [
        (16, 1, 76), (17, 0.5, 79), (17.5, 0.5, 76), (18, 1, 74), (19, 1, 72),
        (20, 1.5, 69), (21.5, 0.5, 72), (22, 2, 74),
        (24, 1, 77), (25, 0.5, 76), (25.5, 0.5, 74), (26, 1, 76), (27, 1, 72),
        (28, 3, 67), (31, 1, 71),
        (32, 1, 72), (33, 0.5, 74), (33.5, 0.5, 76), (34, 1, 79), (35, 1, 76),
        (36, 1.5, 81), (37.5, 0.5, 79), (38, 2, 76),
        (40, 1, 77), (41, 0.5, 76), (41.5, 0.5, 74), (42, 1, 71), (43, 1, 74),
        (44, 4, 72),
    ]
    for (t, d, m) in mel:
        ev.append((t, d, m, "lead", 0.30, 0.2))
    return render(ev, 108, 64, delay_beats=0.5, delay_mix=0.18)


def compose_combat():
    """'Sparks in the Undergrowth' — 140 BPM, 16 bars, E minor. Driving."""
    ev = []
    prog = ["Em", "Em", "C", "D", "Em", "Em", "C", "B"] * 2
    for b, name in enumerate(prog):
        c = CH[name]
        _pad(ev, c, b, vel=0.16)
        _bass8(ev, c[0], b, vel=0.6)
        ev.append((b * 4 + 0, 0.3, 0, "kick", 0.85, 0.0))
        ev.append((b * 4 + 2.5, 0.3, 0, "kick", 0.6, 0.0))
        ev.append((b * 4 + 1, 0.3, 0, "snare", 0.6, 0.05))
        ev.append((b * 4 + 3, 0.3, 0, "snare", 0.6, 0.05))
        for i in range(8):
            ev.append((b * 4 + i * 0.5, 0.2, 0, "hat",
                       0.4 if i % 2 == 0 else 0.25, 0.3))
    # Riff (bars 1-8): tight repeating figure with a lift.
    riff = [(0, 0.5, 76), (0.5, 0.5, 79), (1, 0.5, 76), (1.5, 0.5, 74),
            (2, 1, 76), (3, 1, 71)]
    for rep in range(4):
        base = rep * 8  # every 2 bars
        shift = 0 if rep % 2 == 0 else -2
        for (t, d, m) in riff:
            ev.append((base + t, d, m + shift, "lead", 0.34, 0.15))
    # Melody (bars 9-16), higher and more heroic.
    mel = [
        (32, 1, 83), (33, 0.5, 81), (33.5, 0.5, 79), (34, 1.5, 81), (35.5, 0.5, 79),
        (36, 1, 76), (37, 1, 79), (38, 2, 81),
        (40, 1, 84), (41, 0.5, 83), (41.5, 0.5, 81), (42, 1.5, 83), (43.5, 0.5, 81),
        (44, 1, 79), (45, 1, 76), (46, 2, 79),
        (48, 1, 83), (49, 0.5, 84), (49.5, 0.5, 86), (50, 1.5, 84), (51.5, 0.5, 83),
        (52, 1, 81), (53, 1, 79), (54, 2, 81),
        (56, 1, 79), (57, 0.5, 78), (57.5, 0.5, 76), (58, 1.5, 78), (59.5, 0.5, 76),
        (60, 4, 76),
    ]
    for (t, d, m) in mel:
        ev.append((t, d, m, "lead", 0.36, 0.15))
    return render(ev, 140, 64, delay_beats=0.75, delay_mix=0.2)


def compose_boss():
    """'Grove Golem's Wrath' — 152 BPM, 16 bars, D minor. Relentless."""
    ev = []
    prog = ["Dm", "Dm", "Bb", "A", "Dm", "Dm", "Gm", "A"] * 2
    for b, name in enumerate(prog):
        c = CH[name]
        _pad(ev, c, b, vel=0.18)
        # Chugging 8th bass with chromatic pickup into the next bar.
        pat = [0, 0, 0, 0, 0, 0, 1, 2] if b % 4 == 3 else [0, 0, 0, 0, 0, 0, 0, 0]
        _bass8(ev, c[0], b, vel=0.68, pattern=pat)
        ev.append((b * 4 + 0, 0.3, 0, "kick", 0.9, 0.0))
        ev.append((b * 4 + 1.5, 0.3, 0, "kick", 0.6, 0.0))
        ev.append((b * 4 + 2.5, 0.3, 0, "kick", 0.7, 0.0))
        ev.append((b * 4 + 1, 0.3, 0, "snare", 0.65, 0.05))
        ev.append((b * 4 + 3, 0.3, 0, "snare", 0.7, 0.05))
        if b % 4 == 3:  # fill
            for i in range(4):
                ev.append((b * 4 + 3 + i * 0.25, 0.2, 0, "snare", 0.4 + 0.1 * i, 0.1))
        for i in range(16):
            ev.append((b * 4 + i * 0.25, 0.12, 0, "hat",
                       0.35 if i % 4 == 0 else 0.18, -0.3))
        # Dissonant stab on the &-of-2 (minor 2nd cluster), every other bar.
        if b % 2 == 1:
            for m in (74, 75):
                ev.append((b * 4 + 2.5, 0.4, m, "pluck", 0.4, 0.35))
    # Aggressive lead: descending runs answered by held tritone-tension notes.
    mel = [
        (0, 0.5, 86), (0.5, 0.5, 84), (1, 0.5, 82), (1.5, 0.5, 81),
        (2, 1.5, 79), (3.5, 0.5, 81), (4, 3, 82), (7, 1, 81),
        (8, 0.5, 86), (8.5, 0.5, 84), (9, 0.5, 82), (9.5, 0.5, 81),
        (10, 1.5, 79), (11.5, 0.5, 77), (12, 3, 76), (15, 1, 73),
    ]
    for rep in range(4):
        base = rep * 16
        up = 0 if rep < 2 else 3  # lift a minor 3rd for the back half
        for (t, d, m) in mel:
            ev.append((base + t, d, m + up, "lead", 0.38, 0.12))
    return render(ev, 152, 64, delay_beats=0.5, delay_mix=0.16)


def compose_defeat():
    """'Embers Fade' — 70 BPM, 4 bars + ring-out, A minor. Somber, no loop."""
    ev = []
    prog = ["Am", "F", "Dm", "E"]
    for b, name in enumerate(prog):
        c = CH[name]
        _pad(ev, c, b, vel=0.26)
        ev.append((b * 4, 4, c[0] - 12, "bass", 0.35, 0.0))
        # Slow bell arpeggio.
        for i, m in enumerate([c[0], c[2], c[1] + 12]):
            ev.append((b * 4 + i * 1.25, 1.2, m + 12, "bell", 0.22, -0.2 + 0.2 * i))
    mel = [(0, 2, 76), (2, 1, 74), (3, 1, 72), (4, 3, 69), (7, 1, 72),
           (8, 2, 74), (10, 1, 72), (11, 1, 69), (12, 4, 68)]
    for (t, d, m) in mel:
        ev.append((t, d, m, "lead", 0.30, 0.15))
    ev.append((16, 6, 45, "bass", 0.30, 0.0))       # final low A ring
    for m in CH["Am"]:
        ev.append((16, 6, m, "pad", 0.22, 0.0))
    return render(ev, 70, 22, seamless=False, tail_sec=2.0,
                  delay_beats=1.0, delay_mix=0.25)


def fire_loop(seconds=9.0):
    """Procedural fire-crackle ambience, seamless loop, mono."""
    n = int(seconds * SR)
    rng = np.random.default_rng(4242)
    # Low rumble bed: heavily lowpassed noise (render 2x, keep 2nd half so
    # the filter state wraps; then micro-crossfade the seam).
    bed = _lp(rng.standard_normal(2 * n), 240)[n:]
    bed = bed / (np.max(np.abs(bed)) or 1) * 0.35
    # Crackles: short decaying bursts of bandpassed noise.
    crackle = np.zeros(n)
    for _ in range(220):
        pos = rng.integers(0, n)
        ln = rng.integers(int(0.004 * SR), int(0.030 * SR))
        burst = rng.standard_normal(ln) * np.exp(-np.arange(ln) / (0.15 * ln))
        amp = rng.uniform(0.15, 1.0) ** 2
        end = min(pos + ln, n)
        crackle[pos:end] += burst[: end - pos] * amp
        if pos + ln > n:                       # wrap for seamlessness
            crackle[: pos + ln - n] += burst[end - pos:] * amp
    crackle = _hp(_lp(crackle, 5200), 900)
    crackle = crackle / (np.max(np.abs(crackle)) or 1) * 0.8
    # Slow flame "breath" LFO on the bed (integer cycles -> loops cleanly).
    t = np.arange(n) / SR
    lfo = 0.75 + 0.25 * np.sin(2 * np.pi * 3 * t / seconds)
    x = bed * lfo + crackle
    # 8 ms equal-power seam crossfade.
    f = int(0.008 * SR)
    w = np.linspace(0, 1, f)
    x[:f] = x[:f] * w + x[-f:][::-1] * (1 - w)
    x = x / (np.max(np.abs(x)) or 1) * 0.8
    return x[:, None]  # (n, 1) mono


# ---------------------------------------------------------------- mastering

def measure_lufs(path: Path) -> float:
    r = subprocess.run(
        ["ffmpeg", "-i", str(path), "-af",
         "loudnorm=I=-19:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"],
        capture_output=True, text=True)
    js = r.stderr[r.stderr.rfind("{"):r.stderr.rfind("}") + 1]
    return float(json.loads(js)["input_i"])


def master(wav: Path, out: Path, *, target_lufs: float, q: int,
           channels: int, fade_out: tuple[float, float] | None = None):
    gain = target_lufs - measure_lufs(wav)
    filters = [f"volume={gain:.2f}dB", "alimiter=limit=0.78:level=false"]
    if fade_out:
        st, d = fade_out
        filters.append(f"afade=t=out:st={st}:d={d}")
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", str(wav),
         "-af", ",".join(filters), "-ar", str(SR), "-ac", str(channels),
         "-c:a", "libvorbis", "-q:a", str(q), str(out)], check=True)
    # Evidence: decoded peak must be <= -1.3 dBFS (repo convention).
    chk = subprocess.run(
        ["ffmpeg", "-i", str(out), "-af", "astats=metadata=1", "-f", "null", "-"],
        capture_output=True, text=True)
    for line in chk.stderr.splitlines():
        if "Peak level dB" in line:
            peak = float(line.split(":")[-1])
            assert peak <= -1.3, f"{out.name}: peak {peak} > -1.3 dBFS"
            print(f"  {out.name}: peak {peak:.2f} dBFS  OK")
            return
    raise RuntimeError("no peak stat found")


def main():
    MUSIC.mkdir(parents=True, exist_ok=True)
    SFX.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix="ember_music_"))
    jobs = [
        ("title_menu", compose_title, MUSIC / "title_menu.ogg", -19, 4, 2, None),
        ("map", compose_map, MUSIC / "map.ogg", -19, 4, 2, None),
        ("combat", compose_combat, MUSIC / "combat.ogg", -19, 4, 2, None),
        ("boss_combat", compose_boss, MUSIC / "boss_combat.ogg", -19, 4, 2, None),
    ]
    for name, fn, out, lufs, q, ch, fade in jobs:
        print(f"[{name}] composing...")
        wav = tmp / f"{name}.wav"
        write_wav(wav, fn())
        master(wav, out, target_lufs=lufs, q=q, channels=ch, fade_out=fade)

    print("[defeat] composing...")
    defeat = compose_defeat()
    wav = tmp / "defeat.wav"
    write_wav(wav, defeat)
    dur = len(defeat) / SR
    master(wav, MUSIC / "defeat.ogg", target_lufs=-18, q=4, channels=2,
           fade_out=(dur - 2.5, 2.5))
    # SFX sting: first 6.5 s with a 1.5 s fade (same slot the old file had).
    wav65 = tmp / "defeat65.wav"
    write_wav(wav65, defeat[: int(6.5 * SR)])
    master(wav65, SFX / "defeat.ogg", target_lufs=-18, q=5, channels=1,
           fade_out=(5.0, 1.5))

    print("[ember_ambience_loop] synthesizing...")
    wav = tmp / "fire.wav"
    write_wav(wav, fire_loop())
    master(wav, SFX / "ember_ambience_loop.ogg", target_lufs=-21, q=5, channels=1)
    print("done.")


if __name__ == "__main__":
    sys.exit(main())
