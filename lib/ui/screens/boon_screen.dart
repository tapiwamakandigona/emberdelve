// lib/ui/screens/boon_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class BoonScreen extends StatelessWidget {
  final GameController c;
  const BoonScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final boonIds = ((c.state!['boons']) as List?)?.cast<String>() ?? const [];
    return Stack(fit: StackFit.expand, children: [
      const Vignette(strength: 0.5),
      const EmberDrift(count: 16, opacity: 0.6),
      Column(children: [
        _TopBar(c),
        const SizedBox(height: Space.xl),
        Text('Choose a boon', style: EmberText.h1),
        const SizedBox(height: Space.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: Text('A blessing for this delve — or walk in unaided.',
              style: EmberText.bodyDim, textAlign: TextAlign.center),
        ),
        const SizedBox(height: Space.l),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.l),
            children: [
              for (var i = 0; i < boonIds.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.m),
                  child: _boonCard(context, boonIds[i], i + 1),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.l),
          child: SizedBox(
            width: double.infinity,
            child: EmberButton('Skip — delve unaided',
                key: const ValueKey('boon-skip'),
                onTap: () => c.apply({'type': 'choose_boon', 'index': 0})),
          ),
        ),
      ]),
    ]);
  }

  Widget _boonCard(BuildContext context, String id, int index) {
    final def = boonDef(id);
    return GestureDetector(
      key: ValueKey('boon-$index'),
      onTap: () => c.apply({'type': 'choose_boon', 'index': index}),
      child: Panel(
        child: Row(children: [
          const Icon(Icons.auto_awesome, color: EmberColors.gold, size: 28),
          const SizedBox(width: Space.l),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(def.name, style: EmberText.h2),
              const SizedBox(height: Space.xs),
              Text(def.text, style: EmberText.bodyDim),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Character select + unlocks (endowed-progress toward the cheapest lock)
// ---------------------------------------------------------------------------
