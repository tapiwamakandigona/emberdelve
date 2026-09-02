# R10 — The v0.179.0 review-prompt path, from the code

Owner directive 2026-09-02c, item 2. Sources: `lib/meta/review_service.dart`,
`lib/game/controller.dart:1322–1500` (`_bankRun`; `maybeAsk` call at :1492), `lib/meta/rank.dart`, `lib/data/ranks.dart`,
`lib/main.dart:115–116`, `lib/meta/cloud_merge.dart:165`, `pubspec.lock` (`in_app_review 2.0.12`),
and Google's In-App Review documentation. One headless probe (bot runs, 120 seeds × 2
difficulties, run with the shipped code, script deleted) supplies the distribution numbers.

## 1. Exactly what fires it

`ReviewService.maybeAsk` is called from **one** place: `_bankRun`, after a run reaches `run_won`
or `run_lost` and every counter has been banked. It is never called mid-run, from a button, or
from settings. `eligible()` (`review_service.dart:61–73`) is:

```
if (meta.reviewAsked || tourActive) return false;
if ((wonThisRun && meta.runsWon >= 2) || wonDailyOrWeekly) return true;
return rankedUpToMarks != null && rankedUpToMarks >= 24;
```

So there are three triggers, any one sufficient:

1. **Second-or-later win** — `runsWon` is incremented before the check (`controller.dart:1342`),
   so this is the 2nd win of the profile's life.
2. **Any won daily or weekly** — `wonDailyOrWeekly = run_won && (dailyDate != null || weeklyIndex != null)`
   (`controller.dart:1494–1495`). No run count required.
3. **A rank climb into Sparktender (24 marks) or higher** — `rankedUpToMarks` is
   `rankAfter.marks` when the banked run crossed a tier, else null (`:1497`). Marks are derived
   (`rank.dart`): 3×wins + 5×distinct bosses + 2×distinct foes felled + 1×distinct foes met +
   1×codex entries + 2×dailies/weeklies finished.

Guards: `reviewAsked` (one ask per profile, ORed on cloud merge — `cloud_merge.dart:165`) and
`tourActive` (a Guided Delve beat currently on screen). **The header's claim "never on a profile
that hasn't finished the tour version it was shown" is not in the code** — only the live-beat
check is. In practice the tour lives in the first fight and ends by completion or SKIP, so by the
time a run banks it is inactive; the stronger sentence in the header is documentation, not a
guard.

On Android the backend is `InAppReview.instance.requestReview()` (`main.dart:116`, plugin
2.0.12); elsewhere it is null and the stamp still lands. `reviewAsked = true` is written **before**
the backend is called and regardless of its outcome ("one ask means one attempt").

## 2. Earliest possible fire on a fresh install

**End of the very first run.** Two routes:

- **Route (2):** the first run is the Daily or Weekly and it is won. Nothing gates the shared
  delve behind a run count (`title_screen.dart:208`, `startDailyRun` at `controller.dart:869`
  takes no history check). A brand-new player who taps the daily card first and wins is asked
  after run one.
- **Route (3):** a won first run that banks ≥ 24 marks. A losing first run **cannot** reach 24
  (probe: max 7 marks across 240 lost bot runs), but a won one often can — a full 9-layer clear
  meets ~8 distinct foes, fells most of them and puts down a boss.

Probe (fresh `MetaState`, Kindler, boons on, bot from `sim/autoplay.dart`, seeds 1–120):

| Difficulty | Bot wins | First run banks ≥ 24 marks | Median marks, won / lost |
| --- | --- | --- | --- |
| easy (what a fresh profile is steered to) | 107 / 120 | **18** (all wins; 17 % of wins, 15 % of runs) | 23 / 4 |
| normal | 81 / 120 | **14** (all wins; 17 % of wins) | 23 / 4 |

The bot wins far more than a new human will (sim bands easy 80–90 %, but that is the bot), so
15 % is an upper bound on "asked after run one" for real players. The median won first run sits at
23 marks — one below the floor — so route (3) on run one is a coin-flip *given* a first-run win.

**Is that before a good run?** No — both routes require a *won* run, and a won first run is the
best run a new player can have. The risk is different from the one the directive names: it is
**asking at the end of the first session**, when the player has had one experience of the game
and Play's own guidance says to wait until they have "experienced enough of your app or game to
provide useful feedback" (developer.android.com/guide/playcore/in-app-review, "When to request").
Route (1) (second win) and the rank route on a losing streak (untested how many losses reach 24;
distinct-foe terms saturate, so it is several runs) both satisfy that; route (2) and a strong
route-(3) first run do not. This is a **ratings-quality** question, not volume: the one player it
catches at run one is a winner in a good mood, which is fine for the star and thin for the words.

## 3. What Play's quota does to a player who dismisses

From the same page, verbatim: "Google Play enforces a time-bound quota on how often a user can be
shown the review dialog. Because of this quota, calling the launchReviewFlow method more than once
during a short period of time (for example, less than a month) might not always display a
dialog." and "The specific value of the quota is an implementation detail, and it can be changed
by Google Play without any notice." The Kotlin/Java guide adds: "The API does not indicate whether
the user reviewed or not, or even whether the review dialog was shown."

Consequences for us, from the code above:

- **Dismissal is invisible to us and final.** We stamp `reviewAsked` before calling, we get no
  signal back, and we never call again. A player who swipes the card away is never asked by
  emberdelve again on any device (merge ORs the flag). Play's quota is irrelevant to them
  because we make no second request.
- **The quota can silently spend our one ask.** If the player's quota is already exhausted (the
  page's example is another request within about a month — ours is the first from this app, but
  the quota's scope is not documented, so we cannot say it is per-app), `requestReview()` returns
  with no dialog, the stamp is already set, and the profile has used its single attempt on
  nothing. This is the cost of "stamp on request"; the alternative (stamp on shown) is
  impossible because Play never says.
- **No CTA path.** The docs say not to put a button behind the API because a quota'd user sees
  nothing; we have no such button, consistent.

## 4. Summary for the owner

- Fires only when a run banks; three triggers; one ask per profile ever, stamped on request.
- Earliest fire: end of run one, via a won Daily/Weekly or a ≥24-mark won first run (bot upper
  bound ~15 % of first runs on easy). Never after a lost first run.
- That is after a *good* run but after a *single* run — early by Play's guidance, fine for
  star quality, thin for review text. If that is judged too early, the cheapest tightening (for a
  future, unfrozen cycle) is `meta.runsPlayed >= 2` inside `eligible()` — one line, one test — which
  removes both run-one routes and leaves everything else. Not proposed now; recorded so it is not
  re-derived.
- The header sentence about tour version is aspirational; either drop the sentence or add
  `meta.tourSeenVersion >= tourVersion` to `eligible()` when code is next unfrozen.
