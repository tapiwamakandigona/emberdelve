// lib/ui/screens/boon_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class BoonScreen extends StatelessWidget {
  final GameController c;
  const BoonScreen(this.c, {super.key});

  /// LFP-6c: deterministic RECOMMENDED default, mirroring the reward screen
  /// (design-system §1 smart defaults — the reward flip has had one since
  /// v0.2, the boon pick never did). Pure function of the offer: die boons
  /// rank by die size (same rule as rewards), then lasting stats over
  /// spendables (max HP > gold > banked embers), amount breaking ties inside
  /// a band and the earlier card winning exact ties. No RNG, no sim change.
  static int recommendedIndex(List<String> boonIds) {
    var recIdx = -1, recScore = -1;
    for (var i = 0; i < boonIds.length; i++) {
      final e = boonDef(boonIds[i]).effects;
      final dieId = e['gain_die'] as String?;
      final score = dieId != null
          ? 1000 + dieDef(dieId).size
          : e.containsKey('max_hp')
          ? 500 + (e['max_hp'] as int)
          : e.containsKey('gold')
          ? 200 + (e['gold'] as int)
          : 100 + (e['embers'] as int? ?? 0);
      if (score > recScore) {
        recScore = score;
        recIdx = i;
      }
    }
    return recIdx;
  }

  @override
  Widget build(BuildContext context) {
    final boonIds = ((c.state!['boons']) as List?)?.cast<String>() ?? const [];
    final recIdx = recommendedIndex(boonIds);
    return Stack(
      fit: StackFit.expand,
      children: [
        const Vignette(strength: 0.5),
        const EmberDrift(count: 16, opacity: 0.6),
        Column(
          children: [
            _TopBar(c),
            // Tablet clamp (v0.26.0): content column caps at kMaxContentWidth.
            Expanded(
              child: ContentClamp(
                child: Column(
                  children: [
                    // Header scrolls WITH the cards (overflow sweep
                    // 2026-08-25): with the rumor line added, the fixed
                    // header overran 320px screens at 1.3x text — the probe
                    // font wraps wider than shipped fonts, so the ListView
                    // now owns everything between the top bar and the skip
                    // button.
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.l,
                        ),
                        children: [
                          const SizedBox(height: Space.xl),
                          Text(
                            'Choose a boon',
                            style: EmberText.h1,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Space.xs),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.m,
                            ),
                            child: Text(
                              'A blessing for this delve — or walk in unaided.',
                              style: EmberText.bodyDim,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // The Rumor (v0.53.0): the seed already chose the
                          // boss (pure bossForSeed read — lib/game/rumor.dart),
                          // so every delve opens with a named destination.
                          const SizedBox(height: Space.xs),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.m,
                            ),
                            child: Text(
                              rumorForSeed(c.sim!.runSeed),
                              key: const ValueKey('rumor-line'),
                              style: EmberText.bodyDim,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: Space.l),
                          for (var i = 0; i < boonIds.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Space.m),
                              child: _boonCard(
                                context,
                                boonIds[i],
                                i + 1,
                                recommended: i == recIdx,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(Space.l),
                      child: SizedBox(
                        width: double.infinity,
                        child: EmberButton(
                          'Skip — delve unaided',
                          key: const ValueKey('boon-skip'),
                          onTap: () =>
                              c.apply({'type': 'choose_boon', 'index': 0}),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _boonCard(
    BuildContext context,
    String id,
    int index, {
    bool recommended = false,
  }) {
    final def = boonDef(id);
    final e = def.effects;
    final dieId = e['gain_die'] as String?;
    // Show WHAT you get, not a sentence about it (wordiness pass 2026-07-24):
    // the actual die art for die boons, the currency/stat with its number for
    // the rest; mechanics as a compact `d6 · block +2` caption.
    final lead = dieId != null
        ? SizedBox(
            width: 52,
            height: 64,
            child: FittedBox(
              fit: BoxFit.contain,
              child: DieChip(dieId, skin: c.meta.activeDieSkin),
            ),
          )
        : e.containsKey('gold')
        ? _gain(
            Image.asset(
              Art.currencyCoin,
              width: 26,
              height: 26,
              filterQuality: FilterQuality.none,
            ),
            '+${e['gold']}',
          )
        : e.containsKey('embers')
        ? _gain(
            Image.asset(
              Art.currencyEmber,
              width: 26,
              height: 26,
              filterQuality: FilterQuality.none,
            ),
            '+${e['embers']}',
          )
        : _gain(
            const Icon(Icons.favorite, color: EmberColors.hp, size: 24),
            '+${e['max_hp']}',
          );
    final bits = <String>[
      if (dieId != null) dieFacts(dieDef(dieId)),
      if (dieId == null && e['gold'] != null) '+${e['gold']} gold now',
      if (dieId != null && e['gold'] != null) '+${e['gold']} gold',
      if (e['max_hp'] != null) '+${e['max_hp']} max HP',
      if (e['embers'] != null) '+${e['embers']} embers banked',
    ];
    return GestureDetector(
      key: ValueKey('boon-$index'),
      onTap: () => c.apply({'type': 'choose_boon', 'index': index}),
      child: Panel(
        child: Row(
          children: [
            SizedBox(width: 56, child: Center(child: lead)),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wrap, not Row (overflow sweep 2026-08-25): at 320px @
                  // 1.3x text the inflexible RECOMMENDED chip starved the
                  // title down to one letter per line; wrapping drops the
                  // chip below the title instead. Wide layouts unchanged.
                  Wrap(
                    spacing: Space.s,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(def.name, style: EmberText.h2),
                      // Same chip the reward flip uses — one visual vocabulary
                      // for "the default pick" across both offer screens.
                      if (recommended)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.s,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: EmberColors.ember,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            maxLines: 1,
                            style: EmberText.micro.copyWith(
                              color: const Color(0xFF17110A),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(bits.join(' · '), style: EmberText.bodyDim),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gain(Widget icon, String amount) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(height: 2),
      Text(amount, style: EmberText.h2.copyWith(color: EmberColors.gold)),
    ],
  );
}

// ---------------------------------------------------------------------------
// Character select + unlocks (endowed-progress toward the cheapest lock)
// ---------------------------------------------------------------------------
