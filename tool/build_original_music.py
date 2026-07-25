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

Everything here is synthesized from first principles (numpy/scipy oscillators,
physical models, envelopes, filtered noise). No samples, no soundfonts, no
third-party audio of any kind is read. The compositions (chord progressions,
melodies, drum patterns) are original works written for Emberdelve — same
*genre* as the tracks they replace but never a note-for-note copy of anything.
All outputs (c) Tsoro Studios, dedicated CC0 1.0 in PROVENANCE.md.

Render engine v2 ("immersive"): the original event-list compositions are
performed by a much richer engine — Karplus-Strong plucked strings, felt
piano, tremolo strings, 7-voice supersaw pads, FM bells, sub-weighted bass,
layered drums (incl. timpani/taiko), synthesized stereo impulse responses ->
convolution reverb, ping-pong delay, sidechain ducking, per-section
arrangement arcs, humanized timing, key-pitched cavern-rumble beds, and a
mix EQ chain (low-shelf warmth, 3.2 kHz tinny-band cut, air shelf).
Full production notes: docs/music-production.md. Deterministic (fixed seeds).

Loop seamlessness: loops are rendered twice back-to-back and the SECOND pass
is exported, so envelope releases and reverb/delay tails from the end of the
loop are already present at its start (steady-state loop, no edge fades).

Mastering (repo convention, PROVENANCE.md): measured EBU R128 gain toward
-19 LUFS (music) / -18 LUFS (stings), alimiter ceiling, decoded peak
<= -1.3 dBFS, OGG Vorbis q6 stereo (music; raised from q4 for the v2 engine's
denser spectrum) / q5 mono (sfx), 44.1 kHz.

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
from scipy.signal import fftconvolve, lfilter, resample_poly

REPO = Path(__file__).resolve().parent.parent
MUSIC = REPO / "assets" / "audio" / "music"
SFX = REPO / "assets" / "audio" / "sfx"
SR = 44100
OS = 2  # oversampling factor for naive oscillators
RNG = np.random.default_rng(20260725)


# ------------------------------------------------- shared filter helpers

def _lp(x, cutoff):  # vectorized one-pole via lfilter-equivalent recursion
    from scipy.signal import lfilter
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff / SR)
    return lfilter([a], [1, -(1 - a)], x)


def _hp(x, cutoff):
    return x - _lp(x, cutoff)


RNG = np.random.default_rng(20260725)


# ---------------------------------------------- engine v2: helpers

def midi2f(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def lp1(x, cutoff, sr=SR):
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff / sr)
    return lfilter([a], [1, -(1 - a)], x, axis=0)


def hp1(x, cutoff, sr=SR):
    return x - lp1(x, cutoff, sr)


def adsr(n, a, d, s, r, sr=SR, curve=3.0):
    a_n, d_n, r_n = (max(1, int(x * sr)) for x in (a, d, r))
    if a_n + d_n + r_n > n:
        k = n / (a_n + d_n + r_n)
        a_n, d_n, r_n = (max(1, int(x * k)) for x in (a_n, d_n, r_n))
    s_n = max(0, n - a_n - d_n - r_n)
    atk = np.linspace(0, 1, a_n, endpoint=False) ** (1 / curve)
    dec = s + (1 - s) * np.linspace(1, 0, d_n, endpoint=False) ** curve
    rel = s * np.linspace(1, 0, r_n) ** curve
    return np.concatenate([atk, dec, np.full(s_n, s), rel])[:n]


def saw_os(freq, n, detune_cents=0.0, drift_hz=0.0, drift_amt=0.0):
    """Naive saw at OS*SR then decimated (anti-aliased enough for music)."""
    m = n * OS
    t = np.arange(m) / (SR * OS)
    f = freq * 2.0 ** (detune_cents / 1200.0)
    fa = np.full(m, f)
    if drift_hz:
        fa = fa * (1.0 + drift_amt * np.sin(2 * np.pi * drift_hz * t + RNG.uniform(0, 6.28)))
    ph = np.cumsum(fa) / (SR * OS) % 1.0
    s = 2.0 * ph - 1.0
    return resample_poly(s, 1, OS)[:n]


def stereo(l, r):
    n = min(len(l), len(r))
    return np.stack([l[:n], r[:n]], axis=1)


# ------------------------------------------------------------- instruments
# Each returns (n, 2) stereo float arrays. vel ~ 0..1 from composition data.

def v2_lead(freq, n, vel):
    """Unison detuned saw lead, vibrato, filter envelope, mild grit."""
    voices_l, voices_r = np.zeros(n), np.zeros(n)
    for i, det in enumerate([-9, -4, 0, 4, 9]):
        v = saw_os(freq, n, det, drift_hz=5.2, drift_amt=0.005)
        if i % 2 == 0:
            voices_l += v
        else:
            voices_r += v
    env = adsr(n, 0.015, 0.10, 0.75, 0.10)
    # filter envelope: open on attack, settle
    cut = 1300 + 5200 * (env ** 1.5)
    out_l = np.zeros(n)
    out_r = np.zeros(n)
    seg = 1024
    for s in range(0, n, seg):
        e = min(s + seg, n)
        c = float(cut[s:(e)].mean())
        out_l[s:e] = lp1(voices_l[s:e], c)
        out_r[s:e] = lp1(voices_r[s:e], c)
    body_l = np.tanh(out_l * 1.4) * env
    body_r = np.tanh(out_r * 1.4) * env
    return stereo(body_l, body_r) * vel * 0.30


def v2_pluck(freq, n, vel):
    """Karplus-Strong plucked string, stereo via two slightly different picks."""
    n = max(n, int(0.35 * SR))
    outs = []
    for det, damp in [(0.0, 0.996), (0.15, 0.995)]:
        f = freq * 2.0 ** (det / 1200.0)
        period = max(2, int(round(SR / f)))
        buf = RNG.uniform(-1, 1, period)
        buf = lp1(buf, 9000).ravel()  # pick brightness
        y = np.empty(n)
        idx = 0
        prev = 0.0
        for i in range(n):
            cur = buf[idx]
            new = damp * (0.62 * cur + 0.38 * prev)
            y[i] = cur
            buf[idx] = new
            prev = cur
            idx = (idx + 1) % period
        outs.append(y)
    body = stereo(outs[0], outs[1])
    t = np.arange(len(body)) / SR
    body *= np.exp(-t * 1.4)[:, None]
    return body * vel * 0.55


def v2_pad(freq, n, vel):
    """7-voice supersaw, slow LP sweep, +1 octave shimmer, very wide."""
    l, r = np.zeros(n), np.zeros(n)
    dets = [-13, -8, -4, 0, 4, 8, 13]
    for i, det in enumerate(dets):
        v = saw_os(freq, n, det, drift_hz=0.13 + 0.05 * i, drift_amt=0.004)
        pan = (i / (len(dets) - 1)) * 2 - 1
        l += v * np.sqrt(0.5 * (1 - pan * 0.9))
        r += v * np.sqrt(0.5 * (1 + pan * 0.9))
    shim = saw_os(freq * 2.0, n, 5) * 0.30
    l += shim
    r += saw_os(freq * 2.0, n, -5)[:n] * 0.30
    t = np.arange(n) / SR
    sweep = 1500 + 1200 * np.sin(2 * np.pi * 0.09 * t + 1.0)
    seg = 2048
    for s in range(0, n, seg):
        e = min(s + seg, n)
        c = float(sweep[s:e].mean())
        l[s:e] = lp1(l[s:e], c)
        r[s:e] = lp1(r[s:e], c)
    env = adsr(n, 0.35, 0.3, 0.85, 0.6)
    return stereo(l * env, r * env) * vel * 0.16


def v2_bass(freq, n, vel):
    t = np.arange(n) / SR
    sub = np.sin(2 * np.pi * freq * 0.5 * t)
    fund = np.sin(2 * np.pi * freq * t)
    growl = lp1(saw_os(freq, n), 500)
    body = 0.82 * sub + 0.62 * fund + 0.5 * growl
    body = np.tanh(body * 1.5)
    env = adsr(n, 0.006, 0.06, 0.9, 0.08)
    m = body * env * vel * 0.55
    return stereo(m, m)  # bass stays mono/centered


def v2_bell(freq, n, vel):
    """FM bell with inharmonic partials and long shimmer."""
    n = max(n, int(1.2 * SR))
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * freq * 3.51 * t) * 2.2 * np.exp(-t * 3.0)
    car = np.sin(2 * np.pi * freq * t + mod)
    p2 = 0.35 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t * 4.5)
    p3 = 0.2 * np.sin(2 * np.pi * freq * 5.40 * t) * np.exp(-t * 6.0)
    body = (car * np.exp(-t * 2.2) + p2 + p3)
    # gentle auto-pan for motion
    pan = 0.35 * np.sin(2 * np.pi * 0.6 * t + RNG.uniform(0, 6.28))
    l = body * np.sqrt(0.5 * (1 - pan))
    r = body * np.sqrt(0.5 * (1 + pan))
    return stereo(l, r) * vel * 0.5


def v2_strings(freq, n, vel):
    """Slow ensemble swell — used for added arrangement layers."""
    l, r = np.zeros(n), np.zeros(n)
    for det, pan in [(-7, -0.7), (-3, -0.25), (3, 0.25), (7, 0.7)]:
        v = saw_os(freq, n, det, drift_hz=4.5, drift_amt=0.004)
        v = lp1(v, 3400)
        l += v * np.sqrt(0.5 * (1 - pan))
        r += v * np.sqrt(0.5 * (1 + pan))
    env = adsr(n, 0.5, 0.4, 0.8, 0.8)
    return stereo(l * env, r * env) * vel * 0.16


def v2_flute(freq, n, vel):
    """Breathy sine flute for counter-melodies."""
    t = np.arange(n) / SR
    vib = 1.0 + 0.007 * np.sin(2 * np.pi * 5.0 * t) * np.minimum(t * 2, 1)
    ph = np.cumsum(np.full(n, freq) * vib) / SR
    tone = np.sin(2 * np.pi * ph) + 0.28 * np.sin(2 * np.pi * 2 * ph) + 0.1 * np.sin(2 * np.pi * 3 * ph)
    breath = lp1(hp1(RNG.standard_normal(n), 1500).ravel(), 6000).ravel() * 0.05
    body = (tone + breath) * adsr(n, 0.06, 0.1, 0.85, 0.12)
    return stereo(body, body) * vel * 0.30


def v2_piano(freq, n, vel):
    """Additive felt-piano: detuned partials, hammer, vel->brightness."""
    n = max(n, int(1.3 * SR))
    t = np.arange(n) / SR
    kdec = (freq / 261.0) ** 0.55  # higher notes decay faster
    out = np.zeros(n)
    partials = [(1.0, 1.0, 2.4), (2.004, 0.48, 4.2), (3.009, 0.22, 6.5),
                (4.016, 0.10, 9.0), (5.03, 0.05, 12.0)]
    for i, (mult, amp, dec) in enumerate(partials):
        bright = 1.0 if i == 0 else min(1.0, 0.35 + vel * 1.5)
        out += amp * bright * np.sin(2 * np.pi * freq * mult * t + 0.7 * i) \
               * np.exp(-t * dec * kdec)
    hammer = hp1(RNG.standard_normal(n), 1800).ravel() * np.exp(-t * 160) * 0.10
    body = (out + hammer) * adsr(n, 0.002, 0.05, 0.9, 0.25)
    # two "mics": tiny interchannel delay for width
    d = int(0.0008 * SR)
    l = body
    r = np.concatenate([np.zeros(d), body[:-d]])
    return stereo(l, r) * vel * 0.55


def v2_trem(freq, n, vel):
    """Tremolo string section (Vivaldi-esque tension layer)."""
    x = v2_strings(freq, n, vel)
    t = np.arange(len(x)) / SR
    trem = 0.72 + 0.28 * np.sin(2 * np.pi * 9.5 * t + RNG.uniform(0, 6.28))
    return x * trem[:, None] * 1.25


INSTS2 = {"lead": v2_lead, "piano": v2_piano, "trem": v2_trem, "pluck": v2_pluck, "pad": v2_pad, "bass": v2_bass,
          "bell": v2_bell, "strings": v2_strings, "flute": v2_flute}


# ------------------------------------------------------------------ drums

def d2_kick(n, vel):
    n = max(n, int(0.20 * SR))
    t = np.arange(n) / SR
    f = 130 * np.exp(-t * 30) + 38
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11)
    click = hp1(RNG.standard_normal(n), 3000).ravel() * np.exp(-t * 300) * 0.5
    m = np.tanh((body + click) * 1.8) * vel
    return stereo(m, m)


def d2_snare(n, vel):
    n = max(n, int(0.22 * SR))
    t = np.arange(n) / SR
    noise = hp1(lp1(RNG.standard_normal(n), 9500).ravel(), 1400).ravel() * np.exp(-t * 18)
    tone = (np.sin(2 * np.pi * 180 * t) + 0.6 * np.sin(2 * np.pi * 285 * t)) * np.exp(-t * 30)
    m = (0.9 * noise + 0.5 * tone) * vel
    nz = hp1(RNG.standard_normal(n), 4000).ravel() * np.exp(-t * 18) * 0.2 * vel
    return stereo(m + nz, m - nz)


def d2_hat(n, vel):
    n = max(n, int(0.06 * SR))
    t = np.arange(n) / SR
    # metallic: sum of detuned squares -> HP
    m = np.zeros(n)
    for f in [3187, 4211, 5533, 6917]:
        m += np.sign(np.sin(2 * np.pi * f * t))
    m = hp1(m * 0.25 + RNG.standard_normal(n) * 0.7, 7500).ravel() * np.exp(-t * 60)
    return stereo(m, m) * 0.5 * vel


def d2_taiko(n, vel):
    n = max(n, int(0.5 * SR))
    t = np.arange(n) / SR
    f = 95 * np.exp(-t * 10) + 55
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7)
    skin = lp1(RNG.standard_normal(n), 900).ravel() * np.exp(-t * 25) * 0.6
    m = np.tanh((body + skin) * 1.5) * vel
    return stereo(m, m)


def d2_crash(n, vel):
    n = max(n, int(1.6 * SR))
    t = np.arange(n) / SR
    m = hp1(RNG.standard_normal(n), 5000).ravel() * np.exp(-t * 2.2)
    l = m
    r = hp1(RNG.standard_normal(n), 5200).ravel() * np.exp(-t * 2.2)
    return stereo(l, r) * 0.5 * vel


def d2_shaker(n, vel):
    n = max(n, int(0.09 * SR))
    t = np.arange(n) / SR
    env = np.minimum(t * 60, 1) * np.exp(-t * 35)
    m = hp1(RNG.standard_normal(n), 6000).ravel() * env
    return stereo(m, m) * 0.45 * vel


def d2_timpani(n, vel):
    n = max(n, int(1.1 * SR))
    t = np.arange(n) / SR
    f = 84 * np.exp(-t * 3.5) + 58
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 4.5)
    mallet = lp1(RNG.standard_normal(n), 700).ravel() * np.exp(-t * 40) * 0.5
    m = np.tanh((body + mallet) * 1.5) * vel
    return stereo(m, m)


DRUMS2 = {"kick": d2_kick, "timpani": d2_timpani, "snare": d2_snare, "hat": d2_hat,
          "taiko": d2_taiko, "crash": d2_crash, "shaker": d2_shaker}


# ----------------------------------------------------------------- reverb

def make_ir(seconds, bright=4500, predelay=0.015, seed=7):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    tail_l = rng.standard_normal(n) * np.exp(-t * (6.9 / seconds))
    tail_r = rng.standard_normal(n) * np.exp(-t * (6.9 / seconds))
    tail_l = lp1(tail_l, bright).ravel()
    tail_r = lp1(tail_r, bright).ravel()
    # progressive HF damping deeper into the tail
    damp = np.exp(-t * 1.2)
    hf_l = hp1(tail_l, 2500).ravel() * damp
    hf_r = hp1(tail_r, 2500).ravel() * damp
    tail_l = lp1(tail_l, 2500).ravel() + hf_l
    tail_r = lp1(tail_r, 2500).ravel() + hf_r
    pre = int(predelay * SR)
    ir = np.zeros((n + pre, 2))
    ir[pre:, 0] = tail_l
    ir[pre:, 1] = tail_r
    # early reflections (cave walls)
    for dt, g, pan in [(0.009, 0.6, -0.4), (0.014, 0.5, 0.45), (0.021, 0.42, -0.2),
                       (0.029, 0.35, 0.3), (0.038, 0.28, -0.5)]:
        i = int(dt * SR)
        ir[i, 0] += g * (1 - pan) * 0.5
        ir[i, 1] += g * (1 + pan) * 0.5
    ir /= np.max(np.abs(ir))
    return ir


def reverb(x, ir, mix):
    wet = np.stack([fftconvolve(x[:, 0], ir[:, 0])[: len(x)],
                    fftconvolve(x[:, 1], ir[:, 1])[: len(x)]], axis=1)
    peak_dry = np.max(np.abs(x)) or 1.0
    peak_wet = np.max(np.abs(wet)) or 1.0
    wet *= peak_dry / peak_wet
    return x + wet * mix


def pingpong(x, delay_n, mix, fb=0.45, total_taps=5):
    if delay_n <= 0 or mix <= 0:
        return x
    n = len(x)
    wet = np.zeros_like(x)
    srcL, srcR = x[:, 0].copy(), x[:, 1].copy()
    g = 1.0
    for k in range(1, total_taps + 1):
        off = delay_n * k
        if off >= n:
            break
        g *= fb + (0.1 if k == 1 else 0.0)
        a, b = (srcR, srcL) if k % 2 else (srcL, srcR)
        wet[off:, 0] += a[: n - off] * g
        wet[off:, 1] += b[: n - off] * g
    return x + lp1(wet, 5200) * mix


def highshelf(x, f0=7500, gain_db=3.5):
    """RBJ high-shelf biquad."""
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * f0 / SR
    cw, sw = np.cos(w0), np.sin(w0)
    S = 0.9
    alpha = sw / 2 * np.sqrt((A + 1 / A) * (1 / S - 1) + 2)
    b0 = A * ((A + 1) + (A - 1) * cw + 2 * np.sqrt(A) * alpha)
    b1 = -2 * A * ((A - 1) + (A + 1) * cw)
    b2 = A * ((A + 1) + (A - 1) * cw - 2 * np.sqrt(A) * alpha)
    a0 = (A + 1) - (A - 1) * cw + 2 * np.sqrt(A) * alpha
    a1 = 2 * ((A - 1) - (A + 1) * cw)
    a2 = (A + 1) - (A - 1) * cw - 2 * np.sqrt(A) * alpha
    return lfilter([b0 / a0, b1 / a0, b2 / a0], [1, a1 / a0, a2 / a0], x, axis=0)


def lowshelf(x, f0=140, gain_db=4.5):
    """RBJ low-shelf biquad."""
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * f0 / SR
    cw, sw = np.cos(w0), np.sin(w0)
    S = 0.9
    alpha = sw / 2 * np.sqrt((A + 1 / A) * (1 / S - 1) + 2)
    b0 = A * ((A + 1) - (A - 1) * cw + 2 * np.sqrt(A) * alpha)
    b1 = 2 * A * ((A - 1) - (A + 1) * cw)
    b2 = A * ((A + 1) - (A - 1) * cw - 2 * np.sqrt(A) * alpha)
    a0 = (A + 1) + (A - 1) * cw + 2 * np.sqrt(A) * alpha
    a1 = -2 * ((A - 1) + (A + 1) * cw)
    a2 = (A + 1) + (A - 1) * cw - 2 * np.sqrt(A) * alpha
    return lfilter([b0 / a0, b1 / a0, b2 / a0], [1, a1 / a0, a2 / a0], x, axis=0)


def peakcut(x, f0=3200, gain_db=-2.5, Q=1.1):
    """RBJ peaking EQ — tame the tinny upper-mid band."""
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * f0 / SR
    cw, sw = np.cos(w0), np.sin(w0)
    alpha = sw / (2 * Q)
    b0, b1, b2 = 1 + alpha * A, -2 * cw, 1 - alpha * A
    a0, a1, a2 = 1 + alpha / A, -2 * cw, 1 - alpha / A
    return lfilter([b0 / a0, b1 / a0, b2 / a0], [1, a1 / a0, a2 / a0], x, axis=0)


def sub_bed(total_n, freq=55.0, level=0.030, breath_hz=0.05, seed=101):
    """Deep cavern rumble: filtered brown-ish noise + faint root sine, breathing."""
    rng = np.random.default_rng(seed)
    rumble = lp1(np.cumsum(rng.standard_normal(total_n)) * 0.02, 90).ravel()
    rumble = hp1(hp1(rumble, 30), 30).ravel()   # kill infrasonic drift
    rumble /= (np.max(np.abs(rumble)) or 1.0)
    t = np.arange(total_n) / SR
    root = 0.5 * np.sin(2 * np.pi * freq * t + 0.4 * np.sin(2 * np.pi * 0.03 * t))
    lfo = 0.65 + 0.35 * np.sin(2 * np.pi * breath_hz * t + 2.1)
    m = (rumble * 0.8 + root) * lfo * level
    return stereo(m, m)


# -------------------------------------------------------------- sequencer

CURRENT = {"name": None}

IRS = {
    "hall": make_ir(3.3, bright=3900, predelay=0.026, seed=7),
    "cave": make_ir(2.5, bright=3300, predelay=0.016, seed=11),
    "room": make_ir(1.4, bright=4800, predelay=0.010, seed=13),
    "vast": make_ir(4.6, bright=3500, predelay=0.038, seed=17),
}

TRACK_FX = {
    # (ir, pad_rvb, lead_rvb, drum_rvb, delay_mix_scale, duck_amt, shelf_db)
    "title_menu": ("hall", 0.66, 0.50, 0.24, 1.2, 0.00, 4.0),
    "map":        ("room", 0.44, 0.36, 0.17, 1.0, 0.10, 3.8),
    "combat":     ("cave", 0.36, 0.30, 0.19, 1.0, 0.22, 3.0),
    "boss_combat": ("cave", 0.38, 0.30, 0.22, 0.9, 0.25, 3.0),
    "defeat":     ("vast", 0.78, 0.66, 0.30, 1.3, 0.00, 3.5),
}


MELODY_TO_PIANO = {"title_menu", "map", "defeat"}


def augment(events, name, bpm, loop_beats):
    """Added arrangement layers per track (original writing, same key/harmony)."""
    if name in MELODY_TO_PIANO:  # genre staple: piano carries the tune
        events = [(t, d, p, ("piano" if i == "lead" else i), v * (1.35 if i == "lead" else 1), pan)
                  for (t, d, p, i, v, pan) in events]
    ev = list(events)
    bars = int(loop_beats // 4)
    if name == "title_menu":
        # deep drone on A (root pedal), swaps to F/E with the harmony
        drone = [(0, 16, 33), (16, 16, 29), (32, 16, 33), (48, 8, 26), (56, 8, 28)]
        for (t, d, m) in drone:
            ev.append((t, d, m + 12, "strings", 0.30, 0.0))
        # airy flute echoes of the melody tail, bars 13-16
        for (t, d, m) in [(48.5, 1.5, 88), (52.5, 1.5, 86), (56.5, 1.5, 84), (60, 3, 81)]:
            ev.append((t, d, m, "flute", 0.16, -0.3))
        # lone piano voice in the sparse intro (Hollow Knight-style)
        for (t, d, m) in [(0, 2, 69), (2, 2, 72), (4, 3, 76), (8, 2, 65),
                          (10, 2, 69), (12, 4, 72)]:
            ev.append((t, d, m, "piano", 0.22, 0.05))
        # very sparse deep taiko heartbeats
        for b in range(0, bars, 4):
            ev.append((b * 4, 0.5, 0, "taiko", 0.18, 0.0))
    elif name == "map":
        for b in range(bars):
            for i in range(8):
                ev.append((b * 4 + i * 0.5 + 0.25, 0.15, 0, "shaker",
                           0.30 if i % 2 else 0.18, 0.35))
        # warm string bed following the progression (C Am F G)
        roots = [48, 45, 41, 43] * 4
        for b, r in enumerate(roots):
            ev.append((b * 4, 4, r + 24, "strings", 0.14, 0.1))
        # flute counter-phrase in the last 4 bars
        for (t, d, m) in [(48, 1.5, 84), (49.5, 0.5, 83), (50, 2, 79),
                          (52, 1.5, 81), (53.5, 0.5, 79), (54, 2, 76),
                          (56, 1, 77), (57, 1, 79), (58, 2, 81), (60, 4, 79)]:
            ev.append((t, d, m, "flute", 0.15, -0.25))
    elif name == "combat":
        # staccato low string ostinato doubling the bass rhythm (E pedal)
        prog_roots = [40, 40, 36, 38, 40, 40, 36, 35] * 2
        for b, r in enumerate(prog_roots):
            for i in range(4):
                ev.append((b * 4 + i, 0.45, r + 24, "strings", 0.16, 0.15 * (-1) ** i))
        # crash at loop top + halfway, riser fill via snare handled upstream
        ev.append((0, 2, 0, "crash", 0.4, 0.0))
        ev.append((32, 2, 0, "crash", 0.35, 0.0))
        # toms driving bars 13-16 (Dead Cells-style tom grooves)
        for b in range(12, 16):
            for (o, v) in [(0.5, 0.4), (1.5, 0.35), (2.75, 0.45), (3.5, 0.5)]:
                ev.append((b * 4 + o, 0.3, 0, "taiko", v, -0.2 + 0.1 * (b % 3)))
        # snare fill turnarounds into bar 9 (breakdown) and the loop point
        for base in (31, 63):
            for i in range(6):
                ev.append((base + i / 6.0, 0.12, 0, "snare", 0.25 + 0.06 * i, 0.1))
        # breakdown toms keep pulse while kit ducks (bars 9-10)
        for b in (8, 9):
            for o in (0, 1.5, 2.5):
                ev.append((b * 4 + o, 0.4, 0, "taiko", 0.45, 0.0))
    elif name == "boss_combat":
        # war taikos underlining every bar + crash accents
        for b in range(bars):
            ev.append((b * 4 + 0, 0.4, 0, "taiko", 0.55, 0.0))
            ev.append((b * 4 + 2.5, 0.4, 0, "taiko", 0.40, 0.0))
            if b % 4 == 0:
                ev.append((b * 4, 2, 0, "crash", 0.42, 0.0))
        # menacing low choir-ish strings on the chord roots
        roots = [38, 38, 34, 33, 38, 38, 31, 33] * 2
        for b, r in enumerate(roots):
            ev.append((b * 4, 4, r + 24, "strings", 0.20, 0.0))
            ev.append((b * 4, 4, r + 12, "strings", 0.14, 0.0))
        # tremolo strings tension layer, back half (research: Vivaldi tremolo)
        for b, r in enumerate(roots):
            if b >= 8:
                ev.append((b * 4, 4, r + 36, "trem", 0.16, -0.2))
        # timpani hits under bar downbeats + escalating frenzy fill bars 13-16
        for b in range(0, 16, 2):
            ev.append((b * 4, 1, 0, "timpani", 0.5, 0.0))
        for i in range(8):   # frantic accelerating timpani (Kondo-style solo)
            ev.append((56 + i * 0.5, 0.4, 0, "timpani", 0.35 + 0.05 * i, 0.0))
        for i in range(16):  # double-time snare drive, last 2 bars
            ev.append((56 + i * 0.5, 0.2, 0, "snare", 0.30 + 0.02 * i, 0.08))
        # chromatic rising lead line into the loop point (bars 15-16)
        for i, m in enumerate([74, 75, 76, 77, 78, 79, 80, 81]):
            ev.append((60 + i * 0.5, 0.5, m, "lead", 0.30 + 0.015 * i, 0.1))
    elif name == "defeat":
        # vast low drone + a distant bell toll
        ev.append((0, 22, 33, "strings", 0.22, 0.0))
        for (t, m) in [(0, 69), (8, 65), (12, 64)]:
            ev.append((t, 4, m + 12, "bell", 0.12, 0.2))
        # solo piano echo of the lament, entering after the first phrase
        for (t, d, m) in [(8, 2, 81), (10, 1, 79), (11, 1, 76), (12, 4, 74)]:
            ev.append((t, d, m, "piano", 0.20, -0.1))
    return ev



def air_bed(total_n, level=0.012, breath_hz=0.07):
    """Quiet cave-air / ember-hiss bed, stereo decorrelated, steady-state."""
    rng = np.random.default_rng(99)
    l = hp1(lp1(rng.standard_normal(total_n), 9000).ravel(), 2500).ravel()
    r = hp1(lp1(rng.standard_normal(total_n), 9000).ravel(), 2500).ravel()
    t = np.arange(total_n) / SR
    lfo = 0.7 + 0.3 * np.sin(2 * np.pi * breath_hz * t)
    return stereo(l * lfo, r * lfo) * level



# Arrangement arcs — "subtractive composition": tracks must breathe and unfold.
# gain 0 = instrument sits out this bar; loops still wrap (last bars thin back
# toward the opening texture so the seam sounds intentional).
def section_gain(name, bar, inst):
    b = int(bar)
    if name == "title_menu":            # 16 bars: sparse -> bloom -> recede
        if inst == "pluck":
            return 0.0 if b < 4 else (0.7 if b < 8 else (1.0 if b < 14 else 0.6))
        if inst == "taiko":
            return 0.0 if b < 8 else 1.0
        if inst == "pad":
            return 0.75 if b < 4 else 1.0
    elif name == "map":                 # drums walk in, dropout turnaround
        if inst in ("kick", "shaker"):
            return 0.0 if b < 2 else (0.0 if b == 15 else 1.0)
        if inst == "hat":
            return 0.0 if b < 4 else (0.0 if b == 15 else 1.0)
        if inst == "strings":
            return 0.0 if b < 8 else 1.0
    elif name == "combat":              # bar-8 breakdown, slam back at 10
        if inst in ("kick", "hat", "snare"):
            return 0.35 if b in (8, 9) else 1.0
        if inst == "pad":
            return 1.25 if b in (8, 9) else 1.0
        if inst == "strings":
            return 0.0 if b < 4 else 1.0
    elif name == "boss_combat":         # relentless but escalating
        if inst == "trem":
            return 0.0 if b < 8 else 1.0
        if inst == "hat":
            return 0.6 if b < 4 else 1.0
    return 1.0


def render(events, bpm, loop_beats, *, seamless=True, delay_beats=0.75,
              delay_mix=0.22, tail_sec=0.0):
    name = CURRENT["name"]
    events = augment(events, name, bpm, loop_beats)
    spb = 60.0 / bpm
    loop_n = int(round(loop_beats * spb * SR))
    if seamless:
        evs = list(events) + [(t + loop_beats, d, p, i, v, pan)
                              for (t, d, p, i, v, pan) in events]
        total_n = loop_n * 2
    else:
        evs = list(events)
        total_n = loop_n + int(tail_sec * SR)

    buses = {k: np.zeros((total_n, 2)) for k in
             ("pad", "lead", "pluck", "bass", "drums", "layers")}
    kick_times = []
    hum = np.random.default_rng(777)
    HUMANIZE = {"pluck", "hat", "shaker", "piano", "bell"}
    for (t, d, p, inst, vel, pan) in evs:
        bar = (t % loop_beats) // 4
        g = section_gain(name, bar, inst)
        if g <= 0:
            continue
        vel = vel * g
        if inst in HUMANIZE:
            t = t + hum.uniform(-0.008, 0.012) / spb   # +-~10ms feel
            vel = vel * hum.uniform(0.85, 1.12)
        start = int(round(t * spb * SR))
        if start < 0:
            start = 0
        if start >= total_n:
            continue
        if inst in DRUMS2:
            sig = DRUMS2[inst](int(d * spb * SR), vel)
            bus = buses["drums"]
            if inst in ("kick", "taiko", "timpani"):
                kick_times.append(start)
        else:
            n = max(int(d * spb * SR), 64)
            sig = INSTS2[inst](midi2f(p), n, vel)
            bus = {"lead": buses["lead"], "pad": buses["pad"],
                   "pluck": buses["pluck"], "bass": buses["bass"],
                   "bell": buses["layers"], "strings": buses["layers"],
                   "piano": buses["lead"], "trem": buses["layers"],
                   "flute": buses["layers"]}[inst]
        # apply composition pan on top of instrument stereo
        pan = float(np.clip(pan, -1.0, 1.0))
        gl = np.sqrt(0.5 * (1 - pan))
        gr = np.sqrt(0.5 * (1 + pan))
        end = min(start + len(sig), total_n)
        bus[start:end, 0] += sig[: end - start, 0] * gl * 1.41
        bus[start:end, 1] += sig[: end - start, 1] * gr * 1.41
    del hum

    irname, pad_r, lead_r, drum_r, dscale, duck_amt, shelf_db = TRACK_FX[name]
    ir = IRS[irname]

    dn = int(delay_beats * spb * SR)
    buses["lead"] = pingpong(buses["lead"], dn, delay_mix * dscale)
    buses["pluck"] = pingpong(buses["pluck"], dn, delay_mix * dscale * 0.6)

    buses["pad"] = reverb(buses["pad"], ir, pad_r)
    buses["lead"] = reverb(buses["lead"], ir, lead_r)
    buses["pluck"] = reverb(buses["pluck"], ir, lead_r * 0.8)
    buses["layers"] = reverb(buses["layers"], ir, pad_r * 0.9)
    buses["drums"] = reverb(buses["drums"], IRS["room"], drum_r)

    # sidechain duck (pads/layers dip after each kick for punch)
    if duck_amt > 0 and kick_times:
        duck = np.ones(total_n)
        dl = int(0.09 * SR)
        shape = 1 - duck_amt * np.exp(-np.arange(dl) / (0.03 * SR))
        for kt in kick_times:
            e = min(kt + dl, total_n)
            duck[kt:e] = np.minimum(duck[kt:e], shape[: e - kt])
        for k in ("pad", "layers"):
            buses[k] *= duck[:, None]

    buses["pad"] = hp1(buses["pad"], 95)       # keep warmth, clear only sub
    buses["layers"] = hp1(buses["layers"], 140)
    mix = (buses["pad"] * 0.85 + buses["lead"] * 1.3 + buses["pluck"] +
           buses["bass"] * 1.15 + buses["drums"] * 1.0 + buses["layers"])
    if name in ("title_menu", "defeat"):
        mix += air_bed(total_n, level=0.016)
    elif name == "map":
        mix += air_bed(total_n, level=0.008, breath_hz=0.11)
    # deep cavern rumble bed — felt more than heard (immersion floor)
    # root-pitched (track keys: Am / C / Em / Dm / Am)
    SUBBED = {"title_menu": (55.0, 0.020), "map": (65.41, 0.014),
              "combat": (41.2, 0.020), "boss_combat": (36.71, 0.024),
              "defeat": (55.0, 0.024)}
    sf, sl = SUBBED[name]
    if sl > 0:
        mix += sub_bed(total_n, freq=sf, level=sl)
    mix = hp1(hp1(mix, 26), 26)                # no infrasonic headroom waste
    mix = peakcut(mix, 3200, -2.0)             # tame tinny upper mids
    mix = lowshelf(mix, 140, 3.0)              # real low-end weight
    mix = highshelf(mix, 7500, shelf_db)
    mix = np.tanh(mix * 0.8) / 0.8 * 0.9  # glue
    peak = np.max(np.abs(mix)) or 1.0
    mix *= 0.9 / peak
    assert not np.isnan(mix).any(), "NaN in mix"
    if seamless:
        return mix[loop_n:]
    return mix




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

def write_wav(path: Path, x: np.ndarray) -> None:
    """24-bit PCM WAV (mono or stereo)."""
    if x.ndim == 1:
        x = x[:, None]
    pcm = (np.clip(x, -1, 1) * 8388607).astype("<i4")
    raw = np.frombuffer(pcm.tobytes(), dtype=np.uint8).reshape(-1, 4)[:, :3].tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(3)
        w.setframerate(SR)
        w.writeframes(raw)


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
        ("title_menu", compose_title, MUSIC / "title_menu.ogg"),
        ("map", compose_map, MUSIC / "map.ogg"),
        ("combat", compose_combat, MUSIC / "combat.ogg"),
        ("boss_combat", compose_boss, MUSIC / "boss_combat.ogg"),
    ]
    for name, fn, out in jobs:
        print(f"[{name}] composing (engine v2)...")
        CURRENT["name"] = name
        wav = tmp / f"{name}.wav"
        write_wav(wav, fn())
        master(wav, out, target_lufs=-19, q=6, channels=2, fade_out=None)

    print("[defeat] composing (engine v2)...")
    CURRENT["name"] = "defeat"
    defeat = compose_defeat()
    wav = tmp / "defeat.wav"
    write_wav(wav, defeat)
    dur = len(defeat) / SR
    master(wav, MUSIC / "defeat.ogg", target_lufs=-18, q=6, channels=2,
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
