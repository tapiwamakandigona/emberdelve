// lib/ui/screens/combat/badges.dart — part of screens.dart (see library header there).
// Combat badges: boss name-plate, status chips, the enemy intent badge.
// Extracted from combat_screen.dart 2026-07-26 (remaining-work §7);
// mechanical, behaviour-preserving. Same library: private access is
// unchanged and no public API moved.
part of '../../screens.dart';

/// Boss/elite name-plate splash: "SOOT SHADE — LAYER 1" over a charred band.
class _NamePlate extends StatelessWidget {
  final Map enemy;
  final int layer;
  const _NamePlate({required this.enemy, required this.layer});
  @override
  Widget build(BuildContext context) {
    final boss = enemy['boss'] == true;
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1600),
          builder: (context, f, child) {
            // In 0-15%, hold, out 85-100%.
            final a = f < 0.15
                ? f / 0.15
                : f > 0.85
                ? (1 - f) / 0.15
                : 1.0;
            final scale =
                1.15 -
                0.15 * Curves.easeOut.transform((f / 0.2).clamp(0.0, 1.0));
            return Opacity(
              opacity: a.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: Space.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.18, 0.82, 1.0],
              ),
              border: const Border(
                top: BorderSide(color: EmberColors.ember, width: 1),
                bottom: BorderSide(color: EmberColors.ember, width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (enemy['name'] as String? ?? '').toUpperCase(),
                  textAlign: TextAlign.center,
                  style: EmberText.h1.copyWith(
                    color: boss ? EmberColors.kindBoss : EmberColors.kindElite,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  boss ? 'LAYER $layer · BOSS' : 'LAYER $layer · ELITE',
                  style: EmberText.micro.copyWith(letterSpacing: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// LFP-3a: a status stack ON the combatant (burn today; the vocabulary can
/// grow). Deliberately unlike the intent badge: tight rounded pill, tinted
/// fill, smaller type — reads as a condition, not a plan. Long-press names
/// it (LFP-3b).
class _StatusChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String semantics;
  final VoidCallback? onLongPress;
  const _StatusChip({
    required this.icon,
    required this.color,
    required this.value,
    required this.semantics,
    this.onLongPress,
  });
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              color.withValues(alpha: 0.22),
              EmberColors.raised,
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 2),
              Text(
                '$value',
                style: EmberText.value.copyWith(fontSize: 12, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntentBadge extends StatelessWidget {
  final Map intent;
  final VoidCallback? onLongPress;
  const _IntentBadge(this.intent, {this.onLongPress});
  @override
  Widget build(BuildContext context) {
    final kind = intent['kind'];
    // v0.3.1 F6: attack_block reads as two explicit chips (attack amount +
    // block amount) — one lightning icon over two bare numbers was
    // undecodable without reading the sim.
    final parts = <(IconData, Color, String)>[
      if (kind == 'attack' || kind == 'attack_block')
        (Icons.gps_fixed, EmberColors.danger, '${intent['amount']}'),
      if (kind == 'block')
        (Icons.shield, EmberColors.block, '${intent['amount']}'),
      if (kind == 'attack_block')
        (Icons.shield, EmberColors.block, '${intent['block']}'),
      // v0.47.0 response puzzles: the badge STATES the answer. A charge reads
      // as the hit plus the break number; a counter as the per-strike price;
      // a stagger as the earned blank beat.
      if (kind == 'charge') ...[
        (Icons.flash_on, EmberColors.danger, '${intent['amount']}'),
        (Icons.flash_off, EmberColors.ember, '${intent['threshold']}'),
      ],
      if (kind == 'counter')
        (Icons.sync_alt, EmberColors.kindElite, '${intent['amount']}'),
      if (kind == 'stagger') (Icons.hourglass_empty, EmberColors.textDim, '—'),
    ];
    final border = kind == 'attack_block' || kind == 'counter'
        ? EmberColors.kindElite
        : kind == 'block'
        ? EmberColors.block
        : kind == 'stagger'
        ? EmberColors.textDim
        : EmberColors.danger;
    final spoken = switch (kind) {
      'attack' => 'attack for ${intent['amount']}',
      'block' => 'block ${intent['amount']}',
      'attack_block' =>
        'attack for ${intent['amount']} and block ${intent['block']}',
      'charge' =>
        'charging a ${intent['amount']} hit — deal ${intent['threshold']} '
            'damage this turn to break it',
      'counter' =>
        'countering — each non-killing strike costs you ${intent['amount']}',
      'stagger' => 'staggered — it will do nothing',
      _ => '$kind',
    };
    return Semantics(
      label: 'Enemy intent: $spoken. Long press to explain.',
      excludeSemantics: true,
      // LFP-3b: long-press names the badge in a 2s call-out.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.m,
            vertical: Space.s,
          ),
          decoration: BoxDecoration(
            color: EmberColors.raised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, part) in parts.indexed) ...[
                if (i > 0) const SizedBox(width: Space.m),
                Icon(part.$1, size: 18, color: part.$2),
                const SizedBox(width: Space.xs),
                Text(
                  part.$3,
                  style: EmberText.value.copyWith(fontSize: 18, color: part.$2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
