// lib/ui/fx.dart — shared programmatic effects: ambient ember drift, ember
// burst (death dissolve), screen shake, damage number pops, vignette, and the
// flame-wipe / fade-through-black phase transitions. Everything here is drawn
// (no image assets) and allocation-light: particle parameters are precomputed
// once, painters reuse Paint objects, and every animated layer sits behind a
// RepaintBoundary so it never invalidates the scene around it.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Ambient ember drift — slow rising sparks (title / map / rest / summary).
// ---------------------------------------------------------------------------
class EmberDrift extends StatefulWidget {
  final int count;
  final double opacity;
  final bool falling; // defeat variant: embers sink and die instead of rise
  // Hearth colors (v0.3.3): optional cosmetic tint. Null = the classic
  // emberglow palette, byte-identical to pre-theme rendering.
  final Color? warm;
  final Color? bright;
  const EmberDrift(
      {super.key,
      this.count = 26,
      this.opacity = 1.0,
      this.falling = false,
      this.warm,
      this.bright});

  @override
  State<EmberDrift> createState() => _EmberDriftState();
}

class _EmberDriftState extends State<EmberDrift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(seconds: 14))
    ..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _EmberDriftPainter(_t, widget.count,
              opacity: widget.opacity,
              falling: widget.falling,
              warm: widget.warm,
              bright: widget.bright),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _EmberDriftPainter extends CustomPainter {
  final Animation<double> t;
  final int count;
  final double opacity;
  final bool falling;
  final Color warm;
  final Color bright;
  final Paint _p = Paint();
  _EmberDriftPainter(this.t, this.count,
      {this.opacity = 1.0, this.falling = false, Color? warm, Color? bright})
      : warm = warm ?? const Color(0xFF7A3A16),
        bright = bright ?? EmberColors.gold,
        super(repaint: t);

  // Deterministic per-particle pseudo-random from index (no Random allocs).
  double _h(int i, int salt) {
    final v = math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = t.value;
    for (var i = 0; i < count; i++) {
      final speed = 0.35 + _h(i, 1) * 0.75;
      final phase = _h(i, 2);
      var frac = (time * speed + phase) % 1.0;
      if (falling) frac = 1.0 - frac;
      final y = size.height * (1.06 - frac * 1.12);
      final wobble = math.sin((time * 6.28 * (1.5 + _h(i, 3))) + i) *
          (6 + _h(i, 4) * 14);
      final x = size.width * _h(i, 5) + wobble;
      final flicker =
          0.35 + 0.65 * (0.5 + 0.5 * math.sin(time * 6.28 * 3 + i * 1.7));
      // Embers cool as they climb (or as they die, when falling).
      final heat = falling ? frac : 1.0 - frac * 0.7;
      final color = Color.lerp(warm, bright, heat * _h(i, 6))!;
      final a = (flicker * heat * opacity).clamp(0.0, 1.0);
      if (a <= 0.01) continue;
      _p.color = color.withValues(alpha: a);
      canvas.drawCircle(
          Offset(x, y), 1.2 + _h(i, 7) * 2.2 * heat, _p);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberDriftPainter old) => false;
}

// ---------------------------------------------------------------------------
// Ember burst — one-shot dissolve cloud (deaths). Plays once, then holds
// empty; the parent removes it when choreography ends.
// ---------------------------------------------------------------------------
class EmberBurst extends StatefulWidget {
  final Duration duration;
  final int count;
  const EmberBurst(
      {super.key,
      this.duration = const Duration(milliseconds: 700),
      this.count = 26});

  @override
  State<EmberBurst> createState() => _EmberBurstState();
}

class _EmberBurstState extends State<EmberBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _EmberBurstPainter(_t, widget.count),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _EmberBurstPainter extends CustomPainter {
  final Animation<double> t;
  final int count;
  final Paint _p = Paint();
  _EmberBurstPainter(this.t, this.count) : super(repaint: t);

  double _h(int i, int salt) {
    final v = math.sin(i * 269.5 + salt * 183.3) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final f = Curves.easeOut.transform(t.value);
    if (f >= 1.0) return;
    final cx = size.width / 2;
    final cy = size.height * 0.55;
    for (var i = 0; i < count; i++) {
      final ang = _h(i, 1) * math.pi * 2;
      final dist = (14 + _h(i, 2) * size.shortestSide * 0.55) * f;
      // Sparks fly out, drift up, and cool.
      final x = cx + math.cos(ang) * dist;
      final y = cy + math.sin(ang) * dist * 0.7 - f * f * 26;
      final a = ((1.0 - f) * (0.5 + _h(i, 3) * 0.5)).clamp(0.0, 1.0);
      _p.color = Color.lerp(EmberColors.gold, const Color(0xFF7A2E10),
              (f * 1.3).clamp(0.0, 1.0))!
          .withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), (1.0 - f * 0.6) * (1.5 + _h(i, 4) * 2.5),
          _p);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberBurstPainter old) => false;
}

// ---------------------------------------------------------------------------
// Screen shake — wrap a subtree; call shake(magnitude 0..1) via the key.
// ---------------------------------------------------------------------------
class ShakeBox extends StatefulWidget {
  final Widget child;
  const ShakeBox({super.key, required this.child});
  @override
  ShakeBoxState createState() => ShakeBoxState();
}

class ShakeBoxState extends State<ShakeBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240));
  double _mag = 0;

  /// magnitude 0..1 scales displacement 0..10 px (design-system: shake on
  /// hits, bigger hits shake harder).
  void shake(double magnitude) {
    _mag = magnitude.clamp(0.0, 1.0);
    _t.forward(from: 0);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final f = _t.isAnimating ? (1.0 - _t.value) : 0.0;
        final amp = _mag * 10 * f;
        final dx = math.sin(_t.value * 34) * amp;
        final dy = math.cos(_t.value * 29) * amp * 0.6;
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Damage pop — a number that pops, arcs, and fades. Spawned in a Stack.
// ---------------------------------------------------------------------------
class DamagePop extends StatefulWidget {
  final int amount;
  final bool blocked;
  final bool onPlayer; // arcs left for player hits, right for enemy hits
  final VoidCallback onDone;
  const DamagePop(
      {super.key,
      required this.amount,
      required this.onDone,
      this.blocked = false,
      this.onPlayer = false});

  @override
  State<DamagePop> createState() => _DamagePopState();
}

class _DamagePopState extends State<DamagePop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.blocked ? EmberColors.block : EmberColors.gold;
    final text = widget.blocked ? 'BLOCKED' : '-${widget.amount}';
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final f = _t.value;
        // Pop in (overshoot), arc up-and-away, fade in the last 40%.
        final scale = f < 0.18
            ? 0.4 + (f / 0.18) * 0.9 // 0.4 -> 1.3
            : 1.3 - Curves.easeOut.transform((f - 0.18) / 0.82) * 0.3;
        final dir = widget.onPlayer ? -1.0 : 1.0;
        final dx = dir * 26 * Curves.easeOut.transform(f);
        final dy = -46 * Curves.easeOut.transform(f) + 18 * f * f;
        final alpha = f < 0.6 ? 1.0 : 1.0 - (f - 0.6) / 0.4;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: alpha.clamp(0.0, 1.0),
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: widget.blocked ? 14 : 26,
                  fontWeight: FontWeight.w800,
                  color: color,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 4),
                    Shadow(
                        color: Colors.black,
                        offset: Offset(0, 2),
                        blurRadius: 2),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Text pop — DamagePop's language for words: pop in with overshoot, drift up,
// fade. Used for combo call-outs, exact-kill/overkill moments, burn ticks.
// ---------------------------------------------------------------------------
class TextPop extends StatefulWidget {
  final String text;
  final Color color;
  final double fontSize;
  final IconData? icon;
  final VoidCallback onDone;
  const TextPop(
      {super.key,
      required this.text,
      required this.onDone,
      this.color = EmberColors.gold,
      this.fontSize = 18,
      this.icon});

  @override
  State<TextPop> createState() => _TextPopState();
}

class _TextPopState extends State<TextPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final f = _t.value;
        // Pop in (overshoot), drift up, fade in the last 35%.
        final scale = f < 0.16
            ? 0.5 + (f / 0.16) * 0.75 // 0.5 -> 1.25
            : 1.25 - Curves.easeOut.transform((f - 0.16) / 0.84) * 0.25;
        final dy = -34 * Curves.easeOut.transform(f);
        final alpha = f < 0.65 ? 1.0 : 1.0 - (f - 0.65) / 0.35;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: alpha.clamp(0.0, 1.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon,
                        size: widget.fontSize + 2,
                        color: widget.color,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 4),
                        ]),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    widget.text,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: widget.color,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4),
                        Shadow(
                            color: Colors.black,
                            offset: Offset(0, 2),
                            blurRadius: 2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Vignette — soft dark edges; sells "lit from the middle/below".
// ---------------------------------------------------------------------------
class Vignette extends StatelessWidget {
  final double strength;
  const Vignette({super.key, this.strength = 0.5});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, 0.15),
            radius: 1.25,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: strength),
            ],
            stops: const [0.55, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phase switcher — flame-wipe smash-cut into combat, fade-through-black for
// everything else (kills the stock AnimatedSwitcher cross-fade).
// ---------------------------------------------------------------------------
class PhaseSwitcher extends StatefulWidget {
  final String phaseKey;
  final Widget child;

  /// Phases that get the flame wipe when entered (map -> combat smash cut).
  final bool flameWipe;
  const PhaseSwitcher(
      {super.key,
      required this.phaseKey,
      required this.child,
      this.flameWipe = false});

  @override
  State<PhaseSwitcher> createState() => _PhaseSwitcherState();
}

class _PhaseSwitcherState extends State<PhaseSwitcher>
    with SingleTickerProviderStateMixin {
  // Created eagerly in initState: a lazy `late` controller would otherwise be
  // constructed during dispose() when no transition ever ran.
  late final AnimationController _t;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
  }
  Widget? _old;
  String? _oldKey;
  bool _wipe = false;

  @override
  void didUpdateWidget(PhaseSwitcher prev) {
    super.didUpdateWidget(prev);
    if (prev.phaseKey != widget.phaseKey) {
      _old = prev.child;
      _oldKey = prev.phaseKey;
      _wipe = widget.flameWipe;
      _t
        ..duration = Duration(milliseconds: _wipe ? 520 : 380)
        ..forward(from: 0).whenComplete(() {
          if (mounted) setState(() => _old = null);
        });
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_old == null) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final f = _t.value;
        // Old covers the first half, new reveals in the second.
        final showNew = f >= 0.5;
        return Stack(fit: StackFit.expand, children: [
          KeyedSubtree(
              key: ValueKey('ps-${showNew ? widget.phaseKey : _oldKey}'),
              child: showNew ? widget.child : _old!),
          IgnorePointer(
            child: _wipe
                ? CustomPaint(
                    painter: _FlameWipePainter(f), size: Size.infinite)
                : Container(
                    color: Colors.black.withValues(
                        alpha: (1.0 - (2 * f - 1).abs()).clamp(0.0, 1.0)),
                  ),
          ),
        ]);
      },
    );
  }
}

/// A wall of flame sweeping up: covers 0->0.5, reveals 0.5->1. The leading
/// edge is a jagged sin ridge with hot gradient + spark dots.
class _FlameWipePainter extends CustomPainter {
  final double f;
  final Paint _fill = Paint();
  final Paint _spark = Paint();
  _FlameWipePainter(this.f);

  @override
  void paint(Canvas canvas, Size size) {
    final covering = f < 0.5;
    final p = covering ? f / 0.5 : (f - 0.5) / 0.5;
    // Edge position: sweeps bottom->top covering, keeps sweeping revealing.
    final edgeY = covering
        ? size.height * (1.05 - 1.25 * Curves.easeIn.transform(p))
        : size.height * (-0.2 - 1.0 * Curves.easeOut.transform(p)) +
            size.height * 1.05;
    // Filled region: below edge when covering, above edge when revealing.
    final path = Path();
    const teeth = 14;
    path.moveTo(0, edgeY);
    for (var i = 0; i <= teeth; i++) {
      final x = size.width * i / teeth;
      final y = edgeY +
          math.sin(i * 2.7 + f * 20) * 22 -
          (i.isEven ? 14 : 0);
      path.lineTo(x, y);
    }
    if (covering) {
      path.lineTo(size.width, size.height + 40);
      path.lineTo(0, size.height + 40);
    } else {
      path.lineTo(size.width, -40);
      path.lineTo(0, -40);
    }
    path.close();
    _fill.shader = LinearGradient(
      begin: covering ? Alignment.topCenter : Alignment.bottomCenter,
      end: covering ? Alignment.bottomCenter : Alignment.topCenter,
      colors: const [
        Color(0xFFFFD98A), // hot leading edge
        Color(0xFFF08A2C),
        Color(0xFF7A2E10),
        Color(0xFF150A05), // charred body
      ],
      stops: const [0.0, 0.12, 0.38, 1.0],
    ).createShader(Rect.fromLTWH(0, edgeY - 30, size.width, size.height));
    canvas.drawPath(path, _fill);
    // Sparks along the edge.
    for (var i = 0; i < 20; i++) {
      final v = math.sin(i * 127.1) * 43758.5453;
      final h = v - v.floorToDouble();
      final x = size.width * h;
      final y = edgeY + math.sin(i * 3.3 + f * 24) * 30 - 12;
      _spark.color =
          EmberColors.gold.withValues(alpha: 0.4 + 0.6 * ((i % 3) / 3));
      canvas.drawCircle(Offset(x, y), 1.5 + (i % 3).toDouble(), _spark);
    }
  }

  @override
  bool shouldRepaint(covariant _FlameWipePainter old) => old.f != f;
}

// ---------------------------------------------------------------------------
// Route transition — fade-through-black instead of the stock Material slide.
// ---------------------------------------------------------------------------
Route<T> emberRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, __) => builder(context),
    transitionsBuilder: (context, anim, _, child) {
      // In: hold black until 45%, then fade up. Out: mirror.
      final fade = CurvedAnimation(
          parent: anim, curve: const Interval(0.45, 1.0, curve: Curves.easeOut));
      return Container(
        color: Colors.black,
        child: FadeTransition(opacity: fade, child: child),
      );
    },
  );
}

/// Programmatic camp-fire: layered flickering flame blobs + ground glow.
/// Used on the title screen next to the idling delver.
class CampFire extends StatefulWidget {
  final double size;
  // Hearth colors (v0.3.3): optional cosmetic tint. Null = classic flame.
  final Color? warm;
  final Color? bright;
  const CampFire({super.key, this.size = 44, this.warm, this.bright});
  @override
  State<CampFire> createState() => _CampFireState();
}

class _CampFireState extends State<CampFire>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CampFirePainter(_t, warm: widget.warm, bright: widget.bright),
        size: Size(widget.size, widget.size * 1.3),
      ),
    );
  }
}

class _CampFirePainter extends CustomPainter {
  final Animation<double> t;
  // Flame layer palette: deep outer, mid body, hot core, ground glow.
  final Color outer;
  final Color mid;
  final Color core;
  final Color glow;
  final Paint _p = Paint();
  _CampFirePainter(this.t, {Color? warm, Color? bright})
      : outer = warm != null
            ? Color.lerp(warm, Colors.black, 0.25)!
            : const Color(0xFF9C3A10),
        mid = warm != null && bright != null
            ? Color.lerp(warm, bright, 0.55)!
            : EmberColors.ember,
        core = bright != null
            ? Color.lerp(bright, Colors.white, 0.35)!
            : const Color(0xFFFFD98A),
        glow = warm != null && bright != null
            ? Color.lerp(warm, bright, 0.55)!
            : EmberColors.ember,
        super(repaint: t);

  void _flame(Canvas canvas, Size s, double phase, double w, double h,
      Color color, double a) {
    final time = t.value * math.pi * 2;
    final sway = math.sin(time * 2 + phase) * s.width * 0.06;
    final lick = 1.0 + math.sin(time * 3 + phase * 2) * 0.12;
    final baseY = s.height;
    final cx = s.width / 2 + sway * 0.4;
    final path = Path()
      ..moveTo(cx - w / 2, baseY)
      ..quadraticBezierTo(cx - w * 0.55, baseY - h * 0.45 * lick,
          cx + sway, baseY - h * lick)
      ..quadraticBezierTo(
          cx + w * 0.55, baseY - h * 0.45 * lick, cx + w / 2, baseY)
      ..close();
    _p.color = color.withValues(alpha: a);
    canvas.drawPath(path, _p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Ground glow.
    _p.color = glow.withValues(
        alpha: 0.18 + 0.06 * math.sin(t.value * math.pi * 4));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.98),
            width: size.width * 1.9,
            height: size.height * 0.3),
        _p);
    // Logs.
    _p.color = const Color(0xFF3A2418);
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.95);
    canvas.rotate(0.35);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: size.width * 0.9, height: 5),
            const Radius.circular(2)),
        _p);
    canvas.rotate(-0.7);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: size.width * 0.9, height: 5),
            const Radius.circular(2)),
        _p);
    canvas.restore();
    // Flame layers: deep red -> ember -> hot gold core.
    _flame(canvas, size, 0.0, size.width * 0.72, size.height * 0.78,
        outer, 0.9);
    _flame(canvas, size, 1.6, size.width * 0.5, size.height * 0.6,
        mid, 0.95);
    _flame(canvas, size, 3.1, size.width * 0.28, size.height * 0.4,
        core, 1.0);
  }

  @override
  bool shouldRepaint(covariant _CampFirePainter old) => false;
}
