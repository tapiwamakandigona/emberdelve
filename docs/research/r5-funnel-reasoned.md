# R5 — Where the funnel leaks: install → first delve → second session → Ember Forge (directive 2026-09-01g / 02a, question 2)

Reasoned from the build players actually have (**Play production = v0.59.0, versionCode 85,
2026-08-25** — retention-ledger) and from the live listing record (docs/store/play-listing.md,
docs/store/screenshots/framed/). Nothing instrumented, per directive. Code citations are
`git show v0.59.0:<path>` unless marked HEAD. Console facts `[console]` are owner-relayed.

## The one hard number we have

**7-day retention = 1 device** against 28 monthly-active devices and 38 lifetime installs
`[console, 2026-09-01]` (docs/research/retention-ledger.md). Whatever else is uncertain, almost
nobody who installs is still opening the game a week later. That locates the leak before any
reasoning does: **stage C, first delve → second session.** The rest of this note checks each
stage against the build to see whether it agrees.

## Stage A — listing → install (leak size: unknown; owner can read it)

What a visitor sees (listing record + R3):

- **No star rating** — 2 ratings is below the display threshold (R4 §4.2). This is the single
  largest trust signal on a Play page and it is blank.
- Short description: "Fair dice roguelite. Build your pool, delve deep. No ads, no timers,
  no gacha." (live per play-listing.md) — the trust promise is in the right place.
- Five screenshots (combat roll, boon pick, map, title, ledger) of the eight Play allows
  ([Play Console Help 9866151](https://support.google.com/googleplay/android-developer/answer/9866151):
  "up to 8 screenshots for each supported device type"). No video.
- The business model — "one honest one-time unlock (the Ember Forge) opens HARD and the
  Ascension ladder" — is the **last bullet of the FAIR BY DESIGN block, ~2,900 characters into a ~3,100-character description** (docs/store/play-listing.md, 0.34.0 refresh — the record of what was pasted; the console text may lag it).
  Slice & Dice puts its equivalent in the *first sentence* ("Free demo, no ads, single IAP to
  unlock the full game." — [Play listing](https://play.google.com/store/apps/details?id=com.com.tann.dice)).
  Visitors deciding whether "In-app purchases" on the badge means gacha have to scroll to
  find out it doesn't.

Owner check (10 min): Grow users → Store performance → Conversion analysis: visitors, clicks,
CTR for 90 days. Note Play changed the primary metric to unique *clicks* from June/July 2026
([Play Console Help 9859173](https://support.google.com/googleplay/android-developer/answer/9859173)).
Until that number exists, stage A's leak size is a guess. **If visitors ≫ 38** the listing is
the leak and R3's proposed set matters now; **if visitors ≈ 38–60**, there is no listing leak
to speak of — there is no traffic (traffic-channels.md).

## Stage B — install → first delve (leak size: small, by construction)

v0.59.0 has the Guided Delve tour (0.26/0.30 in the listing's own feature trace), the
`steerToEasy` first-profile steer that moves the *visible* difficulty selector to easy
(`controller.dart:247`), and a single title CTA. Decision distance measured on HEAD (R1
addendum, tool/first_session_distance_test.dart): first meaningful decision at tap 2, first
roll at tap 4, four screens to combat. The tour and steer both predate 0.59.0, so the shape
holds for the shipped build even though the tap count was measured later `[inference]`.

Residual risk here is **wall-clock, not taps**: cold start on a low-end device is still
un-stopwatched (owed since R1). Nothing in the build suggests a structural stage-B leak.

## Stage C — first delve → second session (THE leak)

What v0.59.0 gives a player at the end of a lost first run (most first runs end in loss for
a human even if the bot band on easy is 80–90%; PR #98's "winning a delve is rare by design"
is the owner-side observation, the bot band is the sim — both cited, neither measured on
humans):

- Summary screen buttons: *Delve again*, *Retrace this delve*, *Share this delve*, *Copy delve
  story*, daily/weekly copies, *Leaderboard* (`summary_screen.dart:491–660`). Every CTA is
  "play now" or "post this". **None says what tomorrow holds.** R2 (session-end blindness)
  documented exactly this and it is unchanged in 0.59.0.
- Return hooks present in 0.59.0: Daily Delve, Weekly Delve, Delver's Rank, Provings. All are
  *pull* hooks — the player must already want to come back and then discover them.
- Return hooks **absent** from 0.59.0: the entire Seven Hearths retention arc (v0.178.0),
  the news panel entries after 0.59.0, the reachable review ask (PR #98, v0.178.0+), six
  new delvers (v0.179.0). Everything the last fortnight built for this exact leak is on
  GitHub and in no player's hands.

Reading: the build agrees with the number. D7 = 1 is what a 0.59.0 player would be expected to
do — finish a run, see a scoreboard, have no stated reason to return.

## Stage D — second session → Ember Forge (leak size: near-total, but downstream of C)

Where a v0.59.0 player can meet the paid offer at all:

1. **Title screen, HARD segment**: a lock icon; tapping it opens the Forge sheet instead of
   failing silently (`title_screen.dart:664–670`). Reachable from second zero — but only by a
   curiosity tap on a lock, with no copy saying what is behind it.
2. **Summary screen, one quiet panel, only on a WON run** ("The dark goes deeper. The
   Ascension ladder waits in the Ember Forge." + *Open*; `summary_screen.dart:331–360`).
3. **Character screen** note that the ladder is the Forge's tier (`character_screen.dart:110`).
4. **Settings → THE EMBER FORGE** restore/purchase (`settings_screen.dart:669–676`).

So the only *presented* pitch requires a win. With D7 = 1, exposure to the Forge is
essentially "first-session wins" — and one of those 38 people bought. That is the whole
$4.25 story: **the Forge is not under-converting the people who see it; almost nobody reaches
the moment it is shown.** Fixing D without fixing C changes nothing.

## Ranked conclusion

| Stage | Leak | Evidence weight | What would close it |
| --- | --- | --- | --- |
| C first delve → 2nd session | **largest** | D7=1 `[console]`; 0.59.0 summary CTAs; R2 | Ship what is already built (Seven Hearths + news + PR #98 are all in v0.179.0's AAB). Owner's Play call. |
| A listing → install | unknown | no rating `[console]`; model buried in the last bullet | Read Conversion analysis first; then R3's set + move the "free game is complete, one unlock" line to sentence one |
| D 2nd session → Forge | large but downstream | four surfacing points, three need a win | Nothing until C moves; then consider stating *what* the lock holds on the title (copy, not a popup) |
| B install → first delve | small | tour + steer + 4 taps | Low-end cold-start stopwatch (owed) |

## What this does not license

No prompts, popups, timers, ads, analytics or nags (standing rule). "Ship v0.179.0 to Play"
is a finding, not an action — the directive reserves that call to the owner
(docs/store/PLAY-APPLY-DAY.md is the runbook when they make it; use the v0.179.0 AAB,
sha256 d47fa1d1…).
