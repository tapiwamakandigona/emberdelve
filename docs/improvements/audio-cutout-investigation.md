# Audio cutout investigation (2026-07-24)

Report (owner, real device): tapping the settings gear or switching difficulty
on the title screen kills the background music; assorted other "audio randomly
cuts out" moments.

## Root cause — Android audio focus fights between our own players

`audioplayers` (6.6.0 / android 5.2.1) defaults every player's
`AudioContextAndroid` to `audioFocus: AUDIOFOCUS_GAIN`. Verified in the plugin
source (`AudioContextAndroid.kt`, `FocusManager.kt`, `WrappedPlayer.kt`):

1. Every `play()` calls `FocusManager.maybeRequestAudioFocus()`, which files a
   full exclusive-focus request with Android's `AudioManager`.
2. Each `AudioPlayer` is its **own** focus client — the OS doesn't care that
   they belong to the same app. When an SFX one-shot requests `GAIN`, every
   other holder (our music loop, the ember-ambience bed, other still-playing
   SFX) receives **permanent** `AUDIOFOCUS_LOSS`.
3. `WrappedPlayer.onLoss(isTransient: false)` answers with a full `pause()`
   that sets `playing = false` — so even when focus later returns
   (`onGranted` only restarts if `playing`), **the music never resumes**.

Both reported repros play `ui_tap` through the SFX pool while the title music
loops: the settings gear (`TitleScreen`), the difficulty selector
(`_DifficultySelector`). So does every `EmberButton` — which explains the
"other audio problems": any tap, dice roll, or coin SFX could knock out music,
ambience, or an overlapping SFX, with timing/races deciding which player lost
the coin flip. Bonus defect: every sound also silenced other apps' audio
(Spotify etc.) — a Play-review irritant.

## Fix (PR: fix/audio-focus-cutouts)

- `AudioService.initPlatformAudio()` — called in `main()` **before any player
  exists** — sets the global audio context to
  `AudioContextConfig(focus: mixWithOthers)`:
  - Android: `AUDIOFOCUS_NONE` → nobody requests focus, all our players mix
    freely, other apps' audio untouched.
  - iOS: `playback` category + `mixWithOthers` option.
  - Backgrounding (Home/lock/call) is already handled explicitly by the
    app-lifecycle observer (`pauseAll`/`resumeAll`, v0.3.1 F3), so we lose
    nothing by opting out of focus. Trade-off accepted: game audio no longer
    pauses the user's own music app — normal for mobile games; the music
    mute toggle covers whoever minds.

- Silent-phase latch fix in `playMusic`: `_musicKey` was assigned before the
  try block, so a failed start (focus denied, decoder hiccup) poisoned the
  dedupe key — `syncPhase` would early-return on `key == _musicKey` and the
  whole screen family (title/map/combat) stayed silent until the key changed
  twice. Now a failed start resets `_music`/`_musicKey` (guarded so a newer
  `playMusic` call isn't clobbered) and disposes the dead player. Same latch
  fix applied to the ambience slot in `setAmbience`.

## Audited and judged fine (for the record)

- SFX pool round-robin (6 players): a 7th overlapping SFX legitimately steals
  the oldest player. Cosmetic at worst; combat choreography rarely exceeds it.
- `pauseAll` on `AppLifecycleState.inactive`: also fires for transient
  occlusions (permission dialogs, app-switcher peek) — music correctly
  resumes on `resumed`. In split-screen the app can sit `inactive` while
  visible (music stays paused); acceptable, revisit only if players complain.
- Victory/defeat stings (`ReleaseMode.release`): resume-after-release is a
  caught no-op; phase always changes before the same key is needed again.
- Fade-out timer per superseded music player: one timer per player, cannot
  orphan a fading loop.

## Verification

- `flutter analyze` clean; full test suite green; `dart run bin/autoplay.dart
  200` → 74.0% win, 0 invalids, golden 1117081416 self-consistent (no
  `lib/sim/` change, no SIM_VERSION bump needed).
- True end-to-end confirmation needs the real device (audio focus does not
  exist in widget tests): title screen → tap settings gear → music must keep
  playing; switch difficulty → same; spam dice rolls in combat → music holds.
