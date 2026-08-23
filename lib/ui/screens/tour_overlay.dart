// lib/ui/screens/tour_overlay.dart — part of screens.dart (see library header there).
//
// v0.8.0 "The Guided Delve": spotlight coach-marks anchored to the REAL UI.
// The scrim dims everything except a cutout around the beat's anchor widget;
// a short label points into the hole. Action beats let touches through to
// the game (the player advances by DOING); info beats advance on tap.
// Copy budget: ≤ 12 words per body (design doc §3.2). Always skippable.
part of '../screens.dart';

/// Anchor registry: the combat widgets that beats point at register their
/// GlobalKeys here by beat id. Real render boxes, no hardcoded coordinates —
/// safe across the phone/tablet clamps.
class TourAnchors {
  static final Map<String, GlobalKey> _keys = {};

  static GlobalKey of(String beat) => _keys.putIfAbsent(beat, GlobalKey.new);

  /// The anchor's rect in the overlay's coordinate space, or null while the
  /// target hasn't laid out yet (the overlay just paints a plain scrim then).
  static Rect? rectOf(String beat, BuildContext overlayContext) {
    final key = _keys[beat];
    final target = key?.currentContext?.findRenderObject();
    final host = overlayContext.findRenderObject();
    if (target is! RenderBox || host is! RenderBox) return null;
    if (!target.attached || !host.attached || !target.hasSize) return null;
    final topLeft = target.localToGlobal(Offset.zero, ancestor: host);
    return topLeft & target.size;
  }
}

class _TourOverlay extends StatelessWidget {
  final String beat;
  final bool isInfo;
  final int step;
  final int total;
  final VoidCallback onAdvanceInfo;
  final VoidCallback onSkip;
  const _TourOverlay({
    required this.beat,
    required this.isInfo,
    required this.step,
    required this.total,
    required this.onAdvanceInfo,
    required this.onSkip,
  });

  // (icon, title, body ≤ 12 words) per beat — tested in tour_test.dart.
  static const Map<String, (IconData, String, String)> copy = {
    TourBeats.roll: (Icons.casino, 'YOUR DICE', 'Tap ROLL to throw them.'),
    TourBeats.pick: (
      Icons.touch_app,
      'PICK ONE UP',
      'Tap a die to select it.',
    ),
    TourBeats.spend: (
      Icons.sports_martial_arts,
      'SPEND IT',
      'ATTACK deals its value. BLOCK absorbs hits.',
    ),
    TourBeats.intent: (
      Icons.visibility,
      'ITS NEXT MOVE',
      'The badge always resolves exactly as shown.',
    ),
    TourBeats.reroll: (
      Icons.replay,
      'ONE RISKY REROLL',
      'Once per turn — rescue a bad face.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = copy[beat]!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final hole = TourAnchors.rectOf(beat, context)?.inflate(6);
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final scrim = CustomPaint(
          size: size,
          painter: _SpotlightPainter(hole: hole),
        );
        // Card above the hole when the hole sits low, below otherwise.
        final below = hole == null || hole.center.dy < size.height * 0.45;
        final card = _tourCard(icon, title, body, context);
        return Stack(
          children: [
            // Action beats: the scrim is visual only — the game stays live
            // so the player performs the real move. Info beats: any tap
            // advances (the whole scrim is the continue button).
            if (isInfo)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAdvanceInfo,
                child: scrim,
              )
            else
              IgnorePointer(child: scrim),
            Positioned(
              left: Space.l,
              right: Space.l,
              top: below ? (hole == null ? null : hole.bottom + Space.l) : null,
              bottom: below
                  ? (hole == null ? size.height * 0.28 : null)
                  : size.height - hole.top + Space.l,
              child: IgnorePointer(child: card),
            ),
            // SKIP + progress: small, top-right, always tappable (§Ethics).
            Positioned(
              top: Space.l,
              right: Space.l,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${step + 1} of $total',
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                  const SizedBox(width: Space.m),
                  Semantics(
                    label: 'Skip tour',
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onSkip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.m,
                          vertical: Space.xs,
                        ),
                        decoration: BoxDecoration(
                          color: EmberColors.raised,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: EmberColors.line),
                        ),
                        child: Text(
                          'SKIP',
                          style: EmberText.micro.copyWith(
                            color: EmberColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isInfo && hole != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: Space.l,
                child: IgnorePointer(
                  child: Text(
                    'Tap anywhere to continue',
                    textAlign: TextAlign.center,
                    style: EmberText.micro.copyWith(
                      color: EmberColors.textDim,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _tourCard(
    IconData icon,
    String title,
    String body,
    BuildContext context,
  ) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(Space.l),
        decoration: BoxDecoration(
          color: EmberColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EmberColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, color: EmberColors.ember, size: 26),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: EmberText.label.copyWith(
                      color: EmberColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    body,
                    style: EmberText.body.copyWith(
                      color: EmberColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 80% ember-dark scrim with a rounded-rect cutout over the anchor. A 2px
/// ember ring hugs the hole so the eye lands on the live widget beneath.
class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  const _SpotlightPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      final r = RRect.fromRectAndRadius(hole!, const Radius.circular(12));
      scrim
        ..addRRect(r)
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(
        scrim,
        Paint()..color = EmberColors.bg.withValues(alpha: 0.80),
      );
      canvas.drawRRect(
        r.inflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = EmberColors.ember,
      );
    } else {
      canvas.drawPath(
        scrim,
        Paint()..color = EmberColors.bg.withValues(alpha: 0.80),
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}
