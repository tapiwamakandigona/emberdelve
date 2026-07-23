# Emberdelve — Product Spec (v1, approved 2026-07-23)

Owner approvals on record (2026-07-23, Slack DM): name **Emberdelve**, mechanic **dice-builder**, private repo, free+unlock monetization, green light to build.

## 1. One-liner
A dark, cartoony turn-based roguelite for Android where you build a pool of dice instead of a deck of cards: roll, assign, upgrade, and forge dice as you delve toward the ember at the bottom of the world.

## 2. Product pillars
1. **Fair-addictive**: variable *offerings* (what you're offered), deterministic *resolution* (played actions always resolve as stated). Enemy intents always visible. Death always pays out meta-progress + one learnable insight.
2. **Mobile-native**: portrait, one-thumb reach, 3–7 min atomic unit (one fight/floor), 15–30 min full run, autosave after every action, resume into the pending decision in <5s.
3. **Deterministic under the hood**: seeded runs, replayable, testable. Daily seeded run (offline) post-launch.
4. **Premium feel, honest economy**: free + one-time unlock ($3.99–4.99), no forced ads, no consumables.

## 3. Core loop (run level)
Node map (StS-style, branching, whole-run visible) → fight (dice combat) / event / shop / forge → reward (dice, faces, embers) → boss → next act. v1 ships **one polished act**; acts 2–3 in content updates.

### Dice combat (v1 rules sketch — refine in M1)
- Player has a **dice pool** (start: 3×d6) rolled each turn.
- Each die is assigned to an action slot: **attack**, **block**, or a die/relic-specific power.
- Dice are *items*: bigger sizes (d4→d12), forged faces (e.g. "6 → fire 8"), set bonuses. Loot = new dice + face upgrades.
- Enemy intent (action + amount) always shown before the player commits.
- Turn: roll → assign (in any order, full information) → end turn → enemy resolves shown intent.

## 4. Meta layer (M2+)
- **Embers** (meta-currency) from every run, win or lose → permanent unlocks (new starting dice, characters, forge options).
- First permanent unlock within runs 1–2; unlock tracks pre-filled where honest (endowed progress); "1 more win unlocks X" messaging (goal-gradient).
- Ascension-style stacked difficulty ladder (15–20 rungs) as endgame.
- Death screen = ledger of gains (embers earned, tracks advanced, one insight line).

## 5. Ethics blacklist (hard requirements — banned)
Energy timers / play caps; decaying streaks or loss-framed notifications; rigged/artificial near-misses (only amplify *real* ones honestly); FOMO-expiring content; pay-to-skip friction; hidden odds. Test for every retention feature: *would the player endorse it if we explained exactly how it works?*

## 6. Functional requirements & acceptance (v1 release)
Machine-readable tracking lives in `features.json`. Summary:
- R1 Deterministic sim: same seed + commands ⇒ identical event/state hash on LuaJIT and Lua 5.4 (CI test).
- R2 Full run playable: map → fights → boss → run summary, seeded.
- R3 Kill-safe persistence: process death at any moment loses at most the current animation, never state (autosave every applied command; snapshot/restore round-trip test).
- R4 Resume <5s into pending decision with recap (manual timing on low-end device).
- R5 CI produces installable signed AAB (release) + APK (debug) from a clean clone.
- R6 60fps on a 2GB-RAM Android device during combat with juice effects on.
- R7 Play closed-test build accepted (12 testers / 14 days gate).
- R8 IAP full-unlock functional + restorable.
- R9 All shipped assets license-clean for a commercial title; no licensed raw files in any public repo/release artifact beyond compiled bundles.

## 7. Milestones
| # | Name | Exit criteria |
|---|---|---|
| M0 | Skeleton | CI green: headless sim tests + installable debug APK from clean clone; state files in repo |
| M1 | Prototype | Full seeded run on device (map/fights/boss/summary, placeholder art); determinism suite green; ~10 dice variants, 3 enemies, 1 boss |
| M2 | Vertical slice | Stranger-playable; real art+audio+juice for act 1 slice; release AAB from CI; autosave/resume proven |
| M3 | Content | 30+ dice/faces, 15+ enemies, 20+ relics/events via data files only; autoplayer balance stats |
| M4 | Release | GPGS cloud save, IAP, perf pass, closed test, staged rollout |

## 8. Out of scope for v1
Multiplayer, cloud sync beyond GPGS, iOS (Defold keeps the option open), localization beyond EN, acts 2–3, realistic art style.
