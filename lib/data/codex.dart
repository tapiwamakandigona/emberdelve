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
// 'delver:<id>' v0.110.0 / 'die:<id>' v0.116.0) so MetaState can keep
// ownership in one flat set without collisions. Enemy, relic, delver, and
// die names are NOT stored here — the UI reads them from enemies.dart /
// relics.dart / characters.dart / dice.dart, so a rename there can never
// leave the Codex lying. Places (v0.104.0 The Delve Itself) exist only
// here, so [placeNames] is theirs. Dice lore covers the five BASE CUTS
// only (d4/d6/d8/d10/d12) — one story per shape of hearth-brick; the
// tempered variants are those cuts re-promised, not new stone.
//
// Prices: common enemies 15, elites 20, bosses 30, relics 20, places 10,
// delvers 15 — the world's own words are the cheapest words in the book,
// because 'what is a delve?' is the first question a new delver actually
// asks; who the company are is the second.

/// THE FIRST WORDS (retention lane, DEMAND 2026-08-31c focus #1): entries
/// the book gives away — always unsealed, never charged, never counted as
/// an earned unseal by the ledger's marks. 'What is a delve?' is the first
/// question a new delver actually asks, and a real review answered our old
/// design for us: a player finished easy mode still not knowing. The
/// world's first words are free; the rest of the book still sells.
const Set<String> giftedCodex = {'place:the_delve'};

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
CodexEntryDef _die(String refId, String text) =>
    CodexEntryDef('die:$refId', 'die', refId, text, costEmbers: 15);
// v0.131.0 The Written Rules: the weekly calendar's own words — priced
// like places (the calendar is world, not tool).
CodexEntryDef _rule(String refId, String text) =>
    CodexEntryDef('rule:$refId', 'rule', refId, text, costEmbers: 10);
// v0.142.0 The Written Marks: the anvil's own words — priced like dice
// (the marks are tools of the trade). Names resolve via runeName().
CodexEntryDef _runeEntry(String refId, String text) =>
    CodexEntryDef('rune:$refId', 'rune', refId, text, costEmbers: 15);

/// Display names for 'rule' entries. Five ids mirror lib/data/mutators.dart
/// (asserted by test); 'cold_quarter' is the doubled week's own name.
const Map<String, String> ruleNames = {
  'all_d4': 'Flint Week',
  'elites_only': 'Elite Gauntlet',
  'no_shops': 'No Quarter',
  'short_road': 'Short Road',
  'no_rests': 'Cold Camps',
  'cold_quarter': 'Cold Quarter',
};

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
  // v0.118.0: the seventh chair at the fire.
  _delver(
    'flintwright',
    'Cuts shards where other delvers carry stones, and carries four of '
        'them, because a pocketful of small promises has never once been '
        'a single broken one. The company laughed until the counting '
        'started.',
  ),
  // v0.135.0: the eighth chair.
  _delver(
    'runesmith',
    'The smith at the rest fires takes no ember and gives no name — but '
        'someone taught the smith. The runesmith went down before the '
        'company had a name for going down, and came back marked.',
  ),
  _delver(
    'bearer',
    'The bearer carries the company\u2019s heaviest die and asks for '
        'nothing else. Two hands, two dice, one promise — when the big '
        'face lands, the floor remembers it. The ninth chair is wider '
        'than the others. Nobody jokes about it twice.',
  ),
  _delver(
    'mender',
    'The mender worked the Mend rune into the worst face of a Deep '
        'Coal — so the roll every delver curses is the one that '
        'stitches. Ask why, and they tap the die: the delve takes. '
        'Something at this fire should give back.',
  ),
  _delver(
    'shieldwright',
    'Every other delver marks their dice at the rest fires, one strike '
        'at a time. The shieldwright finished the work topside — an '
        'Aegis driven DEEP into an Ember Die\u2019s six before the '
        'first stair. Ask what the hurry was, and they knock the die '
        'twice: the delve does not wait for the second strike.',
  ),
  _delver(
    'gilder',
    'Most delvers spend their sixes and think no more of it. The '
        'gilder worked gilt into both Ember Dice topside, so every six '
        'that lands leaves coin in the pouch. Ask why gold, of all '
        'runes, twice \u2014 and they shrug: the delve pays whoever '
        'reads it. The gilder just wrote it on the dice.',
  ),
  _delver(
    'cutler',
    'Ask a cutler which matters more, the edge or the spine, and you '
        'will be there a while. Their dice answer faster: a Blade '
        'sharpened into the Deep Coal\u2019s eight, an Aegis worked '
        'into an Ember Die\u2019s six. One face cuts, one face holds. '
        'A good knife, they say, does both.',
  ),
  _delver(
    'collier',
    'A collier\u2019s craft is patience: wood banked under turf, burning '
        'slow for days until every stick is coal. Their dice came out of '
        'the same clamp \u2014 all three worked, none plain. A Blade on '
        'one six, a Gilt on another, and a Mend hidden on the low face, '
        'because a collier knows the small coal keeps the burn alive.',
  ),
  _delver(
    'stoker',
    'A stoker\u2019s craft is appetite: the furnace eats what it is '
        'fed, and a good stoker feeds it whole. Their pouch holds three '
        'heavy dice and nothing else \u2014 no relic, no smith\u2019s '
        'marks, no clever low face. Big coals, big rolls, and a thin '
        'skin between the stoker and the heat they serve.',
  ),
  _delver(
    'hearthkeeper',
    'The last chair belongs to the one who never leaves it empty. A '
        'hearthkeeper\u2019s dice were born to their work \u2014 a Brand '
        'that only strikes, a Ward that only shields, a Steady that never '
        'rolls under three. Nothing plain, nothing spare: the fire is '
        'kept, the door is kept, and the sixteenth chair keeps them both.',
  ),
  _delver(
    'hedger',
    'The first chair of the second circle. A hedger\u2019s craft is the '
        'laid thorn: the wall that answers whoever strikes it. Their '
        'pouch is the kindler\u2019s own \u2014 three plain dice \u2014 '
        'but the Thorn Band prices every blow against them, and thin '
        'skin makes the pricing dear both ways.',
  ),
  _delver(
    'miller',
    'The second chair of the second circle. A miller\u2019s trade is '
        'patience with weight: the stone turns slow, and everything '
        'smaller moves to feed it. One grand die that promises the '
        'grind, two shards that keep the mill fed while it comes round '
        '\u2014 the widest pouch a delver has ever carried.',
  ),
  _delver(
    'brewster',
    'The third chair of the second circle. Brewing is the trade of '
        'waiting well: the kettle does the work if you can last until '
        'it sings. Thin dice, a Hearth Kettle, and the delve walked '
        'rest to rest \u2014 every camp a table set twice over.',
  ),
  _delver(
    'lamplighter',
    'The fourth chair of the second circle. Lamplighting is a dusk '
        'trade: most of the walk is ordinary, and then a wick takes and '
        'a whole street changes. Three Glowing Embers \u2014 plain '
        'sixes until they land true, and when they do, they flare.',
  ),
  _delver(
    'farrier',
    'The fifth chair of the second circle. Farriery is exactness '
        'under weight: the shoe fits or it does not, and the horse '
        'does not care how hard you swung. Three Forged Embers, each '
        'a little more than its face on every roll \u2014 and the '
        'thinnest skin at any fire, because iron this sure was paid '
        'for somewhere.',
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
  // the dice (v0.116.0 The Spoken Dice) — the five base cuts, shallow to
  // deep. One story per shape; the tempered variants are these same cuts
  // re-promised at the forge, so the shapes carry all the lore.
  _die(
    'd4',
    'The smallest promise a delver can carry: four faces, none of them '
        'far apart. A flint shard will not save you, and it will not lie '
        'to you either. Plenty start with nothing else and get home.',
  ),
  _die(
    'd6',
    'The honest middle of every pool. Six faces cut true from '
        'hearth-brick, fed on ember-light, worn round at the corners by '
        'delvers who rolled it when it mattered. When the tales say '
        '\'a die\', they mean this one.',
  ),
  _die(
    'd8',
    'Coal from below the third floor takes a harder edge. An eight keeps '
        'its promises bigger and its silences longer — a delver learns to '
        'plan for both ends of it.',
  ),
  _die(
    'd10',
    'Cut from the heart of a dead forge, and it remembers the work. Ten '
        'faces is enough range to win a fight or lose one all by itself; '
        'the smiths call that honesty, not risk.',
  ),
  _die(
    'd12',
    'The deep\'s own stone, still warm when it is carved. Twelve faces '
        'hold the biggest words a die can say, and the delve listens when '
        'they land. Nobody carries one by accident.',
  ),
  // the rules (v0.131.0) — the weekly calendar's own words -----------------
  _rule(
    'all_d4',
    'The first Monday the delve dealt it, the smiths laughed. By the '
        'third floor nobody was laughing: a d4 keeps every edge a die '
        'ever earned and none of its reach.',
  ),
  _rule(
    'elites_only',
    'A week when the delve fields its captains and no one else. The '
        'old hands pack for it like a war: harder road going down, '
        'richer bags coming home.',
  ),
  _rule(
    'no_shops',
    'The peddler calls it his week off. Everyone else calls it what it '
        'is: nine floors where gold is just a heavy way to count what '
        'you cannot buy.',
  ),
  _rule(
    'short_road',
    'Six floors, cut clean. The delve does not shrink so much as '
        'quicken; the deep foes arrive early, tuned to meet a shorter '
        'blade.',
  ),
  _rule(
    'no_rests',
    'The week the camps go dark. Every hollow that should have held a '
        'fire holds something waiting instead, and healing is a thing '
        'you carry, not a place you find.',
  ),
  _rule(
    'cold_quarter',
    'Once a rotation the delve deals two rules at once: no shops, no '
        'rests. The wardens named it the Cold Quarter and the name '
        'stuck, the way frost does.',
  ),
  // the marks (v0.142.0) — the anvil's own words --------------------------
  _runeEntry(
    'blade',
    'The first rune anyone asks for, and the one the smith respects '
        'least. An edge is honest work, the smith allows — but any '
        'delve will teach you that hitting harder is the smallest of '
        'your problems.',
  ),
  _runeEntry(
    'aegis',
    'Wardens swear by it and the smith swears by wardens. A guard '
        'worked into a face holds like a wall holds: not always, but '
        'exactly when it said it would.',
  ),
  _runeEntry(
    'surge',
    'A roll given back is a decision given back. The gamblers call '
        'surge the only honest luck in the delve, because it is not '
        'luck at all.',
  ),
  _runeEntry(
    'echo',
    'The mark that pays forward: strike, and the guard after it '
        'stands taller; guard, and the strike after it lands harder. '
        'The smith calls it teaching a die to remember.',
  ),
  _runeEntry(
    'mend',
    'One breath of warmth on the face that earned it. The old hands '
        'say mend wins no fights — it just keeps you standing through '
        'the ones you were losing.',
  ),
  _runeEntry(
    'gilt',
    'Gold off a die face, small and steady. The peddler claims the '
        'gilt rune was their idea, and the smith has never denied it '
        'loudly enough to settle the matter.',
  ),
];

/// Lookup by namespaced id ('enemy:cinder_wisp' / 'relic:ember_ring').
final Map<String, CodexEntryDef> codexById = {
  for (final e in codexEntries) e.id: e,
};
