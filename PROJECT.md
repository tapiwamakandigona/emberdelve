# PROJECT.md — Emberdelve

## September 18 — whole-playable-roster follow-up (source PR only)

Owner requested all characters after delivery of #105. Current scoped plan:
`docs/roster-sep18/PROJECT.md` and `features.json`. Build on #105 at `8a54784`,
keep #102/#104/#105 open. Redesign the remaining twenty delvers and extend
native articulation/shared grip/tool-family action to all twenty-two.
Single executor, ten-iteration cap for this new task. No merge/release/Play action.
Previous evidence remains historical; device/purchase gates remain unchanged.

## September 17 visual pass (source PR only)

Current scoped plan and definition of done: `docs/visual-sep17/PROJECT.md`
and `docs/visual-sep17/features.json`. Build on #104's `0df9d51` blood-control
handoff; leave #102/#104 open. Prioritize contact-timed visual health/guard,
then articulated Kindler/Warden bodies and continuous weapon grips.
Single executor, six-iteration cap. No merge, release, version or Play action.
Previous feature criteria and device gates remain unchanged.

## September 13 current open-PR handoff — blood control + critique

Branch `feat/blood-toggle-review-sep13` targets **`legacy/dice-builder`**,
not the frozen platformer on `main`. **Leave this PR open for the next
agent.** This pass adds a saved Blood effects preference and records
candid current ratings: art **6/10**, animation **4/10**, depth **7/10**
(subjective design judgment, not an automated grade or a phone playtest).

Start with `docs/reviews/combat-art-depth-critique-2026-09-13.md`, its
ranked next-agent tasks, and `docs/reviews/blood-toggle-verification-2026-09-13.md`.
Toggle code/analyzer/main suite are verified: **1,387 tests**, original
tests/simulation/assets unchanged. Two existing supplemental tools are
**not green**: the art generator drops authored `hand` metadata from its
output, and the old UI-playthrough harness omits the keystone phase.
Do not erase sockets, disable keystones or weaken assertions to pass them.

Next visual priorities: displayed HP/wounds/guard must agree with impact;
then authored Kindler/Warden body actions with moving grip anchors.
Larger animation, balance and art changes are critique/handoff work,
not implemented in this PR. No merge, version bump, tag, new release,
Play submission or content-rating change in this scope. Blood-off is a
comfort preference, not automatic rating relief. Device/purchase gates
below remain open.

## September 13 verified release resume

`0.183.0+210` ("Bodies in the Fight", PR #103, merge `c611e16`) was built
and signed by CI run 34743081440, published as GitHub release v0.183.0
(Latest), and uploaded to the **Play production track at 100% roll-out**
together with a re-answered IARC questionnaire that declares mild/limited
blood. Both changes were **sent for Google review** on 13 September; managed
publishing is off, so they go live when review passes. At the last check,
210 was **In review** and 208 (0.181.0) **Available on Google Play**.
Do not call 210 live until the production track explicitly marks it available.
Evidence and rating changes: `docs/releases/verification-0.183.0.md`.
Physical-phone FPS/touch review and Play purchase/restore remain open.

## September 8 verified release resume

Candidate `0.182.0+209` was built from `8a9def4`, signed/independently
verified, published as a GitHub prerelease and made available to existing
Play internal testers. Retained internal code12 for legacy Android5–6;
new features require Android7+. Production remains208; do not infer a
rollout from the prerelease or testing publication.
`docs/releases/verification-0.182.0.md` has binary hashes and actual
emulator trace measurements. Trace flows pass, but software raster exceeds
the frame budget; physical low-end FPS/Play purchases remain open.
Managed GitHub App dispatch was denied; owner-authorized supplied PAT
works through documented Actions REST. Never list/expose signing secrets.

**Goal:** A turn-based **dice-builder roguelite** for Android (Google Play), built with Flutter. Mobile-first: portrait, one-thumb, 3–7 minute play units inside 15–30 minute runs. Free download + one-time full-unlock IAP ($3.99–4.99), no forced ads. Quality bar: "fair-addictive" — addictive through quality, never through dark patterns.

**Owner:** memorymadie (Tsoro Studios, Play developer ID 6318480192689304537, GitHub `tapiwamakandigona`). Built by the owner. This repo is designed so **any AI agent can resume the project from these files alone** — read this file, `features.json`, the tail of `progress.md`, then run `init.sh`.

## Canonical artifacts
Active owner-authorized quality pass (2026-09-08):
`docs/quality-sep08.md`. Develop from `legacy/dice-builder`; preserve existing
Forge entitlements and privacy promises. Keepers of the Flame is approved.
Older development freezes do not block this pass; signing, test and Play
verification gates still apply.

Release preparation: candidate `0.182.0+209` (iteration 9); Play production
208 verified September 8. Target source is this quality branch descended
from `legacy/dice-builder`. Release candidate is not production approval.
Current toolchain is Flutter 3.44.9/Dart 3.12.2; older toolchain prose below
is historical. September 8 creative authorization supersedes the earlier
AI-sprite restriction for the explicitly documented original roster update;
`PROVENANCE.md` identifies generated source art, with no human-artist claim.

Current scoped visual PR (2026-09-05): `docs/visual-polish-20260905.md`.
Codex reading/navigation polish only; no release, version, purchase or sim changes.
Verification is public analyzer/full suite/SFX plus real-font before/after plates.

| What | Where |
|---|---|
| Product spec (approved) | `docs/spec.md` |
| Architecture (interfaces frozen) | `docs/architecture.md` |
| Definition of done | `features.json` (machine-readable; workers only flip `passes` + `evidence`) |
| History / decisions | `progress.md` (append-only), `checkpoints/` |
| Dev environment | `init.sh` |

## Standing decisions (do not relitigate without owner)
1. **Engine:** **Flutter/Dart** (stable 3.32.7, Dart ≥3.8.1). *Changed by owner
   2026-07-23 ("remember we making this using flutter") for consistency with
   their other apps (lanlink, quick bucks). Supersedes the original Defold
   decision.* The sim core is a **sealed pure-Dart library** under `lib/sim/`
   (no Flutter imports) so it stays deterministic and headless-testable — same
   seam discipline as before. CI: `flutter analyze` + `flutter test` → `flutter
   build apk`. The Defold-era Lua core was ported to Dart with proven 1:1 hash
   parity (commit history), so the deterministic guarantees carry over.
2. **Repo:** public (all shipped assets are CC0/CC-BY with attribution shipped in-app — see PROVENANCE.md; no license forbids redistribution). Releases are public on GitHub Releases.
3. **Architecture:** sealed pure-Dart simulation core (`lib/sim/`) — commands in, events out, zero Flutter APIs inside. Flutter presentation renders events only. Never violate this seam. The Lua/Defold descriptions in old milestone evidence are historical.
4. **Determinism:** all simulation randomness via the existing per-domain seeded streams. Same seed + same commands ⇒ identical event/state hashes. Existing Dart golden/parity checks stay unchanged.
5. **Mechanic:** dice-builder combat (roll dice pool → assign dice to actions; grow/upgrade dice across the run). Enemy intent always visible; randomness in *offerings*, never in *resolution*.
6. **Monetization:** free + one-time unlock IAP. **Banned:** energy timers, decaying streaks, rigged near-misses, FOMO-expiring content, loss-framed notifications (see `docs/spec.md` §Ethics).
7. **Art direction (M2+):** dark high-contrast cartoony pixel-painterly, 48–64px sprites, portrait. No AI-generated animated sprites. Paid packs need owner budget approval BEFORE purchase.
8. **Audio (M2+):** real recorded SFX only (Sonniss GDC bundles / Leohpaz / Kenney CC0). No AI audio. Licensed (non-CC0) assets must never enter a public repo.
9. **Milestones:** M0 skeleton → M1 prototype (full seeded run) → M2 vertical slice → M3 content → M4 release. One milestone per work session; gate via `features.json` + checkpoint.

## Play publishing status (updated 2026-08-10)
- **PRODUCTION ACCESS GRANTED 2026-08-09** (Play Console email): the 12-tester/14-day gate is permanently cleared for this app. Store: https://play.google.com/store/apps/details?id=com.tsorostudios.emberdelve · opt-in: https://play.google.com/apps/testing/com.tsorostudios.emberdelve · tester group: emberdelve@googlegroups.com.
- Play tracks still carry old builds (internal 12/v0.3.9, alpha 19/v0.3.14); testers are 6 releases behind. **Target-API deadline 2026-08-31** is against the old v0.3.9 build — uploading any current AAB (targetSdk 36) clears it.
- The tutorial promised to testers shipped in v0.3.9+ (first-fight overlay, F11). No open public commitments.
- **Monetization (v0.4.0): the Ember Forge** — free forever: full easy/normal runs, all delvers, Daily Delve; one-time IAP `ember_forge_unlock` ($4.99) opens HARD + Ascension + future acts. See progress.md 2026-08-10 and features.json M4-2 (device evidence pending).
- Details + verified Play mechanics: `docs/release.md` §"Google Play closed testing" and the tail of `progress.md`.

## Session-start ritual (for any AI/human resuming)
1. Read this file, `features.json`, tail of `progress.md`, latest `checkpoints/*.md`.
2. `git log --oneline -20` for recent history.
3. `./init.sh` to bring the environment up and run the test suite.
4. Work the next unfinished feature; update `features.json` (evidence required) and append to `progress.md`.

## Research provenance
Decisions above come from a 5-track research run (market, core-build, art, audio, psychology), 2026-07-23, synthesized in the owner's records. Key conclusions are embedded in `docs/spec.md` and `docs/architecture.md`; trust these files over memory.
