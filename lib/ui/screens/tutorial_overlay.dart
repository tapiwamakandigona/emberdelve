// lib/ui/screens/tutorial_overlay.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class _TutorialOverlay extends StatelessWidget {
  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const _TutorialOverlay({
    required this.step,
    required this.onNext,
    required this.onSkip,
  });

  /// Number of cards — the combat screen's step handler ends the overlay
  /// after the last card without hard-coding the count.
  static int get cardCount => _cards.length;

  static const _cards = [
    // v0.30.0 The Delver's Primer: the word "delve" itself, first — our
    // first outside review finished Easy still not knowing what one was.
    (
      Icons.explore,
      'WHAT\'S A DELVE?',
      'One descent into the dark. Pick a glowing path on the map, clear '
          'each room, and face what waits at the bottom. Win, and every '
          'ember you gathered comes home. Fall, and the ledger still keeps '
          'half. Either way the delve ends there — the next one starts '
          'fresh.',
    ),
    (
      Icons.visibility,
      'THE DARK FIGHTS FAIR',
      // LFP-3c: one clause separating the two channels — the badge above its
      // head is the PLAN, flame chips on the body are STATUS (tester theme:
      // burn beside intent read as "it will burn me for 3").
      'The badge above the enemy\'s head is its next move — attack damage, '
          'shield block, or both. It always resolves exactly as shown. Flame '
          'chips on its body are burn it already suffers, never a threat.',
    ),
    (
      Icons.casino,
      'ROLL, THEN SPEND',
      'Roll your dice, tap one, then ATTACK or BLOCK with its value. Each '
          'die is spent once per turn; a reroll can save a bad face.',
    ),
    (
      Icons.local_fire_department,
      'MATCHING FACES PAY',
      'A PAIR adds +2, a TRIPLE ignites the enemy with burn, and a straight '
          'earns a FREE risky reroll. Forge dice bigger at rest fires.',
    ),
    (
      Icons.shield,
      'BLOCK FADES FAST',
      'Block absorbs the hit shown on the badge, then melts before your '
          'next roll. Stack block on turns a BIG attack is telegraphed — '
          'and spend nothing on block when the badge only shows a shield.',
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
            bottom: step == 1 ? 210 : Space.l,
          ),
          child: Align(
            alignment: align,
            child: Panel(
              padding: const EdgeInsets.all(Space.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: EmberColors.ember, size: 28),
                  const SizedBox(height: Space.s),
                  Text(title, style: EmberText.h2, textAlign: TextAlign.center),
                  const SizedBox(height: Space.s),
                  Text(
                    body,
                    style: EmberText.bodyDim,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.l),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EmberButton('Skip', ghost: true, onTap: onSkip),
                      const SizedBox(width: Space.m),
                      EmberButton(
                        step >= _cards.length - 1 ? 'Got it' : 'Next',
                        primary: true,
                        onTap: onNext,
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.s),
                  Text(
                    '${step + 1} / ${_cards.length}',
                    style: EmberText.micro,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// v0.10.0 "The First Delve" — one staged contextual tip card, shown at the
/// moment of first contact with its concept (lib/game/tips.dart decides the
/// moment; this only renders). Lighter scrim than the manual overlay deck —
/// a nudge beside live combat, not a wall in front of it. Tap anywhere
/// dismisses (§Ethics: no forced taps), and a dismissed tip never returns.
class _ContextTip extends StatelessWidget {
  final String id;
  final VoidCallback onDismiss;
  const _ContextTip({required this.id, required this.onDismiss});

  /// Same card copy as the replayable overlay deck — one rule, one card.
  /// (icon, title, body, where the card sits so it points at its subject)
  static const _cards = <String, (IconData, String, String, Alignment)>{
    ContextTips.whatsADelve: (
      Icons.explore,
      'THIS IS A DELVE',
      'One descent into the dark. Pick a glowing path, clear each room, '
          'and face what waits at the bottom. Win, and every ember you '
          'gathered comes home. Fall, and the ledger still keeps half. '
          'Either way the delve ends there — and the next one starts fresh.',
      Alignment.center,
    ),
    ContextTips.sharedDelve: (
      Icons.today,
      'THE SHARED DELVE',
      'Each day deals one delve that is the same for everyone \u2014 '
          'same seed, same road \u2014 and Monday adds a weekly rule on '
          'top. Play it when you like: a skipped day is silent and costs '
          'nothing.',
      Alignment.center,
    ),
    ContextTips.deepMark: (
      Icons.layers,
      'THE SECOND STRIKE',
      'A marked face can be tempered AGAIN: strike the same rune deeper '
          'and it pays more on the same roll \u2014 a II beside the rune '
          'says the work is done. Deepening spends a temper like any '
          'other mark.',
      Alignment.center,
    ),
    ContextTips.firstAnvil: (
      Icons.auto_awesome,
      'THE SMITH IS IN',
      'This fire can temper a die: pick one face and mark it with a '
          'rune \u2014 an edge, a guard, a reroll, an echo, a mend, or '
          'gold. The mark pays every time that face is rolled and '
          'spent, for the whole delve. Two marks a delve; resting '
          'costs neither.',
      Alignment.center,
    ),
    ContextTips.rollSpend: (
      Icons.casino,
      'ROLL, THEN SPEND',
      'Roll your dice, tap one, then ATTACK or BLOCK with its value. Each '
          'die is spent once per turn; a reroll can save a bad face.',
      Alignment.bottomCenter,
    ),
    ContextTips.intentFair: (
      Icons.visibility,
      'THE DARK FIGHTS FAIR',
      'That move was announced. The badge above the enemy\'s head is always '
          'its next move — attack damage, shield block, or both — and it '
          'always resolves exactly as shown.',
      Alignment.topCenter,
    ),
    ContextTips.combosPay: (
      Icons.local_fire_department,
      'MATCHING FACES PAY',
      'A PAIR adds +2, a TRIPLE ignites the enemy with burn, and a straight '
          'earns a FREE risky reroll. Forge dice bigger at rest fires.',
      Alignment.center,
    ),
    ContextTips.blockFades: (
      Icons.shield,
      'BLOCK FADES FAST',
      'A big hit is telegraphed. Block absorbs exactly what the badge '
          'shows, then melts before your next roll — stack block on turns '
          'like this one, and spend nothing on it when the badge only '
          'shows a shield.',
      Alignment.topCenter,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, title, body, align) = _cards[id]!;
    // Anchor padding points the card at its subject (intent badge up top,
    // dice tray at the bottom) but yields on short screens — at 320x568 with
    // 1.3x text the full reservation would overflow the card (caught by
    // tips_test's sweep). The scroll wrapper is the can't-overflow guarantee.
    final short = MediaQuery.sizeOf(context).height < 640;
    return Positioned.fill(
      child: GestureDetector(
        key: const Key('tip-card'),
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss, // tap anywhere — never traps the player
        child: Container(
          color: Colors.black.withValues(alpha: 0.35),
          padding: EdgeInsets.only(
            left: Space.l,
            right: Space.l,
            top: align == Alignment.topCenter ? (short ? 72 : 120) : Space.l,
            bottom: align == Alignment.bottomCenter
                ? (short ? 96 : 210)
                : Space.l,
          ),
          child: Align(
            alignment: align,
            child: Panel(
              key: Key('tip-$id'),
              padding: const EdgeInsets.all(Space.l),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: EmberColors.ember, size: 28),
                    const SizedBox(height: Space.s),
                    Text(
                      title,
                      style: EmberText.h2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Space.s),
                    Text(
                      body,
                      style: EmberText.bodyDim,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Space.l),
                    EmberButton('Got it', primary: true, onTap: onDismiss),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
