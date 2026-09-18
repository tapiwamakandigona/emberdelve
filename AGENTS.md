# AGENTS.md — Emberdelve

Adapted from canonical subagent-toolkit v3.0.1 templates/AGENTS.md.

## Project

Emberdelve is a portrait, offline-first Android dice roguelite.
Stack: Flutter 3.44.9 / Dart 3.12.2. Shipping branch: legacy/dice-builder.
Main is the frozen former platformer; do not develop there.

## Commands

```bash
flutter pub get
flutter analyze
flutter test
python3 tool/sfx_headroom.py
python3 tool/art/build_delvers.py --check
flutter run
```

## Structure

- `lib/sim/` — sealed deterministic pure-Dart simulation; preserve it.
- `lib/ui/` — presentation and choreography; `assets/` — shipped art/fonts.
- State: `PROJECT.md` (decisions), `features.json` (definition of done),
  `progress.md` (append-only log). Read these first every session.
- Current scoped state: `docs/roster-sep18/PROJECT.md`, `features.json`,
  `progress.md`. Preserve previous root feature criteria and evidence.

## Boundaries

**Always:** commit after each verified task; update `progress.md`;
run the relevant checks before marking anything done; open browser logins as
6-hour sessions (SDK: `get_browser(name, timeout_seconds=21600)`) and
reconnect to one named session instead of re-creating it.
Use the managed Git/GitHub integration for all Git operations and authorship.
One executor, no subagents. Plan → act → verify → commit, one task at a time.
Label claims VERIFIED or ASSUMED. Halt after two no-diff iterations.

**Ask first:** destructive actions, money, missing credentials, ambiguity.

**Never:** weaken tests/checks, alter sealed simulation or purchase logic;
commit secrets; force-push; merge PRs; cut a release without authorization.
Generated assets are reproducible outputs, not a place to patch over checks.

## Deeper docs

- `docs/reviews/combat-art-depth-critique-2026-09-13.md` — current defects.
- `docs/design-system.md` — preserve visual identity.
- `docs/roster-sep18/PROJECT.md` — whole-roster pass's plan and hard cap.
- `docs/visual-sep17/README.md` — completed two-character base and evidence.
