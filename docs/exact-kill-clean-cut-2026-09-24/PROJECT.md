# PROJECT.md — Exact-Kill "Clean Cut" (2026-09-24)

One presentation-only feel feature, requested by the owner (Viktor app,
2026-09-24, Tapiwa): *"improve the models and animations to be more enjoyable"*
plus a test APK.

## Why this, on an all-green tree

The Sept-13 combat critique's P1 items (contact-timeline sync A3/A4, hand-socket
metadata, all-22 articulation) are already shipped and green
(`combat_presentation.dart`, `combat_contact_timeline_test.dart`, roster-sep18).
The feel backlog (`docs/improvements/combat-feel-research.md`) is closed. So the
next honest gain is *additive*, not a red-gate fix.

Gap found: the game's signature tactic — spending a die for **exactly** lethal
damage (drop the foe to 0, not below) — paid off only as a floating `EXACT!`
call-out. The killing blow read identically to a sloppy overkill at the body
layer. Design-system §5: *"visible mastery is presentation, not math."* So an
exact kill now earns a distinct contact read.

## What shipped

`CleanCutFlash` (lib/ui/weapons.dart): a crisp ember-white ring snaps outward and
a four-point glint flares at the contact point, then both fade (440 ms). Spawned
via the existing contact-FX system (`_FxKind.cleanCut`) on the `exact_kill` event
only.

## Standing decisions / boundaries

- **Presentation only.** `lib/sim/` and its hashes are untouched — VERIFIED:
  `git diff` touches four `lib/ui/` files only.
- **Non-blocking.** Spawned without an `await`, so the death choreography's
  timing is unchanged and the contact-timeline contract is preserved.
- **Reduce-motion.** Like `ImpactSlash`/`GuardFlash` it carries information and
  always plays; screen displacement stays in `ShakeBox`, which self-gates.
- **Scope.** Only the exact kill gets it. Ordinary kills and overkills untouched.
- **Source PR only.** No merge, release, version bump, signed store dispatch or
  Play action. Owner aesthetic approval is pending — see the test APK.

Single executor, plan → act → verify → commit, one task. Claims labelled
VERIFIED/ASSUMED.
