# Perf pass 5 — map drag + title tap storm (remaining-work §5), v0.3.16+21

2026-07-26. Attacks the two largest un-attacked numbers left after v0.3.15:
map drag (54.5 paints/frame) and title tap storm (38.8). Both were listed in
`remaining-work-2026-07-25.md` §5 with the parchment-layer theory marked
ASSUMED — that theory was wrong, and this file records what was actually
happening, because the real mechanism will bite again.

Baseline/verify: `tool/perf_probe_test.dart`, same probe file both sides.

## Numbers (paints per frame)

| scenario            | v0.3.15 | this pass | change |
|---------------------|---------|-----------|--------|
| title_tap_storm_12  | 38.8    | 14.5      | −63% (2.7x) |
| map_drag_60f        | 54.5    | 9.5       | −83% (5.7x) |
| title_idle_60f      | 3.0     | 3.0       | flat |
| map_idle_60f        | 19.7    | 19.4      | flat (noise) |
| combat storms, reward flip | — | —       | untouched, re-measured flat |

## Title storm: the LayoutBuilder repaint bubble — VERIFIED

The button press animation was already inside a `RepaintBoundary`
(v0.3.12). The storm still repainted the whole screen, and
`debugPrintMarkNeedsLayoutStacks` shows why:

- Any `setState` below a `LayoutBuilder` schedules the LayoutBuilder's
  layout callback (`_LayoutBuilderElement._scheduleRebuild` →
  `scheduleLayoutCallback` → `markNeedsLayout`), Flutter 3.27+ architecture.
- The re-laid-out LayoutBuilder then calls `markNeedsPaint`, which bubbles
  to the nearest ANCESTOR repaint boundary. The title's LayoutBuilder had no
  ancestor boundary short of the route itself, so all ~39 render objects of
  the screen repainted for every frame of an 80ms press animation — the
  button's own boundary was irrelevant to the bubble ABOVE it.

Fix (title_screen.dart): a `RepaintBoundary` above the LayoutBuilder (stops
the bubble at the shell) and one below it around the scroll view (the
contained repaint becomes a recomposite). Two widgets, no layout change.

Rule worth keeping: **a LayoutBuilder with animating descendants needs a
repaint boundary above it**, or every descendant setState repaints the
route. Combat/map/title all sit under LayoutBuilders; combat already had
band boundaries masking this.

## Map drag: the viewport paints its child at the scroll offset — VERIFIED

`SingleChildScrollView` (unlike ListView) inserts no repaint boundary, so
every drag frame repainted every non-boundaried child of the map Stack:
node chrome outside the medallion boundaries, telegraph badges, the delver
marker — 660 RenderRepaintBoundary + 600 gesture/semantics nodes per 60f in
the probe. The parchment/`_MapScenePainter` theory in the remaining-work doc
was NOT it (that layer was already boundaried; probe shows
RenderCustomPaint flat at 180/60f before and after).

Fix (map_screen.dart): one `RepaintBoundary` directly under the scroll view
— a drag is now a layer translation; the pulsing medallions keep painting
inside their own boundaries. Plus a small boundary around the walking
delver marker so its 650ms hop repaints one sprite-sized layer.

## Verification

- VERIFIED: `flutter analyze` clean; 152/152 tests; store-screenshot
  harness byte-identical on all 6 PNGs vs a legacy/dice-builder baseline
  run on the same toolchain.
- VERIFIED: probe run before/after with the identical probe file; combat
  and reward scenarios re-measured and unchanged.
- NOT VERIFIED: on-device frame times (see remaining-work §1 — the
  frame-trace emulator job in PR #70 exists to close exactly this).
