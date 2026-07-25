# Design notes — pre-release polish pass (2026-07-25)

Research-informed rationale for the maps/audio/store/animation PRs
(#29 audio, #31 skins, #35 shop, #38 decor, juice + layout passes).
Principles below are established game-design practice; where a claim is
about *this* codebase it was verified against the code/tests directly.

## Game feel ("juice") — applied
- **Distinct sounds per verb.** Jump/double-jump/land each got their own
  one-shot; the 3-hit combo plays a pitch-staggered swing phrase
  (neutral/up/heavy) so the combo *reads* rhythmically. Reward sounds
  (chest, feather, secret chime, medal) are distinct from UI clicks —
  players learn loot vocabulary by ear. (Refs: Swink, *Game Feel*;
  Jonasson & Purho, "Juice it or lose it"; Game Maker's Toolkit episodes
  on feedback.)
- **Celebrate the beat, one thing at a time.** Results medals reveal
  staggered with a pop + chime instead of appearing as a static list —
  sequential reveals read as three small wins.
- **Highlight the goal.** The open exit door breathes a golden glow; in a
  boss arena the kill instantly points the eye at the exit.
- **Perf budget respected**: all fx pre-bake geometry; zero per-frame
  allocations (P-M7).

## Maps — applied
- **Dress the world, don't obstruct it.** Decor legend (bush/rock/
  shrooms/tree) is render-only with lint rules (no floaters, no overlap),
  so set dressing can never create phantom collision — a classic
  readability failure in pixel platformers.
- **Sky routes reward mastery.** Each World 1 level got a small optional
  platform chain in the empty sky with coin payoffs — double-jump skill
  expression, Apple-Knight-style, without touching the ground path
  (runner-bot completion tests stayed green, proving the base route is
  unchanged).
- **Risk-reward placement.** Coins now hang over spike/fire pits at
  jump-arc height: greed is a choice, not a trap (the pit was already
  lethal; the coins only add temptation).

## Store — applied
- **Show, don't describe.** Skins were stat-only; now they're real sheets
  rendered in-game, and the shop previews the *actual* idle animation —
  what you buy is what you get (trust; no dark patterns, spec §7).
- **Compare at a glance.** DMG/CRIT/RNG bars beat rows of numbers for a
  6-item catalog; icons give each item identity; prices use the same
  coin/feather glyphs as the HUD (one currency language everywhere).

## Deliberately NOT done (with reasons)
- **Roll/dash verb** (roll.png sheet is bundled but unused): movement
  verbs are the controls/feel lane (PRs #33/#34 by the parallel agent);
  adding a verb mid-pass would collide with that work. Flagged to owner.
- **Footstep sounds**: high repetition-annoyance risk on mobile speakers;
  needs surface variation to not grate. Deferred.
- **World 2 tileset/levels (P-M9)**: content expansion gated on the M7
  device-perf pass per PROJECT.md §10 — polishing World 1 first was the
  higher-leverage move for the existing Play testers.
