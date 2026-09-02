# R7 — What the Play build (0.59.0) lacks at each funnel stage versus v0.179.0, from git

Purpose: R5 located the leak at *first delve → second session* and noted that every return
hook built since 25 Aug is on GitHub only. This note makes that concrete per stage so the
Play apply — if and when the owner makes that call (PLAY-APPLY-DAY.md) — has a before/after
to measure against in the retention ledger. Every line is read from the two tags in this repo
(`git show v0.59.0:… / v0.179.0:…`); nothing is inferred from memory.

## Distance between the two builds

- `v0.59.0` = `b69a78c`, 2026-08-25, `0.59.0+85` — the build on Play production ("Updated on
  Aug 30, 2026" on the live page, R5 §Live check).
- `v0.179.0` = `c4b1655`, 2026-09-01, `0.179.0+205` — [release](https://github.com/tapiwamakandigona/emberdelve/releases/tag/v0.179.0).
- **236 commits**, 72 files under `lib/` changed (+10,967 / −2,703 lines); test files 83 → 217.

## Per stage

| Funnel stage (R5) | Play build 0.59.0 has | v0.179.0 adds | Evidence |
| --- | --- | --- | --- |
| **A — listing → install** | — (store surface, not build) | Nothing; listing is a Console paste (R3) | — |
| **B — install → first delve** | Tour, `steerToEasy` for fresh profiles, tap-2 decision distance | Same skeleton; cold-start critical path changed to overlap `controller.boot()` with service loads; boot-cost probe + meta save-size gate; six `perf:` commits (zero-alloc sprite painter, shader warm-up, summary/map repaint fixes 380→3 and 17→9 paints/frame) | commits `a9cf792`, `1323686`, `d01fc57`, `f3a3234`, `57fe0b9`, `58afc40` |
| **C — first delve → second session** (the leak) | Summary CTAs: "Delve again", "Share this delve"; won-run line "Ascension now stands open."; roster of **6** delvers; provings **10**; no day-2 acknowledgement; no week-scale arc | Summary now carries **"WITHIN REACH" / "NEXT DELVER —"** next-unlock tease, "Retrace this delve", "They wait at the hearth" (won-run pointer to the roster); **The Seven Hearths** (`lib/game/hearths.dart`, v0.178.0) — a seven-played-days arc with day 2 acknowledged on the title screen ("THE RETURNED DELVER"); roster **22** delvers with an unlock ladder to 3000 embers; provings **30**; tales (`lib/data/tales.dart`); rank ladder to 13 fires | `git show v0.59.0:lib/ui/screens/summary_screen.dart` (2 hook strings) vs v0.179.0 (5); `hearths.dart` absent at v0.59.0; commits `e9926ae`, `2ce5f13`, `03b846d`…`27f0fa9` |
| **C' — the review ask** | `(wonThisRun && runsWon >= 2) \|\| wonDailyOrWeekly` — needs a **second win** | Same rule **plus** `rankedUpToMarks >= 24` (climb to Sparktender), reachable from losses | `review_service.dart:52` at v0.59.0 vs `:72–73` at v0.179.0 |
| **D — Forge unlock** | HARD lock glyph on title, won-run panel, Settings | Same surfaces; forge list "joins the page" in the character screen (THE OPEN FORGE `3653c50`); no copy change | title_screen.dart (+777/−…), character_screen.dart (+645) |

## What this means for measurement

1. If the owner applies v0.179.0, the ledger's next pull should watch **D1 and D7 of the
   post-apply cohort** against August's (D7 = 1 device). Stage C is the only stage where the
   build changed materially; stage A did not change at all, so an install-count change would be
   listing/traffic, not build.
2. The review-ask change (C') should show up as a **ratings count** change before a star does
   (5+ floor, R4 §4.2). If ratings rise without installs rising, that is the 24-marks trigger
   working, not the listing.
3. Nothing in v0.179.0 touches stage A. The three listing pastes in R3 addendum 2 are
   independent of the apply and can go first, second, or together — but if they go together,
   the two effects cannot be separated at n≈40. Owner's call; the honest sequencing for
   attribution is **listing first, build two weeks later**.

## Not claimed

- No frame-time or cold-start numbers for 0.59.0 vs 0.179.0 on a real low-end device — still
  owed, still device-blocked. The perf commits above are repaint-count and allocation
  evidence from probes, not wall-clock.
- No statement that v0.179.0 *will* lift D7. It is the only build that could, and the only
  way to know is the ledger.
