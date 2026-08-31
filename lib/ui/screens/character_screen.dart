// lib/ui/screens/character_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class CharacterScreen extends StatefulWidget {
  final GameController c;
  const CharacterScreen(this.c, {super.key});
  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  int ascension = 0;
  // v0.66.0 The Dressed Delver: which delver THE EPITHET shelf dresses.
  // Defaults to the last delved (their record is freshest in mind), else
  // the first unlocked. Screen-local — the dress itself persists in meta.
  String? dressTarget;

  String _defaultDressTarget(MetaState m) {
    final last = m.runHistory.isNotEmpty
        ? m.runHistory.first['character'] as String?
        : null;
    if (last != null && m.isUnlocked(last)) return last;
    return charactersOrder.firstWhere(
      m.isUnlocked,
      orElse: () => defaultCharacter,
    );
  }

  /// v0.72.0 The Given Name: name (or un-name) a delver. Empty field =
  /// restore the true name — reversible, free, no confirmation drama.
  void _promptName(BuildContext context, String id) {
    final c = widget.c;
    final trueName = characters[id]!.name;
    final given = c.meta.charName[id];
    final input = TextEditingController(text: given ?? '');
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: EmberColors.surface,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: Space.l,
          vertical: Space.xl,
        ),
        title: const Text('Name this delver', style: EmberText.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Theirs by birth: $trueName. Leave the field empty to '
              'give it back.',
              style: EmberText.bodyDim,
            ),
            const SizedBox(height: Space.m),
            TextField(
              key: const ValueKey('name-field'),
              controller: input,
              autofocus: true,
              maxLength: 16,
              style: EmberText.body,
              decoration: InputDecoration(hintText: trueName),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: EmberText.bodyDim),
          ),
          TextButton(
            key: const ValueKey('name-save'),
            onPressed: () {
              c.setDelverName(id, input.text);
              Navigator.of(dialogCtx).pop();
              setState(() {});
            },
            child: const Text('Keep', style: EmberText.body),
          ),
        ],
      ),
    );
  }

  /// Pill row naming who the epithet taps below will dress. Hidden by the
  /// caller when only one delver is unlocked (nothing to choose between).
  Widget _dressChipRow(
    BuildContext context,
    MetaState m, {
    String keyPrefix = 'dress',
  }) {
    final target = dressTarget ?? _defaultDressTarget(m);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final id in charactersOrder)
            if (m.isUnlocked(id))
              Padding(
                padding: const EdgeInsets.only(right: Space.s),
                child: GestureDetector(
                  key: ValueKey('$keyPrefix-$id'),
                  onTap: () {
                    if (target == id) return;
                    AudioService.instance?.playSfx('ui_tap');
                    setState(() => dressTarget = id);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.m,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: target == id
                          ? EmberColors.raised
                          : EmberColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: target == id
                            ? EmberColors.ember
                            : EmberColors.line,
                      ),
                    ),
                    child: Text(
                      m.nameFor(id),
                      style: EmberText.micro.copyWith(
                        color: target == id
                            ? EmberColors.textPrimary
                            : EmberColors.textDim,
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final m = c.meta;
    final maxAsc = maxAscensionFor(m); // Forge-gated (v0.4.0)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a delver', style: EmberText.h2),
        backgroundColor: EmberColors.bg,
        leading: BackButton(
          onPressed: () {
            AudioService.instance?.playSfx('ui_back');
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        // Tablet clamp (v0.26.0): content caps at kMaxContentWidth.
        child: ContentClamp(
          child: ScrollComfort(
            child: ListView(
              padding: const EdgeInsets.all(Space.l),
              children: [
                _nextUnlockBar(m),
                const SizedBox(height: Space.l),
                for (final id in charactersOrder) _charCard(context, id),
                const SizedBox(height: Space.l),
                // v0.27.0 The Delver's Wardrobe — dyes, same tap contract as
                // the Ledger's hearth colors / dice skins: tap owned to wear,
                // tap locked to buy (price always visible).
                Row(
                  children: [
                    const Expanded(
                      child: Text('THE WARDROBE', style: EmberText.micro),
                    ),
                    const Icon(
                      Icons.local_fire_department,
                      color: EmberColors.ember,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${m.embers}',
                      style: EmberText.label.copyWith(color: EmberColors.ember),
                    ),
                  ],
                ),
                const SizedBox(height: Space.s),
                // v0.67.0 The Dyed Delver: dyes are worn per delver. Same
                // pills as THE EPITHET, same shared target — one delver is
                // being dressed on this screen.
                if (m.unlockedCharacters.length > 1) ...[
                  _dressChipRow(context, m, keyPrefix: 'dye-dress'),
                  const SizedBox(height: Space.m),
                ],
                for (final id in delverDyesOrder) ...[
                  _dyeCard(context, id),
                  const SizedBox(height: Space.m),
                ],
                const SizedBox(height: Space.s),
                Text(
                  'Dyes recolor a delver everywhere they appear, and each '
                  'delver keeps their own. Bought once with embers, worn by '
                  'any of them. Pure cosmetics — the delve itself never '
                  'changes.',
                  style: EmberText.micro.copyWith(color: EmberColors.textDim),
                ),
                const SizedBox(height: Space.l),
                // v0.35.0 The Vistas — background grades, milestone-unlocked
                // (the other half of the wardrobe ask: 'change backgrounds').
                const Text('THE VISTA', style: EmberText.micro),
                const SizedBox(height: Space.s),
                // v0.115.0 The Delver's Window: vistas are worn per delver —
                // the pills name who the taps below dress. Hidden with one
                // delver unlocked (the shelf reads exactly as it always has).
                if (m.unlockedCharacters.length > 1) ...[
                  _dressChipRow(context, m, keyPrefix: 'vista-dress'),
                  const SizedBox(height: Space.m),
                ],
                for (final id in vistasOrder) ...[
                  _vistaCard(context, id),
                  const SizedBox(height: Space.m),
                ],
                const SizedBox(height: Space.s),
                Text(
                  'Vistas repaint the delve itself — every layer, in the '
                  'light each delver chooses. Earned by delving, never sold.',
                  style: EmberText.micro.copyWith(color: EmberColors.textDim),
                ),
                const SizedBox(height: Space.l),
                // v0.138.0 The Delver's Dice: skins worn per delver — the
                // ledger shelf still buys and sets the global fallback; this
                // row binds an owned skin to the delver being dressed.
                const Text('THE DICE', style: EmberText.micro),
                const SizedBox(height: Space.s),
                if (m.unlockedCharacters.length > 1) ...[
                  _dressChipRow(context, m, keyPrefix: 'skin-dress'),
                  const SizedBox(height: Space.m),
                ],
                for (final id in dieSkinsOrder)
                  if (id == defaultDieSkin || m.ownedDieSkins.contains(id)) ...[
                    _skinCard(context, id),
                    const SizedBox(height: Space.m),
                  ],
                const SizedBox(height: Space.s),
                Text(
                  'Each delver rolls their own set. New skins are bought on '
                  'the Ledger shelf; owned ones are worn here.',
                  style: EmberText.micro.copyWith(color: EmberColors.textDim),
                ),
                const SizedBox(height: Space.l),
                // v0.36.0 The Epithets — earned titles worn under the delver's
                // name; carried onto the shareable Delver's Card.
                const Text('THE EPITHET', style: EmberText.micro),
                const SizedBox(height: Space.s),
                // v0.66.0 The Dressed Delver: titles are worn per delver —
                // the pills name who the taps below dress. Hidden with one
                // delver unlocked (the shelf reads exactly as it always has).
                if (m.unlockedCharacters.length > 1) ...[
                  _dressChipRow(context, m),
                  const SizedBox(height: Space.m),
                ],
                _epithetNoneCard(context),
                const SizedBox(height: Space.m),
                for (final id in epithetsOrder) ...[
                  _epithetCard(context, id),
                  const SizedBox(height: Space.m),
                ],
                const SizedBox(height: Space.s),
                Text(
                  'An epithet is worn under a delver\'s name — on this '
                  'screen, on the summary, and on any card you share. Each '
                  'delver wears their own. Earned by delving, never sold.',
                  style: EmberText.micro.copyWith(color: EmberColors.textDim),
                ),
                const SizedBox(height: Space.l),
                const Text('ASCENSION', style: EmberText.micro),
                const SizedBox(height: Space.s),
                const Text(
                  'Every rung makes enemies tougher; higher tiers hit harder too. '
                  'Unlock the next rung by winning at the current one.',
                  style: EmberText.bodyDim,
                ),
                const SizedBox(height: Space.s),
                // Ember Forge (v0.4.0): the ladder is the Forge's endgame tier.
                if (!m.forgeUnlocked) ...[
                  Panel(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock,
                          color: EmberColors.textDim,
                          size: 18,
                        ),
                        const SizedBox(width: Space.m),
                        const Expanded(
                          child: Text(
                            'The Ascension ladder is part of the '
                            'Ember Forge.',
                            style: EmberText.bodyDim,
                          ),
                        ),
                        EmberButton(
                          'Open',
                          dense: true,
                          onTap: () => showForgeSheet(context, widget.c),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.s),
                ],
                Row(
                  children: [
                    IconButton(
                      onPressed: ascension > 0
                          ? () => setState(() => ascension--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$ascension', style: EmberText.value),
                    IconButton(
                      onPressed: ascension < maxAsc
                          ? () => setState(() => ascension++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    const SizedBox(width: Space.s),
                    Text('max unlocked: $maxAsc', style: EmberText.bodyDim),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nextUnlockBar(m) {
    final target = m.nextUnlockTarget;
    if (target == null) {
      return const Panel(
        child: Text('All delvers unlocked.', style: EmberText.body),
      );
    }
    final frac = (m.embers / target.unlockEmbers).clamp(0.0, 1.0);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT UNLOCK — ${target.name.toUpperCase()}',
            style: EmberText.micro,
          ),
          const SizedBox(height: Space.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 12, color: EmberColors.raised),
                FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(height: 12, color: EmberColors.ember),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s),
          Text(
            '${m.embers} / ${target.unlockEmbers} embers',
            style: EmberText.bodyDim,
          ),
        ],
      ),
    );
  }

  /// v0.35.0: tap unlocked to choose; a locked vista shows its real
  /// milestone (never a price — vistas are earned, §Ethics). The swatch is
  /// the map backdrop wearing the vista — exactly what the delve will paint.
  /// The bare option: no epithet at all. Always selectable.
  Widget _epithetNoneCard(BuildContext context) {
    final c = widget.c;
    final target = dressTarget ?? _defaultDressTarget(c.meta);
    final chosen = c.meta.epithetFor(target) == defaultEpithet;
    return GestureDetector(
      key: const ValueKey('epithet-none'),
      onTap: () {
        if (chosen) return;
        AudioService.instance?.playSfx('ui_tap');
        c.selectEpithet(defaultEpithet, forChar: target);
        setState(() {});
      },
      child: Panel(
        color: chosen ? EmberColors.raised : EmberColors.surface,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('No epithet', style: EmberText.body),
                  const SizedBox(height: 2),
                  Text(
                    'Just a delver. The dark asks no more.',
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                ],
              ),
            ),
            if (chosen)
              Text(
                'WORN',
                style: EmberText.micro.copyWith(
                  color: EmberColors.ember,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Same contract as _vistaCard: tap unlocked to wear; locked shows the
  /// honest milestone and a lock.
  Widget _epithetCard(BuildContext context, String id) {
    final c = widget.c;
    final e = epithets[id]!;
    final unlocked = c.epithetUnlocked(id);
    final target = dressTarget ?? _defaultDressTarget(c.meta);
    final chosen = c.meta.epithetFor(target) == id;
    return GestureDetector(
      key: ValueKey('epithet-$id'),
      onTap: () {
        if (chosen) return;
        if (unlocked) {
          AudioService.instance?.playSfx('ui_tap');
          c.selectEpithet(id, forChar: target);
        } else {
          AudioService.instance?.playSfx('ui_back');
        }
        setState(() {});
      },
      child: Panel(
        color: chosen ? EmberColors.raised : EmberColors.surface,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: unlocked
                        ? EmberText.body
                        : EmberText.body.copyWith(color: EmberColors.textDim),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    e.unlockLine,
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            if (chosen)
              Text(
                'WORN',
                style: EmberText.micro.copyWith(
                  color: EmberColors.ember,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (!unlocked)
              const Icon(
                Icons.lock_outline,
                color: EmberColors.textDim,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  /// v0.138.0: same contract as _vistaCard, owned skins only (buying
  /// stays on the Ledger shelf). Swatch is the skin itself on a DieChip.
  Widget _skinCard(BuildContext context, String id) {
    final c = widget.c;
    final def = dieSkinDef(id);
    final target = dressTarget ?? _defaultDressTarget(c.meta);
    final chosen = c.meta.skinFor(target) == id;
    return GestureDetector(
      key: ValueKey('charskin-$id'),
      onTap: () {
        if (chosen) return;
        AudioService.instance?.playSfx('ui_tap');
        c.setSkinFor(id, forChar: target);
        setState(() {});
      },
      child: Panel(
        color: chosen ? EmberColors.raised : EmberColors.surface,
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 44,
              // FittedBox: the chip renders at its natural size and is
              // scaled to the swatch slot (a hard box overflows by 22px).
              child: FittedBox(child: DieChip('d6', skin: id)),
            ),
            const SizedBox(width: Space.m),
            Expanded(child: Text(def.name, style: EmberText.body)),
            if (chosen)
              Text(
                'WORN',
                style: EmberText.micro.copyWith(
                  color: EmberColors.ember,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _vistaCard(BuildContext context, String id) {
    final c = widget.c;
    final v = vistas[id]!;
    final unlocked = c.vistaUnlocked(id);
    // v0.115.0 The Delver's Window: vistas are worn per delver, bound to
    // the delver being dressed — same target the dyes and epithets use.
    final target = dressTarget ?? _defaultDressTarget(c.meta);
    final chosen = c.meta.vistaFor(target) == id;
    final grade = Art.backgroundGrade(0, id);
    Widget swatch = Image.asset(
      'assets/images/backgrounds/bg_map.png',
      width: 34,
      height: 42,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
    if (grade != null) {
      swatch = ColorFiltered(colorFilter: grade, child: swatch);
    }
    final wash = Art.backgroundWash(0, id);
    return GestureDetector(
      key: ValueKey('vista-$id'),
      onTap: () {
        if (chosen) return;
        if (unlocked) {
          AudioService.instance?.playSfx('ui_tap');
          c.setVistaFor(id, forChar: target);
        } else {
          AudioService.instance?.playSfx('ui_back');
        }
        setState(() {});
      },
      child: Panel(
        color: chosen ? EmberColors.raised : EmberColors.surface,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 34,
                height: 42,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    swatch,
                    if (wash.a > 0) Container(color: wash),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.name,
                    style: unlocked
                        ? EmberText.body
                        : EmberText.body.copyWith(color: EmberColors.textDim),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unlocked ? v.text : v.unlockLine,
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            if (chosen)
              Text(
                'CHOSEN',
                style: EmberText.micro.copyWith(
                  color: EmberColors.ember,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (!unlocked)
              const Icon(
                Icons.lock_outline,
                color: EmberColors.textDim,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  /// Same contract as the Ledger's _skinCard: tap owned to wear, tap locked
  /// to buy (price always visible). The swatch is the delver sprite wearing
  /// the dye — what you see is exactly what every screen will paint.
  Widget _dyeCard(BuildContext context, String id) {
    final c = widget.c;
    final d = delverDyes[id]!;
    final m = c.meta;
    final owned = m.ownedDyes.contains(id);
    final target = dressTarget ?? _defaultDressTarget(m);
    final active = m.dyeFor(target) == id;
    final affordable = m.embers >= d.costEmbers;
    return GestureDetector(
      key: ValueKey('dye-$id'),
      onTap: () {
        if (active) return;
        if (owned) {
          AudioService.instance?.playSfx('ui_tap');
          c.setActiveDye(id, forChar: target);
        } else if (c.buyDye(id)) {
          c.setActiveDye(id, forChar: target);
        } else {
          AudioService.instance?.playSfx('ui_back');
        }
        setState(() {});
      },
      child: Panel(
        color: active ? EmberColors.raised : EmberColors.surface,
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 42,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SpriteView(
                  // v0.67.0: the swatch is the delver being dressed, wearing
                  // this dye — what you see is exactly what they'll paint.
                  target,
                  height: 40,
                  animate: false,
                  dye: Art.dyeFilter(id),
                ),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, style: EmberText.body),
                  const SizedBox(height: 2),
                  Text(
                    d.text,
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            if (active)
              Text(
                'WORN',
                style: EmberText.micro.copyWith(
                  color: EmberColors.ember,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (owned)
              Text(
                'OWNED',
                style: EmberText.micro.copyWith(color: EmberColors.textDim),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 14,
                    color: affordable
                        ? EmberColors.ember
                        : EmberColors.textDisabled,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${d.costEmbers}',
                    style: EmberText.label.copyWith(
                      color: affordable
                          ? EmberColors.ember
                          : EmberColors.textDisabled,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// v0.60.0 The Delver's Tally: "N wins · M delves" for a delver you have
  /// actually taken down (charRuns/charWins, the same counters the Ledger
  /// roster reads). Null when the delver has never delved — the picker stays
  /// clean for fresh delvers and fresh installs.
  static String? _tallyLine(MetaState m, String id) {
    final runs = m.charRuns[id] ?? 0;
    if (runs <= 0) return null;
    final wins = m.charWins[id] ?? 0;
    final base =
        '$wins ${wins == 1 ? 'win' : 'wins'} · '
        '$runs ${runs == 1 ? 'delve' : 'delves'}';
    // v0.65.0 The Charted Depth: this delver's deepest floor, appended to
    // the tally when one exists. Older profiles seed it from the run
    // history on load; a delver with runs but no provable depth (a
    // pre-ledger save) shows the tally alone — never a guessed floor.
    // v0.123.0 The Crowned Company: hard wins join the tally the same way
    // depth did — only when one exists, never a guessed zero.
    final crowns = m.charHardWins[id] ?? 0;
    final crowned = crowns > 0 ? '$base · $crowns hard' : base;
    final depth = m.charBestFloor[id] ?? 0;
    return depth > 0 ? '$crowned · floor $depth' : crowned;
  }

  Widget _charCard(BuildContext context, String id) {
    final c = widget.c;
    final def = characters[id]!;
    final unlocked = c.meta.isUnlocked(id);
    final canAfford = c.meta.embers >= def.unlockEmbers;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Static portrait frame from the character sheet (idle frame 0);
                // animation stays reserved for the combat stage. The signature
                // weapon leans against the frame so the arsenal reads at a
                // glance before the delve.
                Opacity(
                  opacity: unlocked ? 1 : 0.45,
                  child: SizedBox(
                    width: 78,
                    height: 58,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SpriteView(
                          id,
                          height: 56,
                          animate: false,
                          dye: Art.dyeFilter(c.meta.dyeFor(id)),
                        ),
                        Positioned(
                          right: 0,
                          bottom: -2,
                          child: WeaponView(
                            id,
                            height: 46,
                            phase: WeaponPhase.idle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // v0.72.0 The Given Name: an unlocked delver's name
                      // is the player's to give. Tap to name; clearing the
                      // field restores the true name. Locked delvers keep
                      // their roster name untouchable.
                      if (!unlocked)
                        // Fit, don't wrap: 'The Flintwright' (v0.118.0) is
                        // the first roster name long enough to break
                        // mid-word at 320 dp — same rule as given names.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(def.name, style: EmberText.h2),
                        )
                      else
                        InkWell(
                          key: ValueKey('name-edit-$id'),
                          onTap: () => _promptName(context, id),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Fit, don't clip: a full 16-char given name
                              // scales down slightly rather than losing its
                              // tail to an ellipsis (the logotype lesson).
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    c.meta.nameFor(id),
                                    style: EmberText.h2,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Space.s),
                              const Icon(
                                Icons.edit,
                                size: 14,
                                color: EmberColors.textDim,
                              ),
                            ],
                          ),
                        ),
                      // v0.36.0: the worn epithet, under each unlocked
                      // delver's name (a title is worn, not window-shopped).
                      // v0.66.0: THEIR OWN title — each delver resolves
                      // through epithetFor (own dress, else legacy global).
                      if (unlocked && epithets[c.meta.epithetFor(id)] != null)
                        Text(
                          epithets[c.meta.epithetFor(id)]!.title,
                          style: EmberText.micro.copyWith(
                            color: EmberColors.gold,
                          ),
                        ),
                      // v0.60.0 The Delver's Tally: your record with this
                      // delver, at the moment you pick them. Same vocabulary
                      // as the Ledger roster row (one language, two rooms).
                      // A delver never delved with shows nothing — no
                      // "0 delves" line, no clutter, no shame.
                      if (unlocked && _tallyLine(c.meta, id) != null)
                        Text(
                          _tallyLine(c.meta, id)!,
                          key: ValueKey('char-tally-$id'),
                          style: EmberText.micro.copyWith(
                            color: EmberColors.textDim,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!unlocked)
                  Row(
                    children: [
                      const Icon(
                        Icons.lock,
                        size: 14,
                        color: EmberColors.textDim,
                      ),
                      const SizedBox(width: 4),
                      Text('${def.unlockEmbers}', style: EmberText.label),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(def.text, style: EmberText.bodyDim),
            const SizedBox(height: Space.s),
            Text(
              '${def.maxHp} HP · ${weaponFor(id).name} · '
              '${def.startDice.map((d) => dieDef(d).name).join(", ")}',
              style: EmberText.micro,
            ),
            const SizedBox(height: Space.m),
            SizedBox(
              width: double.infinity,
              child: unlocked
                  ? EmberButton(
                      'Delve as ${def.name}',
                      primary: id == defaultCharacter,
                      onTap: () {
                        Navigator.of(context).pop();
                        c.startRun(
                          character: id,
                          ascension: ascension,
                          boons: true,
                          shortRoad: c.meta.preferShortRoad,
                        );
                      },
                    )
                  : EmberButton(
                      canAfford
                          ? 'Unlock (${def.unlockEmbers} embers)'
                          : 'Locked',
                      onTap: canAfford
                          ? () {
                              c.unlock(id);
                              setState(() {});
                            }
                          : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map
// ---------------------------------------------------------------------------
