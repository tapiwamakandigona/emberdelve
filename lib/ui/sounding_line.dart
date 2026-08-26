import 'package:flutter/material.dart';

import 'theme.dart';

/// v0.77.0 The Sounding Line — the depth of the remembered delves, drawn.
///
/// A sounding line is the mariner's depth measure: knots on a rope, read
/// plainly. This one draws the Ledger's runHistory (cap 30) as bars, oldest
/// to newest, each height the floor that run reached relative to the deepest
/// in the window. Every bar is a REAL record (§Ethics honesty) — the line
/// states what happened and nothing else. No trend text, no goal overlay.
class SoundingBar {
  const SoundingBar({required this.frac, required this.result});

  /// 0..1 — floor reached over the deepest floor in the window.
  final double frac;

  /// 'won' | 'lost' | 'abandoned' (anything unknown reads as 'lost').
  final String result;
}

/// Pure mapping from runHistory records (NEWEST first, as MetaState keeps
/// them) to bars in drawing order (OLDEST first). Records missing a floor
/// count as floor 0 and draw as a stub on the baseline — old saves stay
/// honest rather than invented.
List<SoundingBar> soundingBars(List<Map<String, Object?>> history) {
  final ordered = history.reversed.toList();
  var deepest = 1;
  for (final r in ordered) {
    final f = r['floor'] as int? ?? 0;
    if (f > deepest) deepest = f;
  }
  return [
    for (final r in ordered)
      SoundingBar(
        frac: ((r['floor'] as int? ?? 0) / deepest).clamp(0.0, 1.0),
        result: switch (r['result']) {
          'won' => 'won',
          'abandoned' => 'abandoned',
          _ => 'lost',
        },
      ),
  ];
}

class SoundingLine extends StatelessWidget {
  const SoundingLine({super.key, required this.bars});

  final List<SoundingBar> bars;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: CustomPaint(painter: _SoundingLinePainter(bars)),
    );
  }
}

class _SoundingLinePainter extends CustomPainter {
  _SoundingLinePainter(this.bars);

  final List<SoundingBar> bars;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final baseline = Paint()
      ..color = EmberColors.line
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      baseline,
    );
    // Bars fill the width; width-aware sizing lives HERE, inside paint(size).
    final slot = size.width / bars.length;
    final barW = (slot * 0.55).clamp(2.0, 10.0);
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final color = switch (b.result) {
        'won' => EmberColors.ember,
        'abandoned' => EmberColors.textDisabled,
        _ => EmberColors.textDim,
      };
      // A floor-0 record still shows a 2px stub: the delve happened.
      final h = (b.frac * (size.height - 6)).clamp(2.0, size.height - 6);
      final x = slot * i + (slot - barW) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - 1 - h, barW, h),
          const Radius.circular(1.5),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_SoundingLinePainter old) => old.bars != bars;
}
