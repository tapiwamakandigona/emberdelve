# Performance notes (P-M7)

Status legend: **VERIFIED** = measured/audited with evidence in this repo.
**OPEN** = requires real hardware; cannot be honestly measured in a headless
CI/sandbox environment and is deliberately left unclaimed.

## 1. Allocation audit — `Session.update` hot path (VERIFIED, code audit)

Audited 2026-07-25 against `lib/game/session.dart` and everything it calls per
frame (`PlayerCore.update`, every `EnemyCore.update` incl. boss, `physics.dart`).
Method: exhaustive read of the update call graph + pattern grep for
allocation sites (`List(`, `List.from/of`, collection literals, `map/where/
firstWhere/toList`, `cast<>`, `Vector2(`, spreads, string ops).

Findings and resolutions:

| Site | Frequency | Resolution |
| --- | --- | --- |
| `PlayerCore.takeEvents()` copied `_events` even when empty | every frame | fixed: returns `const []` when empty |
| `LevelSession.takeEvents()` / `takePlayerEvents()` same pattern | every frame (Flame layer calls both) | fixed: `const []` fast path |
| `tileAt` instance tear-off passed to `e.update(...)` (tear-offs allocate a fresh closure per evaluation) | per enemy, per frame | fixed: cached `late final TileQuery _tileQuery` |
| `_applePool.cast<...>().firstWhere(...)` (CastList + closure) | on throw press only | fixed anyway: plain loop, zero-alloc |
| `_emberPool.cast<...>().firstWhere(...)` | on totem shot request only | fixed anyway: plain loop, zero-alloc |
| `SessionEvent` / `CoinEntity` / FX objects | event-driven (hits, pickups, chest bursts) | acceptable by design; bounded by `kMaxLiveParticles`/`kMaxPooledProjectiles` pools |
| `attackHitbox` record | per frame only during the 60% damage window of a swing (~10 frames) | acceptable: single small record, event-bounded |

Steady-state result: **zero per-frame allocations** in the pure-Dart sim while
idle/walking/jumping; allocations occur only on discrete gameplay events.
Enemy/player/physics update bodies were already allocation-free (they mutate
pre-built `Body`/state objects; projectiles and coins are pooled or reused).

Note: the Flame render layer (`components/`) draws HUD readouts procedurally
(`Vector2` temporaries in `HudReadout.render`). That is outside the
`Session.update` acceptance scope; revisit only if a device trace shows GC
pressure from render.

## 1c. Sim hot-path cost — measured (VERIFIED, headless benchmark)

`test/session_bench_test.dart` drives the door-seeking bot through the two
worst levels while timing every `LevelSession.update` (VM JIT, sandbox CPU,
warmup excluded; 2026-07-25):

| Level | n | avg | p50 | p95 | p99 | max |
| --- | --- | --- | --- | --- | --- | --- |
| `w1_l5` (densest) | 2022 | 23.4 µs | 15 µs | 37 µs | 123 µs | 1.55 ms |
| `w1_boss` (all phases) | 3516 | 6.3 µs | 3 µs | 10 µs | 75 µs | 0.95 ms |

The pure-Dart sim uses ~0.1–0.2% of the 16 ms frame budget — frame cost on
device will be dominated by build/raster, not gameplay logic. The test also
acts as a **regression guard** (generous bounds: avg < 2 ms, p99 < 8 ms);
if it ever fails, something expensive landed in the hot path. Device AOT
numbers will differ, but the order of magnitude carries.

## 2. Frame budget on 2GB-class device — **OPEN**

Acceptance requires a profile-mode timeline (`flutter run --profile`) on real
or emulated low-end hardware for `w1_l5` and `w1_boss`, avg frame
build+raster ≤ 16ms. The CI sandbox has no GPU/device; running an Android
emulator headlessly would not produce honest raster numbers. **Not claimed.**
How to run when hardware is available:

```
flutter run --profile
# DevTools -> Performance -> record w1_l5 full run + w1_boss all 3 phases
# record avg/max build and raster times here
```

## 3. Cold start ≤ 3s — **OPEN**

Same constraint: needs a physical device stopwatch/`adb shell am start -W`
measurement. Not claimed.

## 4. APK size / split-per-abi / tree-shake-icons — decision

- CI already builds with `--release`; icon tree-shaking is **on by default**
  for release builds since Flutter 3.x (MaterialIcons subset only).
- Universal APK at v1.0.0-alpha.1: **36.8 MB**; AAB: **55.8 MB**.
- **Decision: ship the AAB to Play (Play serves per-ABI splits automatically),
  keep the universal APK on GitHub releases for sideloading testers.**
  `--split-per-abi` on the GitHub artifact would roughly halve sideload size
  but triples artifact count and confuses non-technical testers picking the
  wrong ABI; the Play pipeline already gets split benefits from the AAB.
  Revisit only if the universal APK passes ~60 MB.
