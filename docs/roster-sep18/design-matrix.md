# Whole-roster art direction

**ASSUMED aesthetic intent**, selected from the existing character identities
and tools in `lib/data/characters.dart` / `lib/ui/weapons.dart`. These are working
delvers, not a new class system. Costumes never change kits or imply new powers.
Native output, not a high-resolution concept, is the acceptance surface.

| Delver | Distinguishing silhouette / equipment | Tool / body action |
|---|---|---|
| Kindler | Retain delivered lean half-hood, scarf and rear coal lantern | Ember Brand / planted cut |
| Warden | Retain delivered low helm, broad iron shoulders and furnace-door shield | Ward Maul / overhead crush |
| Gambler | Off-centre flat-brim hat, short split coat, coin sash | Lucky Fang / quick compact thrust |
| Ascetic | Bare close-cropped head, one wrapped shoulder, narrow split robe | Brand Iron / controlled forward thrust |
| Peddler | High square framed pack, rolled blanket, short cargo apron | Coin Hook / reach then hauling pull |
| Tinker | Low goggles on leather cap, one angular shoulder pad, offset tool belt | Pin Wrench / grounded overhead blow |
| Flintwright | Low peaked dust hood, broad knapping apron, shard satchel | Knapping Pick / short close chop |
| Runesmith | Square flat forge mask raised over brow, asymmetric etched collar | Rune Chisel / precise stamping jab |
| Bearer | Very broad low sloping shoulders, load harness and stone back slab | Stone Maul / deep weight-driven crush |
| Mender | Small rolled linen hood, crossed wrap bands, two rear medical rolls | Stitching Awl / economical thrust |
| Shieldwright | Tall square leather neck guard, rolled steel strip at rear hip | Planishing Hammer / measured crush |
| Gilder | Fitted cap, high clean cuffs, short angular gold-trimmed apron | Agate Burnisher / compact stamp |
| Cutler | Lean rolled sleeves, diagonal leather apron, sheathed tools at rear | Steeling Rod / point-led thrust |
| Collier | Broad soot cowl, round coal basket behind shoulders, ash gaiters | Coal Rake / long gathering pull |
| Stoker | Thick asymmetric heat mantle, rolled trousers and huge gauntlets | Fire Iron / weighty forward drive |
| Hearthkeeper | Broad half-cape, split tabard, heavy rear key ring | Hearth Hook / guarded hooking pull |
| Hedger | Low straw/leather brim, jagged thorn shoulder mat, tied bundles | Billhook / compact hooked cut |
| Miller | Rounded flour cap, pale shoulder cloth, low rear grain sack | Grain Flail / falling-weight crush |
| Brewster | Tied kerchief, wide copper-coloured apron, small rear kettle | Long Ladle / pendulum crush |
| Lamplighter | Tall narrow hood, long split oilskin coat, spare rear lamp cage | Lamp Pole / long controlled hook |
| Farrier | Stocky squared body, bare forearms, heavy split shoeing apron | Shoeing Hammer / short precise pick |
| Glover | Fitted leather cap, narrow waist, contrasting heavy/light cuffs | Glover's Needle / fast stitching thrust |

## Shared construction

- Existing forge/ash palette and restrained role accents; no neon/photorealism.
- Transparent source atlas; four poses per row: idle, breathe, alternating walk.
- Four rows per art group; groups follow the existing roster order.
- All face right. Separate boots on one baseline. Negative space under forward
  forearm. Empty rightward primary fist; signature tool is attached at runtime.
- Coarse native 32x40 clusters, no gradients/dither. Preserve 2px margins.
- Authored measured anchors and anatomical regions come from the resulting
  native source cells, never from prompt coordinates assumed to have landed.
- Portraits retain sprite-row animation; combat uses source-pixel articulation.
- Public provenance identifies generated source and deterministic conversion.
