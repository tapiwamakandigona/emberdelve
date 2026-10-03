# progress.md — 0.186.0 release (append-only)

## 2026-10-03 — iteration 1: audit + packaging

- Authority: the October pass plan (`PLAN.md` §1 and §5) and my decisions
  of 2026-10-03. Merging reviewed PRs and cutting GitHub releases is a go
  (01:38 UTC). Play production is authorised at 100 % (02:12 UTC). At
  05:56 UTC: "go ahead with everything".
- VERIFIED GitHub state before packaging (API, 2026-10-03 09:37 UTC):
  - Latest stable is v0.185.0 "Living Foes": tag → `c08a0d5`, prerelease
    false, published 2026-09-27.
  - None of the 224 releases mentions 0.186 or versionCode 219 in its tag,
    name or body.
  - No `v0.186*` tag exists on origin.
- VERIFIED lane head `c90c520` (merge of #125). CI 37113171978 (analyze +
  test) and ios 37113171986 both succeeded on that push.
  - Every PR head from #112 to #125 had analyze+test green before it merged.
  - Every code PR also had iOS green. #120 is docs only and ran
    analyze+test.
  - Checked via the check-runs API per head SHA.
- VERIFIED scope audit with `git diff c08a0d5 c90c520`:
  - `c08a0d5` is an ancestor of the lane.
  - These paths are unchanged: lib/sim, lib/meta (store and entitlement
    code), lib/game, android, ios, .github, assets, pubspec.yaml and
    pubspec.lock.
  - lib changes are 14 files in lib/ui, plus lib/l10n/catalog.dart (one
    tutorial card) and lib/main.dart (edge-to-edge).
  - test/ numstat is 15 files, +2578 −15:
    - 12 new files.
    - test/victory_beat_test.dart gains lines only.
    - test/readout_lanes_test.dart is +149 −13. It moved to the new lane
      API, and review 0187 found no weakened assertion.
    - test/marked_week_test.dart is +8 −2. This corrects its Short Road
      self-contradiction, as authorised at 2026-10-03 01:38 UTC.
  - tool/ has 2 new review harnesses and the l10n source for the tutorial
    card.
- Packaging (this commit):
  - pubspec `0.185.0+218` → `0.186.0+219`.
  - `currentAppVersion` set to 0.186.0.
  - One 0.186.0 "Clear Choices" news entry (4 lines, ending in thanks).
  - New `docs/releases/v0.186.0.md`.
  - New play notes: en-GB at 476 characters and de-DE at 464 characters,
    both under Play's 500.
  - Release state files: this file, `PROJECT.md` and `features.json`.
  - `loop.sh` copied verbatim from the subagent-toolkit v3.2.0 templates.
- VERIFIED locally (Flutter 3.47.6; CI's 3.44.9 is the gate):
  - test/news_test.dart passes 7/7. It covers the version pin, a note for the
    shipping release, newest-first order, 2–4 lines and the §Ethics word
    list.
  - test/news_ui_test.dart passes 3/3. The title-screen panel shows the new
    entry's first line, and the archive lists every entry.
  - `dart format` reports no change to news.dart.
- ASSUMED until CI runs on the release commit: the full suite and the
  analyzer stay green with the packaging diff. It touches no test, check or
  runtime code besides the news data and the version line.
- Next: the packaging PR goes through CI, then the read-only review of #125
  finishes, then the merge. After that comes the signed `workflow_dispatch`
  build on the lane, artifact checks, tag `v0.186.0`, the GitHub release
  and an unauthenticated hash check. The Play edit waits for the publishing
  service-account key (REL186-PLAY).
