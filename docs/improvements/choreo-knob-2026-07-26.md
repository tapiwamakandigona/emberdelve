# §3, measured: shortening the swing makes the frame cost *worse*

`remaining-work-2026-07-25.md` §3 parks the combat button storm at 87.7
paints/frame and says the only way materially below ~85 is to change the
animation design — "shorter or fewer overlapping tweens" — and that this is a
feel call for the owner.

Half of that is right. The measurement below shows *shorter* is the wrong lever,
and in the direction that matters it is actively counter-productive.

## The knob

All seven swing beats now derive from one integer, `_CombatScreenState.choreoPercent`:

```dart
static const int choreoPercent = 100;      // 80 = 20% snappier, 120 = heavier
static Duration _pace(int ms) => Duration(milliseconds: math.max(16, ms * choreoPercent ~/ 100));
static final _contact = _pace(250);        // whoosh lead-in (SYNC_POINTS.md)
static final _squashTime = _pace(90);
static final _enemyWindupTime = _pace(190);
static final _hitStop = _pace(80);
static final _knockTime = _pace(140);
static final _flashTail = _pace(120);
static final _deathTime = _pace(700);
```

Pacing is now a one-line change instead of eight edits that can drift apart. The
*relative* anatomy — anticipation shorter than contact, hit-stop the shortest
beat, death the longest — is preserved by construction, and that ratio is what
reads as "a hit". The 16 ms floor keeps any beat from collapsing below one frame.

## What the scale actually buys — measured

`flutter test tool/perf_probe_test.dart`, scenario `combat_tap_storm_12`
(12 verb taps), same build, one variable changed:

| `choreoPercent` | frames | total paints | **paints/frame** | rebuilds/frame |
|---|---|---|---|---|
| 70 (snappier) | 50 | 4,835 | **96.7** | 23.9 |
| **100 (shipped)** | 60 | 5,261 | **87.7** | 19.3 |
| 130 (heavier) | 70 | 5,742 | **82.0** | 17.1 |

VERIFIED, and the shape is the opposite of the §3 assumption:

- Shortening the choreography by 30% removes only **8% of the total paints**
  (5,261 → 4,835) — the same layers still animate, they just animate for fewer
  frames.
- But it removes **17% of the frames**, so the work per frame goes **up**:
  87.7 → 96.7 paints/frame. A snappier swing is a *denser* swing.
- Stretching it the other way trades the reverse: 82.0 paints/frame, but the
  player waits 30% longer for the same hit.

Paints/frame is the jank proxy, so "shorter tweens" would have made the metric
§3 is worried about worse while also spending feel. The only lever that actually
lowers it is the other one the doc names: **fewer simultaneously animating
layers** during a hit (or collapsing the sprite stage into one `CustomPainter`).

## Why 100 stays the default

The §1 emulator trace (PR #70) measured the UI thread during this exact
scenario: average build 1.21 ms, p99 7.40 ms, **zero frames over the 16.7 ms
build budget** across 84 frames. At the current pacing there is roughly 9 ms of
headroom per frame, so 87.7 paints/frame is not costing dropped frames — it is a
number that looks alarming without a device trace behind it.

Changing the pacing therefore buys no measured performance, only feel. That is
the owner's call, so the default is unchanged and the knob is there for when he
wants to try one: edit `choreoPercent`, run the probe, keep or revert.

**VERIFIED at the default:** `flutter analyze` clean, full suite green, and the
probe reproduces the pre-change baseline exactly (87.7 paints/frame, 60 frames,
5,261 paints), i.e. the refactor is behaviour-identical at 100.
