// lib/ui/screens/reward_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class RewardScreen extends StatelessWidget {
  final GameController c;
  const RewardScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    // Stale-frame guard (same as Shop/Event): offers is null for one frame
    // right after choose_reward while the phase cross-fade still shows this
    // screen — without the guard that frame throws a null cast.
    final offers = (c.state?['offers'] as List?)?.cast<String>();
    if (offers == null) return const SizedBox.shrink();
    var recIdx = 0, recSize = -1;
    for (var i = 0; i < offers.length; i++) {
      if (dieDef(offers[i]).size > recSize) {
        recSize = dieDef(offers[i]).size;
        recIdx = i;
      }
    }
    return Column(
      children: [
        _TopBar(c),
        const SizedBox(height: Space.xl),
        Text('Choose a die', style: EmberText.h1),
        const SizedBox(height: Space.xs),
        Text(
          'It joins your pool for the rest of the run.',
          style: EmberText.bodyDim,
        ),
        // Offers stay thumb-anchored at the bottom on tall screens and become
        // scrollable on short ones instead of overflowing.
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const SizedBox(height: Space.m),
                      for (var i = 0; i < offers.length; i++)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Space.l,
                            0,
                            Space.l,
                            Space.m,
                          ),
                          child: _dieOffer(offers[i], i + 1, i == recIdx),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Space.s),
        Padding(
          padding: const EdgeInsets.all(Space.l),
          child: SizedBox(
            width: double.infinity,
            child: EmberButton(
              'Skip',
              onTap: () => c.apply({'type': 'choose_reward', 'index': 0}),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dieOffer(String id, int index, bool recommended) {
    final def = dieDef(id);
    return GestureDetector(
      onTap: () => c.apply({'type': 'choose_reward', 'index': index}),
      child: Panel(
        color: recommended ? EmberColors.raised : EmberColors.surface,
        child: Row(
          children: [
            DieChip(id),
            const SizedBox(width: Space.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Flexible + ellipsis: long die names share the row with the
                      // RECOMMENDED chip instead of overflowing on narrow screens.
                      Flexible(
                        child: Text(
                          def.name,
                          style: EmberText.h2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: Space.s),
                        // Flexible + FittedBox: at large system font sizes the chip
                        // scales down instead of pushing the row past the panel.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
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
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(_dieDesc(def), style: EmberText.bodyDim),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _dieDesc(DieDef d) {
  final parts = <String>['d${d.size}'];
  final m = d.mods;
  if (m['attack_bonus'] != null) parts.add('+${m['attack_bonus']} attack');
  if (m['block_bonus'] != null) parts.add('+${m['block_bonus']} block');
  if (m['min_value'] != null) parts.add('min ${m['min_value']}');
  if (m['on_max_bonus'] != null) parts.add('+${m['on_max_bonus']} on max');
  if (m['attack_only'] == true) parts.add('attack only');
  if (m['block_only'] == true) parts.add('block only');
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Rest + forge
// ---------------------------------------------------------------------------
