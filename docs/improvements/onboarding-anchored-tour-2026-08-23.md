# Onboarding v2 — Anchored Tour ("Point At The Real Thing")

**Date:** 2026-08-23 · **Status:** PLAN (no code in this PR)
**Trigger:** Direct player feedback post-Play-launch: people install the game and
don't know how to play. This is happening *despite* the existing 4-card tutorial
and contextual tips — which tells us the problem is the *form* of the teaching,
not its absence.

---

## 1. Diagnosis — why the current FTUE fails

What we ship today (verified in code):

| Piece | Where | Form |
|---|---|---|
| 4-card tutorial (`_TutorialOverlay`) | first fight, once ever (`MetaState.tutorialSeen`) | **abstract text cards** with an icon — they *describe* the badge/dice/combos but never point at them |
| Contextual tips (`TipDirector`, 4 tips) | first-contact moments | text cards again |
| Replay "?" (`Icons.help_outline`) | inside combat, enemy panel row | tiny, dim (`textDim`, 20px), only discoverable *after* you're already in a fight |

Failure modes, mapped to research:

1. **Text describes; it doesn't anchor.** "The badge above the enemy's head" forces
   the player to *translate* prose into pixels. Players mash through card walls and
   retain nothing (Solana Garden FTUE guide; CHI 2012 "The Impact of Tutorials on
   Games of Varying Complexity" — contextually anchored beats textual for
   learnability). Our cards are literally the "wall of text" anti-pattern in
   4-card form.
2. **Everything fires at once, in the most stressful room.** All 4 cards land in
   the first combat, before the player has rolled once. Working memory holds 3–4
   items (ui-patterns.com, coachmarks); we spend that budget before the first tap.
3. **No teaching outside combat.** Title screen, map, rest fire, forge, shop,
   boons — zero guidance. "I don't know how to play" plausibly includes "what is
   this map", "what does forge do", "why did I get embers".
4. **Veterans can't be re-onboarded.** `tutorialSeen` is sticky and cloud-merged
   (set-union), so shipping better cards does nothing for the 33+ existing users
   — the exact people who complained.
5. **The "?" is invisible.** 20px dim icon inside a busy combat HUD.

## 2. Design goals

- **G1 — Anchored, not abstract:** every teaching beat points at the *real* UI
  element (spotlight/coach-mark), never at a drawing of it.
- **G2 — One idea per beat**, ≤ 12 words of body copy each (coach-mark best
  practice: users read arrows, not paragraphs).
- **G3 — Do, don't read:** each combat beat completes on the player *performing*
  the action (tap a die → beat done), not on tapping "Next".
- **G4 — Everyone sees v2 once**, including veterans (versioned flag), and can
  replay it forever from an obvious place.
- **G5 — Respect §Ethics:** skippable at every beat, no forced grind, no dark
  patterns. Skip = mark seen.
- **G6 — Zero sim contamination:** pure UI layer; the sealed `lib/sim` core is
  untouched. Tour logic is pure Dart, unit-testable like `tips.dart`.

## 3. The feature — Anchored Tour

### 3.1 Mechanism: spotlight coach-marks on live UI

A full-screen scrim (80% ember-dark) with a cut-out spotlight around the target
widget, a short label, and an arrow/notch pointing into the cut-out. Target
widgets self-register via `GlobalKey`s in a `TourAnchors` registry (id → key),
so the tour finds real render boxes — no hardcoded coordinates, safe across
phone/tablet clamps.

Implement in-house (~1 widget + 1 pure-logic director), matching the existing
`tips.dart` pattern. No new dependency needed (`tutorial_coach_mark` pub package
exists but pulls opinions we don't need; our design system already has scrims
and motion).

### 3.2 Beat script (combat, replaces the 4 cards)

Beats fire in the first fight, sequenced by *player action*, one at a time:

| # | Anchor (widget) | Copy (≤12 words) | Completes when |
|---|---|---|---|
| 1 | dice tray (`tray.dart`) | "Your dice. Tap ROLL." | roll happens |
| 2 | a rolled die | "Tap a die to pick it up." | die selected |
| 3 | ATTACK / BLOCK buttons (`action_zone.dart`) | "Spend it: ATTACK deals its value. BLOCK absorbs." | action taken |
| 4 | enemy intent badge (`enemy_panel.dart`) | "Its next move. It always resolves exactly as shown." | tap-to-continue |
| 5 | reroll affordance | "One risky reroll per turn — bank a bad face." | tap-to-continue |

Beats 4–5 are the only tap-to-continue ones (they anchor *information*, not an
action). Combos/burn/block-fade stay with `TipDirector` — those are genuinely
better at their first-contact moment; the tour must not steal their job.

### 3.3 Out-of-combat beats (one each, first visit, via same director)

| Screen | Anchor | Copy |
|---|---|---|
| map | next-node choices | "Choose your path. Branches never merge back." |
| rest fire | forge option | "Forge upgrades a die face — bigger numbers, forever this run." |
| reward | ember count | "Embers. Exact-kill bonuses pay extra — spend at shops." |
| boon pick | boon list | "Boons bend the rules for the whole run. Pick one." |

Each is a single spotlight, auto-dismissed on the screen's natural first action.

### 3.4 Re-onboarding everyone (the versioned flag)

- New persisted field: `MetaState.tourSeenVersion: int` (default 0).
- Tour v2 runs when `tourSeenVersion < 2` — so **every existing player sees it
  once** after updating, then never again. Future reworks bump the constant.
- Keep `tutorialSeen` field for save-compat (read, never written by new code);
  old cards + their overlay are deleted.
- Cloud merge: `max()` of both sides (consistent with sticky-progress rules in
  `cloud_merge.dart`).
- First run after update shows a 1-line title-screen toast: "New: guided tour —
  replay anytime from Settings." (reuses the existing news/update toast slot,
  never a modal).

### 3.5 Replay + discoverability

- **Settings → "How to play (guided tour)"** row — sets a pending-tour flag; next
  fight/screen visits replay their beats. Settings is the natural home
  (GitHub Primer: onboarding should live where the feature lives in perpetuity).
- Keep the combat "?" but brighten it to `textPrimary` at 24px and give it a
  one-time attention pulse (existing `fx.dart` glow) until first tapped.
- **Codex addition:** "Field Guide" page — a static, always-available reference
  listing each UI element with its meaning (the annotated-screenshot content,
  in-game, searchable by players who want to *look things up* rather than replay).

## 4. Annotated screenshots (store + web, the "pointing at things" ask)

Produce 4 annotated captures — callout arrows + short labels on real frames
(design-system colors, Staatliches for labels, consistent 3px ember arrows):

1. **Combat anatomy:** intent badge / burn chips / dice tray / reroll / ATTACK-BLOCK.
2. **Map:** branch choice, node types (fight / event / rest / shop / boss).
3. **Rest fire:** forge a face — before/after die face close-up.
4. **Run economy:** embers, exact-kill bonus, shop.

Placement:
- Play listing: replace/append screenshots 2–5 (after the 2-week listing-freeze
  window clears; pairs with the planned "roguelike" long-description edit).
- `tapiwa.me/emberdelve` — "How it plays" section (4 images, already-built page).
- Press kit folder gains the annotated set (reviewers love labeled UI shots).

Production path: existing screenshot harness (`test_driver` appstore screenshot
route) → overlay annotations via a small Python/Pillow script checked into
`tool/` → outputs to `docs/store/screenshots/annotated/`.

## 5. Acceptance criteria (features.json candidates)

1. Fresh install: tour beats 1–5 fire in first fight, each anchored to a live
   widget rect (integration test: spotlight rect intersects target render box).
2. Beats 1–3 complete only on the real action; SKIP visible on every beat;
   skipping marks `tourSeenVersion = 2`.
3. Upgrade path: save with `tutorialSeen=true`, `tourSeenVersion=0` → tour runs
   once → never again (unit test on MetaState + cloud merge union test).
4. Replay from Settings works twice in a row (no sticky lock).
5. No `lib/sim` diffs. Tour director is pure Dart with unit tests (mirror
   `tips_test.dart`).
6. TipDirector suppressed while a tour beat is on screen (reuse the existing
   "manual overlay suppresses tips" rule).
7. All copy ≤ 12 words body; verified by a test over the beat table.

## 6. Delivery plan

| Phase | Scope | Est. |
|---|---|---|
| P1 | Tour director (pure Dart) + spotlight widget + combat beats 1–5, versioned flag, Settings replay | 2–3 days |
| P2 | Out-of-combat beats + Codex Field Guide page | 1–2 days |
| P3 | Annotated screenshot set + store/web/press placement | 1 day |

P1 alone fixes the complaint; P2/P3 compound it. Ship P1+P2 as **0.8.0 "The
Guided Delve"**; P3 rides the listing-freeze expiry.

## 7. Sources

- Apple, "Onboarding for Games" (teach the core loop, in context) —
  developer.apple.com/app-store/onboarding-for-games/
- CHI 2012, "The Impact of Tutorials on Games of Varying Complexity" —
  contextual > textual for learnability.
- ui-patterns.com "Coachmarks" + Chameleon/PIE spotlight guidance — 3–4 item
  working-memory budget; dim scrim; arrows over prose.
- Solana Garden, "Game Tutorial and Onboarding Design Explained" — replace card
  walls with contextual hints tied to imminent actions.
- Rogue Legacy deep dive (gamedeveloper.com) — teach during real play, fast.
- Dicey Dungeons 0.16 changelog + Slice & Dice dev tidbits (tann.fun) — genre
  peers: minimal handholding, teach-by-doing in the first real episode.
- Internal: tester nearly reinstalled to re-see the tutorial (comment in
  `enemy_panel.dart`) — replayability and re-onboarding are real demands.
