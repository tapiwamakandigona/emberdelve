// data/codex.dart — The Codex (v0.4.3, P1 ember sink). CONTENT AS DATA,
// ZERO LOGIC.
//
// Ember-priced lore entries for every enemy and relic in the game. Same
// charter as hearth colors and dice skins (docs/spec.md §Ethics): prices
// shown up front, no timers, no FOMO, and the lore is flavor only — it never
// hides rules knowledge behind a paywall. Everything mechanical (intents,
// relic effects) stays visible in play for free; the Codex sells the story.
//
// Entry ids are namespaced ('enemy:<id>' / 'relic:<id>' / 'place:<id>' /
// 'delver:<id>', v0.110.0) so MetaState can keep ownership in one flat set
// without collisions. Enemy, relic, and delver names are NOT stored here —
// the UI reads them from enemies.dart / relics.dart / characters.dart, so a
// rename there can never leave the Codex lying. Places (v0.104.0 The Delve
// Itself) exist only here, so [placeNames] is theirs.
//
// Prices: common enemies 15, elites 20, bosses 30, relics 20, places 10,
// delvers 15 — the world's own words are the cheapest words in the book,
// because 'what is a delve?' is the first question a new delver actually
// asks; who the company are is the second.

class CodexEntryDef {
  final String id; // 'enemy:cinder_wisp' / 'relic:ember_ring'
  final String kind; // 'enemy' | 'relic' | 'place'
  final String refId; // key into enemies / relics
  final String text; // the lore, unlocked on purchase
  final int costEmbers;
  const CodexEntryDef(
    this.id,
    this.kind,
    this.refId,
    this.text, {
    required this.costEmbers,
  });
}

CodexEntryDef _enemy(String refId, String text, {int cost = 15}) =>
    CodexEntryDef('enemy:$refId', 'enemy', refId, text, costEmbers: cost);
CodexEntryDef _relic(String refId, String text) =>
    CodexEntryDef('relic:$refId', 'relic', refId, text, costEmbers: 20);
CodexEntryDef _place(String refId, String text) =>
    CodexEntryDef('place:$refId', 'place', refId, text, costEmbers: 10);
CodexEntryDef _delver(String refId, String text) =>
    CodexEntryDef('delver:$refId', 'delver', refId, text, costEmbers: 15);

/// Display names for 'place' entries — places exist only in the Codex, so
/// the name lives beside the lore. Append-only, like every catalog.
const Map<String, String> placeNames = {
  'the_delve': 'The Delve',
  'the_ember': 'The Ember',
  'the_hearth': 'The Hearth',
  'the_depths': 'The Depths',
  'the_dice': 'The Dice',
  'the_forge': 'The Forge',
  'the_provings': 'The Provings',
  'the_vistas': 'The Vistas',
};

/// Authoring order — the world first (a new delver's questions in the order
/// they get asked), then enemies shallow-to-deep, then relics by shop
/// grouping.
final List<CodexEntryDef> codexEntries = [
  // the world -------------------------------------------------------------
  _place(
    'the_delve',
    'A delve is a walk down into the dark with a light you have to feed. '
        'Floor under floor under floor, and at the bottom, the Ember. Some '
        'come back. What they carried up is written in the Ledger; what '
        'they left is not.',
  ),
  _place(
    'the_ember',
    'The old fires died, all but one, and it went deep to sulk. Every '
        'spark a delver pockets on the way down is a word of its name. '
        'Claim it and it climbs the stairs with you, warm as a grudge '
        'forgiven.',
  ),
  _place(
    'the_hearth',
    'The room at the top of the stairs. The kettle is always on, the '
        'chairs do not match, and nobody asks how far you got until you '
        'have eaten. Tales are told here, one per rest, in order.',
  ),
  _place(
    'the_depths',
    'Delvers count floors the way sailors count weather — out loud, to '
        'stay honest. Past the ninth the maps stop agreeing with each '
        'other, which the mapmakers insist is the floors\' fault.',
  ),
  _place(
    'the_dice',
    'A delver\'s dice are cut from hearth-brick and fed on ember-light. '
        'They are not luck. They are a bag of small promises, and every '
        'roll is one of them being kept or broken.',
  ),
  _place(
    'the_forge',
    'Between floors there is sometimes an anvil that was not there for '
        'the last delver. The smith takes no ember and gives no name. '
        'Hand over a die and it comes back heavier in exactly one way.',
  ),
  _place(
    'the_provings',
    'Set delves with set rules, kept by the Hearth so delvers can measure '
        'themselves against something that holds still. Clearing one '
        'proves the delver; the delve itself was never in doubt.',
  ),
  _place(
    'the_vistas',
    'What the Hearth\'s one window looks out on. The view does not change '
        'because the world changed — it changes because the delver did. '
        'Earn a vista and the window admits it.',
  ),

  // the company (v0.110.0 The Named Company) — one entry per delver, in
  // roster order. Flavor only: kits and numbers stay on the picker, free.
  _delver(
    'kindler',
    'First down the stairs, every time, and not because anyone asked. A '
        'kindler\'s trade is plain: carry fire into a place that eats '
        'fire, and keep smiling while it haggles. Three honest dice, one '
        'stubborn habit of coming home.',
  ),
  _delver(
    'warden',
    'Wardens take one oath and keep it with their whole body: the delver '
        'behind you climbs out, whatever the stairs decide about you. The '
        'scale mail is borrowed. The patience is not.',
  ),
  _delver(
    'gambler',
    'Cut their luck die thin on purpose — a fair die tells you nothing '
        'about yourself. The Hearth keeps a jar of what the gambler owes '
        'it, and the gambler keeps a jar of what the delve owes them. '
        'Neither jar has ever been emptied.',
  ),
  _delver(
    'ascetic',
    'Owns a brand iron, a whetstone, and no second shirt. The ascetic '
        'went down once with everything and came up with nothing but an '
        'opinion: weight is a debt the deep collects. Now they carry only '
        'edges.',
  ),
  _delver(
    'peddler',
    'Knows the price of every floor and pays none of them full. The '
        'peddler\'s kiln key opens no door in the delve — it opens the '
        'shops, which the peddler will tell you is the same thing said '
        'politely.',
  ),
  _delver(
    'tinker',
    'The tinker does not trust a die they have not taken apart. Every '
        'forge between floors knows them by their knock, and the smith — '
        'who takes no ember and gives no name — has twice almost smiled.',
  ),

  // enemies — common -----------------------------------------------------
  _enemy(
    'cinder_wisp',
    'The first thing a delver meets and the last thing most forget. Wisps '
        'are hearth-sparks that wandered too deep and learned to want.',
  ),
  _enemy(
    'ash_rat',
    'They nest in cold flues and eat the grey. An ash rat has never won a '
        'fight it did not start with three of its cousins.',
  ),
  _enemy(
    'soot_shade',
    'Where a delver burned quick, a shade keeps the shape. It remembers '
        'how to flinch, which is more than some delvers manage.',
  ),
  _enemy(
    'ember_beetle',
    'Its shell is a dead coal and its belly is a live one. Kiln-keepers '
        'once bred them as foot-warmers, then stopped, for good reasons.',
  ),
  _enemy(
    'scoria_tick',
    'Small, patient, and full of somebody else\'s heat. The old rule: if '
        'your ember pouch feels lighter, check your boots.',
  ),
  _enemy(
    'char_sprite',
    'A sprite dances because burning is the only thing it knows how to '
        'love. Do not applaud; they take it as an invitation.',
  ),
  _enemy(
    'flue_crawler',
    'It climbed a chimney once, in some warmer age, and has been looking '
        'for the way back up ever since. Delvers are just rungs to it.',
  ),
  _enemy(
    'cinder_pup',
    'Every delve has strays. Pups will follow a warm hand for miles — '
        'and follow a wounded one further.',
  ),
  _enemy(
    'soot_hound',
    'What a cinder pup grows into when nobody whistles it home. The pack '
        'howls in smoke, not sound; you smell it before you hear it.',
  ),
  _enemy(
    'ash_wraith',
    'A wraith is what a fire owes and never paid. It drifts toward the '
        'living the way a draft finds a keyhole.',
  ),
  _enemy(
    'cinder_crawler',
    'Many legs, one grudge. Crawlers strip a corridor of heat and leave a '
        'frost of grey behind — the delve\'s way of sweeping up.',
  ),
  _enemy(
    'ember_moth',
    'Moths circle a delver\'s lantern until the lantern circles them. '
        'Their wings shed sparks that dreams are said to catch from.',
  ),
  _enemy(
    'slag_brute',
    'Foundry waste that stood up. A brute swings slow enough to count '
        'along with — the counting is the hard part.',
  ),
  _enemy(
    'clinker_ogre',
    'When a furnace is raked out badly, the clinker keeps a temper. Ogres '
        'hoard the fused lumps of everything the fire refused to take.',
  ),
  _enemy(
    'smoke_stalker',
    'You will not see it; that is the arrangement. Stalkers hunt the gap '
        'between a lantern\'s edge and a delver\'s nerve.',
  ),
  _enemy(
    'basalt_shell',
    'Old lava with an opinion. A shell cannot be talked around, only '
        'worn down — patience against patience, and it has more.',
  ),
  _enemy(
    'wick_widow',
    'She spins in tallow, not silk. Whole camps have been found perfectly '
        'preserved, upright, and slightly translucent.',
  ),
  // v0.12.0 commons
  _enemy(
    'tinder_mote',
    'It burns at exactly one temperature and strikes at exactly one pace. '
        'Delvers who learned to count learned it here.',
  ),
  _enemy(
    'slag_snail',
    'It has never hurried and never once been caught off guard. The shell '
        'and the strike arrive together, every time, forever.',
  ),
  _enemy(
    'vent_serpent',
    'It breathes with the mountain — five beats to a cycle, same as the '
        'deep vents. Old delvers tap the count on their pommels.',
  ),
  _enemy(
    'pumice_hulk',
    'Light as bread, hard as grudges. It swings twice because the first '
        'one is for asking and the second is the answer.',
  ),
  // v0.22.0 late regulars
  _enemy(
    'ashglass_sentinel',
    'Vitrified where it stood when the first hearth failed. It guards in '
        'perfect silence — twice — and then remembers what it was posted for.',
  ),
  _enemy(
    'coal_seam_wyrm',
    'It swims the black seams and surfaces on the beat. Miners set their '
        'shifts by wyrm-knock: one to strike, one to hide, forever.',
  ),
  // v0.47.0 response puzzles
  _enemy(
    'vent_ram',
    'It breathes the sour green of the deep vents and charges on the '
        'exhale. Strike it hard mid-breath and the whole engine stalls.',
  ),
  _enemy(
    'cinder_urchin',
    'Every spine remembers the hand that touched it. The urchin does not '
        'attack so much as invoice — one sting per blow, paid on receipt.',
  ),
  // enemies — elite --------------------------------------------------------
  _enemy(
    'pyre_howler',
    'The howl is the weapon; the teeth are punctuation. Pyre howlers sing '
        'a fire higher, and delvers are mostly kindling that walks.',
    cost: 20,
  ),
  _enemy(
    'kiln_golem',
    'Built to tend a kiln that burned out an age ago. It still tends. '
        'Anything that enters the firing chamber is, by definition, pottery.',
    cost: 20,
  ),
  _enemy(
    'ash_reaper',
    'It does not swing its hook in anger. Ash must be gathered, the deep '
        'delve must be swept, and you are standing in the pile.',
    cost: 20,
  ),
  _enemy(
    'forge_warden',
    'The last shift never ended for the warden. It checks the doors, '
        'banks the coals, and removes anything flammable. You are flammable.',
    cost: 20,
  ),
  _enemy(
    'molten_maw',
    'A mouth that outlived its animal. The maw eats heat, metal, and '
        'argument, in that order.',
    cost: 20,
  ),
  _enemy(
    'bellows_knight',
    'Armor with wind for marrow. Each breath it draws makes the delve\'s '
        'fires lean toward it, like courtiers.',
    cost: 20,
  ),
  _enemy(
    'quench_hag',
    'She hates fire the way only something made of it can. A hag\'s bucket '
        'has drowned more hearths than any flood.',
    cost: 20,
  ),
  // v0.12.0 elite
  _enemy(
    'cinder_marshal',
    'The delve\'s garrison never disbanded; it just stopped being alive. '
        'The Marshal still drills, still inspects, still finds you wanting.',
    cost: 20,
  ),
  // v0.47.0 response-puzzle elite
  _enemy(
    'magma_lancer',
    'It fences by catechism: answer the riposte with one clean blow, '
        'answer the charge with many, answer wrong and be corrected.',
    cost: 20,
  ),
  // enemies — bosses --------------------------------------------------------
  _enemy(
    'ember_tyrant',
    'The Tyrant ruled the first hearth and never abdicated. Every ember '
        'you bank is, by its reckoning, taxes owed.',
    cost: 30,
  ),
  _enemy(
    'ashen_colossus',
    'They built it to carry the mountain\'s fire down safely. It carried. '
        'Nobody remembered to tell it where to stop.',
    cost: 30,
  ),
  _enemy(
    'pyre_matriarch',
    'Every wick widow in the delve spun from her line. The Matriarch '
        'tends her brood the way a fire tends a forest.',
    cost: 30,
  ),
  _enemy(
    'cinder_hierophant',
    'It preaches to the coals and the coals believe. The Hierophant\'s '
        'liturgy has one commandment: burn brighter, whatever it costs the '
        'unburnt.',
    cost: 30,
  ),
  _enemy(
    'the_bellows',
    'Not a creature — an office. Something must breathe for the deep '
        'delve, and whatever holds the post is called The Bellows until it '
        'bursts.',
    cost: 30,
  ),
  _enemy(
    'ashfall_twins',
    'One fell into the fire; one was pulled out. They have argued about '
        'which was luckier ever since, and delvers make convenient juries.',
    cost: 30,
  ),
  // v0.22.0 bosses
  _enemy(
    'slag_regent',
    'The Regent holds the causeway for a crown that never came back for '
        'it. It raises its guard the way courts raise drawbridges: twice, '
        'in silence, and then the audience ends.',
    cost: 30,
  ),
  _enemy(
    'hearthless_king',
    'A king who banked his own hearth to outlast his rivals, and did. Now '
        'he keeps the only time left to him: strike, guard, strike, guard.',
    cost: 30,
  ),
  // relics -------------------------------------------------------------------
  _relic(
    'ember_ring',
    'A wedding band from a marriage of coin and coal. It warms when gold '
        'changes hands, which in the delve is constantly.',
  ),
  _relic(
    'kiln_key',
    'It opens no kiln anyone has found. The keepers paid well to keep it '
        'that way, and the paying never quite stopped.',
  ),
  _relic(
    'ashen_idol',
    'A little god of what remains. It asks no worship — only that you '
        'keep winning, which it considers the same thing.',
  ),
  _relic(
    'midas_die',
    'Cast from a king\'s last meal. It loves a perfect throw the way its '
        'first owner loved his daughter: profitably, and too late.',
  ),
  _relic(
    'lucky_coin',
    'Two faces, both winners. Somewhere there is a coin with two losing '
        'faces, and the delve keeps them apart.',
  ),
  _relic(
    'iron_scale',
    'One scale from the thing that sleeps below the forges. It shrugs '
        'off blows out of habit; the rest of the animal never noticed any.',
  ),
  _relic(
    'bulwark_sigil',
    'Chalked on shield-walls by soldiers who went down singing. The delve '
        'kept the chalk; the song is in there somewhere too.',
  ),
  _relic(
    'whetstone',
    'It has sharpened blades, wits, and one very specific grudge. Only '
        'the blades ever thanked it.',
  ),
  _relic(
    'war_drum',
    'The hide remembers the charge; the delver\'s pulse keeps the count. '
        'Armies fell before anyone thought to ask what the drum wanted.',
  ),
  _relic(
    'kite_charm',
    'A child\'s toy from the last town above that saw the sky. It pulls '
        'gently upward on everything around it, including spirits.',
  ),
  _relic(
    'loaded_pips',
    'Honest dice weighted by a dishonest saint. He swore the low faces '
        'were where the devil sat, and filed them off accordingly.',
  ),
  _relic(
    'gamblers_eye',
    'A glass eye that watched one bluff too many. Wear it and the delve '
        'occasionally lets you take a throw back — once, and it counts.',
  ),
  _relic(
    'twin_eye',
    'The pair to the Gambler\'s Eye, lost in a different bet. Together '
        'they see the roll you meant instead of the roll you made.',
  ),
  _relic(
    'fire_salve',
    'Rendered from ember-moth wings and forgiveness. It closes wounds '
        'with a warmth that stays exactly long enough.',
  ),
  _relic(
    'phoenix_feather',
    'The bird is a story, but something molts down there. The feather '
        'does not grant rebirth — just a stubborn refusal to finish dying.',
  ),
  _relic(
    'thorn_band',
    'A crown for the kind of ruler who is only touched once. The delve '
        'has never lacked for volunteers to test it.',
  ),
  _relic(
    'slayers_mark',
    'A brand taken willingly by hunters of the delve\'s champions. The '
        'big ones see the mark and know that this time it is personal.',
  ),
  _relic(
    'tyrant_bane',
    'Forged from the crown of the last delver who nearly won. It '
        'remembers the throne room, and it swings heavier there.',
  ),
  _relic(
    'bedroll',
    'Wool, straw, and the smell of a house that no longer stands. The '
        'delve grants deeper sleep to those who carry their home with them.',
  ),
  _relic(
    'haggler_tongue',
    'Preserved from the delve\'s greatest merchant, who talked a dragon '
        'down to cost. Shopkeepers can tell you carry it, and sigh.',
  ),
  _relic(
    'blood_ruby',
    'It beats. Faintly, but it beats, and while you carry it your own '
        'heart takes advice from something older.',
  ),
  _relic(
    'ember_heartstone',
    'The heart of a hearth that burned a hundred years unbanked. What it '
        'sheltered then, it shelters still — currently, you.',
  ),
  // v0.12.0 relics
  _relic(
    'cinder_lantern',
    'A lantern that gives no light, only steadiness. Watchmen of the old '
        'garrison carried them; their shadows learned to stand still.',
  ),
  _relic(
    'serpent_fang',
    'Pulled from a vent serpent that bit a delver in full plate. The '
        'serpent regretted it first. The fang remembers how that felt.',
  ),
  _relic(
    'pumice_plate',
    'Armor cut from a hulk\'s shoulder: absurdly light, stubbornly whole. '
        'It floats, which has embarrassed exactly one delver at a crossing.',
  ),
  _relic(
    'hearth_kettle',
    'Every camp had one; this is the one that survived them. Water boiled '
        'in it tastes faintly of iron and strongly of getting to rest.',
  ),
  // v0.22.0 relics
  _relic(
    'siege_hook',
    'Forged to open gates that preferred to stay shut. It has no opinion '
        'on doors, walls, or guards — only on the difference between '
        'outside and inside.',
  ),
  _relic(
    'kings_ransom',
    'The toll bowl of the Hearthless King, worn smooth by paying hands. '
        'Whatever you win while carrying it, it quietly takes its cut — '
        'and adds it to yours.',
  ),
  // v0.25.0 relics
  _relic(
    'drowned_bell',
    'It rang the old garrison to sleep and to arms in the same voice. '
        'Sunk in a quenching pool the night the King fell, it still keeps '
        'both appointments.',
  ),
  _relic(
    'ashglass_prism',
    'Slag cools into glass where the fire burned proudest. Held to a '
        'lantern it splits light into colors the deep otherwise keeps '
        'for itself.',
  ),
  _relic(
    'wyrmscale_cloak',
    'Shed scales of a coal-seam wyrm, stitched with wire. It turns a '
        'blade the way the wyrm turned pickaxes: with visible contempt.',
  ),
  _relic(
    'choir_censer',
    'The soot choir circles it when it swings. What they are paid in is '
        'unclear; what you are paid in is not.',
  ),
  // v0.46.0 — "The Delvers Before" -----------------------------------------
  _relic(
    'cairn_stone',
    'Taken from the top of a cairn, or meant for the top of one. Delvers '
        'carry it so that, either way, the stone arrives.',
  ),
  _relic(
    'rivals_compass',
    'It does not point north. It points the way she went, which was always '
        'the cheaper road, and she never once told you why.',
  ),
  _relic(
    'keepers_lantern',
    'Trimmed and refilled by every hand that carries it. The light is not '
        'yours; you are only the keeper this far down.',
  ),
  _relic(
    'tally_chain',
    'One link for every delve someone came back from. It is longer than it '
        'looks, and it is not finished.',
  ),
];

/// Lookup by namespaced id ('enemy:cinder_wisp' / 'relic:ember_ring').
final Map<String, CodexEntryDef> codexById = {
  for (final e in codexEntries) e.id: e,
};
