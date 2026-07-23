// lib/ui/widgets.dart — shared UI atoms built to the design system.
// De-Flutter pass: buttons are painted (chamfered slabs, 3 tiers), dice render
// as real die faces (pips over the die art), HP bars are segmented ember bars
// with a damage ghost trail, and panels light warm-from-below.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/audio_service.dart';
import '../data/dice.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Buttons — three painted tiers: primary ember / secondary charcoal / ghost.
// ---------------------------------------------------------------------------
class EmberButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;
  final bool ghost;
  final IconData? icon;
  const EmberButton(this.label,
      {super.key,
      this.onTap,
      this.primary = false,
      this.danger = false,
      this.ghost = false,
      this.icon});

  @override
  State<EmberButton> createState() => _EmberButtonState();
}

class _EmberButtonState extends State<EmberButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final tier = widget.danger
        ? _ButtonTier.danger
        : widget.primary
            ? _ButtonTier.primary
            : widget.ghost
                ? _ButtonTier.ghost
                : _ButtonTier.secondary;
    final fg = !enabled
        ? EmberColors.textDisabled
        : switch (tier) {
            _ButtonTier.primary || _ButtonTier.danger => const Color(0xFF17110A),
            _ButtonTier.secondary => EmberColors.textPrimary,
            _ButtonTier.ghost => EmberColors.textDim,
          };
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              AudioService.instance?.playSfx('ui_tap', volume: 0.8);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: CustomPaint(
          painter: _ButtonPainter(tier: tier, enabled: enabled, down: _down),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Space.xl, vertical: Space.l),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: fg),
                  const SizedBox(width: Space.s),
                ],
                Text(widget.label,
                    style: TextStyle(
                        fontFamily: 'Cinzel',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        letterSpacing: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ButtonTier { primary, secondary, ghost, danger }

/// Chamfered slab with a warm-from-below gradient, dark rim, top char line
/// and (primary) an ember under-glow — a drawn button, not a Material one.
class _ButtonPainter extends CustomPainter {
  final _ButtonTier tier;
  final bool enabled;
  final bool down;
  _ButtonPainter({required this.tier, required this.enabled, required this.down});

  Path _slab(Size s, [double inset = 0]) {
    const c = 9.0; // chamfer
    final r = Rect.fromLTWH(inset, inset, s.width - 2 * inset, s.height - 2 * inset);
    return Path()
      ..moveTo(r.left + c, r.top)
      ..lineTo(r.right - c, r.top)
      ..lineTo(r.right, r.top + c)
      ..lineTo(r.right, r.bottom - c)
      ..lineTo(r.right - c, r.bottom)
      ..lineTo(r.left + c, r.bottom)
      ..lineTo(r.left, r.bottom - c)
      ..lineTo(r.left, r.top + c)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final slab = _slab(size);
    final rect = Offset.zero & size;
    final dim = down ? 0.12 : 0.0;

    if (!enabled) {
      canvas.drawPath(slab, Paint()..color = EmberColors.surface);
      canvas.drawPath(
          slab,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = EmberColors.line.withValues(alpha: 0.6));
      return;
    }

    List<Color> grad;
    Color rim;
    switch (tier) {
      case _ButtonTier.primary:
        grad = const [Color(0xFFC2661B), Color(0xFFF08A2C), Color(0xFFFFB65C)];
        rim = const Color(0xFF4A2508);
        // Under-glow (warm light spilling below).
        canvas.drawPath(
            _slab(size).shift(const Offset(0, 3)),
            Paint()
              ..color = EmberColors.ember.withValues(alpha: 0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        break;
      case _ButtonTier.danger:
        grad = const [Color(0xFF7E2424), Color(0xFFC24040), Color(0xFFE07B5B)];
        rim = const Color(0xFF3D0F0F);
        break;
      case _ButtonTier.secondary:
        grad = const [Color(0xFF221A2E), Color(0xFF2A2136), Color(0xFF3B2F4C)];
        rim = EmberColors.line;
        break;
      case _ButtonTier.ghost:
        canvas.drawPath(
            slab, Paint()..color = Colors.black.withValues(alpha: 0.25));
        canvas.drawPath(
            slab,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = EmberColors.textDim.withValues(alpha: 0.5));
        return;
    }

    canvas.drawPath(
        slab,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    for (final c in grad)
                      Color.lerp(c, Colors.black, dim)!
                  ])
              .createShader(rect));
    // Char line along the top (cool shadow side).
    canvas.drawLine(
        Offset(10, 1.2),
        Offset(size.width - 10, 1.2),
        Paint()
          ..strokeWidth = 2
          ..color = Colors.black.withValues(alpha: 0.28));
    // Hot edge along the bottom (lit side).
    if (tier == _ButtonTier.primary || tier == _ButtonTier.danger) {
      canvas.drawLine(
          Offset(10, size.height - 1.6),
          Offset(size.width - 10, size.height - 1.6),
          Paint()
            ..strokeWidth = 2.4
            ..color = const Color(0xFFFFE0A3).withValues(alpha: 0.55));
    } else {
      canvas.drawLine(
          Offset(10, size.height - 1.4),
          Offset(size.width - 10, size.height - 1.4),
          Paint()
            ..strokeWidth = 1.6
            ..color = EmberColors.ember.withValues(alpha: 0.25));
    }
    canvas.drawPath(
        slab,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = rim);
  }

  @override
  bool shouldRepaint(covariant _ButtonPainter old) =>
      old.tier != tier || old.enabled != enabled || old.down != down;
}

// ---------------------------------------------------------------------------
/// A labelled resource pip (embers / gold), value bright, label micro.
class ResourcePip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  final String? imageAsset; // painted currency icon; falls back to [icon]
  const ResourcePip(this.icon, this.color, this.value, this.label,
      {super.key, this.imageAsset});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (imageAsset != null)
        Image.asset(imageAsset!,
            width: 18, height: 18, filterQuality: FilterQuality.medium)
      else
        Icon(icon, size: 18, color: color),
      const SizedBox(width: Space.xs),
      Text('$value',
          style: EmberText.value.copyWith(fontSize: 18, color: color)),
      const SizedBox(width: Space.xs),
      Text(label, style: EmberText.micro),
    ]);
  }
}

// ---------------------------------------------------------------------------
// StatBar — segmented ember bar with a chip-away ghost trail on damage.
// ---------------------------------------------------------------------------
class StatBar extends StatefulWidget {
  final int value;
  final int max;
  final int block;
  final Color color;
  final String label;
  const StatBar(
      {super.key,
      required this.value,
      required this.max,
      required this.color,
      required this.label,
      this.block = 0});

  @override
  State<StatBar> createState() => _StatBarState();
}

class _StatBarState extends State<StatBar> {
  late double _ghost = _frac; // lags behind on damage (chip-away trail)

  double get _frac =>
      widget.max <= 0 ? 0.0 : (widget.value / widget.max).clamp(0.0, 1.0);

  @override
  void didUpdateWidget(StatBar old) {
    super.didUpdateWidget(old);
    if (old.value > widget.value) {
      // keep ghost at the old level; TweenAnimationBuilder eases it down.
      _ghost = old.max <= 0 ? 0.0 : (old.value / old.max).clamp(0.0, 1.0);
    } else {
      _ghost = _frac;
    }
  }

  @override
  Widget build(BuildContext context) {
    final frac = _frac;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('${widget.value}', style: EmberText.value.copyWith(fontSize: 20)),
        Text(' / ${widget.max}', style: EmberText.bodyDim.copyWith(fontSize: 14)),
        const Spacer(),
        if (widget.block > 0)
          Row(children: [
            const Icon(Icons.shield, size: 14, color: EmberColors.block),
            const SizedBox(width: 2),
            Text('${widget.block}',
                style: EmberText.value
                    .copyWith(fontSize: 16, color: EmberColors.block)),
          ]),
      ]),
      const SizedBox(height: Space.xs),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: _ghost, end: frac),
        duration: const Duration(milliseconds: 700),
        curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
        builder: (context, ghost, _) => TweenAnimationBuilder<double>(
          tween: Tween(end: frac),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          builder: (context, fill, _) => CustomPaint(
            painter: _SegBarPainter(
                fill: fill, ghost: ghost, max: widget.max, color: widget.color),
            size: const Size(double.infinity, 12),
          ),
        ),
      ),
      const SizedBox(height: Space.xs),
      Text(widget.label, style: EmberText.micro),
    ]);
  }
}

/// Skinned bar: charcoal trough, warm-from-below fill gradient, segment
/// notches every 10 points, and a pale ghost strip where HP just was.
class _SegBarPainter extends CustomPainter {
  final double fill;
  final double ghost;
  final int max;
  final Color color;
  _SegBarPainter(
      {required this.fill,
      required this.ghost,
      required this.max,
      required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(3));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF171021));
    // Ghost trail (recently lost chunk).
    if (ghost > fill) {
      canvas.drawRect(
          Rect.fromLTWH(size.width * fill, 1, size.width * (ghost - fill),
              size.height - 2),
          Paint()..color = const Color(0xFFEDE6DA).withValues(alpha: 0.45));
    }
    // Fill, lit from below.
    if (fill > 0) {
      canvas.drawRect(
          Rect.fromLTWH(0, 1, size.width * fill, size.height - 2),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(color, Colors.black, 0.35)!,
                color,
                Color.lerp(color, const Color(0xFFFFE0A3), 0.45)!,
              ],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    }
    // Segment notches every 10 points.
    if (max > 10) {
      final seg = Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..strokeWidth = 1.4;
      for (var v = 10; v < max; v += 10) {
        final x = size.width * v / max;
        canvas.drawLine(Offset(x, 1), Offset(x, size.height - 1), seg);
      }
    }
    // Rim.
    canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF3A3148));
  }

  @override
  bool shouldRepaint(covariant _SegBarPainter old) =>
      old.fill != fill || old.ghost != ghost || old.max != max ||
      old.color != color;
}

// ---------------------------------------------------------------------------
// DieChip — a real die: the die art with pips painted per rolled value, and a
// physical tumble (rotation + bounce) when a new roll lands.
// ---------------------------------------------------------------------------
class DieChip extends StatefulWidget {
  final String dieId;
  final int? value;
  final bool assigned;
  final bool selected;
  final bool maxed;
  final VoidCallback? onTap;

  /// Increment per roll to trigger the tumble; [tumbleDelayMs] staggers dice.
  final int rollToken;
  final int tumbleDelayMs;
  const DieChip(this.dieId,
      {super.key,
      this.value,
      this.assigned = false,
      this.selected = false,
      this.maxed = false,
      this.onTap,
      this.rollToken = 0,
      this.tumbleDelayMs = 0});

  @override
  State<DieChip> createState() => _DieChipState();
}

class _DieChipState extends State<DieChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tumble = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void didUpdateWidget(DieChip old) {
    super.didUpdateWidget(old);
    if (widget.rollToken != old.rollToken && widget.value != null) {
      Future.delayed(Duration(milliseconds: widget.tumbleDelayMs), () {
        if (mounted) _tumble.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _tumble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = dieDef(widget.dieId);
    return GestureDetector(
      onTap: widget.assigned ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _tumble,
        builder: (context, _) {
          final f = _tumble.isAnimating ? _tumble.value : 1.0;
          // Rotation settles with a decaying wobble; die hops once.
          final settle = 1.0 - Curves.easeOut.transform(f);
          final rot = math.sin(f * math.pi * 4) * 0.55 * settle;
          final hop = -math.sin(f * math.pi).abs() *
              14 *
              (1.0 - f * 0.6);
          // While mid-tumble, show cycling faces instead of the result.
          final showValue = widget.value == null
              ? null
              : (f < 0.55 && _tumble.isAnimating)
                  ? 1 + ((f * 31).floor() * 7 + widget.tumbleDelayMs) % def.size
                  : widget.value;
          return Transform.translate(
            offset: Offset(0, _tumble.isAnimating ? hop : 0),
            child: Transform.rotate(
              angle: _tumble.isAnimating ? rot : 0,
              child: _face(def, showValue),
            ),
          );
        },
      ),
    );
  }

  Widget _face(DieDef def, int? value) {
    final borderColor = widget.selected
        ? EmberColors.ember
        : widget.maxed
            ? EmberColors.gold
            : Colors.transparent;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: widget.assigned ? 0.35 : 1.0,
      child: Container(
        width: 64,
        height: 80,
        decoration: widget.selected || widget.maxed
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: borderColor.withValues(alpha: 0.55),
                      blurRadius: 12),
                ],
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(fit: StackFit.expand, children: [
                // Pixel die art at exactly 0.5x of its 128px source.
                Image.asset('assets/images/ui/dice/die_d${def.size}.png',
                    filterQuality: FilterQuality.none),
                if (value != null)
                  CustomPaint(
                      painter: _PipPainter(value,
                          maxed: widget.maxed, selected: widget.selected)),
                if (widget.selected)
                  CustomPaint(painter: _DieRingPainter(EmberColors.ember))
                else if (widget.maxed)
                  CustomPaint(painter: _DieRingPainter(EmberColors.gold)),
              ]),
            ),
            const SizedBox(height: 2),
            Text(
                value != null && widget.maxed
                    ? 'd${def.size} MAX'
                    : 'd${def.size}',
                style: EmberText.micro.copyWith(
                    fontSize: 9,
                    color: widget.maxed
                        ? EmberColors.gold
                        : EmberColors.textDim)),
          ],
        ),
      ),
    );
  }
}

/// Selection ring drawn around the die silhouette (not a rounded-rect box).
class _DieRingPainter extends CustomPainter {
  final Color color;
  _DieRingPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
        size.center(Offset.zero),
        size.shortestSide * 0.52,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = color.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(covariant _DieRingPainter old) => old.color != color;
}

/// Pip layouts per value (1–12), drawn over the die face. Dark pips with a
/// hot rim highlight so they read on the light die art.
class _PipPainter extends CustomPainter {
  final int value;
  final bool maxed;
  final bool selected;
  _PipPainter(this.value, {this.maxed = false, this.selected = false});

  // Unit positions (-1..1) per value; classic pip arrangements, extended
  // symmetrically for 10–12.
  static const Map<int, List<Offset>> _layouts = {
    1: [Offset.zero],
    2: [Offset(-1, -1), Offset(1, 1)],
    3: [Offset(-1, -1), Offset.zero, Offset(1, 1)],
    4: [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)],
    5: [
      Offset(-1, -1), Offset(1, -1), Offset.zero, Offset(-1, 1), Offset(1, 1)
    ],
    6: [
      Offset(-1, -1), Offset(1, -1), Offset(-1, 0), Offset(1, 0),
      Offset(-1, 1), Offset(1, 1)
    ],
    7: [
      Offset(-1, -1), Offset(1, -1), Offset(-1, 0), Offset.zero, Offset(1, 0),
      Offset(-1, 1), Offset(1, 1)
    ],
    8: [
      Offset(-1, -1), Offset(0, -1), Offset(1, -1), Offset(-1, 0),
      Offset(1, 0), Offset(-1, 1), Offset(0, 1), Offset(1, 1)
    ],
    9: [
      Offset(-1, -1), Offset(0, -1), Offset(1, -1), Offset(-1, 0),
      Offset.zero, Offset(1, 0), Offset(-1, 1), Offset(0, 1), Offset(1, 1)
    ],
    10: [
      Offset(-1, -1), Offset(0, -1), Offset(1, -1),
      Offset(-1, -0.33), Offset(1, -0.33),
      Offset(-1, 0.33), Offset(1, 0.33),
      Offset(-1, 1), Offset(0, 1), Offset(1, 1)
    ],
    11: [
      Offset(-1, -1), Offset(0, -1), Offset(1, -1),
      Offset(-1, -0.33), Offset(1, -0.33),
      Offset.zero,
      Offset(-1, 0.33), Offset(1, 0.33),
      Offset(-1, 1), Offset(0, 1), Offset(1, 1)
    ],
    12: [
      Offset(-1, -1), Offset(0, -1), Offset(1, -1),
      Offset(-1, -0.33), Offset(0, -0.33), Offset(1, -0.33),
      Offset(-1, 0.33), Offset(0, 0.33), Offset(1, 0.33),
      Offset(-1, 1), Offset(0, 1), Offset(1, 1)
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final pips = _layouts[value.clamp(1, 12)]!;
    final c = size.center(Offset.zero);
    // Conservative face area so pips stay inside every die silhouette
    // (d4 triangle is the tightest); dense values pack slightly smaller.
    final extent = size.shortestSide * (pips.length > 9 ? 0.20 : 0.17);
    final radius =
        size.shortestSide * (pips.length > 6 ? 0.045 : 0.06);
    final pip = Paint()..color = const Color(0xFF241407);
    final rim = Paint()
      ..color = (maxed ? EmberColors.gold : const Color(0xFFFFD98A))
          .withValues(alpha: maxed ? 0.9 : 0.5);
    for (final o in pips) {
      final p = c + Offset(o.dx * extent, o.dy * extent);
      canvas.drawCircle(p + const Offset(0, 0.8), radius + 0.8, rim);
      canvas.drawCircle(p, radius, pip);
    }
  }

  @override
  bool shouldRepaint(covariant _PipPainter old) =>
      old.value != value || old.maxed != maxed || old.selected != selected;
}

// ---------------------------------------------------------------------------
/// Small titled card container (shop slots, event options, panels).
/// Charcoal slab, chamfered corners, faint warm light along the bottom edge.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(Space.l),
      this.color});
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _PanelPainter(color ?? EmberColors.surface),
        child: Padding(padding: padding, child: child),
      );
}

class _PanelPainter extends CustomPainter {
  final Color color;
  _PanelPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const c = 10.0;
    final path = Path()
      ..moveTo(c, 0)
      ..lineTo(size.width - c, 0)
      ..lineTo(size.width, c)
      ..lineTo(size.width, size.height - c)
      ..lineTo(size.width - c, size.height)
      ..lineTo(c, size.height)
      ..lineTo(0, size.height - c)
      ..lineTo(0, c)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(color, Colors.black, 0.18)!,
              color,
              Color.lerp(color, EmberColors.ember, 0.06)!,
            ],
            stops: const [0.0, 0.6, 1.0],
          ).createShader(Offset.zero & size)
          ..color = color.withValues(alpha: 0.94));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = EmberColors.line);
    // Warm hairline along the bottom (lit-from-below rule).
    canvas.drawLine(
        Offset(c + 2, size.height - 1),
        Offset(size.width - c - 2, size.height - 1),
        Paint()
          ..strokeWidth = 1.2
          ..color = EmberColors.ember.withValues(alpha: 0.18));
  }

  @override
  bool shouldRepaint(covariant _PanelPainter old) => old.color != color;
}

void showFlash(BuildContext context, String msg) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Text(msg, style: EmberText.body),
    backgroundColor: EmberColors.raised,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(milliseconds: 1400),
  ));
}
