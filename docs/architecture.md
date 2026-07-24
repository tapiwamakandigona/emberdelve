# Emberdelve v2 — Architecture (platformer)

Flutter + Flame. Interfaces below are the integration contract — change only with a note in `progress.md`.

## Module map
```
lib/
  main.dart              # boot → TitleScreen (Flutter routes own the meta UI)
  core/
    rng.dart             # seeded streams (kept from v1)
    save.dart            # JSON save file via path_provider; atomic write + .bak (kept pattern from v1)
  audio/                 # AudioService (kept from v1): music loops + sfx one-shots, settings
  game/                  # Flame: everything inside a level run
    ember_game.dart      # FlameGame subclass; owns level lifecycle, camera, HUD wiring
    tuning.dart          # ALL feel constants (jump, coyote, buffers, speeds)
    level/
      level_data.dart    # ASCII grid parser → tiles + entity spawns (pure Dart, unit-tested)
      level_component.dart
    player/              # player component: state machine (idle/run/jump/fall/attack/hurt)
    enemies/             # one file per enemy; shared EnemyComponent base
    objects/             # coin, apple, chest, spikes, door, sign, feather, cracked wall
    hud/                 # joystick/d-pad, buttons, hearts, counters (Flame HUD components)
  meta/
    economy.dart         # wallets, prices, transactions (pure Dart, unit-tested)
    catalog.dart         # weapons/skins/abilities data (stats, specials, prices)
    progress_state.dart  # per-level medals/chests/secrets; unlock rules
  ui/                    # Flutter screens: title, world map/level select, shop (3 tabs),
                         # settings, credits, pause + results overlays
assets/
  levels/w1_l1.txt …     # ASCII levels
  images/… audio/…       # atlases, sprites, music/sfx (CC0/CC-BY only — PROVENANCE.md)
```

## Key contracts
- **LevelData.parse(String ascii) → LevelData**: throws on malformed grids; exposes `solidAt(x,y)`, spawn list, chest/feather counts. Pure Dart. Every shipped level has a parse + lint test (reachable exit, counts match HUD totals).
- **Physics:** AABB sweep vs tile grid, fixed substeps; constants only from `tuning.dart`. Pure-Dart resolution functions unit-tested headlessly.
- **Player state machine:** explicit enum states; inputs come through an `InputIntent` struct (dpad, jumpPressed/held, attackPressed, throwPressed) so touch/keyboard/tests share one path.
- **Save schema v2** (`core/save.dart`): `{version, wallets:{coins,feathers}, ownedWeapons[], equippedWeapon, ownedSkins[], skinLevels{}, equippedSkin, abilities[], levels:{id:{medals,chests,secrets,bestTime}}}`. Migration: legacy v1 dice saves → carry nothing but grant a small coin bonus (fresh game).
- **Flame/Flutter seam:** Flame runs only during gameplay (`GameWidget` route). All meta screens are plain Flutter. Overlays (pause/results) via Flame `overlays` API.

## Performance rules (binding, see spec §6)
- Sprite atlases per world; `SpriteBatch`/`SpriteAnimationComponent` reuse; pool projectiles/particles/coins.
- No allocations in `update(dt)` hot paths; cache `Vector2`s; avoid per-frame `List` growth.
- Enemies sleep (skip update) when > 1.5 screens from camera.

## Testing
`flutter test` gates CI: level parser + linter, physics resolution, economy/save round-trip + migration, catalog integrity (prices/specials), widget smoke tests for every screen, tuning sanity (jump clears 2 tiles, double-jump clears 3.5).

## Kept from v1 (verified worth keeping)
- CI + signing workflow (`.github/workflows/ci.yml`) — untouched signing plumbing.
- `AudioService` + settings; music/sfx assets (retagged in CREDITS).
- Seeded RNG streams; atomic save + backup pattern; package id.
Legacy dice sim/UI: archived on `legacy/dice-builder`, deleted here.
