# Checkpoint 00 — Foundation (M0)

**Date:** 2026-07-23 · **Phase:** Foundation · **Decision: GO** (pending CI green — see open items)

## Decisions + reasons
- Name **Emberdelve** (owner pick from collision-checked candidates), package `com.tsorostudios.emberdelve`.
- Private repo; CI on private free minutes (2,000/mo); public build-repo split deferred until minutes become a real constraint (YAGNI; licensed assets stay private either way).
- Spec [HUMAN GATE] satisfied by owner's explicit approvals on 2026-07-23 (name, mechanic=dice-builder, monetization, green light) on top of the 5-track research synthesis; `docs/spec.md` codifies it.
- Architecture written and frozen by orchestrator directly (held full research context; delegation would have lost it). Foundation built by orchestrator: tightly-coupled single-artifact scaffold per toolkit "when NOT to multi-agent" rule. M1+ uses subagent swarms.
- Golden determinism hash captured in CI logs at first green run; anchor via EMBERDELVE_GOLDEN env in later milestones.

## Artifacts
`PROJECT.md`, `features.json`, `progress.md`, `init.sh`, `docs/spec.md`, `docs/architecture.md`, `sim/{init,rng,combat}.lua`, `tests/run_tests.lua`, `main/`, `.github/workflows/ci.yml`.

## Open items
1. CI run on main must go green (test + build-android) — M0-4/M0-5 evidence.
2. Manual APK install smoke test on a real device (owner's phone) — nice-to-have for M0, required in M1.
3. M1 planning: map generation, content-as-data schema, autoplayer, monarch/druid/defold-saver integration.

## Next step
Push to main → verify Actions → flip M0 features with evidence → plan M1 task list (`../prompts/artifacts/task-list.md` template) → delegate M1 builds to subagents.
