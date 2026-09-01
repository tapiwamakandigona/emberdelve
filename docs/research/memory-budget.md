# Emberdelve decoded-bitmap budget — Play 2027 memory thresholds

2026-09-01 · Response to DEMAND drop 2026-09-01c (owner-inbox-evidence.md).
Google's numeric thresholds are UNPUBLISHED — nothing here claims compliance.
This is the closest aggregate-only proxy available without a device: a static
worst-case decoded-bitmap budget computed from the shipped asset set (PNG
width × height × 4 bytes), plus the two decode-hint fixes it exposed.

## The budget (all 115 bundled PNGs, computed from source 2026-09-01)

| Asset class | Count | Worst-case decoded |
|---|---|---|
| Backgrounds 1080×1920 (title/map/combat/boss) | 4 | 7.91 MB **each**, 31.6 MB all |
| Boss art 384×216 | 8 | 0.32 MB each |
| Event icons 256×256 | 10 | 0.25 MB each |
| Characters/sprites/UI (≤192×252) | 93 | ≤0.18 MB each |
| **Total, every PNG resident at once** | 115 | **48.4 MB** |

(assets/icon/app_icon_master_1024.png is a build-time launcher-icon source —
NOT in pubspec assets, never shipped or decoded at runtime.)

The realistic steady state is one background + the current screen's small
images: **~8–9 MB of bitmaps** — but Flutter's global image cache keeps every
*visited* background resident, so a full session climbed toward the 31.6 MB
background total, at full 1080×1920 decode even on a 720-wide phone.

## Fixes shipped (both with regression tests, test/background_decode_test.dart)

1. **ScreenBackground now decodes at the device's physical width**
   (`cacheWidth = min(physical width, 1080)`, lib/ui/art.dart). A 720p
   low-end phone — exactly our audience — now pays ~3.5 MB per background
   instead of 7.9 MB; all four visited: ~14 MB instead of 31.6 MB. Flagships
   at ≥1080 px are unchanged. BoxFit.cover semantics identical.
2. **Character-screen vista swatch** drew 34×42 dp by decoding the full
   1080×1920 map background (~7.9 MB). Now `cacheWidth: 144` (~0.1 MB).

Suite 1138 green, analyze clean. No release (freeze); rides in the branch.

## What stays unknown (honestly)

- Google's numeric thresholds per RAM bucket (games column) — unpublished.
  Re-check the Android Developers Blog technical guide when it lands.
- Actual anonymous RSS + swap — needs a physical device (`dumpsys meminfo`)
  or Play vitals field data; Emberdelve's vitals show "Limited data" at
  38 installs. Recorded as unanswerable-for-now per the R2 rule.
- Dart-heap/engine overhead is not bitmaps and is not estimated here.

## Pointers

- Device-migration item: emberdelve_meta.json already rides in cloud backup
  AND device transfer (settled earlier); games are currently exempt from the
  Zero-Tap Sign-In rule per pyregrove's checklist (blog verbatim), and we
  have no sign-in at all.
- DEX/R8: emberdelve has isMinifyEnabled + isShrinkResources since 8f756dd8.
- Cross-repo: pyregrove/docs/PLAY-QUALITY-2027.md is the evidence-graded
  master checklist; this file is the emberdelve memory-side companion.
