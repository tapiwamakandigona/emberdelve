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

## Archetype gap analysis (2026-09-01, complete)

Occupied identities, by what DEFINES the start: balanced (kindler),
tank+guard die (warden), variance+reroll (gambler), glass cannon
(ascetic), fight economy (peddler), consistency floor (tinker),
four-small swarm (flintwright), pre-marked surge (runesmith),
two-dice giant + echo (bearer), mend-on-worst-face healer (mender),
deep aegis ward (shieldwright), gilt coin (gilder), blade+aegis mixed
marks (cutler), fully-worked pool (collier), all-heavy d8s (stoker),
all-forged sworn dice (hearthkeeper).

Every start rune is spoken for (surge/echo/mend/aegis/blade/gilt all
appear in someone's startTempers). Every DICE-SHAPE extreme is taken
(2 giant / 4 small / all-heavy / all-forged). What is genuinely open,
using existing pieces only (simVersion stays sealed):

1. **Retaliation** — `thorn_band` ('Attackers take 3 damage', mods
   {'thorns': 3}) exists, is fully simmed, and NO delver starts with
   it. Damage you deal by BEING hit is a real identity the roster
   lacks: it inverts the block calculus (an unblocked hit is no
   longer pure loss) — a genuinely different decision texture, not a
   stat reshuffle. ← DELVER #17.
2. **Mixed extremes** — one d12 + two d4s (millstone and sparks);
   bearer is two dice, flintwright four small, nobody straddles.
   ← candidate #18.
3. **Rest economy** — `bedroll`/`hearth_kettle` start (the delver who
   delves slow); interacts with the rest-forge lane. ← candidate #19.

## Delver #17 spec — THE HEDGER (thorn identity)

- id `hedger`, name 'The Hedger' — the hedge-layer, a real old craft:
  the one who weaves thorn walls. Fits the trade-name register of the
  roster (collier, cutler, stoker...).
- text (≤ card budget): 'The thorn-layer: a Thorn Band and plain
  Ember Dice — every blow against them is answered.'
- startDice ['d6','d6','d6'], startRelic 'thorn_band', no marks. The
  kindler comparison IS the design: same pouch, but the relic changes
  what a hit means. Distinct from warden (block-shaped) because the
  hedger WANTS contact priced in, not prevented.
- maxHp: **20 — SWEPT AND SETTLED** (tool/hedger_sweep_probe_test.dart,
  400 seeds): HP 29 → 93.75/80.25/58.75 (thorns is strong), HP 22 →
  90.75/69.25/47.75 (easy+hard over band), **HP 20 → 89.25/65.50/43.00
  — all three bands hit** (easy 80–90 / normal 55–70 / hard 30–45)
  [sweep, 2026-09-01]. The hedge is sharp, not thick: lowest HP but
  the stoker. Tuned ONLY via HP per roster doctrine.
- unlockEmbers 2250 (curve continues +150; honors never re-price).
- Sprite: knight_m base (armored silhouette reads as the wall) with a
  new hue family — must read distinct next to warden/flintwright/
  bearer/shieldwright at 56dp; plate critique required.
- Fiction: FIRST delver of the second circle — new tales/codex say a
  second circle opened at the hearth; the first fire's sixteen chairs
  and 'sixteen ways down' stay exactly as published. No shipped words
  edited. (Owner may veto the framing; nothing published until the
  next release anyway.)
- Full lane checklist per the completeness bar above; pipeline files
  to mirror: hearthkeeper_test.dart + hearthkeeper_sweep_probe_test
  (every delver since v0.145 has both).
- **Exact def (proven by sweep; wiring reverted to keep the branch
  green — re-apply when all lanes land together):** charactersOrder
  appends 'hedger' after hearthkeeper under a SECOND CIRCLE comment
  block; map entry: CharacterDef('hedger', 'The Hedger', 'The
  thorn-layer: a Thorn Band and plain Ember Dice \u2014 every blow
  against them is answered.', maxHp: 20, startDice: ['d6','d6','d6'],
  startRelic: 'thorn_band', unlockEmbers: 2250).
- **The suite's own lane list** (from running with the def wired —
  these are the tests that must move with the roster, each one a work
  item): amethyst 'stands last' pin, assets sprite_meta + sheet,
  crowned-company target 16→17, deep-wardrobe six_handed target,
  delve-code round-trip-every-delver + v2 founding-16 expectation
  (parameterise on charactersOrder.length, not literal 16),
  fourth/sixth-cycle tale facts ('sixteen answers' style counts —
  tale WORDING stays, tests must pin the first circle explicitly),
  hearthkeeper 'stands last' pin, honest-ledger whole-catalog
  promises, named-company codex coverage in roster order, runesmith
  roster-growth contracts, tenth-chair vista pin. Plus new: weapon
  def, sprite row/hue, codex entry, <id>_wins achievement, proving,
  tale(s), hedger_test.dart, delve-code index-16 round-trip.

## Sequencing

1. ✅ Delve-code v2 — the enabler, zero player-visible change until a
   17th delver exists.
2. ✅ Archetype gap analysis (above): retaliation is #17; mixed
   extremes and rest economy queued as #18/#19 candidates.
3. Second-circle fiction: proposed above, additive-only; owner can
   veto before release (freeze holds regardless).
4. Build THE HEDGER complete per the bar; then #18+ only after #17
   proves the pipeline.
5. Seven Hearths retention pairing is ALREADY SHIPPED (v0.178.0) —
   the DEMAND's "reason to return across days" box is ticked; do not
   double-build it.

## Constraints inherited (not negotiable)

No ads / analytics / telemetry / timers / dark patterns; content
ships complete; freeze holds — build on branch, no tag, no release,
no Play submission until the owner says so.
