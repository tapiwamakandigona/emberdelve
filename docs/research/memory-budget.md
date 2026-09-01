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

## Re-check 2026-09-01 — the technical guide landed (partially)

- **Published**: developer.android.com/topic/performance/vitals/memory-usage
  — defines the metric (anonymous RSS + swap = heap + native allocations
  incl. bitmap pixel data + thread stacks; unevictable footprint), vitals
  breakdown by process state (foreground / user-perceived services /
  background / cached) and by RAM bucket, percentile timelines. The ONE
  number in it: **P90/P50 ratio > 3.5× by process name = likely memory
  leak** during extended sessions. **Numeric bad-behavior thresholds are
  STILL not published** — the games column remains unknown. [android-dev,
  2026-09-01]
- **Not yet published**: the bitmap-memory vitals page
  (…/vitals/bitmap-memory-usage is a soft 404). Re-check later.
- **New blog** "Preparing your app for broader memory limits"
  (android-developers.googleblog.com/2026/08/app-broader-memory-limits.html):
  over the coming year more OEMs adopt Android per-app memory limits across
  4 GB–16 GB+ devices; exceeding them = throttled or terminated. AOSP
  Memory Limiter doc (source.android.com/docs/core/perf/memory-limiter):
  visible processes capped at 1/2–2/3 of total RAM, not-visible at 1/4–1/3,
  OEM-tunable. [aosp, 2026-09-01]
- **Reading for Emberdelve**: the OS limiter is not our risk — even the
  pre-fix worst case (~50 MB bitmaps + Dart heap) is two orders of
  magnitude under a 4 GB device's not-visible cap (~1 GB). The live
  exposure is the unpublished vitals percentile thresholds and the
  P90/P50 leak ratio, both checkable only once Play vitals has data
  (currently "Limited data" at 38 installs). Action stands: keep decoded
  bitmaps proportional to the device (done), re-check for the games
  thresholds and the bitmap page on the next research pass.

## DEX optimization measurement — shipped v0.178.0 (2026-09-01)

Play's Feb-2027 quality bar requires "a minimum of 25% coverage across
optimization, shrinking, and obfuscation using a tool such as R8."
Measured on the shipped release asset (same androguard method the
pyregrove checklist used):

- Artifact: `emberdelve-v0.178.0-arm64-v8a.apk` (GitHub release
  v0.178.0, the tagged Play candidate).
- `classes.dex` + `classes2.dex`: **3,537 classes, 2,640 (74.6%)
  carry R8-obfuscated short names** (final segment ≤2 chars).
- Verdict: **VERIFIED-MET** — 74.6% ≫ 25%. The unobfuscated remainder
  is keep-rule-protected API surface (Play Billing listener
  interfaces, gson internals, androidx) — expected and correct;
  obfuscating those would break reflection/JNI contracts.
- Config: `isMinifyEnabled` + `isShrinkResources` since 8f756dd8;
  this measurement closes the gap between "config says on" and
  "shipped bytes show it".

[androguard census, 2026-09-01]
