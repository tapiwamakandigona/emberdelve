# Music production notes — engine v2 ("immersive")

How the five Emberdelve music tracks are made, end to end. Companion to
`tool/build_original_music.py` (the only place any of this audio comes from)
and the provenance record in `PROVENANCE.md`.

**Ground rules (unchanged from original-asset pass 1):**

- 100% original, studio-owned work — no samples, no soundfonts, no
  third-party audio is ever read. No AI-generated audio either: every sound
  is synthesized from first principles in numpy/scipy (oscillators, physical
  models, envelopes, filtered noise) by code we wrote.
- Deterministic: fixed seeds, so `python3 tool/build_original_music.py`
  reproduces every shipped OGG bit-for-bit.
- The **compositions** (chord progressions, melodies, drum patterns, keys,
  BPM) are the same original works from pass 1. Engine v2 changes how they
  are *performed, mixed and mastered* — not what they are.

---

## 1. The tracks

| Track | Title | BPM / key | Form |
|---|---|---|---|
| `title_menu.ogg` | Delve Below | 90, A minor | 64-beat seamless loop |
| `map.ogg` | Wayfarer's Ledger | 108, C major | 64-beat seamless loop |
| `combat.ogg` | Sparks in the Undergrowth | 140, E minor | 64-beat seamless loop |
| `boss_combat.ogg` | Grove Golem's Wrath | 152, D minor | 64-beat seamless loop |
| `defeat.ogg` | Embers Fade | 70, A minor | non-looping, 2.5 s fade |

Compositions live as plain event lists — `(start_beat, duration, midi_note |
drum_name, instrument, velocity, pan)` — in the `compose_*` functions. The
engine is a sequencer that renders those events through synthesized
instruments into stereo buses, then mixes and masters.

## 2. Research: how games in this genre actually score

Before engine v2 we studied the scoring practice of the games this genre
borrows from (Hollow Knight, Dead Cells, Shovel Knight, and classic
Nintendo boss scoring). The recurring craft points that drove our design:

- **A real lead voice carries the tune** — Hollow Knight's identity is a
  simple felt-piano line over strings, not a wall of synths.
- **Subtractive composition** — delete most of what you could play;
  arrangement arcs (intro → bloom → recede) make a loop feel alive.
- **Loops must unfold, not tile** — a 16-bar loop that repeats bars 1–4
  four times reads as "menu music" instantly; sections need turnarounds and
  dropouts.
- **Human timing** — quantized-to-the-sample performance sounds like a
  ringtone; a few milliseconds of jitter on plucked/struck instruments reads
  as played.
- **Boss music** = ostinato + chromatic rise + accelerating percussion, not
  just "combat but louder".

## 3. The instruments (all synthesized)

| Instrument | Method |
|---|---|
| Felt piano | Multi-partial additive strike with inharmonicity, hammer noise, per-note decay; carries the melody on title/map/defeat |
| Plucked strings | Karplus-Strong physical model (excited delay line with damping) |
| Tremolo strings | Detuned saw ensemble, amplitude tremolo, slow attack |
| Supersaw pad | 7 detuned oversampled saws, slow filter sweep, wide stereo spread |
| Lead / flute / bells | Unison saws with vibrato + filter envelope; breathy sine flute; inharmonic FM bells |
| Bass | Sub sine + fundamental + low-passed saw growl through tanh saturation, mono/centered |
| Drums | Layered synthesis: deep kick (pitch-swept sine, 38 Hz tail), noise snare, metallic hats, taiko, timpani (tuned membrane), crash, shaker |

Oscillators are rendered 2× oversampled and decimated (`resample_poly`) to
keep aliasing out of the top octave.

## 4. Space and depth

- **Convolution reverb with synthesized impulse responses** — four rooms
  (hall 3.3 s, cave 2.5 s, room 1.4 s, vast 4.6 s) built from
  exponentially-decaying noise with progressive HF damping, pre-delay, and
  discrete early reflections. Each track picks its room (title→hall,
  map→room, combat/boss→cave, defeat→vast).
- **Depth staging** — drums/bass stay dry and close; pads, bells and string
  layers get progressively wetter, placing them behind the lead.
- **Ping-pong delay** on leads/plucks, tempo-synced per track.
- **Sidechain ducking** — pads/layers dip ~90 ms after each kick on the
  combat tracks for punch.
- **Ambience floor** — a quiet decorrelated "cave-air" hiss bed on the calm
  tracks, plus a key-pitched sub-rumble bed (root of each track's key, e.g.
  A1 = 55 Hz on the title) that is felt more than heard. Combat skips the
  rumble to stay punchy.

## 5. Arrangement arcs and humanization

- `augment()` adds per-track arrangement layers on top of the composed
  events (drones, ostinatos, swells, timpani) — same harmony, new voicing.
- `section_gain()` shapes each loop into sections: the title opens with lone
  piano, blooms, and recedes; the map walks its drums in at bar 3 and drops
  them for a turnaround; combat has a bar-9 breakdown; the boss climbs a
  chromatic rise with accelerating timpani into the loop point.
- Plucked/struck instruments get ±10 ms of seeded timing jitter and small
  velocity variation.

## 6. Mix and tonal balance

Per-bus EQ carving (pads high-passed so bass/kick own the low end), then a
master chain: low-shelf +3 dB @ 140 Hz (weight), peaking −2 dB @ 3.2 kHz
(the "tinny" band), gentle air shelf @ 7.5 kHz, tanh glue saturation, and a
26 Hz high-pass so infrasonics never eat headroom.

A tuning lesson worth recording: an early pass of this chain overshot the
low end — after loudness normalization the sub band (<80 Hz) held ~90% of
total energy and the mix collapsed toward mono mud. Loudness targets are
zero-sum: boosting one band trades every other band away. The fix was
halving the boosts and high-passing the rumble bed; the guard is now part of
verification (band-share measurement below).

## 7. Loop seamlessness

Loops are rendered **twice back-to-back and the second pass is exported**,
so envelope releases and reverb/delay tails from the end of the loop are
already ringing at its start. No edge fades, no seam. (IR + delay tails are
shorter than one loop, which this depends on.)

## 8. Mastering and verification

Repo convention (asserted by the build script itself):

- Measured EBU R128 gain to **−19 LUFS** (music) / **−18 LUFS** (defeat +
  sting), `alimiter` ceiling, decoded peak **≤ −1.3 dBFS**.
- OGG Vorbis **q6 stereo** for music (raised from q4: the v2 engine's denser
  spectrum — reverb tails, air band, sub content — deserves the headroom),
  q5 mono for sfx, 44.1 kHz.

Beyond the built-in asserts, each engine revision is checked with offline
measurements before it ships:

- **Loudness range (LRA)** and per-section RMS, to confirm arcs unfold
  (title LRA went 1.0 → ~3 across engine versions; defeat ~9).
- **Band energy shares** (sub <80 Hz / bass 80–250 / mids / 2–5 kHz / air),
  to keep the spectrum balanced — this is the guard that caught the
  sub-mud overshoot above.
- **Stereo correlation**, to verify width without mono-collapse risk.
- **Loop-point continuity** (decoded head/tail continuity of the exported
  second pass).

## 9. History

- **Pass 1 (original-asset pass 1)**: minimal chip-adjacent engine (pulse/
  triangle instruments, algorithmic echo). Legally complete, sonically flat:
  ~95% of energy below 1.9 kHz, essentially mono, no dynamics arc.
- **Pass 2**: new render engine (physical models, convolution reverb, wide
  stereo, layered drums) — much bigger, still tiled and machine-timed.
- **Pass 3**: research pass (§2) — felt piano lead, arrangement arcs,
  humanization, turnarounds, boss chromatics.
- **Pass 4 (shipped as engine v2)**: tonal-balance pass from listening
  feedback ("tinny, no bass, no depth") — fatter bass + deeper kick,
  low-shelf warmth, 3.2 kHz cut, longer IRs, key-pitched rumble beds,
  infrasonic guards. Verified: low end +~2 dB with real 80–250 Hz body,
  2–5 kHz share down ~60%, arcs and loop seams intact.
