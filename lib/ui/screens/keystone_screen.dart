// lib/ui/screens/keystone_screen.dart — part of screens.dart (see library
// header there).
part of '../screens.dart';

/// The one keystone pick of the run, offered after the first won fight. Same
/// card grammar as the boon screen so the two "choose one" moments read as one
/// vocabulary; declining is a first-class button, never a dark pattern.
class KeystoneScreen extends StatelessWidget {
  final GameController c;
  const KeystoneScreen(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    final ids =
        ((c.state!['keystone_offers']) as List?)?.cast<String>() ?? const [];
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
                    const SizedBox(height: Space.xl),
                    // Padded so the heading WRAPS at large accessibility text scales
                    // instead of running off both edges (visual sweep 2026-08-12).
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: Space.l),
                      child: Text(
                        'Set a keystone',
                        style: EmberText.h1,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: Space.xl),
                      child: Text(
                        'One rule for the rest of this delve. It rewards how you '
                        'play, not what you roll.',
                        style: EmberText.bodyDim,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: Space.l),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.l,
                        ),
                        children: [
                          // THE DEALT HAND: same staggered deal as the boon
                          // hand (fx.dart DealtIn).
                          for (var i = 0; i < ids.length; i++)
                            DealtIn(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  bottom: Space.m,
                                ),
                                child: _card(ids[i], i + 1),
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
                          'Take none',
                          key: const ValueKey('keystone-skip'),
                          onTap: () =>
                              c.apply({'type': 'choose_keystone', 'index': 0}),
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

  Widget _card(String id, int index) {
    final def = keystoneDef(id);
    return GestureDetector(
      key: ValueKey('keystone-$index'),
      onTap: () => c.apply({'type': 'choose_keystone', 'index': index}),
      child: Panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 56,
              child: Center(
                child: Icon(
                  Icons.hexagon_outlined,
                  color: EmberColors.ember,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.name, style: EmberText.h2),
                  const SizedBox(height: Space.xs),
                  Text(def.blurb, style: EmberText.bodyDim),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
