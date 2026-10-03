// lib/ui/victory_beat.dart — experimental polish loop, critic round 2 issue
// C2-02: the final-boss kill had no victory beat. The board just went
// still for ~1.9 s and then cut to the summary.
//
// [VictoryBeat] is a stage-scoped overlay shown once the run-ending blow
// lands:
//   • a banner ("VICTORY!", ≥ 22 sp, ember glow) that scales in over
//     250 ms with ease-out-back;
//   • embers rising from the boss's spot (a cheap painter, no assets).
// Under reduced motion the banner only fades in (no scale) and there are
// no particles. Pinned by test/victory_beat_test.dart. Presentation only
// (nothing in lib/sim is touched).
//
// Critic round 4, C4-01: the banner used to sit at the stage's centre at
// 34 sp, so at 320x568 its "V" covered the delver's sword arm and the
// killing blow's "-5" printed across it. It is now placed by rect
// ([VictoryBeat.place]): centred in the free stage area above both actors'
// heads, stepping its font down from 34 to 22 sp until it fits clear of
// the delver's raised-weapon pose and the boss. Pinned by
// test/victory_moment_test.dart and test/victory_beat_test.dart.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

class VictoryBeat extends StatefulWidget {
  /// The banner's words. Short and plain so a young child can read them.
  static const String text = 'VICTORY!';

  /// Banner font size in logical pixels: the largest it is drawn at. C4-01
  /// steps it down from here until the banner fits a clear area.
  static const double fontSize = 34;

  /// The smallest banner font (critic acceptance: ≥ 22 sp).
  static const double minFontSize = 22;

  /// Font steps tried between [fontSize] and [minFontSize].
  static const double fontStep = 2;

  /// Banner scale-in (normal motion) / fade-in (reduced motion).
  static const Duration intro = Duration(milliseconds: 250);

  /// How long the embers keep rising (one pass; the screen leaves before).
  static const Duration embers = Duration(milliseconds: 1600);

  /// C4-01: how long the tray lane's call-outs take to fade once the banner
  /// lands (the stage's own readouts clear on its first frame).
  static const Duration clear = Duration(milliseconds: 150);

  /// The delver's raised-weapon pose at full strength: lift (dp) and
  /// backward tilt (radians) about the feet. The stage eases into it with
  /// ease-out-back; [heroEnvelope] covers it.
  static const double poseLift = 10;
  static const double poseTilt = 0.08;

  /// Room around the word inside the banner's box.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 4,
  );

  /// The banner keeps this far inside the stage's edges (critic: stage top
  /// + 8 dp) and [gap] off either body's box (critic: bbox − 4 dp).
  static const double inset = 8;
  static const double gap = 4;

  /// Where the embers start, in stage coordinates (the boss's body). The
  /// banner also keeps off it while there is room.
  final Rect source;

  /// The delver's box through the whole victory pose, in stage coordinates
  /// ([heroEnvelope]). The banner never touches it.
  final Rect hero;

  /// Reduced motion: fade only, no scale, no particles.
  final bool reduced;

  const VictoryBeat({
    super.key,
    required this.source,
    required this.hero,
    required this.reduced,
  });

  /// The banner's text style at [size] (shadows don't change layout, so
  /// [measure] reads the same box the banner lays out).
  static TextStyle styleFor(double size) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w900,
    letterSpacing: 2,
    color: const Color(0xFFFFE3A3),
    shadows: [
      const Shadow(color: EmberColors.ember, blurRadius: 18),
      Shadow(color: EmberColors.ember.withValues(alpha: 0.8), blurRadius: 6),
      const Shadow(
        color: Color(0xCC000000),
        offset: Offset(0, 2),
        blurRadius: 2,
      ),
    ],
  );

  /// The banner's box at [size] — the word plus [padding] — laid out as the
  /// banner lays it out ([base] is the ambient text style it inherits).
  static Size measure(double size, {TextStyle? base}) {
    final style = (base ?? const TextStyle()).merge(styleFor(size));
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    final out = Size(
      (tp.width + padding.horizontal).ceilToDouble() + 1,
      (tp.height + padding.vertical).ceilToDouble() + 1,
    );
    tp.dispose();
    return out;
  }

  /// How far forward of its mark (in delver heights) the keep-out reaches:
  /// the delver is still stepping back from the killing lunge when the
  /// banner first shows. Measured at 320x568 under Reduce Motion, +600 ms
  /// (the banner's first visible frame): 0.24 heroH forward of the pose's
  /// box; the banner's own 8 dp padding covers the rest.
  static const double stepBack = 0.15;

  /// The delver's box from the banner's first visible frame on, in stage
  /// coordinates, for a delver [heroH] tall standing on [floorY] at the
  /// stage's left end. The figure is 0.8 heroH wide and its weapon draws in
  /// a heroH square at the same origin; the pose lifts it [poseLift] and
  /// tilts it back [poseTilt] about the figure's feet (0.4 heroH in), so the
  /// weapon box's far corner, 0.6 heroH out, rises by 0.6 heroH sin(tilt);
  /// ease-out-back overshoots by ~10 %. Measured on the shipped delver at
  /// 320x568, 360x800 and 412x915: x −0.084..1.0 heroH, rising up to 14.1 /
  /// 15.6 dp. Plus [stepBack].
  ///
  /// 0.186.0 review, all 22 playable delvers at the same three sizes, on the
  /// frames test/victory_moment_test.dart checks (+600 ms, +1200 ms and every
  /// frame after the intro): the box spans x −0.104..1.284 heroH and rises
  /// at most 0.5 dp past the top. The farthest reach (gambler, ascetic,
  /// cutler, glover) is 0.114 heroH past the right edge, 8.2 dp at 72 dp and
  /// 11.9 dp at 104 dp, inside [gap] plus the banner's 8 dp padding; the
  /// kindler's is 0.07 heroH.
  static Rect heroEnvelope({required double floorY, required double heroH}) {
    const overshoot = 1.1; // Curves.easeOutBack peaks at ~1.0999
    final rise =
        poseLift * overshoot + 0.6 * heroH * math.sin(poseTilt * overshoot);
    return Rect.fromLTRB(
      -0.1 * heroH,
      floorY - heroH - rise,
      (1.02 + stepBack) * heroH,
      floorY,
    );
  }

  /// C4-01: where the banner rests in a [stage] of this size and how big it
  /// is drawn. Areas, in order: the free band above both actors' heads (the
  /// critic's direction); above the delver's head, short of the boss; then
  /// beside the delver, over the boss's spot — the boss is dying there and
  /// its body dissolves under the banner (the rolled 320x568 stage is 86 dp
  /// with both actors standing in all of it). In the first area where the
  /// banner fits at [minFontSize] it takes the largest step of [fontSize]
  /// down to [minFontSize] that fits, centred in that area. If none fits,
  /// it is drawn at [minFontSize] in the band beside the delver without the
  /// vertical inset when that band is wide enough (a stage shorter than the
  /// banner plus both insets), else centred in the stage (narrower than any
  /// supported phone). [measure] gives the banner's box at a size.
  static BannerPlacement place({
    required Size stage,
    required Rect hero,
    required Rect foe,
    required Size Function(double size) measure,
  }) {
    final areas = <(String, Rect)>[
      (
        'above',
        Rect.fromLTRB(
          inset,
          inset,
          stage.width - inset,
          math.min(hero.top, foe.top) - gap,
        ),
      ),
      (
        'above-hero',
        Rect.fromLTRB(inset, inset, foe.left - gap, hero.top - gap),
      ),
      (
        'beside',
        Rect.fromLTRB(
          hero.right + gap,
          inset,
          stage.width - inset,
          stage.height - inset,
        ),
      ),
    ];
    for (final (name, area) in areas) {
      if (area.width <= 0 || area.height <= 0) continue;
      for (var size = fontSize; size >= minFontSize; size -= fontStep) {
        final box = measure(size);
        if (box.width <= area.width && box.height <= area.height) {
          return BannerPlacement(
            Rect.fromCenter(
              center: area.center,
              width: box.width,
              height: box.height,
            ),
            size,
            name,
          );
        }
      }
    }
    final box = measure(minFontSize);
    // A stage too short for the inset still has the band beside the
    // delver: the gambler's rolled 320x568 stage is 40 dp, not 86, and
    // centring there put the banner on the gambler (0.186.0 review).
    // When the band is wide enough the banner is centred in it at
    // [minFontSize], as tall as the stage allows.
    final beside = Rect.fromLTRB(
      hero.right + gap,
      0,
      stage.width - inset,
      stage.height,
    );
    if (box.width <= beside.width) {
      return BannerPlacement(
        Rect.fromCenter(
          center: beside.center,
          width: box.width,
          height: math.min(box.height, stage.height),
        ),
        minFontSize,
        'beside',
      );
    }
    return BannerPlacement(
      Rect.fromCenter(
        center: Offset(stage.width / 2, stage.height / 2),
        width: math.min(box.width, stage.width),
        height: math.min(box.height, stage.height),
      ),
      minFontSize,
      'centre',
    );
  }

  @override
  State<VictoryBeat> createState() => _VictoryBeatState();
}

/// Where the victory banner rests (stage coordinates, padding included),
/// the font size it is drawn at, and which area of [VictoryBeat.place] it
/// took ('above', 'above-hero', 'beside' or 'centre').
class BannerPlacement {
  final Rect rect;
  final double fontSize;
  final String area;
  const BannerPlacement(this.rect, this.fontSize, this.area);

  @override
  String toString() => 'BannerPlacement($area, $fontSize sp, $rect)';
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
    final base = DefaultTextStyle.of(context).style;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final at = VictoryBeat.place(
            stage: box.biggest,
            hero: widget.hero,
            foe: widget.source,
            measure: (size) => VictoryBeat.measure(size, base: base),
          );
          // FittedBox is only a safety net: the box is measured to fit.
          final banner = FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: VictoryBeat.padding,
              child: Text(
                VictoryBeat.text,
                key: const ValueKey('victory-banner'),
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: VictoryBeat.styleFor(at.fontSize),
              ),
            ),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              if (!widget.reduced)
                CustomPaint(
                  key: const ValueKey('victory-embers'),
                  painter: _EmberRisePainter(_embers, widget.source),
                ),
              Positioned.fromRect(
                key: ValueKey('victory-banner-${at.area}'),
                rect: at.rect,
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
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * s,
                        child: child,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
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
