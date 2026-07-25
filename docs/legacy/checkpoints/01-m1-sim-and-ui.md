# Checkpoint 01 — M1 sim v2 + full UI (2026-07-23)

## What exists now
- sim v2 (SIM_VERSION=2): sim/init.lua (dispatch/hash/persistence, run.post after every cmd), sim/run.lua (map position, node entry, rewards via loot stream, rest, ledger, terminal phases), sim/combat.lua (encounter layer only; combat.begin seam; sets sim.combat_over, never touches phase), sim/map.lua (pure layered map gen), data/dice.lua (12) + data/enemies.lua (7, _order arrays).
- Command set v2: start_run, choose_node, roll, assign, end_turn, choose_reward, rest (start_encounter REMOVED).
- UI: main/game.lua + game.gui_script (6 screens, programmatic nodes), sys.save/sys.load autosave after every eventful apply, resume-on-boot; input/game.input_binding touch.
- Tests: run 18, map 12, content 21, autoplay (100 seeds, win-band 20-80%, snapshot twin-hash). All in CI with EMBERDELVE_GOLDEN=311044885.

## Key decisions
- Enemy damage x2.75 balance pass (measured, see progress.md). Don't scale HP up for difficulty - blocking bots get stronger.
- Events added in M1: enemy_blocked{enemy,amount,enemy_block}; damage_dealt.blocked=N; invalid reason "encounter_over" after combat_over.
- Content tests must reference data module values, never hardcode balance numbers.
- Golden hash re-anchored ONLY by orchestrator, AFTER balance changes settle.

## Open for M2+
- M1-3/M1-4 need device evidence from owner (install APK, full run, kill+resume).
- Repo still public (Actions billing); flip private when resolved.
- Balance is bot-calibrated; human playtesting may want a gentler early curve (cinder_wisp now hits 11/14/8 vs 30hp).
