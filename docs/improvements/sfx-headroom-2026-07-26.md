# Layered SFX: closing §6 without ears — mix-bus headroom, measured

`remaining-work-2026-07-25.md` §6 says the voice pool is "verified by test, not by
ear" and parks it on the owner. Two different questions were tangled in there:

1. **Is a cascade too loud / does it clip?** That is not a taste question, it is a
   number. It is now measured and guarded in CI.
2. **Does a cascade sound *good*?** Still a taste question. Unchanged, still the
   owner's, and a one-line edit to `sfxVoices` if the answer is no.

This document closes (1).

## The tool

`tool/sfx_headroom.py` rebuilds the worst-case cascades offline from the shipped
`assets/audio/sfx/*.ogg`, then measures each one:

- it **parses `AudioService.sfxVoices`** out of the Dart source, so the caps it
  models can never drift from the app;
- it **models voice stealing**: when the N+1th trigger of an id arrives with all
  N voices busy, the oldest copy is cut at that instant, exactly like
  `AudioPlayer.play()` on a resident player;
- it applies the **real per-call volume trims** from the call sites
  (`enemy_hit` 0.5 on multi-hit and burn, `block` 0.5/0.55, `ui_tap` 0.8) with
  the SFX slider at its maximum of 1.0 — the loudest a player can get;
- it measures **sample peak, inter-sample true peak and integrated loudness**
  with ffmpeg's EBU R128 meter, not just a naive `max(abs(x))`.

Run it: `python3 tool/sfx_headroom.py` (add `--write-clips out/` to also get an
mp3 of every cascade to listen to).

## Results — 2026-07-26, assets at v0.3.16

| scenario | layers | sample peak | true peak | LUFS-I | clipped | verdict |
|---|---|---|---|---|---|---|
| `die_assign_3x_same_frame` | 3 | +5.43 dBFS | +6.00 dBTP | −15.3 | 72 | over ceiling (unreachable) |
| `die_assign_4x_fast` | 4 | −4.11 dBFS | −3.50 dBTP | −21.0 | 0 | PASS |
| `roll_then_assigns` | 4 | −3.52 dBFS | −3.20 dBTP | −21.4 | 0 | PASS |
| `coin_3x_simultaneous` | 3 | +5.87 dBFS | +5.90 dBTP | −12.0 | 122 | over ceiling (unreachable) |
| `coin_3x_spaced` | 3 | −3.40 dBFS | −3.40 dBTP | −16.6 | 0 | PASS |
| `enemy_hit_3x_multihit` | 3 | −7.97 dBFS | −7.90 dBTP | −21.4 | 0 | PASS |
| `full_attack_turn` | 8 | −1.00 dBFS | −0.90 dBTP | −13.7 | 0 | TIGHT |
| `enemy_turn_block_stack` | 4 | −1.97 dBFS | −2.00 dBTP | −15.9 | 0 | PASS |
| `ui_tap_over_cascade` | 5 | −3.46 dBFS | −2.90 dBTP | −20.4 | 0 | PASS |

Ceiling: FAIL above 0.0 dBTP, TIGHT above −1.0 dBTP.

**VERIFIED: every reachable cascade clears the digital ceiling.** The loudest
one a player can actually produce is the full attack turn (whoosh + three hits +
ember gain + three coins) at −0.9 dBTP — under the ceiling, but with less than a
decibel of headroom, so it is the one to re-measure whenever a combat SFX is
replaced or a trim is removed.

## The interesting finding: coherent summing, and what prevents it

The two scenarios over the ceiling are the ones where the *same* sample starts on
the *same* frame. Identical waveforms sum coherently — three copies is +9.5 dB of
amplitude, not the ~+5 dB you get from three loosely spaced copies — and that
pushes `coin` to +5.9 dBTP with 122 hard-clipped samples.

Those scenarios are unreachable today, and it is worth knowing exactly why,
because it is a load-bearing accident:

- `AudioService.handleEvents` plays **each id at most once per event batch**, so
  the three gold events that all map to `coin` (`gold_gained`, `gold_spent`,
  `bought`) can never fire three coin voices together;
- every other multi-voice id is either driven by a discrete tap (`die_assign`) or
  by the combat choreographer, which spaces impacts by animation beats.

So the mix is safe *because of* the de-dupe, not because the assets are quiet.
That is now pinned by three tests in `test/audio_voices_test.dart`
("SFX mix-bus invariants"): the de-dupe itself — extracted as the pure
`AudioService.sfxIdsForEvents` so it is testable without a platform player —
and a golden copy of the audited `sfxVoices` table. Raise a cap or drop the
de-dupe and the tests fail, telling you to re-run the tool.

`tool/sfx_headroom.py` also runs in CI on every PR, so replacing an .ogg with a
hotter master fails the build instead of shipping a clipped cascade.

## What is left for ears

Whether four dice in 300 ms sound like a satisfying cascade or like clutter.
Render the clips (`--write-clips`), listen, and if any of them feels busy the fix
is still the one the original doc named: drop that id's count in `sfxVoices` from
3 to 2, or add a per-call volume trim. The tests will then ask you to re-run the
measurement, which takes about twenty seconds.
