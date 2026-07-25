# Checkpoint 00 — Foundation (M0)

**Date:** 2026-07-23 · **Phase:** Foundation · **Decision: GO — COMPLETE.** CI green: https://github.com/tapiwamakandigona/emberdelve/actions/runs/29990121111

## Decisions + reasons
- Name **Emberdelve** (owner pick from collision-checked candidates), package `com.tsorostudios.emberdelve`.
- Private repo intended; **Actions blocked on private repo (billing)** → repo flipped PUBLIC temporarily (safe: zero licensed assets, all own code; pre-authorized by owner). Flip back private once owner enables Actions billing for private repos, or split a public compile repo.
- Spec [HUMAN GATE] satisfied by owner's explicit approvals on 2026-07-23 (name, mechanic=dice-builder, monetization, green light) on top of the 5-track research synthesis; `docs/spec.md` codifies it.
- Architecture written and frozen by orchestrator directly (held full research context; delegation would have lost it). Foundation built by orchestrator: tightly-coupled single-artifact scaffold per toolkit "when NOT to multi-agent" rule. M1+ uses subagent swarms.
- Golden determinism hash captured in CI logs at first green run; anchor via EMBERDELVE_GOLDEN env in later milestones.

## Artifacts
`PROJECT.md`, `features.json`, `progress.md`, `init.sh`, `docs/spec.md`, `docs/architecture.md`, `sim/{init,rng,combat}.lua`, `tests/run_tests.lua`, `main/`, `.github/workflows/ci.yml`.

## Resolution (2026-07-23)
- CI run **29990121111** fully green: `test` 12/12; `build-android` bundled debug APK via bob 1.13.0 on JDK 25.
- Artifact `emberdelve-debug-apk` (ID 89150834647): 29.6 MB APK, ABIs arm64-v8a + armeabi-v7a, AndroidManifest + classes.dex + Defold archives (game.arcd/arci/dmanifest) verified by download+inspection.
- Golden hashes: event_hash=158933364, state_hash=387435555 (bit-identical lua5.1/5.4/luajit2.0/2.1).
- CI operational learnings: `build/` is reserved by bob → bundle to `dist/bundle`; fine-grained-PAT pushes never trigger `push` workflows → dispatch with `gh workflow run CI --ref main`; PAT can't read check annotations (403) → use `gh api .../actions/runs/<id>/jobs`.

## Open items (carried to M1)
1. Manual APK install smoke test on owner's phone (required in M1).
2. Repo visibility endgame: owner to enable private-repo Actions billing OR keep public until licensed assets arrive.
3. M1 planning: map generation, content-as-data schema, autoplayer, monarch/druid/defold-saver integration — delegate to ultra subagents per toolkit lifecycle.
