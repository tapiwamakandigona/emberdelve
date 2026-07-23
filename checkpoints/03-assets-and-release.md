# Checkpoint 03 — Curated assets, animations, audio, v0.2.0 release (2026-07-23)

## What shipped
- Full art/audio/animation integration (branch `assets-integration`, merged
  `01bc2f4` into main): 75 asset PNGs + 26 audio files, all CC0/CC-BY/OFL,
  provenance in PROVENANCE.md + CREDITS.md (also bundled in-app).
- SpriteView (sprite_meta.json-driven idle loops @8fps), combat choreography
  (lunge + whoosh 250ms pre-contact, hit-flash, death fade-collapse), per-screen
  music with crossfade, 20 SFX synced to animation contact frames
  (SYNC_POINTS.md), settings persistence, credits screen, launcher icons.
- Review pass (independent reviewer): APPROVE-WITH-NITS, 0 blocking. All 4
  should-fix findings fixed in a51dc69 (audio fade timer race, sprite
  controller leak, settings save-on-drag, missing PROVENANCE.md).
- **Release v0.2.0 published**: tag `v0.2.0`, GitHub release with
  `emberdelve-v0.2.0.apk` (release build, debug-key signed).
- CI on main: runs 30011499453 + 30011501605 both fully green.
- Tests: 29 green (incl. new `test/decode_probe_test.dart` which decodes every
  bundled PNG with the real engine codec — guards against corrupt assets).
- All asset PNGs re-encoded with canonical libpng encoding (PIL optimize) —
  original curated files came from a non-standard encoder; both encodings are
  valid, canonical is smaller and maximally compatible.

## Emulator live test (headless AVD, API 33, swiftshader, -no-audio)
VERIFIED working: app installs/launches (release + debug), title → character
select → map → event (Broken Cart, +12 gold applied, node marked visited) →
fight (Soot Shade: HP bars, dice roll 1/6/6, dice selection, Attack/Block,
End turn). Full game flow and sim wiring work on Android. Evidence screenshots
in orchestrator run dir (emulator-evidence/).

KNOWN EMULATOR-ONLY ARTIFACT (not an app bug — do not "fix" in app code):
Flutter's in-engine image decode fails on this headless swiftshader AVD
("Could not decompress image" under Impeller / "Codec failed to produce an
image" under Skia). Proven environmental:
1. all 75 PNGs pass strict chunk/CRC validation;
2. `flutter test` decodes all 75 with the engine codec on host;
3. an on-device `app_process` probe decoded the same file fine via Android's
   own BitmapFactory AND ImageDecoder (hardware + software allocators);
4. re-encoding all PNGs canonically changed nothing;
5. failure identical on both render backends → shared cause is the emulator's
   software-GPU/AHB path used by Flutter's decoder, absent host GPU/KVM.
Audio `paused/idle` states in dumpsys are likewise explained: AVD runs with
`-no-audio`. Real-device confirmation of images+audio is OWNER-GATED.

## Next
- Owner: real-device install of v0.2.0 APK (confirm art + audio), then IAP,
  GPGS, Play upload decisions.
