# Emberdelve v2 — Product Spec (action platformer)

*Approved direction: owner DM 2026-07-24 ("rethink emberdelve… same type of gameplay loop as Apple Knight… make it better and well optimised").*

## 1. Pitch
A crisp pixel action-platformer: a knight delves through the cursed forest of **Emberwood**, slashing beasts, looting chests, and hunting secret rooms. Apple Knight's loop — but with tighter game-feel, fairer economy, and no ads shoved in your face.

## 2. Core loop
1. Pick a level from the world map (levels unlock sequentially).
2. Platform + fight through it: collect **coins**, **apples** (throwable weapon), **treasure chests** (big coin caches, sometimes gear), and find **secret rooms**.
3. Finish at the exit door → results screen with **3 medals**: (a) finish, (b) all chests, (c) low-damage clear.
4. Spend coins/feathers in the **shop**: weapons (stats + specials), skins (level up with use → melee power multiplier), abilities.
5. Replay levels for full medals; unlock the boss; next world.

## 3. Player verbs & game-feel (the "better than Apple Knight" part)
- Run (touch d-pad), **jump / double-jump**, fall, **melee attack** (3-hit combo chain on repeated taps), **apple throw** (arc projectile, limited ammo), interact.
- Feel spec (all tunable constants in `lib/game/tuning.dart`):
  - **Coyote time** 0.10s; **jump buffer** 0.12s; variable jump height (release to cut).
  - Attack input buffered 0.15s; hit-pause 40ms on connect; small screen-shake on kills.
  - Landing dust, footstep particles — pooled, capped.
- Camera: smooth-damped follow, look-ahead in facing direction, **hold-down to peek below** (AK pain point fixed).

## 4. Systems
- **Health:** 3 hearts (upgradable +2); enemy contact/hazard = 1 heart, i-frames 1s + knockback.
- **Currencies:** coins (common), **feathers** (rare, 1–3 hidden per level) for premium shop items.
- **Chests:** N per level, tracked on HUD (`2/7` style); secret rooms behind cracked walls / hidden passages.
- **Enemies (World 1):** Thornling (patroller), Ashbat (sine flyer), Ember Totem (ranged spitter), Rotshield (blocks front, hit from behind/above) + **Grove Golem** boss (3 phases, telegraphed).
- **Weapons:** damage / range / crit% / crit damage + one **special** each (e.g. *Wind God's Hammer*: triple jump; *Ember Fang*: burn DoT; *Warden Blade*: +1 heart). Bought with coins/feathers, no rentals.
- **Skins:** cosmetic + slow "skin level" growth from kills → small melee power multiplier (e.g. ×1.03). Never purchasable power beyond this gentle curve.
- **Abilities:** passive slots (magnet radius, +apple cap, cheaper shop, chest radar ping).
- **Quests (post-alpha):** daily "kill X / collect Y" for feathers — AK doesn't have this; retention without FOMO (quests never expire mid-progress).
- **Tutorial:** Level 1-1 teaches move/jump/attack/throw via signposts + safe layout (promise made to Play testers — release blocker).

## 5. Content plan
- **World 1 "Emberwood"** at alpha: 5 levels + boss arena; ≥2 secrets and 2–7 chests per level; par times for medals.
- Level format: ASCII tile grids + entity legend in `assets/levels/*.txt` (headless-parseable, unit-tested, diff-friendly). Worlds 2–3 (Cinder Caves, The Delve) later.

## 6. Performance budget (2GB Android phone)
- 60fps steady in `--release`; frame budget 16ms: physics ≤2ms, rendering via sprite atlases/batching.
- Object pooling: projectiles, particles, coins. Zero allocations in `update()` hot paths (no closures/lists per frame).
- Texture atlases per world; audio pre-cached at level load; total APK ≤ 60MB.

## 7. Monetization & ethics (binding)
Free. Optional one-time supporter IAP later. Rewarded ads **only** if owner asks, always opt-in ("get rewards" chest style), never interstitials. Banned: energy timers, decaying streaks, FOMO-expiring content, loss-framed notifications, pay-to-win.

## 8. Release targets
- `v1.0.0-alpha.1`: M1–M6 complete, World 1 playable end-to-end, tutorial in, CI signed APK, GitHub prerelease, Play closed-track update.
- `v1.0.0-beta`: quests, 2nd world start, balance pass from tester feedback.
- Production application: after Play 14-day gate (~2026-08-07).
