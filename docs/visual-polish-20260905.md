# Codex readability — visual PR, not a release

## Plan

The Codex is a reading surface, but its prose uses the same 11px treatment as
tiny counters. Its section links are 11px gesture targets with no visible
selected state. Keep the existing warm palette and unsealed/locked mechanics.

- Use 13px Inter labels with 1.5 line height for reading text.
- Give the section strip keyboard-focusable 48px-high buttons, a visible
  last-chosen section, and matching selected semantics.
- Retain the existing eight anchors, lazy-list navigation and purchase logic.
- Retain every existing test. Add targeted size/semantics/contrast tests.
- Capture real-font headless plates at 360×800 and 320×568 with 1.3× text,
  before and after, on the existing public repository's standard runner.
  The additive test emits PNG chunks only on this review branch; recover them
  from the existing public CI log. No workflow file needs modification.

## Definition of done

Analyzer, full existing suite, added checks and SFX headroom pass; before/after
artifacts exist; no sim, asset, payment, version or release changes. A render
artifact is not a physical-device usability test. A PR is not deployment.

## Evidence

Pending public CI and artifact inspection. No completion claimed.

## Verification-plan correction before retry

The managed push rejected a new workflow:
`refusing to allow a GitHub App to create or update workflow
.github/workflows/visual-review.yml without workflows permission`.
Removed that unpushed file. Use the existing full-suite command with additive
capture tests. First push retains baseline UI for before plates and intended
red readability tests; then apply the proposed source to the same branch.
Existing tests and checks remain read-only.
