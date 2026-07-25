# Performance: whole-screen repaint storm + SFX tap latency (2026-07-25)

Owner report (legacy/dice-builder, released v0.3.11): *"It is laggy, even the
audio is sometimes like [glitchy], and when I click a button too quick it lags
a lot."*

All three symptoms have one shared cause and one separate cause.

## How this was measured

`tool/perf_probe_test.dart` (tool/, not in CI). Flutter calls
`debugOnProfilePaint` for every `RenderObject` painted in a frame and
`debugOnRebuildDirtyWidget` for every `Element` rebuilt, both in debug builds.
The probe counts them across four scenarios and writes
`build/perf_probe/metrics.json`.

**"Render objects painted per frame" is the number that matters.** A
well-isolated UI repaints only what changed; if an idle screen is repainting
200 render objects every frame it is re-rasterising itself entirely, 60 times a
second, forever.

Root causes were pinned with `debugPrintMarkNeedsPaintStacks` and
`debugPrintMarkNeedsLayoutStacks`, not guessed.

## Results

| Scenario | Before | After | |
|---|---|---|---|
| Title, idle | 49.6 paints/frame | **3.0** | 16x |
| Title, 12 rapid taps | 167.9 | **38.8** | 4.3x |
| Combat, idle | 204.0 | **2.0** | 100x |
| Combat, 12 rapid real taps | 207.2 | **95.4** | 2.2x |

Rebuilt elements per idle frame went 2-3 -> 0 on both screens.

## Cause 1 — animation via `setState` inside a `LayoutBuilder`/scroll subtree

Three always-on animations drove their visuals by rebuilding widgets every
frame:

- `SpriteView` — frame loop via `..addListener(() => setState(() {}))`, and the
  LFP-4 idle bob/sway via an `AnimatedBuilder`.
- `WeaponView` — 2.6s idle sway + swing tween via an `AnimatedBuilder`.
- `EmberLogotype` — 6s ember pulse via an `AnimatedBuilder`.

A `setState` 60x/s is bad on its own. It is *much* worse here because of where
these widgets live:

- the combat stage is wrapped in a `LayoutBuilder`
  (`combat_screen.dart`, `_stage`), and marking anything inside a
  `LayoutBuilder` dirty schedules a **layout callback** — so every sprite frame
  forced a full relayout of the combat screen, and layout invalidation is not
  stopped by a `RepaintBoundary`;
- the title screen is inside a scroll view with an `IntrinsicHeight`, with the
  same effect.

Result: the entire screen relaid out and repainted every frame, permanently,
with nothing happening.

**Fix:** every always-on animation now feeds its `CustomPainter` through
`CustomPainter.repaint` and reads `animation.value` at paint time. No
`setState`, no rebuild, no relayout — just a repaint of that painter, inside
its own `RepaintBoundary`. The idle bob/sway moved from `Transform` widgets
into `canvas.translate`/`canvas.rotate` in `_SpritePainter`, which is visually
identical and costs nothing.

## Cause 2 — no `RepaintBoundary` around the button press animation

`EmberButton` animates `AnimatedScale` over a `CustomPaint` on press, and the
primary tier paints a `MaskFilter.blur` under-glow. With no boundary, each
press repainted the whole screen for the full 80ms of the animation — so
hammering buttons held the UI in a continuous repaint storm. Now boundaried.

## Cause 3 — the logotype laid out text five times per frame

`_LogotypePainter` built five `TextPainter`s (probe, two blurred glow passes,
outline, gradient fill) and laid each one out on **every frame**. Text layout
is one of the most expensive things you can do in a paint. All five are now
cached; the one time-varying pass (the breathing glow) is quantised into 24
buckets so it hits the cache too — an alpha step of 0.005 and a blur step of
0.09px at fontSize 44, below the visible threshold.

## Cause 4 — SFX re-prepared a MediaPlayer on every tap

`AudioService.playSfx` round-robined a pool of six **default-mode**
`AudioPlayer`s and called `stop()` + `play(AssetSource(...))` per sound. On
Android, `PlayerMode.mediaPlayer` means each of those calls tears down and
re-prepares a `MediaPlayer`: a JNI hop, an asset read and a codec prepare, on
the platform thread, in the same moment the UI is trying to render the tap.
That is the late/glitchy audio, and it stacks with the repaint storm on rapid
taps.

**Fix:** one player per sound id, created in `PlayerMode.lowLatency`
(`SoundPoolPlayer` on Android — sample decoded once and resident in memory,
playback is a single non-blocking native call), with the source set once up
front. Re-trigger is `stop()` -> `resume()`, which SoundPool implements as
"play a new stream from the decoded sample". `main()` warms up the six
first-touch sounds in the background. Every SFX asset is <=56KB, comfortably
inside SoundPool's per-sample budget.

Behaviour change: re-triggering a sound that is still playing restarts it
instead of layering a second copy. That matches what the six-player pool
already did once more than six sounds were in flight, and it is the correct
behaviour for UI clicks.

## Not changed

- No `lib/sim` or `lib/data` change. Balance, RNG, saves and replays are
  untouched.
- The combat screen's own rebuild-on-notify structure is unchanged. That is why
  the rapid-tap scenario improves 2.2x rather than 100x: a real tap legitimately
  changes game state and rebuilds the screen. Splitting that 2000-line screen
  into `ValueListenable`-scoped sections is the next available win and is a
  bigger, riskier change.

## Verification

- `flutter analyze` clean.
- `flutter test` — 143/143 pass, unchanged.
- `tool/play_session_test.dart` green (4 bot-guided runs through the real UI).
- **Not verified on a physical Android device** — no device or emulator was
  available. The paint/rebuild counts above are exact and framework-level, and
  the `PlayerMode.lowLatency` behaviour is read from the plugin's Kotlin
  source, but the on-device frame times and audio latency are inferred, not
  measured.
