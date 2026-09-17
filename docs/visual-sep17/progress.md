# Visual pass — append-only progress

## 2026-09-17 — baseline and scope

- VERIFIED canonical harness cloned on main at v3.0.1; HARNESS.md and
  templates read. Templates copied, then adapted; loop.sh retained verbatim
  as reference only, never executed to spawn an agent.
- VERIFIED fresh repository clone and all remote branch refs inspected.
  Root main is frozen platformer; active dice work is legacy/dice-builder.
  Read open #102/#104 critiques, merged #103/#101/#99 and older combat work.
- VERIFIED working branch feat/combat-visuals-sep17 is based on #104 head
  0df9d51. Preserve its blood comfort control and leave old PRs open.
- VERIFIED PAT authenticated as expected account and browser login completed
  through user-approved GitHub Mobile. No credentials stored in this repo.
- Environment failure, quoted: `HTTP Error 404: Not Found` for the official
  Flutter release manifest/archive. One retry returned 404. Mirror returned
  403; no further mirror attempts. Canonical Flutter source tag 3.44.9
  cloned instead; engine bootstrap succeeds, Dart 3.12.2 verified.
- ASSUMED design direction: fix contact causality before spectacle, then
  authored cut/maul body action with shared grip. Actual render baseline
  and new tests are still pending; no visual quality/completion claim.

- Bookkeeping patch failure, quoted: `Error reading /work/todo.md: cat:
  /work/todo.md: No such file or directory`. Prior hunks verified present;
  task checklist recreated once without reapplying those hunks.

## Iteration 1/6 — contact timeline, baseline and red regressions

- VERIFIED unchanged #104 source: analyzer clean, 1387/1387 tests pass,
  SFX reachable cascades pass (existing full-attack -0.90 dBTP TIGHT).
  Initial foreground init was killed by the 200000ms shell deadline;
  single retry as a tracked background job completed successfully.
- VERIFIED additive contact tests reproduce early displayed HP in all four
  delvers: `Expected: <19>` / `Actual: <14>` at 100ms, before 340ms contact.
  No source or original-test edits yet.
- New fixture defect: incoming/burn/fast-forward cases attempted End turn
  before rolling. Exact failure: `The finder "Found 0 widgets with widget
  matching predicate: []" (used in a call to "tap()") could not find any
  matching widgets.` This is test setup, not a game bug. Asked permission
  to add only the missing Roll step; all assertions remain read-only.
  App question action `emberdelve_contact_fixture_setup`; awaiting answer.
- Baseline actual-render job started for Kindler and Warden before source
  edits. Its completion/output must be checked before claiming new captures.

- Owner authorized changes ("you can change anything you want"). Corrected
  only the missing Roll fixture step in incoming, burn and fast-forward
  scenarios; assertions and all original tests unchanged.
- VERIFIED baseline actual-render captures complete: Kindler + Warden,
  175 samples each at 40ms simulated intervals; each capture test passes.
  Original source manifest matches. These are not measured phone FPS.

- VERIFIED corrected fixtures: all 12 new cases reproduce the product
  defects on #104, then pass after contact ledger wiring. Original checks
  remain untouched. Analyzer clean; complete suite 1399/1399.
- Implemented copied presentation fields, advanced from sim event payloads
  at player/enemy impact, riposte and burn. Live sim/input remain immediate.
  Full guard remains through impact; unused block expires at recovery.
  Terminal corpse retains event HP zero while the old route is held.
- Source `lib/sim/`, dependencies, original tests, workflows, art and version
  hashes unchanged. No physical device/performance claim.
- Bookkeeping patch partially applied before a root-log context mismatch:
  `Failed to find expected lines`. Verified scoped hunks present; retry
  appends the new root section against the actual file tail only.
