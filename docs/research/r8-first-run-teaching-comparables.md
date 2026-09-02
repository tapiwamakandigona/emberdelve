# R8 — How the comparables teach the first run, and where emberdelve stands (2026-09-02)

Scope: standing directive to research how indie developers improve their games, applied to the
one stage R5 says leaks (first delve → second session). Only developer-authored primary sources
are used; emberdelve's side is read from `lib/`, not from memory. **Finding: emberdelve already
practises the three things the comparables' developers wrote about; this note found no new
build gap.** It is written so the question is not re-asked.

## What the developers themselves wrote

| Source (primary) | Practice | Quote |
| --- | --- | --- |
| tann, *Slice & Dice dev tidbits* — [tann.fun/article/slice-dice-dev-tidbits](https://tann.fun/article/slice-dice-dev-tidbits) | Tutorial that never forces; checkboxes for actions not yet done; refined by watching streamers | "The tutorial doesn't force you to do anything, it only suggests actions you haven't done yet… I got to improve the tutorial from watch[ing] streamers play through it." |
| Evan Debenham, *What's Coming in Shattered Pixel Dungeon v0.6.1 pt.2* — [shatteredpixel.com](https://shatteredpixel.com/blog/whats-coming-in-shattered-pixel-dungeon-v061-2.html) | Replace up-front signposts with in-dungeon guide pages that persist between runs and can be re-read | "The Adventurer's Guide is a complete overhaul to the new player experience, replacing the existing signpost tutorial system… Collected pages persist between runs and can be referenced anytime." |
| Debenham, *Shattered Pixel Dungeon v0.9.3* — [shatteredpixel.com](https://shatteredpixel.com/blog/shattered-pixel-dungeon-v093.html) | Shorter runs; info "right as you need it" rather than text-heavy | "Levelgen tweaks, to make the game overall a little shorter… The current guidebook is too text-heavy and doesn't do the best job of giving you info right as you need it." |
| Debenham, *Coming Soon to Shattered: Duelist Buffs* — [shatteredpixel.com](https://shatteredpixel.com/blog/coming-soon-to-shattered-duelist-buffs-and-additions.html) | Most of the player base has never won | Widening the sample from players with a win to players who beat the first boss: "The overall number of runs studied increases by about 5x, there are lots of people who haven't gotten their first win yet!" |

## Where emberdelve stands (read from the code at `legacy/dice-builder`)

| Practice | emberdelve | Evidence |
| --- | --- | --- |
| Non-forcing, action-completed tutorial | Five-beat anchored tour; action beats complete only on the real action, SKIP always available, seen once per `tourVersion` | `lib/game/tour.dart` header rules; `TourBeats` roll/pick/spend/intent/reroll |
| Info at first contact, not up front | Staged contextual tips fire at first contact with each concept, one at a time, once ever; the up-front 4-card wall was removed in v0.10.0 | `lib/game/tips.dart` (`whats_a_delve`, `roll_spend`, `intent_fair`, `combos_pay`, `block_fades`, `first_anvil`, `shared_delve`, `deep_mark`) |
| Re-readable reference | "How to play" control on the enemy panel reopens the card set (THIS IS A DELVE / ROLL, THEN SPEND / THE DARK FIGHTS FAIR / MATCHING FACES PAY / BLOCK FADES FAST / THE SHARED DELVE / THE SECOND STRIKE / THE SMITH IS IN); Codex persists tales and entries across runs | `lib/ui/screens/combat/enemy_panel.dart:54` (`Semantics(label: 'How to play')` → `_restartTutorial`); `lib/ui/screens/tutorial_overlay.dart` |
| Design for the never-won majority | Default 'normal' with `steerToEasy` for fresh profiles; review ask reachable from losses (24 marks) since v0.179.0; sim bands easy 80–90 % | `controller.dart:247`; `review_service.dart:72–73`; R7 |

## What the comparables did that we cannot copy in a research phase

- tann tuned the tutorial by **watching streamers**. We have no session recordings and no
  telemetry (by rule). The nearest honest substitute is the owner watching one new player's
  first ten minutes over their shoulder and writing down where they hesitate — a single
  observed session is worth more than another hypothesis here. Not a build task; an owner task.
- Shattered's "make the game a little shorter" was a data-driven levelgen change. We have no
  first-run wall-clock on a real device (still owed). Do not shorten anything on a guess.

## Conclusion

No new gap. The first-run teaching layer already matches what the comparables' developers
describe. This is consistent with R5's placing of the leak *after* the first delve (the reason
to come back), not inside it — and v0.179.0's changes (R7) target exactly that.
