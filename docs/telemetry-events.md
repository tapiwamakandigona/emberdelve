# Telemetry events — schema of record (v0.3.9, phase 1)

Every analytics call goes through `TelemetryService.logEvent` and is a
**no-op** unless BOTH are true:

1. Firebase is configured (`android/app/google-services.json` present at
   build time so `Firebase.initializeApp()` succeeds), and
2. the player tapped **Allow** on the first-launch disclosure dialog (or
   turned "Gameplay analytics" on in Settings).

Crash reports (Crashlytics) are separate: on by default under legitimate
interest, opt-out via Settings → "Crash reports".

Rules: event and param names are `snake_case`; **no PII ever** (no names,
emails, IDs, free text). Run seeds are shared-content identifiers, not user
identifiers, but are still not logged. Add new events to this table first.

## Events

| Event | When it fires | Params | Notes |
|---|---|---|---|
| `app_open` | Every app start, after `controller.boot()` (`lib/main.dart`) | — | Complements FA's automatic `session_start`; ours is consent-gated like everything else. |
| `run_started` | `GameController.startRun` — every new run incl. daily and "delve again" | `character` (id), `difficulty` (easy/normal/hard), `ascension` (int), `daily` (0/1) | |
| `run_ended` | `GameController._bankRun` (won/lost) and `abandonRun` | `outcome` (won/lost/abandoned), `floor` (int, 1-based layer reached), `floors` (int, map depth), `character`, `difficulty`, `ascension`, `daily` (0/1), `embers` (int; omitted on abandon) | The funnel core: outcome + depth per run. |
| `die_forged` | `GameController.apply` sees a sim `forged` event (rest-site forge) | `floor` (int) | The dice-builder's central crafting ("die crafted") action. |
| `settings_changed` | Settings screen — any control changed | `setting` (music_volume, music_muted, sfx_volume, sfx_muted, haptics, analytics_consent, crash_reports), `value` (stringified) | Volume logged once per slider release, 2-dp string. `analytics_consent: false` / `crash_reports` flips may not arrive (collection turns off). |

## Consent & persistence

- Prefs (shared_preferences): `telemetry_analytics_consent` (bool; absent =
  never asked → dialog shows), `telemetry_crashlytics_enabled` (bool,
  default true).
- Manifest: `firebase_analytics_collection_enabled=false` (collection only
  enabled at runtime post-consent),
  `google_analytics_default_allow_ad_personalization_signals=false`, and
  `AD_ID` permission force-removed (`tools:node="remove"`).

## Phase 2/3 (not in this build)

- Phase 2: verify events/crashes in console, update Play Data safety form +
  privacy policy, promote to closed testing (pre-launch reports).
- Phase 3: PostHog (`posthog_flutter`) with mobile session replay, manual
  init AFTER the same consent gate; mirror `run_*` events there.
