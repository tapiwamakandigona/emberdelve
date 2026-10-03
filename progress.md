# progress.md — append-only log (segment 2)

Segment 1 (2026-07-23 to 2026-10-03 09:45 UTC, 502,217 bytes) was moved
verbatim to `archive/progress-segment-1.md` because it had grown far past the
64 KiB boot budget (subagent-toolkit `HARNESS.md`: rotate past 64 KB, verbatim,
with a SHA-256 link). Its SHA-256 is
`d1b232abfd6cb06bbae45b9ba6010bee1534e7ef7477380ce8f02352267ac8e0`.
Older references to "progress.md" in code comments, tests and docs mean that
archive. Never edit archived entries; append new ones here.

## 2026-10-03 — 0.186.0 "Clear Choices" published on GitHub

- VERIFIED: the read-only review of #125/#126 passed with no blocking
  findings. The signed CI artifacts of run 37114318037 checked out
  independently (package, versions 219/1219/2219/4219 and AAB 219, signer
  pin, not debuggable). v0.186.0 is published as the latest release, tagged
  at the built commit `2a553ad`, and an unauthenticated asset download
  matched its SHA-256. Details and every hash are in
  `docs/release-0.186.0/progress.md` (iteration 2).
- Play is on hold by my decision of 2026-10-03 14:33 UTC. No Play call was
  made.
- Deferred minor review findings for the next pass:
  `test/victory_moment_test.dart:253` (silent skip when the hero keys are
  missing) and `heroEnvelope` measured on the kindler only.
