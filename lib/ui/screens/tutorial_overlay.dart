// lib/ui/screens/tutorial_overlay.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class _TutorialOverlay extends StatelessWidget {
  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const _TutorialOverlay(
      {required this.step, required this.onNext, required this.onSkip});

  /// Number of cards — the combat screen's step handler ends the overlay
  /// after the last card without hard-coding the count.
  static int get cardCount => _cards.length;

  static const _cards = [
    (
      Icons.visibility,
      'THE DARK FIGHTS FAIR',
      'The badge above the enemy is its next move — attack damage, shield '
          'block, or both. It always resolves exactly as shown.'
    ),
    (
      Icons.casino,
      'ROLL, THEN SPEND',
      'Roll your dice, tap one, then ATTACK or BLOCK with its value. Each '
          'die is spent once per turn; a reroll can save a bad face.'
    ),
    (
      Icons.local_fire_department,
      'MATCHING FACES PAY',
      'A PAIR adds +2, a TRIPLE ignites the enemy with burn, and a straight '
          'earns a FREE risky reroll. Forge dice bigger at rest fires.'
    ),
    (
      Icons.shield,
      'BLOCK FADES FAST',
      'Block absorbs the hit shown on the badge, then melts before your '
          'next roll. Stack block on turns a BIG attack is telegraphed — '
          'and spend nothing on block when the badge only shows a shield.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = _cards[step];
    // Dim everything; the card sits near what it explains (intent up top,
    // dice tray at the bottom, combos mid-stage).
    final align = switch (step) {
      0 => Alignment.topCenter,
      1 => Alignment.bottomCenter,
      _ => Alignment.center,
    };
    return Positioned.fill(
      child: GestureDetector(
        onTap: onNext, // tapping anywhere advances — never traps the player
        child: Container(
          color: Colors.black.withValues(alpha: 0.62),
          padding: EdgeInsets.only(
              left: Space.l,
              right: Space.l,
              top: step == 0 ? 120 : Space.l,
              bottom: step == 1 ? 210 : Space.l),
          child: Align(
            alignment: align,
            child: Panel(
              padding: const EdgeInsets.all(Space.l),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: EmberColors.ember, size: 28),
                const SizedBox(height: Space.s),
                Text(title, style: EmberText.h2, textAlign: TextAlign.center),
                const SizedBox(height: Space.s),
                Text(body,
                    style: EmberText.bodyDim, textAlign: TextAlign.center),
                const SizedBox(height: Space.l),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  EmberButton('Skip', ghost: true, onTap: onSkip),
                  const SizedBox(width: Space.m),
                  EmberButton(step >= _cards.length - 1 ? 'Got it' : 'Next',
                      primary: true, onTap: onNext),
                ]),
                const SizedBox(height: Space.s),
                Text('${step + 1} / ${_cards.length}', style: EmberText.micro),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
