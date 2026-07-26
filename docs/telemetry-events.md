# Telemetry events — schema of record (v2 platformer)

Every analytics call goes through `TelemetryService.logEvent`
(`lib/telemetry/telemetry_service.dart`) and is a **no-op** unless BOTH are
true:

1. Firebase is configured (`android/app/google-services.json` present at
   build time so `Firebase.initializeApp()` succeeds — Firebase project
   "Emberdelve", `gen-lang-client-0980262477`), and
2. the player tapped **Allow** on the first-launch disclosure dialog
   (`lib/telemetry/consent_dialog.dart`) or turned "Gameplay analytics" on
   in Settings. **Opt-in only; undecided = OFF.**

Rules: event and param names are `snake_case`; **no PII ever** (no names,
emails, IDs, free text). Daily-seed values are not logged. Add new events to
this table first.

## Events

| Event | When it fires | Params | Notes |
|---|---|---|---|
| `app_open` | Every app start, after `initTelemetry()` (`lib/main.dart`) | — | Complements FA's automatic `session_start`; ours is consent-gated like everything else. |
| `run_started` | `GameController.startRun` — every run incl. Daily Delve | `character`, `ascension`, `difficulty`, `daily` (true/false) | |
| `run_ended` | `GameController._bankRun` (won/lost) or `abandonRun` (abandoned) | `result` (won/lost/abandoned), `character`, `floor`, `embers` | The funnel core: outcome + progress per run. |
| `settings_changed` | Settings screen — analytics toggle | `setting` (analytics_consent), `value` (stringified) | An `analytics_consent: true` flip may not arrive (collection was off when logged); `false` flips do. |

## Consent & persistence

- Prefs (shared_preferences): `telemetry_analytics_consent` (bool; absent =
  never asked → dialog shows).
- Manifest: `firebase_analytics_collection_enabled=false` (collection only
  enabled at runtime post-consent),
  `google_analytics_default_allow_ad_personalization_signals=false`, and
  `AD_ID` permission force-removed (`tools:node="remove"`).
- `INTERNET` / `ACCESS_NETWORK_STATE` permissions exist solely for this;
  the privacy policy (docs/store/privacy-policy.md) documents it.

## Not in this build (future phases)

- Crashlytics (crash reports) — PR #27 has a reference implementation
  (legitimate-interest opt-out model) if wanted later.
- PostHog session replay — same consent gate, manual init after opt-in.
- Play Data safety form must be updated before the next Play release
  (Analytics = optional, user-controlled, not shared, not ads-related).
