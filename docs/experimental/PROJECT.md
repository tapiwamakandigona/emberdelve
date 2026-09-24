# Experimental polish loop — scoped plan (started 2026-09-24)

**Owner ask (Viktor app, 2026-09-24):** work on Emberdelve's visuals and animations
"until they're perfect", with a super-strict critic, and keep iterating: build →
commit → push → GitHub release → critic → iterate. Scope grows to whatever the critic
finds: animation/game feel, art, audio, gameplay and loop, menus that fit every
screen, onboarding a young child can follow. "Open it up as an experimental build
until I order otherwise."

## Branch and base
- Work branch: `experimental/polish-loop` (never push to `main`, `legacy/dice-builder`,
  `release/*` or another agent's `feat/*` branch).
- Base: PR #108 head `ac387e6` (living foes + clean cut, on `legacy/dice-builder` 741b439)
  merged with `release/production-sep19` (0.184.0+211 packaging) → `b5b6bfe`.
- Integrate newer upstream work by merging `origin/legacy/dice-builder` (and any newer
  PR head the owner names) into this branch; never rebase published history.

## Standing decisions for this loop
1. **Experimental only.** GitHub releases from this branch are **pre-releases with
   `latest=false`**. `lib/meta/update_service.dart` polls `/releases/latest`, which
   ignores pre-releases — so real sideload players are never prompted. Never create a
   non-prerelease from this branch. No Play, itch.io or store action of any kind.
2. **Versioning:** `0.185.0-exp.N+<211+N>` in pubspec, `currentAppVersion` and a
   news entry (test/news_test.dart pins all three). Tag `v0.185.0-exp.N`. Before any
   production release the release owner replaces the exp news entries.
3. **Signed builds** come only from CI `workflow_dispatch` on this branch (permanent
   upload key, cert check in CI). Verify the downloaded APK cert SHA-256 before
   attaching. Never touch signing config or `EXPECTED_CERT_SHA256`.
4. **Project rules still bind** (root `PROJECT.md`): sealed `lib/sim`, determinism
   hashes, §Ethics bans, CC0/CC-BY-or-original assets with `PROVENANCE.md`/`CREDITS.md`,
   no AI audio, no paid packs without owner budget approval.
5. **Checks:** `flutter analyze` clean + full `flutter test` green (CI) + art/SFX tools.
   Never weaken or delete an existing assertion; a test/harness diff is only allowed
   when the task IS that check, and is called out in the commit and progress entry.
6. **Critic:** independent read-only reviewer (`emberdelve-critic`, Ultra preset) — an
   owner-requested exception to the harness's no-subagent rule. It never writes code;
   the maker verifies every critic claim against the images before acting.

## Iteration protocol (one backlog item per iteration)
1. Read this file, `backlog.json`, the tail of root `progress.md`, latest `critic/round-*.md`.
2. Pick the highest-ranked open item (P0 → P1 → …; ties: smallest effort).
3. Implement with a test (red before, green after) where behaviour is testable.
4. Gates: analyze, targeted tests, before/after render plates.
5. Commit + push; bump version; dispatch signed CI; verify cert; publish pre-release.
6. Capture the evidence pack; run the critic; merge its JSON into `backlog.json`;
   save `critic/round-NN.md`; append root `progress.md`.

## Guards
- Stall: two consecutive iterations with no diff → stop the loop and report.
- Failure: one retry with the failure quoted verbatim, then descope/escalate.
- Hard cap: 30 iterations, then pause for owner review. Credit floor enforced by the
  scheduler condition script.
- Owner can stop, pause or redirect at any time; owner instructions override this file.
