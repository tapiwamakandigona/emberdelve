# STATE.md — live build state for any AI/human resuming

**Read order for resuming:** this file → `PROJECT.md` → `docs/spec.md` →
`docs/m3-contract.md` → tail of `progress.md` → `features.json` → `git log --oneline -20`.
Then `./init.sh` (installs Flutter, runs `dart test`).

## Current stage (2026-07-23)
Milestone **M2/M3 combined build**, owner-directed solo (no subagents).
Owner instructions this session (DM 2026-07-23):
1. "make the complete game no sub agents on your own"
2. "remember we making this using flutter" → **STACK PIVOT: Flutter/Dart**,
   superseding the earlier Defold decision (PROJECT.md standing decision #1).
   Rationale: consistency with owner's other apps (lanlink, quick bucks are
   Flutter). Defold shell removed in commit `54f2e85`; git history preserves it.
3. "learn from uxpeak" (channel, multiple videos) → design principles distilled
   into `docs/design-system.md`, applied to the Flutter UI.
4. Keep state discoverable for other agents (this file).

## What is DONE and VERIFIED
- **Sim core ported Lua→Dart**, `lib/sim/` (rng, hashing, map_gen, combat,
  run_layer, sim). Parity was PROVEN at the pivot commit (54f2e85): a parity
  dump diffed 1:1 against the Lua reference — golden `event_hash=311044885`,
  identical terminal (phase, event_hash) for all 100 autoplay seeds (59W/41L),
  snapshot/restore twins identical. (The one-off `bin/parity.dart` prover was
  removed after it served its purpose — `flutter analyze` is fatal on its
  `print`s; the git history at 54f2e85 preserves it.) Any sim change must be a
  deliberate SIM_VERSION bump with a re-anchored golden (v3 golden 513683311).
- **Flutter app scaffolded** (`lib/`, `android/`, `pubspec.yaml`), fonts
  Cinzel + Inter (OFL) bundled, `path_provider` for saves.
- **M3 content data** authored (data-only, zero logic): `lib/data/dice.dart`
  (31 dice, tiers + forgeTo), `enemies.dart` (15: 9 regular, 5 elite, 1 boss,
  fromLayer gating), `relics.dart` (22, hook vocabulary), `events.dart`
  (16, effect vocabulary).
- **Design system** `docs/design-system.md` (UXPeak-derived).

## What is IN PROGRESS
- Sim v3 (SIM_VERSION→3): gold economy + shop + forge + events + relics +
  tiered/eligible rewards + insight-on-death, then meta layer (embers→unlocks,
  ascension) in a separate save namespace.
- Contract doc `docs/m3-contract.md` (frozen interface for v3) — WRITE THIS
  alongside the code; it governs commands/events/state shape.

## What is NOT STARTED
- Flutter UI screens (title, map, combat, shop, event, rest/forge, reward,
  summary, meta/unlocks) per design-system.md.
- Dart test suite port + autoplayer balance pass (win band 20–80%).
- CI rewrite: `dart analyze` + `dart test` gate → `flutter build apk`.
- features.json M2/M3 entries; checkpoint 02.

## Key decisions & reasoning (append as you go)
- Stack = Flutter/Dart (owner override, see above). Sim stays a **sealed pure
  Dart library** (no Flutter imports) so it runs under `dart test` headless and
  stays deterministic — same seam discipline as the Lua era.
- Hashing port emulates Lua's `tostring(key)` sort exactly (lists hashed as
  keys "1".."N" sorted lexicographically) so hashes match the Lua golden.
- Map/enemy/dice numbers UNCHANGED from M1 to preserve the golden during the
  port; NEW systems (gold/shop/events/relics/forge) will bump SIM_VERSION and
  re-anchor the golden deliberately.
- Ethics blacklist (spec §5) is binding: events never kill (hp floors at 1),
  progress bars never fake, no timers/FOMO. UXPeak psychology applied honestly.

## Owner-gated / blocked items (need owner, do NOT self-approve)
- Device install test (M1-3/M1-4 evidence), Play Console upload, IAP wiring,
  paid art/audio purchases, flipping repo private (Actions billing).

## UPDATE 2026-07-23 (checkpoint 02 — Flutter full game complete headlessly)
Everything below "NOT STARTED" in the original list is now DONE:
- Sim v3 systems (gold/shop/events/relics/forge/characters/ascension/insight) — DONE, committed.
- Meta layer (lib/meta/) — DONE.
- Full Flutter UI (lib/ui/, lib/game/controller.dart) — all 9 screen types — DONE.
- Dart tests + autoplay balance — DONE (25 tests green, 53.5% win band, deterministic).
- CI rewritten for Flutter (analyze+test+build apk) — DONE and **CONFIRMED GREEN**:
  run 30004629450 (commit 2ed37a1), both jobs success, debug APK artifact
  `emberdelve-debug-apk` (89.2MB) produced.
- features.json M2/M3 entries + checkpoint 02 — DONE.
Golden v3 = 513683311. `flutter test` is the gate. See checkpoints/02-flutter-full-game.md.
Remaining = OWNER-GATED only: on-device playthrough + screenshots (install the
CI APK artifact from run 30004629450), IAP full-unlock, GPGS cloud save, Play
closed test, paid art/audio, flip repo private once Actions billing is fixed.
