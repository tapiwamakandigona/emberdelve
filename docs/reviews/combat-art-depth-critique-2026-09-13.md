# Emberdelve — current art, animation and depth

**13 September 2026 · Open-PR handoff, not release approval**

Reviewed the active dice-builder at `b8b24a7` / version `0.183.0+210`,
with this PR's presentation-only blood preference. Existing game art,
simulation, weapon plans and combat timings are unchanged by this PR.
The September 10 critique in [PR #102](https://github.com/tapiwamakandigona/emberdelve/pull/102)
is historical context, **not** the basis for claiming that today's game
has no weapon animation.

## The candid rating

These are **subjective design judgments**, not automated scores, player
research or a physical-device playtest. Scale: **5 = functional but visibly
unfinished; 7 = strong indie execution; 9 = exceptional, cohesive polish**.
“Realistic” here means believable weight and acting within pixel art,
not photorealistic graphics.

| Area | Now | Why |
|---|---:|---|
| **Art** | **6/10** | Recognisable ember/forge identity, strong UI contrast, and a readable roster with distinctive hats, packs and tools. The compact bodies, mixed sprite scales and clean procedural weapon/effect layers do not yet read as one fully art-directed combat scene. |
| **Animation** | **4/10** | Weapon-family motion, selection heat, hit effects, guard and HP-linked condition really exist. But the body acting is still mostly moving, rotating and stretching an idle sprite. Hands, shoulders, feet and defensive reactions do not convincingly work together. |
| **Gameplay depth** | **7/10** | There are meaningful allocation, reroll, exact-kill, route and build choices. Keystones alter sequencing rather than merely adding stats. Encounter vocabulary and demonstrated human balance are weaker than the size of the catalog suggests. |

**Bottom line:** the rules are currently stronger than their physical
presentation. Do not spend the next pass adding more particles or another
large roster batch. Make one sword fighter and one maul fighter convincingly
attack, absorb a blow and recover; then extend the proven approach.

## What was actually reviewed

**VERIFIED evidence, with boundaries:**

- Four real Flutter combat recordings: **Kindler / Ember Brand**,
  **Warden / Ward Maul**, **Gambler / Lucky Fang**,
  **Runesmith / Rune Chisel**. Shipped fonts, warmed shipped assets,
  real hit-tested controls, **360 × 640 logical pixels**. Each shows a
  face-1 attack, face-5 attack, block and enemy turn against Flue Crawler.
  Seed **1**, easy, starting boon declined. These are short controlled
  encounters, not complete human-played runs.
- **25 fps simulated-time samples**, encoded at 720 × 1280.
  That is the capture interval, **not measured device performance**.
  Native video inspection was supplemented by slowed/cropped exact frames,
  runtime observations and source inspection. No generated gameplay footage.
  Video-model observations were cross-checked: claims of “no windup” or
  “no hero wounds” were contradicted by source/pixels and are not adopted.
- An actual-render roster plate of **all 22 delvers** and separate
  blood-on/off plates with **both combatants deliberately forced to 20% HP**.
  Those injury plates are fixtures, not damage earned in the recorded fights.
- Current simulation/catalog source and **600 deterministic greedy-bot runs**:
  four characters × three difficulties × seeds 1–50.
  No human win-rate, retention or representative balance claim.
- The old interactive playthrough tool failed on unchanged base, twice.
  **Zero complete UI runs verified by that tool.** Its missing keystone
  handling is detailed below; it does not establish a player-facing softlock.
- No audio in the review clips; no listening-quality score.
  No physical phone, Play purchase/restore or complete boss-art review.

[Evidence and exact reproduction commands](blood-toggle-2026-09-13/README.md)
· [Verification, including failures](blood-toggle-verification-2026-09-13.md)

## 1. Art — preserve the identity; unify the construction

### What works

- Charcoal surfaces, restrained ember accents and readable HP/block
  semantics give the game a coherent theme. Cinzel headings and Inter UI
  make this feel like a specific forge/delve game rather than a default app.
- The roster is not simply one recolour: hats, robes, packs, shields and
  tools supply identifiable silhouettes. Preserve the stable character
  identities and ownership/unlocks rather than replacing everything.
- Clear dice and action controls serve the actual tactical game. Do not
  sacrifice that clarity to a larger combat illustration.

### Where it falls short

1. **Body construction is too similar across many delvers.** Even with
   different gear, many share a compact stance and dense dark midsection.
   Small metal/tool details compete at phone size. Give selected families
   distinct stance, shoulder line, weight and negative space—not just
   more surface texture.
2. **The layers have different visual grammars.** Shipped delver cells are
   **32 × 40**; enemy cells vary from **48 × 48 to 96 × 108**. Smooth
   vector weapon arcs, wound dabs and glows sit over nearest-neighbour
   sprite art. Different cell sizes are not inherently wrong, but the
   perceived pixel scale, edges, lighting and contact must look intentional.
3. **Too much fighting happens through distant effects.** The sampled
   short weapon motions do not make every contact across the stage gap
   physically convincing. Keep the readable arena, but author the approach,
   reach and impact origin around actual weapon geometry.
4. **Injury marks are mechanically uniform.** `woundSpots` uses the same
   normalised locations across body types. Alpha compositing correctly
   keeps the marks inside the sprite, but a mark inside opaque pixels is
   not necessarily a believable cut on that character's anatomy or armour.
   Dark marks also get lost on dark clothing.

**Next art pass:** a pose sheet and consistent material/pixel treatment
for Kindler + Warden, then a small enemy set. Review normal and wounded
silhouettes at actual phone size, in colour and greyscale, with effects
disabled. Keep the existing palette, fonts and recognisable gear.

## 2. Animation — real systems, insufficient acting

### Improvements that should not be dismissed

- `planStrike()` has six families: cut, crush, stab, stamp, hook and pick.
  The four sampled weapons use distinct arcs, contact shapes and recovery
  values. Low/high dice affect amplitude and windup. They are **not all
  literally the same slash anymore**.
- Die selection updates heat before Attack. In the recorded d6 examples,
  face 1 gives **0.2917**, face 5 **0.8583**, matching `heatFor()`.
- Block has a weapon guard phase and a body bracing transform.
  Landed damage, absorbed damage and fully blocked hits have different
  feedback. The blood-off control preserves this information.
- `Condition` really changes wounds, saturation, lean/sag, breath and
  sub-quarter-health tremor. The wound pixel regressions confirm the
  toggle changes rendered output, not merely a boolean.

### The unresolved problems

**A1 — No authored attack/block/death body rows.**

Every delver sheet declares two idle frames, two run frames and one hit
frame at 6 fps. Combat constructs a `SpriteView` in its default idle state.
`_combatant()` supplies a whole-body matrix and slide; the separate weapon
rotates around a socket. That is a useful effects scaffold, not an
articulated shoulder/elbow/hip/foot action.

**A2 — The socket is only an idle anchor.**

The new per-sheet `hand` is an improvement over one shared offset. But
the sprite's breathing/sway/heave happens inside its painter, while the
weapon is a sibling with its own animation clock. A static idle coordinate
does not guarantee a continuous grip through breathing, frame changes,
windup or fatigue. Verify this with tracked source-pixel grip markers,
not a claim that an offset exists.

**A3 — Contact timing and visual health disagree.**

This is reproduced in the new runtime observations, not inferred from
the old critique. In Kindler's high attack, **frame 60 / 2.40s** has
enemy HP **18 → 13** and wound count **0 → 1** while the weapon is still
in **`raise`**. The normal contact path waits for the authored
windup + travel envelope (**340 ms**) after synchronous `c.apply()`.
The foe body reads already-resolved live HP before that contact.
Gambler/Runesmith similarly acquire two wounds during their raise.

Fix the **presentation timeline**, not simulation determinism: retain
pre-contact displayed HP/condition and advance the visual event state
at impact. Do not delay, duplicate or randomly alter the sealed sim.

**A4 — Guard can be lost before the incoming blow lands.**

In the controlled Kindler/Gambler/Runesmith clips the weapon is `guard`
at frame 96, but returns to `idle` at the first enemy-turn sample
(frame 105), before incoming contact. `_playerBraced` derives from
post-resolution block; consumed block is gone before the visual hit.
Warden's remaining block behaves differently. Carry the *visual guard*
through impact, then show absorption/partial failure and recovery.

**A5 — Fatigue is mostly whole-sprite treatment.**

The model is present; calling it absent would be wrong. Yet a maximum
~5° lean, small compression, saturation drain and a bob/tremor do not
fully communicate laboured human effort. Injured idle silhouettes,
shoulder/chest motion, a dropped guard and a slower-looking recovery
can tell that story without changing gameplay stats. Wounds should be
per-body overlays with clear progression, not just extra red dabs.

### Suggested visual acceptance tests

- Kindler cut: anticipation → planted step/hip turn → shoulder/arm
  action → contact → follow-through → controlled recovery.
  Warden maul: two-hand grip → load weight → downward strike → recoil.
  Small and large dice must read differently with particles turned off.
- Track hand and grip on representative frames; target **≤1 native
  sprite pixel separation** through idle, swing, guard and fatigue.
  This is a proposed quality criterion, not something currently passing.
- Full block, partial block, unblocked hit and riposte: guard silhouette,
  impact flash, damage number and visual HP/wound transition agree
  within one captured frame. Test normal/reduced motion and fast-forward.
- At 100/60/30/15% HP, show increasingly tired posture on hero **and**
  enemy without touching simulation hashes. Blood-off retains non-bloody
  injury information; full block never adds blood.
- Review at 320/360/412 logical widths before expanding to the roster.
  Then measure real-device frame times; headless captures are not that gate.

## 3. Depth — strong decisions, narrower encounters than the catalog

### Why it earns 7

- Spending a die on attack or defence, choosing rerolls, timing exact
  kills/overkill and responding to visible intent produce real opportunity
  costs. Resolution is deterministic rather than a hidden accuracy roll.
- Route/rest/shop/forge/event choices affect survival and the future pool.
  Pair/triple/straight rewards and six face runes support different builds.
- The four keystones change decisions:
  **Ashen Edge** rewards attacking before spending the pool;
  **Living Bastion** retains some unused block;
  **Crown of Twelve** rewards using different die sizes;
  **Twin Bellows** rewards alternating attack/block.
  These are more interesting than four passive damage bonuses.
- Charge-break and counter stances challenge the usual allocation rule.
  Vent Ram, Cinder Urchin and Magma Lancer are promising examples to
  develop, not proof that every enemy is equivalent.

### Why it is not an 8 or 9 yet

1. **Catalog breadth overstates encounter variety.** The executable catalog
   contains **42 enemies**, but **39** use only `attack`, `block` and/or
   `attack_block` in their declared patterns. Only **three distinct enemy
   definitions** introduce charge/counter; two have charge and two have
   counter, with Magma Lancer in both. Ordering and amounts still create
   meaningful rhythms, so “39 identical enemies” would be false. The
   opportunity is to add different decisions, not just bigger numbers.
2. **Simple greedy play is effective in the sample.** On normal difficulty,
   the unchanged bot won **31/50 Kindler (62%)**, **44/50 Warden (88%)**,
   **27/50 Gambler (54%)**, **30/50 Runesmith (60%)**. Easy ranged
   **90–96%**, hard **32–50%**. All 600 terminated with no invalid commands.
   This is a policy-specific diagnostic, **not human win rates and not
   enough evidence to nerf Warden**. Kit/policy interaction and seed
   sensitivity need investigation.
3. **Build abundance can become repetition.** The sampled final pools
   had median sizes **5–9**, depending on character/difficulty.
   More individually assigned dice can lengthen “obvious move” turns.
   Measure meaningful choices and taps, not only catalog entries or
   total run duration.
4. **Depth must be discoverable in play.** Existing intent explanations
   and previews are worth keeping. Observe whether a new player can
   predict counter costs, explain a charge break, and use a keystone
   deliberately. Tests of arithmetic do not answer those questions.

### Next depth experiments, without an immediate rebalance

- Run multiple policies (greedy, defence-heavy, burst/charge-aware,
  keystone-aware) on held-out seeds; report confidence intervals and
  decision differences. Add human sessions before changing difficulty.
- Design a few enemy encounters where the best move differs under the
  **same rolled pool**. State the intended choice and counterplay;
  avoid surprises hidden from the intent UI.
- Add explanatory previews for any proposed new mechanic. Preserve fair
  resolution, accessibility, no-FOMO promises and the one-time-unlock model.
- Measure per-turn taps/time and whether a player can describe their
  build's plan. More relics or characters are not automatically more depth.

## 4. Handoff priorities — work in this order

| Priority | Task | Evidence to close it |
|---|---|---|
| **P1: verification** | Bring the old art generator up to date with authored `hand` metadata. | Reproduce the current failure first; generator output includes all sockets from an explicit source, `--check` passes without deleting assertions or hand data. |
| **P1: verification** | Repair the old interactive UI harness's keystone phase handling. | Legal transition graph matches sim; real hit-tested keystone pick/decline; four complete seeded UI runs with invariants intact. |
| **P1: visible defect** | Synchronise displayed HP/wounds and guard with contact. | Before/after timed frames for A3/A4, terminal/counter/queue coverage, unchanged sim hashes. |
| **P1: biggest quality gain** | Authored Kindler + Warden body actions and moving grip anchors. | Particle-free low/high attack, full/partial block and recovery clips at phone size; anatomy/grip review. |
| **P2** | Per-body fatigue/wounds, then a small enemy set. | 100/60/30/15% comparisons, blood on/off, reduced motion, clear silhouettes. |
| **P2** | Investigate encounter and policy diversity. | Held-out policy matrix plus human decision observations; no balance claim from one bot. |
| **Before any later release** | Physical-phone performance/touch and Play purchase/restore. | Device traces and actual Play-signed purchase/restore evidence; keep existing open release gates open until then. |

### Known existing verification failures

**Art generator, unchanged base and this branch:**

```text
AssertionError: metadata differs
```

The generated image-pixel comparisons complete before that assertion.
Comparing every generated/current metadata entry shows the mismatch is
the added **`hand` field on all 22 delvers**: `entry_for()` does not emit it.
Do **not** run the generator in write mode as a “fix”—that would erase the
new sockets. This PR deliberately does not weaken or modify the old check.

**Old interactive UI tool, twice on unchanged base, seed 1842571558:**

```text
INVARIANT step 62: illegal transition player_turn → keystone
STUCK: keystone|t10|r3,2,6|a1|hp25|ehp0 after 40 identical steps (run 0)
```

The simulator intentionally offers a keystone after the first victory,
and the UI has a keystone screen. The old tool's legal graph and dispatch
omit that phase. Fix the tool against the actual contract rather than
disabling keystones or treating this as proof the game itself is stuck.

## PR boundary

This PR implements the blood comfort control and records the above critique.
**It does not implement the critique's larger animation/balance changes.**
Leave this PR **OPEN for the next agent**. No auto-merge, version bump,
tag, signed release build, Play submission or rating change is part of it.
The earlier 0.183.0 submission is separate; review status is not live status.
