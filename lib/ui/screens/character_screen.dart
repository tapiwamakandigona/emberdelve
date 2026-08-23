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
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final m = c.meta;
    final maxAsc = maxAscensionFor(m); // Forge-gated (v0.4.0)
    return Scaffold(
      appBar: AppBar(
        title: Text('Choose a delver', style: EmberText.h2),
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
                  Expanded(child: Text('THE WARDROBE', style: EmberText.micro)),
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
              for (final id in delverDyesOrder) ...[
                _dyeCard(context, id),
                const SizedBox(height: Space.m),
              ],
              const SizedBox(height: Space.s),
              Text(
                'Dyes recolor your delver everywhere they appear. '
                'Pure cosmetics — the delve itself never changes.',
                style: EmberText.micro.copyWith(color: EmberColors.textDim),
              ),
              const SizedBox(height: Space.l),
              Text('ASCENSION', style: EmberText.micro),
              const SizedBox(height: Space.s),
              Text(
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
                      Expanded(
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
    );
  }

  Widget _nextUnlockBar(m) {
    final target = m.nextUnlockTarget;
    if (target == null) {
      return Panel(child: Text('All delvers unlocked.', style: EmberText.body));
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

  /// Same contract as the Ledger's _skinCard: tap owned to wear, tap locked
  /// to buy (price always visible). The swatch is the delver sprite wearing
  /// the dye — what you see is exactly what every screen will paint.
  Widget _dyeCard(BuildContext context, String id) {
    final c = widget.c;
    final d = delverDyes[id]!;
    final m = c.meta;
    final owned = m.ownedDyes.contains(id);
    final active = m.activeDye == id;
    final affordable = m.embers >= d.costEmbers;
    return GestureDetector(
      key: ValueKey('dye-$id'),
      onTap: () {
        if (active) return;
        if (owned) {
          AudioService.instance?.playSfx('ui_tap');
          c.setActiveDye(id);
        } else if (c.buyDye(id)) {
          c.setActiveDye(id);
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
                  defaultCharacter,
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
                          dye: Art.dyeFilter(c.meta.activeDye),
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
                Expanded(child: Text(def.name, style: EmberText.h2)),
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
