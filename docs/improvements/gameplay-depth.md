# Improvement backlog — Gameplay depth ("more addictive", the fair way)

**Status:** proposal, owner-reviewed direction (memorymadie, 2026-07-23 DM). Written by Viktor for
whichever agent picks this up next. Read `PROJECT.md`, `docs/spec.md`, and `features.json` first —
especially the ethics blacklist (spec §Ethics) and the determinism pillar: **randomness lives in
offerings, never in resolution.** Nothing below may violate those.

**Diagnosis (from sim code + playtest):** the bones are right (visible intent, deterministic
resolution, embers meta), but the moment-to-moment turn is the weakest link. A turn is mostly
"assign biggest die to attack, spare die to block" — correct play is too obvious, so tension is
low. The best dice roguelites make **every roll a small drama**. Everything below serves that.

## A. In-combat: make each roll a drama

1. **Combo faces** *(highest impact)*. Dice are currently independent; add set effects:
   pair = +2, triple = ignite (burn DoT), straight = free reroll next turn. Creates real,
   *earned* near-misses ("rolled 5-5-4… so close to the triple") — the hook slot machines fake,
   but honest. Also makes small dice valuable (a d4 pairs more often), fixing "bigger die is
   always better." Sim work: combo detection over the rolled pool in `lib/sim/combat.dart`,
   new events for the UI; keep it deterministic (combos are a pure function of the roll).
2. **One risky reroll per turn** *(cheapest big win)*. Reroll any subset once per turn, at a
   cost (rerolled dice −1 pip, or take 1 damage). Push-your-luck is the core loop of Yahtzee /
   Slice & Dice / Dicey Dungeons. Today there is no decision *after* the roll lands — the roll
   is the outcome. Reroll must consume from the seeded combat RNG stream so replays stay
   deterministic given the same commands.
3. **Faces that interact, not just numbers.** Forge ("6 → fire 8") exists; add chaining faces:
   fire face + oil relic = double burn; a "copy the die to my left" face; a 0-value face that
   doubles the next die. Build variety → "what if I try a burn build next run" → replay itch.
4. **Exact-kill / overkill bonuses.** Kill with exact damage → small ember bonus; overkill →
   splash to next enemy. Suddenly assigning a 4 vs a 6 matters; players do arithmetic every
   turn instead of idle sorting.

## B. Between fights: make the next node irresistible

5. **Telegraph rewards on the map.** Show temptation, not just type: "⚔️ elite — guaranteed
   rare die." The route becomes a bet you place, not a walk. (Map gen already tags node types
   in `lib/sim/map_gen.dart`; add a reward-preview field resolved from the seeded offering
   stream so it's honest.)
6. **Mid-run "build spike" moment.** Ensure at least one relic/face combo per act can feel
   broken (huge number, infinite-ish chain). Chasing that high drives run #40. Balance with the
   greedy autoplayer (`lib/sim/autoplay.dart`, 200-seed band 20–80%).
7. **Shops that hurt.** Keep one slot always slightly too expensive → "I'll come back with gold
   next run" loop. Pure shop-stock/pricing tuning in the offering tables.

## C. Meta loop: kill friction between runs

8. **Death → next run in 2 taps.** Death ledger + insight (already in) → embers tick up a
   visible track with next unlock shown → **"Delve again"** offering 1-of-3 starting boons.
   The boon choice makes restarting itself fun. Retention lives in these 10 seconds.
9. **Daily seeded run.** Already spec'd for post-launch; determinism makes it nearly free.
   Shared seed + local best score is the strongest *honest* daily hook (no streak decay —
   curiosity does the work).
10. **Unlock cadence.** Something new (die, face, relic, character, ascension rung) at least
    every 2–3 runs for the first ~15 runs. First unlock within runs 1–2 (already spec'd).

## D. Feel ("juice") — cheap but huge

11. **Combat juice layer:** dice tumble with haptics, big hits shake + ~80 ms hit-stop,
    kill crunch, damage-number pop. Same mechanics + good juice ≈ 2× perceived fun. The
    animation/SFX sync shipped in v0.2.0 is the foundation; this is the next layer.
    (Overlaps with `visuals.md` §C — coordinate.)
12. **Turn ghost-preview.** Live projected damage/block totals while assigning dice — lowers
    cognitive load, speeds turns, feels snappy on a phone. Pure UI; sim already exposes
    everything needed to compute projections.

## Anti-goals (do NOT do)

- Anything on the spec's ethics blacklist (energy timers, decaying streaks, rigged near-misses,
  FOMO content, loss-framed notifications).
- No randomness added to *resolution* to fake tension. Deterministic resolution is why deaths
  feel fair, and fair deaths are why players run it back instead of uninstalling.

## Suggested v0.3.0 "gameplay depth" milestone order

**#1 combos → #2 reroll → #8 restart flow → #11 juice → #9 daily seed.**
Process: spec each into `features.json` with acceptance evidence, keep the sim core sealed and
pure-Dart, re-anchor the golden hash deliberately (it WILL move — document old→new in
`progress.md`), keep the 200-seed autoplay win-rate band 20–80%, and run the full suite
(`flutter analyze` + `flutter test`) before merging.
