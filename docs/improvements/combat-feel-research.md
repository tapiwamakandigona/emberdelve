# Combat feel — research notes + backlog (2026-07-24)

Owner ask (2026-07-24 DM): *"you don't even see the weapons currently … the
gameplay models are almost just the same bare stuff, we need people to be
addicted here"*. This doc records the research behind the
`feat/combat-weapons-juice` pass and the remaining backlog, so parallel agents
don't re-derive it. Everything must stay inside `docs/spec.md` §Ethics
("fair-addictive": addictive through quality, never dark patterns).

## What the research says

**1. Attacks are anatomy: anticipation → strike → recovery.**
(GDKeys "Keys to Combat Design: Anatomy of an Attack"; GDQuest "Juicing up
your game attacks".) Wind-up is held long (100–200 ms) to build tension, the
impact frame is the *shortest* (20–40 ms) so the hit feels violent, recovery
eases out. Swings should **accelerate into contact and decelerate after** —
that contrast is where perceived weight comes from (MoCap Online sword-anim
guide). Our timings: raise 90 ms → swing 230 ms easeInCubic (completes just
before the 250 ms contact frame) → recover 260 ms easeOutCubic.

**2. Smear/trail VFX sell speed with zero extra frames.**
A trail following the weapon "makes the attack feel faster than it actually
is" (GDQuest) and "highlights its deadly part" (GDKeys key #5). This is how
you get weapon presence without buying attack-frame sprite packs (which are
owner-budget-gated anyway, PROJECT.md #7).

**3. Slay the Spire proves minimal character animation is fine — if the VFX
carry it.** Its creatures barely animate; "the cards animate and have VFX,
that's the important part" (dev response on Steam). Massive target zones,
intent always visible, huge juice on resolution. We already follow the intent
rule; this pass adds the resolution VFX (weapon smear on the enemy, claw rake
on the player, guard arc on block).

**4. Every action needs feedback <100 ms** (design-system §5, Solana Garden
game-feel guide: hit-stop, camera kick, shake tail). Audit result: attack had
full choreography, **block had literally none** — no sound, no visual, no
number. Fixed in this pass (guard arc + `+N BLOCK` pop + sfx + shield flash
when a hit is fully absorbed, both directions).

**5. Roguelite "one more run" psychology (ethical version).**
(Polygon "Why losing in roguelikes feels like winning"; Overbaked "Why are
deckbuilders so addictive".) The compulsion loop that works WITHOUT dark
patterns: (a) losing must teach — death screens lead with what you learned/
kept (we do: ledger, insight payout); (b) variable-ratio rewards live in
*offerings* (dice/relic drops), never in *resolution* (we do: PROJECT.md #5);
(c) short cheap runs make "again" an easy yes (we do: fast Delve-again);
(d) visible mastery: the player must FEEL stronger — which is presentation,
not math. Bare stages read as "same bare stuff" even when the pool doubled.
Weapon/arsenal visibility is mastery visibility.

## Shipped in feat/combat-weapons-juice

- `lib/ui/weapons.dart`: per-character signature weapons (Ember Brand /
  Ward Maul / Lucky Fang / Brand Iron), programmatic CustomPainter — zero
  binary assets, decision-#7 safe. Idle sway, anticipation raise, smear-arc
  swing riding the existing squash/lunge flags (no new awaits, choreography
  timing unchanged).
- Contact FX on the victim: weapon smear crescent (player hits), 3-line claw
  rake (enemy hits — sheets have no attack frames, the overlay IS the
  strike), spark burst on the impact frame.
- Block feedback (was zero): guard-arc flourish + `+N BLOCK` pop + sfx;
  guard flash on either side when a hit is fully absorbed; enemy shield-up
  gets the same arc.
- Character select: weapon leans against the portrait + weapon name in the
  stat line (arsenal reads before the delve).

## Backlog — next highest-value feel work (in order)

1. **Enemy silhouettes during intent** — tint/lean the enemy on its wind-up
   (attack intents telegraph physically, not just via the badge).
2. **Dice impact on assign** — assigning a die to attack should *charge* the
   weapon (brief glow scaled by pips); makes the die→weapon causality visible.
   Cheap: WeaponView already takes phase; add a `charge` level.
3. **Boss kill moment** — bosses currently die like trash mobs (same 700 ms
   dissolve). Deserve: slow-mo hold + bigger burst + screen flash.
4. **Reward flip** (visuals.md #4, still open): rewards as 3 physical cards
   you flip — the variable-reward moment deserves its own animation.
5. **Run-power recap on victory screen**: "your pool, forged this run" strip
   (IKEA effect, design-system §1) — show the arsenal they built.
6. **Plain reroll retumble**: single-die reroll doesn't retumble the die
   (only risky reroll bumps `_rollGen`); per-die tumble tokens would fix it.
7. **Map ambience audio bed** per layer depth (hotter = lower rumble).

## Cited sources
- gdkeys.com/keys-to-combat-design-1-anatomy-of-an-attack
- gdquest.com/library/juicy_attack
- mocaponline.com/blogs/mocap-news/sword-melee-animation-guide
- charios.com/blog/2d-impact-animation-anatomy
- solana.garden/guides/game-juice-and-feel-explained
- janmeppe.com/blog/the-juiciness-of-slay-the-spire
- polygon.com/psychology-roguelikes-punishment-into-reward
- overbaked.studio/blog/why-deckbuilder-games-are-addictive
