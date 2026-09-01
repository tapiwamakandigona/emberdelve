# Renderer watch — the Skia pin's exit criteria

Written 2026-09-01. THE STEADY RENDERER (AndroidManifest, 2026-09-01)
pins the engine to Skia via `EnableImpeller=false`. The pin's own
comment says "remove once Impeller GLES is clean on low-end" — this
doc is the tracker: what was verified, what would end the pin, and
what to re-check on every Flutter upgrade.

## Verified state on Flutter 3.44.9 (shipped engine, primary source)

**The pin is LIVE — verified in the engine source of our own Flutter
checkout, not from blog posts:**

- Java embedding: `FlutterEngineFlags.java` defines
  `ENABLE_IMPELLER = new Flag("--enable-impeller=", "EnableImpeller", true)`
  — javadoc: "Allowed in release to control which rendering backend is
  used in production. Settable via the command line and manifest."
  Engine test `FlutterLoaderTest.itSetsEnableImpellerFromMetadata`
  covers metadata `false` → `--enable-impeller=false`.
- C++ (`flutter_main.cc`): `enable_impeller == false` →
  `SelectedRenderingAPI` returns `kSkiaOpenGLES`; the switch then
  keeps `settings.enable_impeller = false`. No API-level carve-out —
  the opt-out applies on Android 10+ too.

**Circulating claim, checked and FALSE for our build:** a June-2026
Medium post ("Flutter Just Removed Skia from Every Modern Android
Device") says the opt-out was deprecated in 3.41 and *removed* in
3.44, silently ignored on Android 10+. The 3.44.9 source above
disproves the "removed/ignored" part. What IS true: 3.44.9 sets
`settings.warn_on_impeller_opt_out = true` (a startup log warning,
flutter/flutter PR #173375), and upstream states the opt-out "will go
away in an upcoming release" (issue #181441 pushback thread). Treat
the removal as coming, not arrived. [engine source + web, 2026-09-01]

## Why the pin exists (unchanged evidence)

- Adreno 506: Impeller GLES ~28–31fps vs Skia ~54–55, jank in build
  phase (flutter/flutter #187009, reproduced on 3.44.0).
- Skia rasters ~1.6× faster than Impeller GLES across 250→4000 layers;
  at 1000 layers Impeller hitches 95–145ms vs Skia ≤50ms (#191979).
- Impeller GLES ImageDecoder SIGABRT on Android 10 Mali persists on
  3.44.8 (#190640) — this game decodes sprite PNGs; the 28-day
  zero-crash record is a DEMAND pillar.
- Impeller GLES also pays a cold-start cost vs Vulkan (engine init,
  #190618) and first-use LinkProgram stalls on 32-bit low-end
  (#173955) — both hit exactly this game's market (older Adreno/Mali).
- Vulkan is denylisted on Adreno ≤650, so "Impeller" on our audience
  MEANS Impeller GLES — the weak backend, not the good one.

## Exit criteria — the pin comes OFF when ALL of these hold

1. #187009 (Adreno 5xx regression) closed as fixed, or an equivalent
   benchmark shows Impeller GLES within ~15% of Skia on Adreno 5xx.
2. #190640 (Mali ImageDecoder SIGABRT) closed as fixed.
3. Our own probe: a profile build on a GLES-only device (or the
   slowest available emulator config) holds 60fps through title →
   map → combat with no first-use hitches. No device in sandbox —
   this step needs the owner or a cloud device farm; do not skip it
   on upstream's word alone.

## Forced-exit scenario — opt-out removed before GLES is fixed

If a future Flutter release drops the opt-out while low-end GLES is
still slow, DO NOT blind-upgrade. Options in preference order:
1. Hold the last Flutter version where the pin works (record it here),
   ship security-critical fixes from that pin, and wait out the GLES
   fixes.
2. If holding becomes untenable (Play target-SDK deadline forces a
   Flutter bump), re-benchmark Impeller GLES at that point — years of
   upstream work may have landed by then; the 2026 numbers must not be
   assumed eternal.
Never trade the zero-crash record for an engine upgrade.

## Upgrade checklist (run on EVERY Flutter version bump)

1. `grep -rn "EnableImpeller" engine/src/flutter/shell/platform/android/io/flutter/embedding/engine/FlutterEngineFlags.java`
   in the NEW checkout — confirm the flag still exists and is
   release-allowed. If gone → forced-exit scenario above.
2. `grep -n "kSkiaOpenGLES" engine/src/flutter/shell/platform/android/flutter_main.cc`
   — confirm the enable_impeller=false → Skia path survives.
3. Re-read #187009, #190640, #191979 status.
4. Note findings here with a dated line; never edit old lines.

## Side-findings worth keeping

- ShaderWarmUp only matters BECAUSE of the Skia pin (Impeller
  precompiles pipelines at build time). If the pin ever comes off,
  EmberShaderWarmUp becomes inert on Impeller devices but harmless —
  keep it for the pre-API-29 fallback population either way.
- Flutter latest stable is 3.47.x [flutter.dev, 2026-09-01]; we ship
  3.44.9. No upgrade urgency: 3.44 is in the supported window and the
  pin is verified working there. An upgrade re-runs the checklist
  above first.
