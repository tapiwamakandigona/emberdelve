// lib/ui/screens/rest_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class RestScreen extends StatefulWidget {
  final GameController c;
  const RestScreen(this.c, {super.key});
  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> {
  GameController get c => widget.c;

  @override
  void initState() {
    super.initState();
    // v0.139.0 The Shown Anvil: first contact with a live anvil defines
    // the temper system (map_screen's onMapArrival idiom). canTemper is
    // re-derived here so a spent anvil never teaches an absent button.
    final run = c.state?['run'] as Map?;
    // v0.160.0 The Second Strike: a tier-1 mark in the pool makes this
    // fire deepening's first-contact moment (custom dice are always in
    // the pool by construction; absent tier key = tier 1, v0.155.0).
    var shallow = false;
    final customs = run?['custom_dice'] as Map?;
    if (customs != null) {
      for (final v in customs.values) {
        if (((v as Map)['tier'] as int? ?? 1) == 1) shallow = true;
      }
    }
    c.tipDirector.onRestArrival(
      canTemper: (run?['tempers_used'] as int? ?? 0) < 2,
      hasShallowMark: shallow,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = c.state!['player'] as Map;
    final run = c.state!['run'] as Map?;
    final dice0 = (player['dice'] as List).cast<String>();
    final forgeable = <int>[];
    for (var i = 0; i < dice0.length; i++) {
      if (resolveRunDie(run, dice0[i]).def.forgeTo.isNotEmpty) forgeable.add(i);
    }
    // v0.3.1 F9: never offer a heal that heals nothing.
    final fullHp = (player['hp'] as int) >= (player['max_hp'] as int);
    // v0.89.0: the button prints the exact outcome — sim's own arithmetic
    // (base + rest_bonus relics, capped at max), so it can never lie.
    final hp = player['hp'] as int;
    final heal = c.sim == null ? 0 : restHealPreview(c.sim!);
    // v0.132.0 The Second Mark: two tempers per delve. Once both are spent
    // the option disappears rather than sitting there greyed out (v7 rule).
    final tempersUsed = run?['tempers_used'] as int? ?? 0;
    final canTemper = tempersUsed < 2;
    return Stack(
      fit: StackFit.expand,
      children: [
        const EmberDrift(count: 16, opacity: 0.6),
        Column(
          children: [
            _TopBar(c),
            // Tablet clamp (v0.26.0): content column caps at kMaxContentWidth.
            Expanded(
              child: ContentClamp(
                child: Column(
                  children: [
                    const SizedBox(height: Space.xl),
                    Text('A warm hollow', style: EmberText.h1),
                    const SizedBox(height: Space.xs),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.l),
                      child: Text(
                        canTemper
                            ? 'Rest to heal, forge a die into something stronger, or '
                                  'temper one face. '
                                  '${tempersUsed == 0 ? 'Two marks a delve.' : 'One mark left.'}'
                            : 'Rest to heal, or forge a die into something stronger. '
                                  'One only.',
                        style: EmberText.bodyDim,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    // v0.96.0 The Hearth Tale: one short tale of the world per
                    // hollow, in a fixed lifetime sequence (lib/data/tales.dart)
                    // — the "what's a delve" answer as a drip, not a card.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                      child: Text(
                        '\u201C${hearthTale(c.meta.hearthTalesHeard)}\u201D',
                        key: const ValueKey('hearth-tale'),
                        style: EmberText.bodyDim.copyWith(
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(Space.l),
                      child: SizedBox(
                        width: double.infinity,
                        child: EmberButton(
                          // At full HP this is the ONLY exit when nothing is forgeable —
                          // a disabled button here soft-locked the run (found in play
                          // session 2026-07-24). The sim's `rest` command is safe at full
                          // HP: it heals 0 and moves to the map.
                          fullHp
                              ? 'Move on — fully rested'
                              : 'Rest — heal $heal HP '
                                    '($hp\u00A0to\u00A0${hp + heal})',
                          primary: !fullHp,
                          icon: fullHp
                              ? Icons.arrow_forward
                              : Icons.local_fire_department,
                          onTap: () => c.apply({'type': 'rest'}),
                        ),
                      ),
                    ),
                    if (canTemper)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.l,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: EmberButton(
                            tempersUsed == 0
                                ? 'Temper a face — two per delve'
                                : 'Temper a face — one mark left',
                            key: const ValueKey('rest-temper'),
                            icon: Icons.auto_awesome,
                            onTap: () => showTemperSheet(context, c),
                          ),
                        ),
                      ),
                    if (canTemper) const SizedBox(height: Space.m),
                    if (forgeable.isNotEmpty)
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.l,
                          ),
                          children: [
                            Text('FORGE', style: EmberText.micro),
                            const SizedBox(height: Space.s),
                            for (final i in forgeable)
                              Padding(
                                padding: const EdgeInsets.only(bottom: Space.s),
                                child: _forgeRow(run, dice0[i], i + 1),
                              ),
                          ],
                        ),
                      )
                    else
                      const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (c.tipDirector.active != null)
          _ContextTip(
            id: c.tipDirector.active!,
            onDismiss: () => setState(c.dismissTip),
          ),
      ],
    );
  }

  Widget _forgeRow(Map? run, String id, int index) {
    final def = resolveRunDie(run, id).def;
    final into = def.forgeTo.first;
    // Compact chips + dense button: the full-size row overflowed 320dp
    // phones by ~9px (many-dice layout sweep 2026-07-24).
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _chip(id, run),
              const Icon(
                Icons.arrow_forward,
                size: 16,
                color: EmberColors.ember,
              ),
              _chip(into, null),
              const Spacer(),
              EmberButton(
                'Forge',
                dense: true,
                onTap: () =>
                    c.apply({'type': 'forge', 'die': index, 'into': into}),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          // Full-width caption line: squeezed beside the button it wrapped
          // mid-word on 320dp phones.
          Text(
            '${def.name} → ${dieDef(into).name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EmberText.label,
          ),
          // v0.97.0 The Counted Forge: when either side carries mods, the
          // row states what actually changes — the same dieFacts sentence
          // the reward/shop/boon pickers use, before and after. Plain
          // size-only forges stay quiet: the chips' own d-labels already
          // count that, and restating it three times is noise.
          if (def.mods.isNotEmpty || dieDef(into).mods.isNotEmpty) ...[
            const SizedBox(height: Space.xs),
            Text(
              '${dieFacts(def)}  →  ${dieFacts(dieDef(into))}',
              key: ValueKey('forge-facts-$index'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: EmberText.micro,
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String id, Map? run) => SizedBox(
    width: 48,
    height: 60,
    child: FittedBox(
      fit: BoxFit.contain,
      child: DieChip(id, run: run, skin: c.activeRunSkin),
    ),
  );
}

// ---------------------------------------------------------------------------
// Shop
// ---------------------------------------------------------------------------
