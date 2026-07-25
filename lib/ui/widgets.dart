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

  /// Compact vertical padding for short screens (combat action zone).
  final bool dense;
  const EmberButton(
    this.label, {
    super.key,
    this.onTap,
    this.primary = false,
    this.danger = false,
    this.ghost = false,
    this.icon,
    this.dense = false,
  });

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
            _ButtonTier.primary ||
            _ButtonTier.danger => const Color(0xFF17110A),
            _ButtonTier.secondary => EmberColors.textPrimary,
            _ButtonTier.ghost => EmberColors.textDim,
          };
    void handleTap() {
      AudioService.instance?.playSfx('ui_tap', volume: 0.8);
      widget.onTap!();
    }

    // One merged semantics node per button: TalkBack reads the label and can
    // activate it; the drawn (CustomPaint) chrome is invisible to a11y.
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: enabled ? handleTap : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled ? handleTap : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: CustomPaint(
            painter: _ButtonPainter(tier: tier, enabled: enabled, down: _down),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Space.xl,
                vertical: widget.dense ? Space.m : Space.l,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: fg),
                    const SizedBox(width: Space.s),
                  ],
                  // Flexible + soft-wrap (v0.3.1 F4): long labels (event
                  // options) wrap to a second line instead of clipping
                  // off-screen at phone widths.
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        letterSpacing: 0.6,
                      ),
                    ),
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

enum _ButtonTier { primary, secondary, ghost, danger }

/// Chamfered slab with a warm-from-below gradient, dark rim, top char line
/// and (primary) an ember under-glow — a drawn button, not a Material one.
class _ButtonPainter extends CustomPainter {
  final _ButtonTier tier;
  final bool enabled;
  final bool down;
  _ButtonPainter({
    required this.tier,
    required this.enabled,
    required this.down,
  });

  Path _slab(Size s, [double inset = 0]) {
    const c = 9.0; // chamfer
    final r = Rect.fromLTWH(
      inset,
      inset,
      s.width - 2 * inset,
      s.height - 2 * inset,
    );
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
          ..color = EmberColors.line.withValues(alpha: 0.6),
      );
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
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
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
          slab,
          Paint()..color = Colors.black.withValues(alpha: 0.25),
        );
        canvas.drawPath(
          slab,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = EmberColors.textDim.withValues(alpha: 0.5),
        );
        return;
    }

    canvas.drawPath(
      slab,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [for (final c in grad) Color.lerp(c, Colors.black, dim)!],
        ).createShader(rect),
    );
    // Char line along the top (cool shadow side).
    canvas.drawLine(
      Offset(10, 1.2),
      Offset(size.width - 10, 1.2),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.black.withValues(alpha: 0.28),
    );
    // Hot edge along the bottom (lit side).
    if (tier == _ButtonTier.primary || tier == _ButtonTier.danger) {
      canvas.drawLine(
        Offset(10, size.height - 1.6),
        Offset(size.width - 10, size.height - 1.6),
        Paint()
          ..strokeWidth = 2.4
          ..color = const Color(0xFFFFE0A3).withValues(alpha: 0.55),
      );
    } else {
      canvas.drawLine(
        Offset(10, size.height - 1.4),
        Offset(size.width - 10, size.height - 1.4),
        Paint()
          ..strokeWidth = 1.6
          ..color = EmberColors.ember.withValues(alpha: 0.25),
      );
    }
    canvas.drawPath(
      slab,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = rim,
    );
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
  const ResourcePip(
    this.icon,
    this.color,
    this.value,
    this.label, {
    super.key,
    this.imageAsset,
  });
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value ${label.toLowerCase()}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageAsset != null)
            Image.asset(
              imageAsset!,
              width: 18,
              height: 18,
              filterQuality: FilterQuality.medium,
            )
          else
            Icon(icon, size: 18, color: color),
          const SizedBox(width: Space.xs),
          Text(
            '$value',
            style: EmberText.value.copyWith(fontSize: 18, color: color),
          ),
          const SizedBox(width: Space.xs),
          Text(label, style: EmberText.micro),
        ],
      ),
    );
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
  const StatBar({
    super.key,
    required this.value,
    required this.max,
    required this.color,
    required this.label,
    this.block = 0,
  });

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
    return Semantics(
      label:
          '${widget.label.toLowerCase()}: ${widget.value} of ${widget.max} HP'
          '${widget.block > 0 ? ', ${widget.block} block' : ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${widget.value}',
                style: EmberText.value.copyWith(fontSize: 20),
              ),
              Text(
                ' / ${widget.max}',
                style: EmberText.bodyDim.copyWith(fontSize: 14),
              ),
              const Spacer(),
              if (widget.block > 0)
                Row(
                  children: [
                    const Icon(
                      Icons.shield,
                      size: 14,
                      color: EmberColors.block,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${widget.block}',
                      style: EmberText.value.copyWith(
                        fontSize: 16,
                        color: EmberColors.block,
                      ),
                    ),
                  ],
                ),
            ],
          ),
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
                  fill: fill,
                  ghost: ghost,
                  max: widget.max,
                  color: widget.color,
                ),
                size: const Size(double.infinity, 12),
              ),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(widget.label, style: EmberText.micro),
        ],
      ),
    );
  }
}

/// Skinned bar: charcoal trough, warm-from-below fill gradient, segment
/// notches every 10 points, and a pale ghost strip where HP just was.
class _SegBarPainter extends CustomPainter {
  final double fill;
  final double ghost;
  final int max;
  final Color color;
  _SegBarPainter({
    required this.fill,
    required this.ghost,
    required this.max,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFF171021));
    // Ghost trail (recently lost chunk).
    if (ghost > fill) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * fill,
          1,
          size.width * (ghost - fill),
          size.height - 2,
        ),
        Paint()..color = const Color(0xFFEDE6DA).withValues(alpha: 0.45),
      );
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
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
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
        ..color = const Color(0xFF3A3148),
    );
  }

  @override
  bool shouldRepaint(covariant _SegBarPainter old) =>
      old.fill != fill ||
      old.ghost != ghost ||
      old.max != max ||
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

  /// LFP-2c: what this die actually contributed when it was assigned
  /// (modifiers, combos and relics included) — shown on the spent label so
  /// "5 rolled, 7 landed" stops being silent arithmetic.
  final int? contribution;

  /// LFP-1: physical throw-in. When true, a roll flings the die from the
  /// thumb's throw origin (bottom-center of the screen) in an arc with spin
  /// and one soft bounce before it settles into its tray slot — instead of
  /// the in-place hop. Pure presentation: the result is sim-determined
  /// before the animation starts, and total flight stays inside the same
  /// 520ms budget so pacing doesn't slow.
  final bool flight;

  /// LFP-1b: fires once when a flying die lands (the stagger across the
  /// tray turns per-die light haptics into a rattle).
  final VoidCallback? onSettle;
  const DieChip(
    this.dieId, {
    super.key,
    this.value,
    this.assigned = false,
    this.selected = false,
    this.maxed = false,
    this.onTap,
    this.rollToken = 0,
    this.tumbleDelayMs = 0,
    this.contribution,
    this.flight = false,
    this.onSettle,
  });

  @override
  State<DieChip> createState() => _DieChipState();
}

class _DieChipState extends State<DieChip> with SingleTickerProviderStateMixin {
  late final AnimationController _tumble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  // LFP-1: where this throw came from (tray-slot-local delta to the throw
  // origin), captured when the flight starts; null = in-place tumble.
  Offset? _throwDelta;
  bool _settled = true;
  static const double _flightSplit = 0.72; // flight → settle handoff

  @override
  void initState() {
    super.initState();
    _tumble.addListener(() {
      // LFP-1b: settle beat — one light haptic per die as it lands.
      if (!_settled && _tumble.value >= _flightSplit) {
        _settled = true;
        widget.onSettle?.call();
      }
    });
  }

  @override
  void didUpdateWidget(DieChip old) {
    super.didUpdateWidget(old);
    if (widget.rollToken != old.rollToken && widget.value != null) {
      Future.delayed(Duration(milliseconds: widget.tumbleDelayMs), () {
        if (!mounted) return;
        if (widget.flight) {
          // Capture the chip's slot position NOW (post-layout) and aim the
          // throw from the bottom-center of the screen — where the thumb is.
          final box = context.findRenderObject() as RenderBox?;
          if (box != null && box.attached && box.hasSize) {
            final center = box.localToGlobal(box.size.center(Offset.zero));
            final screen = MediaQuery.sizeOf(context);
            final origin = Offset(screen.width / 2, screen.height - 56);
            _throwDelta = origin - center;
          } else {
            _throwDelta = const Offset(0, 220); // sane fallback: from below
          }
          _settled = false;
        } else {
          _throwDelta = null;
        }
        _tumble.forward(from: 0);
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
    // Spoken description for TalkBack: die size, face, and state. The painted
    // pips/rings below carry no semantics of their own.
    final a11y = StringBuffer('${def.name}, d${def.size} die');
    if (widget.value != null) a11y.write(', rolled ${widget.value}');
    if (widget.maxed && !widget.assigned) a11y.write(', max roll');
    if (widget.assigned) {
      a11y.write(
        widget.contribution != null
            ? ', spent for ${widget.contribution}'
            : ', spent',
      );
    } else if (widget.selected) {
      a11y.write(', selected');
    }
    // v0.3.1 F1: taps are no longer swallowed here for assigned dice — the
    // caller decides (CombatScreen flashes "ALREADY ASSIGNED" feedback).
    return Semantics(
      button: widget.onTap != null,
      label: a11y.toString(),
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _tumble,
          builder: (context, _) {
            final f = _tumble.isAnimating ? _tumble.value : 1.0;
            // While mid-tumble, show cycling faces instead of the result.
            final showValue = widget.value == null
                ? null
                : (f < 0.55 && _tumble.isAnimating)
                ? 1 + ((f * 31).floor() * 7 + widget.tumbleDelayMs) % def.size
                : widget.value;
            // LFP-1: physical throw — arc in from the throw origin with
            // spin, then one soft bounce as it settles into the slot. The
            // in-place hop remains for non-tray contexts (flight == false).
            if (widget.flight && _throwDelta != null && _tumble.isAnimating) {
              final delta = _throwDelta!;
              Offset offset;
              double rot;
              if (f < _flightSplit) {
                final ft = Curves.easeOutCubic.transform(f / _flightSplit);
                // Straight-line approach + parabolic lift = a thrown arc.
                final lin = Offset.lerp(delta, Offset.zero, ft)!;
                final lift = -math.sin(ft * math.pi) * 30.0;
                // Deterministic per-slot spin, alternating direction so the
                // tray doesn't rotate in lockstep.
                final dir = (widget.tumbleDelayMs ~/ 50).isEven ? 1.0 : -1.0;
                rot =
                    dir *
                    (1.0 - ft) *
                    (0.9 + (widget.tumbleDelayMs % 150) / 300) *
                    2 *
                    math.pi;
                offset = lin + Offset(0, lift);
              } else {
                final st = (f - _flightSplit) / (1 - _flightSplit);
                // One soft bounce with a decaying wobble.
                offset = Offset(
                  0,
                  -math.sin(st * math.pi) * 7.0 * (1 - st * 0.4),
                );
                rot = math.sin(st * math.pi * 3) * 0.06 * (1 - st);
              }
              return Transform.translate(
                offset: offset,
                child: Transform.rotate(
                  angle: rot,
                  child: _face(def, showValue),
                ),
              );
            }
            // Rotation settles with a decaying wobble; die hops once.
            final settle = 1.0 - Curves.easeOut.transform(f);
            final rot = math.sin(f * math.pi * 4) * 0.55 * settle;
            final hop = -math.sin(f * math.pi).abs() * 14 * (1.0 - f * 0.6);
            return Transform.translate(
              offset: Offset(0, _tumble.isAnimating ? hop : 0),
              child: Transform.rotate(
                angle: _tumble.isAnimating ? rot : 0,
                child: _face(def, showValue),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _face(DieDef def, int? value) {
    // v0.3.1 F1: a spent (assigned) die must read as spent — never keep the
    // gold MAX halo or the selection ring on a die whose taps do nothing.
    final glowSelected = widget.selected && !widget.assigned;
    final glowMaxed = widget.maxed && !widget.assigned;
    final borderColor = glowSelected
        ? EmberColors.ember
        : glowMaxed
        ? EmberColors.gold
        : Colors.transparent;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: widget.assigned ? 0.35 : 1.0,
      child: Container(
        width: 64,
        height: 80,
        decoration: glowSelected || glowMaxed
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.55),
                    blurRadius: 12,
                  ),
                ],
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Pixel die art at exactly 0.5x of its 128px source.
                  Image.asset(
                    'assets/images/ui/dice/die_d${def.size}.png',
                    filterQuality: FilterQuality.none,
                  ),
                  // Face content: rolled values as pips (numeral on the d4 —
                  // the square pip layouts spill off the triangle), and a dim
                  // engraved size numeral while unrolled, so a die never
                  // renders as a blank cream shape (owner report 2026-07-24:
                  // boon cards / pre-roll tray showed featureless squares).
                  CustomPaint(
                    painter: _FacePainter(
                      value: value,
                      sides: def.size,
                      maxed: glowMaxed,
                      selected: glowSelected,
                    ),
                  ),
                  if (glowSelected)
                    CustomPaint(painter: _DieRingPainter(EmberColors.ember))
                  else if (glowMaxed)
                    CustomPaint(painter: _DieRingPainter(EmberColors.gold))
                  // LFP-2c: modded dice (boon/forged/shop specials) carry a
                  // quiet accent ring all the time, so "this die is special"
                  // stops being knowledge you need the shop card for.
                  else if (def.mods.isNotEmpty && !widget.assigned)
                    CustomPaint(
                      painter: _DieRingPainter(
                        EmberColors.kindElite.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // Flexible + FittedBox: "d10 SPENT" must never wrap inside the
            // 64x80 chip, and at large system font sizes (1.3x) the label
            // scales down instead of overflowing the fixed-height chip.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.assigned && value != null
                      ? (widget.contribution != null
                            ? '+${widget.contribution} SPENT'
                            : 'd${def.size} SPENT')
                      : value != null && widget.maxed
                      ? 'd${def.size} MAX'
                      : 'd${def.size}',
                  maxLines: 1,
                  style: EmberText.micro.copyWith(
                    fontSize: 9,
                    color: glowMaxed ? EmberColors.gold : EmberColors.textDim,
                  ),
                ),
              ),
            ),
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
        ..color = color.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _DieRingPainter old) => old.color != color;
}

/// Die face content painted over the die art.
///
/// - Rolled: classic pips (dark, hot rim) per [_layouts] — except the d4,
///   which gets an engraved numeral like a real tetrahedral die: the square
///   pip arrangements (corner pips for 2–4) land outside the triangle
///   silhouette (owner screenshot 2026-07-24 — a pip floated off the die).
/// - Unrolled ([value] == null): a dim engraved size numeral, so pre-roll
///   tray dice and boon/shop/reward die cards read as dice, never as blank
///   cream shapes.
class _FacePainter extends CustomPainter {
  final int? value;
  final int sides;
  final bool maxed;
  final bool selected;
  _FacePainter({
    required this.value,
    required this.sides,
    this.maxed = false,
    this.selected = false,
  });

  static const _ink = Color(0xFF241407);

  /// The d4 triangle's visual centroid sits below its bounding-box center;
  /// content drawn at the box center floats toward the apex.
  Offset _faceCenter(Size size) {
    final c = size.center(Offset.zero);
    return sides == 4 ? c + Offset(0, size.height * 0.11) : c;
  }

  void _numeral(
    Canvas canvas,
    Size size,
    String text, {
    required Color color,
    Color? rim,
    required double fontSize,
    FontWeight weight = FontWeight.w800,
  }) {
    TextPainter tp(Color c) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          fontWeight: weight,
          color: c,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final main = tp(color);
    final at = _faceCenter(size) - Offset(main.width / 2, main.height / 2);
    // Same treatment as the pips: a warm rim highlight under the dark ink.
    if (rim != null) tp(rim).paint(canvas, at + const Offset(0, 1.0));
    main.paint(canvas, at);
  }

  // Unit positions (-1..1) per value; classic pip arrangements, extended
  // symmetrically for 10–12.
  static const Map<int, List<Offset>> _layouts = {
    1: [Offset.zero],
    2: [Offset(-1, -1), Offset(1, 1)],
    3: [Offset(-1, -1), Offset.zero, Offset(1, 1)],
    4: [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)],
    5: [
      Offset(-1, -1),
      Offset(1, -1),
      Offset.zero,
      Offset(-1, 1),
      Offset(1, 1),
    ],
    6: [
      Offset(-1, -1),
      Offset(1, -1),
      Offset(-1, 0),
      Offset(1, 0),
      Offset(-1, 1),
      Offset(1, 1),
    ],
    7: [
      Offset(-1, -1),
      Offset(1, -1),
      Offset(-1, 0),
      Offset.zero,
      Offset(1, 0),
      Offset(-1, 1),
      Offset(1, 1),
    ],
    8: [
      Offset(-1, -1),
      Offset(0, -1),
      Offset(1, -1),
      Offset(-1, 0),
      Offset(1, 0),
      Offset(-1, 1),
      Offset(0, 1),
      Offset(1, 1),
    ],
    9: [
      Offset(-1, -1),
      Offset(0, -1),
      Offset(1, -1),
      Offset(-1, 0),
      Offset.zero,
      Offset(1, 0),
      Offset(-1, 1),
      Offset(0, 1),
      Offset(1, 1),
    ],
    10: [
      Offset(-1, -1),
      Offset(0, -1),
      Offset(1, -1),
      Offset(-1, -0.33),
      Offset(1, -0.33),
      Offset(-1, 0.33),
      Offset(1, 0.33),
      Offset(-1, 1),
      Offset(0, 1),
      Offset(1, 1),
    ],
    11: [
      Offset(-1, -1),
      Offset(0, -1),
      Offset(1, -1),
      Offset(-1, -0.33),
      Offset(1, -0.33),
      Offset.zero,
      Offset(-1, 0.33),
      Offset(1, 0.33),
      Offset(-1, 1),
      Offset(0, 1),
      Offset(1, 1),
    ],
    12: [
      Offset(-1, -1),
      Offset(0, -1),
      Offset(1, -1),
      Offset(-1, -0.33),
      Offset(0, -0.33),
      Offset(1, -0.33),
      Offset(-1, 0.33),
      Offset(0, 0.33),
      Offset(1, 0.33),
      Offset(-1, 1),
      Offset(0, 1),
      Offset(1, 1),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final v = value;
    if (v == null) {
      // Engraved stamp — dim and low-contrast, clearly "not rolled yet",
      // never mistakable for the bright rimmed pips of a rolled value.
      _numeral(
        canvas,
        size,
        '$sides',
        color: _ink.withValues(alpha: 0.30),
        fontSize: size.shortestSide * 0.30,
        weight: FontWeight.w700,
      );
      return;
    }
    if (sides == 4) {
      _numeral(
        canvas,
        size,
        '$v',
        color: _ink,
        rim: (maxed ? EmberColors.gold : const Color(0xFFFFD98A)).withValues(
          alpha: maxed ? 0.9 : 0.5,
        ),
        fontSize: size.shortestSide * 0.34,
      );
      return;
    }
    final pips = _layouts[v.clamp(1, 12)]!;
    final c = _faceCenter(size);
    // Conservative face area so pips stay inside every die silhouette
    // (d4 triangle is the tightest); dense values pack slightly smaller.
    final extent = size.shortestSide * (pips.length > 9 ? 0.20 : 0.17);
    final radius = size.shortestSide * (pips.length > 6 ? 0.045 : 0.06);
    final pip = Paint()..color = const Color(0xFF241407);
    final rim = Paint()
      ..color = (maxed ? EmberColors.gold : const Color(0xFFFFD98A)).withValues(
        alpha: maxed ? 0.9 : 0.5,
      );
    for (final o in pips) {
      final p = c + Offset(o.dx * extent, o.dy * extent);
      canvas.drawCircle(p + const Offset(0, 0.8), radius + 0.8, rim);
      canvas.drawCircle(p, radius, pip);
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) =>
      old.value != value ||
      old.sides != sides ||
      old.maxed != maxed ||
      old.selected != selected;
}

// ---------------------------------------------------------------------------
/// Small titled card container (shop slots, event options, panels).
/// Charcoal slab, chamfered corners, faint warm light along the bottom edge.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.l),
    this.color,
  });
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
        ..color = color.withValues(alpha: 0.94),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = EmberColors.line,
    );
    // Warm hairline along the bottom (lit-from-below rule).
    canvas.drawLine(
      Offset(c + 2, size.height - 1),
      Offset(size.width - c - 2, size.height - 1),
      Paint()
        ..strokeWidth = 1.2
        ..color = EmberColors.ember.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _PanelPainter old) => old.color != color;
}

void showFlash(BuildContext context, String msg) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(msg, style: EmberText.body),
      backgroundColor: EmberColors.raised,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1400),
    ),
  );
}
