// lib/ui/screens/combat/fx.dart — part of screens.dart (see library header there).
// Transient combat FX records: ghosts, pulses, contact fx, call-outs, damage pops.
// Extracted from combat_screen.dart 2026-07-26 (remaining-work §7);
// mechanical, behaviour-preserving. Same library: private access is
// unchanged and no public API moved.
part of '../../screens.dart';

/// LFP-2a: one in-flight assign ghost (die → verb button).
class _Ghost {
  final int id;
  final Offset from;
  final Offset to;
  final int value;
  final String action; // 'attack' | 'block'
  const _Ghost(this.id, this.from, this.to, this.value, this.action);
}

/// LFP-2a: pulses its child (1.0 → ~1.07 → 1.0) every time [token] changes —
/// the verb button visibly "receives" the die. token 0 renders statically so
/// nothing pulses on first build.
class _Pulse extends StatelessWidget {
  final int token;
  final Widget child;
  const _Pulse({required this.token, required this.child});
  @override
  Widget build(BuildContext context) {
    if (token == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey('pulse-$token'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, f, c) =>
          Transform.scale(scale: 1.0 + math.sin(f * math.pi) * 0.07, child: c),
      child: child,
    );
  }
}

/// One transient combat call-out (combo, burn tick, exact-kill, overkill).
/// One transient stage contact effect (weapon smear, claw rake, guard arc).
enum _FxKind { slash, claws, guard }

class _Fx {
  final int id;
  final _FxKind kind;
  final bool onPlayer;
  final Color color;
  const _Fx(this.id, this.kind, {required this.onPlayer, required this.color});
}

class _Note {
  final int id;
  final String text;
  final Color color;
  final IconData? icon;
  final bool onEnemy; // anchors near the enemy instead of the dice tray
  final Duration life; // LFP-5: 1s while fast-forwarding, 2s otherwise
  _Note(
    this.id,
    this.text,
    this.color,
    this.icon, {
    required this.onEnemy,
    this.life = const Duration(milliseconds: 2000),
  });
}

/// One floating damage number's spawn record.
class _Pop {
  final int id;
  final int amount;
  final bool onPlayer;
  final bool blocked;
  _Pop(this.id, this.amount, {required this.onPlayer, required this.blocked});
}
