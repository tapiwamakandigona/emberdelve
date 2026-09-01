# Roster expansion — answering DEMAND 2026-09-01f

The first real player words this game ever received asked for one
thing: *"Add more delvers, I need more... give mee moreee."* The DEMAND
makes content volume — delvers — the next major update. This doc is
the engineering plan: what "roster closed at sixteen" actually pinned,
how each pin is released honestly, and what a COMPLETE new delver
requires (the DEMAND's own bar: a half-finished delver is worse than
none).

## What closed the roster, and how each lock opens

1. **Delve codes — bits 31..34 full (4 bits = 16 delvers).** SOLVED
   FIRST, shipped with this doc: delve-code v2 (delve_code.dart). The
   founding sixteen emit byte-identical 9-char codes forever; a
   17th-or-later delver emits a 10-char form carrying 4 high index
   bits (256 delver ceiling) plus a reserved bit that must be zero.
   An old build handed a v2 code sees "not a code" — polite fallback,
   never a wrong delve. A v2 spelling of a v1-range delver is
   rejected: one challenge, one spelling. Pinned by the v2 suite in
   test/delve_code_test.dart against an extended fake roster — the
   encoding can never be the reason a new delver breaks old shares.
2. **Narrative: shipped tales/codex call the fire "complete at
   sixteen"** (tales.dart, achievements.dart `sixteen_ways_down`,
   epithets target 24). These are PUBLISHED player-facing words —
   never silently rewrite them. The expansion needs a fiction that
   honors them: the sixteen chairs of the first fire stay complete;
   newcomers sit at a SECOND fire (a new circle at the hearth), so
   "sixteen ways down" stays true as the first circle's honor.
   OWNER-VISIBLE design choice; flagged, not decided here.
3. **Sprite bases**: 4 bases × hue rotation currently cover 16. More
   delvers = new rows in existing sheets or new hue families on the
   4 bases (RAM-free, per the hue-rotation discipline). Audit per
   delver.
4. **Historical honors are frozen**: unlockEmbers ladder 0..2100 never
   re-prices; newcomers continue the curve upward (next steps ~2250,
   2400 — exact values with the win-rate work, not invented here).

## The completeness bar — one delver is ALL of this

Data lanes (each has append-LAST discipline and existing patterns):
- characters.dart def (id, name, text, maxHp, startDice, startRelic,
  startTempers?, unlockEmbers) — a mechanically DISTINCT identity, not
  a stat reshuffle; the archetype gap analysis comes first.
- weapons.dart WeaponDef (silhouette + accent, sway params)
- Sprite base + hue (art.dart / sprites.dart mapping)
- codex.dart entry (lore, honest mechanical hint)
- achievements.dart `<id>_wins` + roster-count achievement IF the
  fiction says a second circle opens (never edit sixteen_ways_down)
- provings.dart proving (the delver's teaching challenge)
- tales.dart hearth tale(s) (≤200 chars, escape-doubling grep after)
- epithets/ranks integration where milestone-derived
- meta: nothing — charRuns/charWins etc. are map-keyed, absent = 0;
  boot clamps and cloud merge are id-agnostic (verified in meta.dart)

Verification per delver (the guardrails, unchanged):
- Seeded win-rate bands hold: easy 80–90 / normal 55–70 / hard 30–45
  on the sim harness; fuzz clean; golden re-anchor table updated.
- Widget: title row select, character screen, ledger, summary at
  320×568→412×915 @1.3× — overflow sweep + plate critique.
- Delve code round-trip for the new index (v2 suite extends).
- Codex/achievement/proving/tale wiring tests per existing patterns.

## Sequencing

1. ✅ Delve-code v2 (this commit) — the enabler, zero player-visible
   change until a 17th delver exists.
2. Archetype gap analysis: what does the roster NOT have? (First
   pass: no debuff/damage-over-time identity; no dice-count extremes
   beyond stoker; no "changes the map" identity.) Pick 1–3 that are
   distinct BY MECHANIC.
3. Second-circle fiction proposal → owner sign-off (it touches the
   published "complete at sixteen" words).
4. Build delver #17 complete per the bar above; then #18+ only after
   #17 proves the pipeline.
5. Seven Hearths retention pairing is ALREADY SHIPPED (v0.178.0) —
   the DEMAND's "reason to return across days" box is ticked; do not
   double-build it.

## Constraints inherited (not negotiable)

No ads / analytics / telemetry / timers / dark patterns; content
ships complete; freeze holds — build on branch, no tag, no release,
no Play submission until the owner says so.
