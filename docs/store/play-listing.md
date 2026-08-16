# Emberdelve — Google Play listing draft

> **0.7.0 REFRESH (2026-08-16, ready to paste):** the copy below was updated to match the
> build actually live on Play (0.7.0+33 "The Face Forge"). Features verified present in that
> build's code (`git grep` at commit `3a199e5`): Face Forge tempering, Keystones, the Ledger
> (achievements), the Codex, daily + weekly seeded delves. Do NOT mention 0.8–0.12 features
> (floor trace shares, rotating daily trials, self-teaching tutorial, per-enemy records, New
> Embers content) — those are GitHub-only builds not on Play yet.

Draft copy for the Play Console listing (owner to review before submitting).
Screenshots + feature graphic: first pass committed under
`docs/store/screenshots/` (1080×1920 PNGs + 1024×500 graphic, rendered from
real screens via `tool/store_screenshots_test.dart` — rerun any time the UI
changes). Real-device captures can replace them later if preferred (that
session also closes the real-device playthrough gate, features.json M1-3).

## App name (30 chars max)

Emberdelve: Dice Roguelite

## Short description (80 chars max)

Fair dice, real choices. A pocket dice roguelite with zero ads, played offline.

*(78 chars. Live console currently shows "Fair dice roguelite. Build your pool, delve deep.
No ads, no timers, no gacha." — either is fine; the line above leads with the promise.)*

## Full description (4000 chars max) — 0.7.0 refresh

Descend into the delve, one roll at a time.

Emberdelve is a single-player dice roguelite built on one promise: every
death is fair. Enemies always telegraph their next move, dice resolve by
rules you can learn — no hidden modifiers, no rigged near-misses — and every
run is seeded, so the same choices always play out the same way.

BUILD YOUR POOL
Draft, forge, and upgrade a pool of dice — keen edges, warding irons, lucky
charms. Chase pairs, triples, and straights: combos turn a spare d4 into the
best die on the table.

TEMPER A FACE
Once per delve, mark one face of one die at a rest — Blade, Aegis, Surge, or
Echo. A tempered die wears its mark in the tray, and it lights up when the
roll lands. Your pool becomes YOUR pool.

CHOOSE A KEYSTONE
After your first won fight, pick a run-shaping power (or decline): reward
early strikes, carry unused block, pay for die variety. Every run gets a
plan, not just a pile of dice.

PUSH YOUR LUCK
One risky reroll per turn. Exact kills pay out bonus embers; overkill splashes
to the next foe. Assigning a 4 instead of a 6 is a real decision, every turn.

CHOOSE YOUR PATH
Branching maps with honest reward previews — see what an elite guards before
you commit. Shops, forges, strange events, and a boss waiting at the bottom.

DIE FORWARD
Death banks embers. Spend them on new dice, delvers, hearth colours, and dice
skins. Pick a starting boon and delve again in seconds — 15 boons keep
restarts fresh.

KEEP THE RECORD
The Ledger tracks real feats — exact-kill streaks, boss clears, wins per
delver. The Codex holds the lore of every enemy and relic you've met. A daily
seeded delve shared by everyone, and a weekly delve with one declared
modifier, give the long game a heartbeat.

FAIR BY DESIGN
• Zero ads, plays fully offline — analytics only if you switch it on
• No energy timers, no streaks, no FOMO mechanics
• Deterministic runs: fair deaths, learnable rules
• Free forever: full runs, every delver, the daily and weekly
• One honest one-time unlock (the Ember Forge) opens HARD and the
  Ascension ladder — no subscriptions, no consumables, ever

Made for one-thumb portrait play. Delve in.

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

- Collects no data, shares no data (see docs/store/privacy-policy.md).
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
