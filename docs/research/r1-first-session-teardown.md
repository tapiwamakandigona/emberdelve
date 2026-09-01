# R1 — First-session teardown: comparable dice roguelites on Google Play

Date: 2026-09-01. Owner brief (DEMAND 477857cf): play comparable dice
roguelites, timestamp the first meaningful decision, capture the
60-second-mark screen, the first reward, the day-2 hook, and loss
handling; end with a concrete delta list vs Emberdelve.

## Method — and its honest limits

This sandbox has no Android device or emulator, and none of the
candidates ship a browser-playable build (Slice & Dice's free demo is
Windows/Mac/Android downloads only — 66 MB Android APK on itch, no
HTML5). So this teardown could NOT be first-hand play. Every claim
below is labeled:

- **[listing]** — read directly from the game's Play/itch page copy.
- **[video]** — from recorded first-session gameplay/reviews.
- **[wiki/docs]** — from the game's official wiki or devlogs.
- **[inferred]** — my reasoning from the above; weakest tier.

Timestamps are therefore estimates from recorded sessions, not
stopwatch measurements of my own play. If the owner wants stopwatch
numbers, the follow-up is a 30-minute session per game on a real
device (all four top candidates are free-to-try).

## Candidates (narrowed from 7 to 4)

Kept: genuinely dice-core, run-based, phone-playable, discoverable by
the same searcher who finds us. Dropped: Dice Royale (poker framing),
Dicey Elementalist (thin data), Dice of Kalma (kept only as a pacing
note — its reviews stress "minimalistic, core loop first").

### 1. Slice & Dice (tann) — the genre benchmark
- Scale: 23.2K Play reviews, 1M+ installs; paid unlock like ours
  (free demo = first 12 levels, was 20). [listing]
- First meaningful decision: the very first combat turn — which hero
  die to assign where. No menu maze; demo drops into a run. [video]
- ~60-second mark: mid-first-fight, full dice tray visible. [video]
- First reward: level-up hero choice after the first fight (~2-3
  min). [video]
- Loss handling: lose one fight → run over, restart; brutal but the
  undo system removes misclick pain. Play copy leads with "undo as
  much as you like, no hidden mechanics, everything visible" — it
  sells TRUST, not content volume. [listing]
- Day-2 hook: none mechanical. Pull is mastery + unlockable modes
  and cursed/blessed items; no daily. [wiki/docs]

### 2. Dicey Dungeons (Terry Cavanagh) — premium, tutorial gold standard
- First launch drops STRAIGHT into Warrior episode 1 ("The Warrior's
  Welcome") — no title-screen decisions at all. [video]
- First meaningful decision: turn one of fight one, place a die on
  Sword vs Shield (~30-45 s from cold start). [video]
- ~60-second mark: in combat, two equipment slots, dice rolling.
- First reward: level-up (+HP, new equipment choice) after 1-2
  fights, inside minute ~3. [wiki/docs]
- Loss handling: HP 0 → back to title, keep nothing inside the
  episode; progression is UNLOCKING episodes, so a completed episode
  is never lost. Episode 1 ≈ 15-25 min for a new player (6 floors;
  speedruns ~4 min). [wiki/docs]
- Day-2 hook: none; pull is the episode ladder (6 characters × 6
  episodes) framed as a story. [wiki/docs]

### 3. Heroll: Dice Roguelike (Crater Co.) — the F2P contrast
- F2P with "all the F2P trappings" (SNAPP review) — ads, currencies,
  a "Rate Us" prompt early enough that App Store reviews mention it
  with irritation. [video/reviews]
- Loop: roll-move-fight on a looping board; first decision is a
  route/upgrade pick within ~1 min. [video]
- Day-2 hook: classic F2P daily missions + login-adjacent economy.
- Reviews complain rolls "feel rigged, favoring negative outcomes" —
  the exact trust failure our fairness pillar answers. [reviews]

### 4. Dice Gambit: Farkle Roguelite (pxlforge) — closest mechanic
- Push-your-luck banking (Farkle combos vs bank-to-survive) —
  mechanically the nearest neighbor to our bank-or-press ember
  decision. [listing]
- Dev is still building an interactive tutorial post-launch after
  players bounced off dice rules (itch comments) — evidence that
  UNTAUGHT dice rules are the genre's biggest first-session killer.
  [wiki/docs]
- Meta: "unlock 30+ permanent items across runs to grow stronger
  forever" — permanent POWER creep, which we deliberately refuse
  (our meta adds options, not stats). [listing]

## Pattern table

| Game | First decision | First reward | Loss | Day-2 hook |
|---|---|---|---|---|
| Slice & Dice | ~30 s, combat assign | ~2-3 min level-up | restart, undo softens | none (mastery) |
| Dicey Dungeons | ~30-45 s, combat | ~3 min level-up | episode ladder keeps | none (story ladder) |
| Heroll | ~1 min route pick | fast drip | soft (F2P) | daily missions |
| Dice Gambit | ~1 min roll/bank | run items | permanent power meta | permanent meta |
| **Emberdelve** | first fight after gifted words + tour | first won fight → keystone offer | embers banked (kept = embers~/2), killer named, codex entry | morrow trial, day-2 return line, Seven Hearths |

## Delta list — what they do that we don't (and verdicts)

1. **Cold-start speed.** The two best-loved games put a die in your
   hand in under ~45 s with ZERO title-screen decisions. Our path is
   gifted words → tour → title → run. **Action candidate:** measure
   our own cold-start-to-first-roll on a real device; if > 60 s,
   consider a "first launch goes straight into the delve" path with
   the tour woven into fight one. (R1's falsifiable follow-up.)
2. **Trust as the headline.** Slice & Dice's listing leads with
   undo/no-hidden-mechanics. Our fairness pillar is the same asset
   but our listing buries it below the fold. → feed to R3.
3. **Undo.** We have no misclick forgiveness in combat. An
   assign-undo (before confirming a turn) is charter-clean and the
   single most praised trust feature in the genre. **Strongest
   product candidate from R1** — for a FUTURE authorized release,
   not now.
4. **Loss keeps something visible.** We already do this better than
   all four (banked embers + named killer + codex). No action;
   protect it.
5. **Day-2 mechanics.** None of the premium peers have any; only the
   F2P has dailies. Our morrow trial + Seven Hearths is genuinely
   differentiated in the premium lane. Protect; don't add more.
6. **Untaught dice rules kill first sessions** (Dice Gambit's
   post-launch scramble). Our anchored tour + steerToEasy already
   answer this; the "what's a delve" review says vocabulary, not
   rules, is our residual gap.
7. **Download size.** Slice & Dice's DEMO alone is 66 MB Android; we
   ship the full game in 20.6 MB. Keep saying so. → feed to R3.

## What NOT to copy

- Heroll's F2P scaffolding (ads, early rate-us nag, rigged-feeling
  rolls) — the reviews are the cautionary tale.
- Dice Gambit's permanent power meta — breaks our fairness claims.
- Slice & Dice's lose-one-fight-restart severity — our ember banking
  is kinder and tests better with our n=1 review.

*All entries [web, 2026-09-01]; first-hand device play still owed if
owner wants stopwatch-grade timestamps.*

## Addendum (2026-09-01) — our own decision distance, measured

Delta #1 asked for our cold-start number. Wall-clock cold start needs
a real device (still owed), but the deterministic half — decision
distance — is now measured by `tool/first_session_distance_test.dart`
(hit-tested taps, fresh profile, tour unseen, steerToEasy active):

- **First meaningful decision: tap 2** (the boon pick — offered
  immediately after the single title CTA).
- **First roll: tap 4** (title Delve → boon pick → first map node →
  ROLL, with tour beat 1 anchored on the ROLL button).
- **Screens to combat: 4** (title → boon → map → combat). First
  words are a non-blocking line ON the title, not an extra screen.

Reading vs the genre leaders: Slice & Dice and Dicey Dungeons reach
the first decision in ~1-2 taps by skipping ANY pre-run choice; we
spend our tap-2 on a boon pick, which IS a meaningful decision — so
in decisions-per-tap we are already at the front of the pack. The
open question is purely wall-clock (engine boot + title settle +
map sweep on a low-end device), which no tap count can answer.
Verdict: no structural change warranted from tap distance alone;
the device stopwatch pass remains the follow-up. [probe, 2026-09-01]

## Addendum 2 (2026-09-01) — the "what's a delve" gap is already closed; do not re-fix

Delta #6 named a residual vocabulary gap ("I still don't understand
what's a delve", player review, 2026-08-23). Code audit shows this gap
was already closed by v0.71.0 and the earlier claim needs correcting:

- **Title, fresh profile** — `firstWordsLine` (title_screen.dart)
  pushes the definition unprompted: "The delve is the dark below the
  hearth — floor under floor of it. Go down with your dice, come back
  with the Ember." Retires after the first banked run. Its own doc
  comment cites this exact review as the reason it exists.
- **Codex** — `place:the_delve` is the one GIFTED entry ("A delve is
  a walk down into the dark with a light you have to feed…"), so the
  pull-channel answer is free from minute one.
- **Why the review still happened**: the reviewer was on the Play
  production build 0.59.0, which predates v0.71.0. The review is
  evidence about an old build, not the current product.

Verdict: nothing to ship. The remaining sliver — a player who banks
run 1 still confused loses the title line forever — is thin (they've
by then walked a delve and hold the gifted codex entry) and not worth
a product change. Future runs: check `firstWordsLine` before
proposing any vocabulary fix. [code-audit, 2026-09-01]
