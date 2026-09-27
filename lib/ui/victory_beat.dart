// lib/ui/victory_beat.dart — experimental polish loop, critic round 2 issue
// C2-02: the final-boss kill had no victory beat. The board just went
// still for ~1.9 s and then cut to the summary.
//
// [VictoryBeat] is a stage-scoped overlay shown once the run-ending blow
// lands:
//   • a banner ("VICTORY!", ≥ 22 sp, ember glow) that scales in over
//     250 ms with ease-out-back, centred in the stage and scaled down to
//     fit it on narrow phones;
//   • embers rising from the boss's spot (a cheap painter, no assets).
// Under reduced motion the banner only fades in (no scale) and there are
// no particles. Pinned by test/victory_beat_test.dart. Presentation only
// (nothing in lib/sim is touched).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

class VictoryBeat extends StatefulWidget {
  /// The banner's words. Short and plain so a young child can read them.
  static const String text = 'VICTORY!';

  /// Banner font size in logical pixels (critic acceptance: ≥ 22 sp).
  static const double fontSize = 34;

  /// Banner scale-in (normal motion) / fade-in (reduced motion).
  static const Duration intro = Duration(milliseconds: 250);

  /// How long the embers keep rising (one pass; the screen leaves before).
  static const Duration embers = Duration(milliseconds: 1600);

  /// Where the embers start, in stage coordinates (the boss's body).
  final Rect source;

  /// Reduced motion: fade only, no scale, no particles.
  final bool reduced;

  const VictoryBeat({super.key, required this.source, required this.reduced});

  @override
  State<VictoryBeat> createState() => _VictoryBeatState();
}

class _VictoryBeatState extends State<VictoryBeat>
    with TickerProviderStateMixin {
  // Built in initState, never lazily: dispose() must not create them.
  late final AnimationController _intro;
  late final AnimationController _embers;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: VictoryBeat.intro)
      ..forward();
    _embers = AnimationController(vsync: this, duration: VictoryBeat.embers);
    if (!widget.reduced) _embers.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _embers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          VictoryBeat.text,
          key: const ValueKey('victory-banner'),
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: VictoryBeat.fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: const Color(0xFFFFE3A3),
            shadows: [
              const Shadow(color: EmberColors.ember, blurRadius: 18),
              Shadow(
                color: EmberColors.ember.withValues(alpha: 0.8),
                blurRadius: 6,
              ),
              const Shadow(
                color: Color(0xCC000000),
                offset: Offset(0, 2),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!widget.reduced)
            CustomPaint(
              key: const ValueKey('victory-embers'),
              painter: _EmberRisePainter(_embers, widget.source),
            ),
          Center(
            child: AnimatedBuilder(
              animation: _intro,
              child: banner,
              builder: (context, child) {
                final t = _intro.value;
                if (widget.reduced) {
                  return Opacity(opacity: t, child: child);
                }
                final s = Curves.easeOutBack.transform(t);
                return Opacity(
                  opacity: (t * 2).clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.6 + 0.4 * s, child: child),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Embers drifting up from [source]. Deterministic (fixed seeds) so plates
/// and tests are stable.
class _EmberRisePainter extends CustomPainter {
  final Animation<double> t;
  final Rect source;

  _EmberRisePainter(this.t, this.source) : super(repaint: t);

  static const int count = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    if (v <= 0 || v >= 1) return;
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final r = math.Random(i * 7919 + 13);
      final delay = r.nextDouble() * 0.35;
      final life = ((v - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (life <= 0 || life >= 1) continue;
      final x0 = source.left + r.nextDouble() * source.width;
      final y0 = source.top + source.height * (0.3 + 0.6 * r.nextDouble());
      final rise = source.height * (0.9 + r.nextDouble() * 0.8) * life;
      final sway = math.sin(life * math.pi * 2 + i) * 6;
      final radius = 1.5 + r.nextDouble() * 2;
      final alpha = (1 - life) * 0.9;
      paint.color = Color.lerp(
        const Color(0xFFFFD27A),
        EmberColors.ember,
        life,
      )!.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x0 + sway, y0 - rise), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_EmberRisePainter old) =>
      old.source != source || old.t != t;
}
