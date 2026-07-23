# Checkpoint 02 — Flutter full game (2026-07-23)

## What exists now (solo build, no subagents, owner-directed)
- **Stack = Flutter/Dart** (owner pivot). Sim core is a sealed pure-Dart library
  `lib/sim/` (rng, hashing, map_gen, combat, run_layer, relic_hooks, sim,
  autoplay). Lua→Dart port proven 1:1 (golden 311044885 at pivot commit).
- **Sim v3 (SIM_VERSION=3):** full game systems — gold economy, shops
  (die/relic/heal, tier-gated), 16-event deck (effect vocabulary; events never
  kill — hp floors at 1), 22 relics (additive hook vocabulary resolved in
  combat + run layer), forge at rests, tiered/eligible rewards, 4 characters,
  ascension ladder (deterministic additive scaling), fair-death insight payout.
- **Content:** 31 dice, 15 enemies (fromLayer gating), 22 relics, 16 events,
  4 characters. All data-only (`lib/data/*.dart`).
- **Meta layer** `lib/meta/` (OUTSIDE sim): embers/unlocks/best-ascension/stats
  via path_provider; endowed-progress unlock bar.
- **UI** `lib/ui/` + `lib/game/controller.dart`: title, character/unlock, map
  (node graph + edges painter), combat (intent badge, dice tray, assign/reroll/
  end), reward (smart-default RECOMMENDED), rest+forge, shop, event, summary
  (gains-first ledger + insight). Design tokens from `docs/design-system.md`
  (UXPeak psychology + typography laws). Autosave every eventful apply +
  resume-on-boot.
- **Tests:** `flutter test` — 25 green: sim (determinism/rules/persistence/
  golden v3=513683311), map (200-seed properties), content (schema), autoplay
  (band 20-80% + ascension monotonic), widget smoke. `flutter analyze` clean.
- **CI:** `.github/workflows/ci.yml` → analyze + test → `flutter build apk`.

## Key decisions
- Golden v3 = 513683311 (seed 20260723, greedy bot). Re-anchor ONLY after
  deliberate balance changes; bump SIM_VERSION on any sim behavior change.
- Balance (greedy autoplayer): default Kindler 51.7%, overall 53.5%. Specialist
  chars warden/ascetic ~85% (unlock rewards; ascension + human play add
  challenge) — acceptable first pass; tune in a later content patch if desired.
- Events never kill; no timers/FOMO/fake progress (spec §Ethics + UXPeak ethics).
- Meta feeds sim ONLY via two scalar start_run params (character, ascension).

## Open / OWNER-GATED
- On-device install + playthrough (M1-3) and UI screenshots — need emulator/
  device. Build path ready via CI.
- CI green run + APK artifact (M2-3) — confirm after push; Actions billing /
  repo visibility owner-gated.
- IAP full-unlock, GPGS cloud save, Play closed test, real art/audio (M4 / paid
  assets need owner budget approval).
