# Lead scout — The Hearthkeeper (sixteenth and FINAL delver)

Chosen: the sixteenth delver, the SWORN POUCH — every die a forged
specialist and none of them plain. A Brand Iron (attack-only, +2), a
Ward Iron (block-only, +2), a Steady Ember (min 3). The collier's pouch
was worked BY the smith (plain dice, rune faces); the hearthkeeper's
dice were BORN to their work (forged die types, committed roles). Two
of three dice locked to a single job is the tension the sweep prices
in. Pure data — existing die ids, no relic, no marks, no re-anchor.

**The roster is CLOSED at sixteen.** The delve-code delver index
(bits 31..34) holds exactly sixteen values and the hearthkeeper takes
the last one. There is no seventeenth chair; the "last chair" is the
identity, and the tests pin `charactersOrder.length == 16` as the
tripwire.

Balance: 400-seed sweep. First guess 28 HP swept 92.00/70.25/45.75
(slightly hot); 26 HP swept 91.50/68.25/42.00 vs kindler
89.75/67.25/41.50 — in band at the second guess, shipped. Unlock 2100
(ladder ascending), index 15.

Sprite: palette variant of ascetic (hue +20°, sat ×1.0 floor 0.40,
val ×1.12 — hearth gold). doc base count evens to 4; the spare robed
silhouette reads as a keeper, and the warm gold keeps them apart from
the ash ascetic, sage mender and steel cutler at a glance. First cut
(floor 0.32, val ×1.05) read muddy-brown on the picker; the brighter
gold won the A/B.

Weapon: Hearth Hook (accent 0xFFD9A85A, reach 0.50 — keepers hold the
threshold, neither the longest reach nor the shortest).

Tale cap note: the sixteen-name recount of tale 5 hit exactly 200
chars (cap is <=200, test/hearth_tale_test.dart) after trimming the
closing clause to 'Each answers the delve.'

Considered and rejected:
- one-die-of-each-size pouch (d4/d6/d8/d12): brushes the bearer's
  biggest-die identity and the rejected d12-based-pouch lead.
- two starting relics: needs a schema change (startRelic is scalar)
  and resizes nothing the identity needs; the sworn-dice identity is
  purely data.
- d4_lucky in the pouch (brand/ward/charm): the Charm Bone is the
  gambler's signature die; committed dice + the steady keel is the
  cleaner statement of "every die has one job".
- any startTempers: collides with collier (fully worked) and
  shieldwright (deep lead); forged TYPES not rune FACES is the point.

Proving + honors follow in the NEXT commit under new names (v0.119
pattern, tenth use): the Kept Hearth proving + char-win and
sixteen-ways honors, the_proven 23 -> 24.
