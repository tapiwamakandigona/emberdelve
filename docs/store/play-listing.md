# Emberdelve — Google Play listing draft

> **0.34.0 REFRESH (2026-08-25, ready to paste):** copy updated to match the build actually
> LIVE IN PRODUCTION on Play (0.34.0+60 "The Delver's Card", 177 countries). Every feature
> below is traced to a shipped release note in `docs/releases/` — floor trace & Delver's Card
> share (0.8/0.34), rotating daily trials (0.9), content drops (0.12/0.22), ranks (0.13),
> TalkBack (0.19), balance-swept Ascension (0.20), Deep Hum (0.23), save codes (0.24), guided
> onboarding (0.26/0.30), Wardrobe dyes (0.27), depth-graded strata (0.28), Codex 71 (0.31),
> Gramophone (0.33). Console paste + IARC + data-safety forms are owner/Google-gated.

## App name (30 chars max)

Emberdelve: Dice Roguelite

## Short description (80 chars max)

Fair dice, real choices. A pocket dice roguelite with zero ads, played offline.

*(78 chars. Live console currently shows "Fair dice roguelite. Build your pool, delve deep.
No ads, no timers, no gacha." — either is fine; the line above leads with the promise.)*

## Full description (4000 chars max) — 0.34.0 refresh

Descend into the delve, one roll at a time.

Emberdelve is a single-player, turn-based dice roguelike built on one promise: every death is fair. Enemies always telegraph their next move, dice resolve by rules you can learn — no hidden modifiers, no rigged near-misses — and every run is a seeded dungeon delve, so the same choices always play out the same way.

BUILD YOUR POOL
Draft, forge, and upgrade a pool of dice — keen edges, warding irons, lucky charms. Chase pairs, triples, and straights: combos turn a spare d4 into the best die on the table.

TEMPER A FACE
Once per delve, mark one face of one die — Blade, Aegis, Surge, or Echo. A tempered die wears its mark in the tray and lights up when the roll lands. Your pool becomes YOUR pool.

CHOOSE A KEYSTONE
After your first won fight, pick a run-shaping power (or decline): reward early strikes, carry unused block, pay for die variety. Every run gets a plan, not just a pile of dice.

PUSH YOUR LUCK
One risky reroll per turn. Exact kills pay out bonus embers; overkill splashes to the next foe. Assigning a 4 instead of a 6 is a real decision, every turn.

CHOOSE YOUR PATH
Branching maps with honest reward previews — see what an elite guards before you commit. Shops, forges, strange events, and bosses holding the crowned deep. The rock itself changes as you descend, and a living soundscape deepens with it.

CLIMB THE ASCENSION
Twenty rungs of stacked challenge, each opened by winning the one below — and every rung is winnable by design: we sweep the whole ladder with a balance bot before we ship it.

DIE FORWARD
Death banks embers. Spend them on new dice, delvers, dyes from the Wardrobe, hearth colours, and dice skins. Pick a starting boon and delve again in seconds.

TELL THE TALE
Every run ends in a shareable Delver's Card and a floor-by-floor trace made to be posted. A daily seeded delve is shared by everyone — with rotating trial days that declare one honest modifier — and a weekly delve raises the stakes.

KEEP THE RECORD
The Ledger opens with your rank — nine named tiers — and tracks real feats: exact-kill streaks, boss clears, wins per delver. The Codex holds the lore of all 71 enemies and relics you've met. The Gramophone keeps every track of the score, ready to replay.

CARRY YOUR EMBER
Your whole ledger travels as one line of text. New phone? Reinstall? Copy your save code, paste it, and everything comes home. No account, no server, no sign-in.

FAIR BY DESIGN
• Zero ads, plays fully offline — analytics only if you switch it on
• No energy timers, no streaks, no FOMO mechanics
• Deterministic runs: fair deaths, learnable rules
• Plays with TalkBack — the whole game works with Android's screen reader
• Free forever: full runs, every delver, the daily and the weekly
• One honest one-time unlock (the Ember Forge) opens HARD and the Ascension ladder — no subscriptions, no consumables, ever

For fans of Dicey Dungeons and turn-based dice roguelites — dungeon-crawl runs you can learn and beat.

Made for one-thumb portrait play. Delve in.

## ASO / keyword analysis (2026-08-16) — honest coverage audit

For a game with no ad budget and 0 ratings, Play Store keyword discoverability IS the free
growth channel. Audited current copy against real genre search terms (web-verified competitors:
Dicey Dungeons, Dice Royale, Roll & Slay, Cascade, Heroll). Play Store indexes the **title,
short description, and long description** for ranking.

**Truthful terms currently MISSING (add — every one is accurate for this game):**
- **"roguelike"** — Play treats `roguelike` and `roguelite` as *distinct* query terms;
  roguelike is the higher-volume spelling and roguelite is a subgenre of it, so indexing both
  is honest and standard ASO. Woven into the long description below.
- **"turn-based"** — accurate (it is a turn-based dice game). High-intent genre filter.
- **"dungeon" / "dungeon crawl"** — accurate (you delve floors of foes to a boss).
- **"for fans of Dicey Dungeons"** — Dicey Dungeons is itself a dice roguelite; this is an
  honest peer comparison and the single highest-intent discovery vector (players searching a
  known title). Added as a closing line.

**Terms deliberately NOT added (would misposition — honesty guardrail):**
- ~~deckbuilder / deck builder~~ — Emberdelve builds a *dice pool*, not a card deck. Say
  "dice-builder" / "build your pool" (already in copy), never "deckbuilder".
- ~~Balatro / poker / Yahtzee~~ — those are poker/score-chaser mechanics; Emberdelve is not
  poker-based. Claiming them would draw the wrong players and earn 1-star "not what I expected".
- ~~Slay the Spire~~ — it's a *card* deckbuilder, not dice; too loose a comparison to claim
  directly. Dicey Dungeons is the honest anchor.

**Recommended short-description variant (keyword-tighter, 80 max):**
`Turn-based dice roguelike. Build your pool, delve deep. No ads, offline.` *(71 chars —
adds "turn-based" + "roguelike" spelling vs the current line; owner picks.)*

**Recommended closing line for the long description** (append before "Made for one-thumb…"):
`For fans of turn-based dice roguelikes and dungeon-crawl runs you can learn and beat.`

These are drop-in, owner-reviewed. They add real query coverage without a single false claim.

## Telemetry note (0.4.3+, added 2026-08-11)

v0.4.3 bundles Firebase Analytics with collection disabled in the manifest until the
player opts in (`lib/telemetry/`). Two consequences for this listing:
- The old "zero tracking" wording is no longer accurate and has been replaced above.
- The Play Console **Data safety form must be updated before 0.4.3 is uploaded**
  (analytics data, not linked to identity, optional/user-controlled).

## Category / tags

- Category: Games > Card (or Games > Strategy)
- Tags: roguelite, dice, turn-based, offline, single player

## Content rating questionnaire (IARC) — expected answers

- Violence: mild fantasy violence (stylized pixel creatures, no gore) → likely
  Everyone 10+ / PEGI 7
- No user interaction/communication, no data sharing
- Digital purchases: YES — one optional one-time unlock (the Ember Forge,
  v0.4.0+); no loot boxes, no gambling mechanics, no subscriptions
- No gambling with real money; contains dice but no wagering

## Data safety form

- Optional, off-by-default analytics only (Firebase, opt-in via Settings since
  0.4.3): declare "App activity — analytics, optional, not linked to identity".
  Otherwise collects no data, shares no data (see docs/store/privacy-policy.md).
  Purchases are processed entirely by Google Play Billing; the app stores
  only a local owns/doesn't-own flag and never sees payment details.
- Privacy policy URL:
  https://tapiwamakandigona.github.io/emberdelve/store/privacy-policy.html
  (GitHub Pages, serves main:/docs — the styled page is
  docs/store/privacy-policy.html; the markdown source stays the canonical
  text).

## Still needed (owner-gated)

- [x] 5 phone screenshots 1080×1920 (docs/store/screenshots/01–05, rendered
      from real screens; regenerate with `flutter test tool/store_screenshots_test.dart`)
- [x] Feature graphic 1024×500 (docs/store/screenshots/feature-graphic-1024x500.png)
- [ ] App icon 512×512 (export of the launcher icon)
- [x] Hosted privacy policy URL (GitHub Pages enabled 2026-07-24, main:/docs):
      https://tapiwamakandigona.github.io/emberdelve/store/privacy-policy.html
- [ ] Console: content rating questionnaire + data safety form submission
