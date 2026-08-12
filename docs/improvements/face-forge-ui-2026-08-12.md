# Face Forge reaches the player

v7 iteration 07. `temper_face` had been a fully tested command with no way into
it from the game. This closes that, and fixes the class of bug it exposed.

## The temper flow

At any rest, before the run has spent its one temper: **Temper a face — once
per delve**. The sheet asks three questions in the order a player thinks about
them — which die, which face, which rune — and commits nothing until the last
button. Each rune states its rule in one line (`runeBlurb`), so nobody has to
learn the system from a wiki.

Tempering is the rest's one action, like resting or forging, so the sim moves
the run on afterwards. Once spent, the option disappears rather than sitting
greyed out asking to be re-read at every later rest.

## The bug the UI exposed

The pool is a `List<String>`, and a tempered die replaces its slot with a
run-local `custom_N` id. Every presentation path that resolved a pool entry
through the catalog `dieDef` therefore threw `unknown die id: custom_1` — the
rest screen crashed outright, and `buildIdentity` silently *dropped* the die,
which would have under-counted the end-of-run "POOL FORGED THIS RUN" recap.

Fixed at the boundary rather than per screen:

- `DieChip` takes the run ledger and resolves through `resolveRunDie`.
- `buildIdentity` takes an optional run and counts a tempered die as its
  catalog base — a rune changes what a face pays, never what kind of die it is.
- The rest screen resolves the pool before asking what is forgeable.

`test/temper_ui_test.dart` walks a tempered die from the rest screen into a
live combat tray, so this cannot regress silently.

## Reading a tempered die

The chip wears a corner mark: rune initial plus its face (`B4`), tinted per
rune, and **lit when the roll actually landed on that face**. So the trigger is
readable at a glance instead of requiring the player to remember what they
tempered. The mark is decoration; the Semantics label speaks
"tempered Surge on 3" for TalkBack.

## What gets announced

Feedback rule: only announce what the numbers on screen do not already say.
Blade, Aegis, Ashen Edge, Crown of Twelve and Twin Bellows all land inside the
die's own `+N SPENT`, so they stay silent. These three do not, so they toast:

- Surge returning a reroll
- Echo arming the opposite verb
- Living Bastion carrying block across the turn boundary

## Visual sweep

`tool/temper_visual_test.dart` captures the rest screen, the sheet, and a
tempered die in the tray at 412×915, 360×640, and 1.5× text. Two defects found
and fixed:

1. The sheet overflowed by 273 px on short screens. The three steps now scroll
   inside a height-capped sheet with the commit button pinned.
2. The harness itself was wrong: a bare `MediaQueryData` has size zero, which
   collapsed everything that measures the screen. Both visual tools now
   `copyWith` from the real context. Worth remembering — that mistake makes a
   screen look broken when the screen is fine.
