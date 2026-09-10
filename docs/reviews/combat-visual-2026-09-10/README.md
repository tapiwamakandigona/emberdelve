# Combat review evidence

Read the [critique](../combat-visual-critique-2026-09-10.md) first.

**VERIFIED method:** real released Flutter widgets, fonts, sprite sheets and
weapon painters, not replacement artwork. Fixture setup is explicit in the
additive harness; Roll/die/Attack/End turn taps hit the actual UI.
**Not** a native Android combat recording or a physical performance measurement.

## Reproduce

Use the repository's pinned Flutter `3.44.9` / Dart `3.12.2`.
Set `FLUTTER_ROOT` to that installation so the harness can load its actual
MaterialIcons font. Run from the checkout root:

```sh
flutter pub get
flutter analyze
flutter test
flutter test --reporter expanded tool/combat_review_frames_test.dart
```

The last command produces four `140`-frame sequences and runtime observations
under the ignored `build/combat_review_frames` directory. It does not edit
application source, assets or existing tests.

To encode one captured sequence without synthesizing or interpolating frames:

```sh
ffmpeg -framerate 25 \
  -i build/combat_review_frames/kindler/frame-%04d.png \
  -c:v libx264 -crf 16 -pix_fmt yuv420p -movflags +faststart kindler.mp4
```

Repeat for Warden, Gambler and Runesmith. The published combined recording
concatenates those clips in that order. There is no audio track. The same
capture logic passed again after formatting; the published video is the
previously inspected recording, while selected stills and rerender hashes
come from the final run.

## Integrity

- `verification.json`: source identity, preservation counts, test results,
  failed native attempt URLs, scope and limitations.
- `SHA256.json`: SHA-256 of the published evidence and final capture tool.
- `original-files.sha256.json`: every original tracked file except the three
  intentional state-file edits; compared byte-for-byte against the review base.
- `original-features.sha256.json`: original feature-object hashes, using
  Python `json.dumps(feature, sort_keys=True, separators=(",", ":")).encode()`.
  Every original feature object remains equal to its base object.
- `observations.json`: actual selected/attacking weapon charge and enemy HP.
- `timelines.json`: sampled phases; these are simulated timestamps.
- `rerender-frame-hashes.json`: final rerun's raw PNG hashes, not encoded-video
  frame hashes. Raw sequences can be regenerated locally.
- `analyze.log`, `original-suite.log`, `render-cases.log`: successful checks.
  Only local checkout-path prefixes are replaced by `.` in public copies.
  The manifest also stores unredacted log digests.

No baseline check was relaxed. Existing phone, purchase and quality gates are
still open. The temporary native-capture workflow is absent from the final
diff; the two failed runs are failures, not combat evidence.
