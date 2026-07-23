// lib/ui/logo.dart — the EMBERDELVE logotype, drawn (not a plain Text):
// stacked render passes over the display face — a soft ember glow bloom, a
// charred top / molten bottom vertical gradient fill (the global
// warm-from-below lighting rule), a crisp charcoal outline, and rising spark
// pinpricks across the letterforms. No image assets involved.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

class EmberLogotype extends StatefulWidget {
  final String text;
  final double fontSize;
  const EmberLogotype(this.text, {super.key, this.fontSize = 44});

  @override
  State<EmberLogotype> createState() => _EmberLogotypeState();
}

class _EmberLogotypeState extends State<EmberLogotype>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) => CustomPaint(
          painter: _LogotypePainter(widget.text, widget.fontSize, _t.value),
          size: Size(double.infinity, widget.fontSize * 1.5),
        ),
      ),
    );
  }
}

class _LogotypePainter extends CustomPainter {
  final String text;
  final double fontSize;
  final double time;
  _LogotypePainter(this.text, this.fontSize, this.time);

  TextPainter _tp(TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  }

  TextStyle _base({Paint? foreground, Color? color}) => TextStyle(
        fontFamily: 'Cinzel',
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: fontSize * 0.06,
        foreground: foreground,
        color: foreground == null ? color : null,
      );

  double _h(int i, int salt) {
    final v = math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = 0.5 + 0.5 * math.sin(time * math.pi * 2);
    final probe = _tp(_base(color: Colors.white));
    final origin = Offset(
        (size.width - probe.width) / 2, (size.height - probe.height) / 2);
    final rect = origin & Size(probe.width, probe.height);

    // 1. Bloom: two blurred glow passes, breathing slightly.
    final glowBig = Paint()
      ..color = EmberColors.ember.withValues(alpha: 0.30 + 0.12 * pulse)
      ..maskFilter =
          MaskFilter.blur(BlurStyle.normal, fontSize * (0.34 + 0.05 * pulse));
    _tp(_base(foreground: glowBig)).paint(canvas, origin);
    final glowTight = Paint()
      ..color = const Color(0xFFFFB65C).withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, fontSize * 0.10);
    _tp(_base(foreground: glowTight)).paint(canvas, origin);

    // 2. Charcoal outline grounds the letterforms.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.5, fontSize * 0.07)
      ..color = const Color(0xFF17110A);
    _tp(_base(foreground: outline)).paint(canvas, origin);

    // 3. Fill: charred top -> molten bottom (warm-from-below).
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF6E6258), // ash top
          Color(0xFFEDE6DA),
          Color(0xFFFFC46B),
          Color(0xFFF08A2C), // ember base
        ],
        stops: const [0.0, 0.42, 0.72, 1.0],
      ).createShader(rect);
    _tp(_base(foreground: fill)).paint(canvas, origin);

    // 4. Spark pinpricks drifting up through the letters.
    final spark = Paint();
    for (var i = 0; i < 14; i++) {
      final f = (time * (0.5 + _h(i, 1) * 0.8) + _h(i, 2)) % 1.0;
      final x = rect.left + rect.width * _h(i, 3);
      final y = rect.bottom - rect.height * f * 1.15;
      final a = ((1.0 - f) * 0.8).clamp(0.0, 1.0);
      spark.color = const Color(0xFFFFD98A).withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), 1.0 + _h(i, 4) * 1.4, spark);
    }
  }

  @override
  bool shouldRepaint(covariant _LogotypePainter old) =>
      old.time != time || old.text != text || old.fontSize != fontSize;
}
