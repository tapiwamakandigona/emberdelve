// tool/repaint_roots_probe_test.dart — the method that found The Quiet Shell
// (v0.180.0), kept as a tool. For each phase entrance it prints a paint
// TIMELINE (paints per 10 frames after the phase change) and, for the worst
// frame after the midpoint mount, the repaint ROOTS: painted render objects
// whose parent did not paint, with size and ancestor chain. A 360×800 root
// means the whole shell repainted. Reports, never asserts.
//
//   flutter test tool/repaint_roots_probe_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

final Set<RenderObject> _frame = {};
int _paints = 0;

void _hook(RenderObject ro) {
  _frame.add(ro);
  _paints++;
}

String _desc(RenderObject r) {
  var t = r.runtimeType.toString();
  if (r is RenderCustomPaint) t += '(${r.painter.runtimeType})';
  if (r is RenderParagraph) {
    final s = r.text.toPlainText();
    t += '("${s.substring(0, s.length.clamp(0, 24))}")';
  }
  if (r is RenderBox && r.hasSize) t += ' ${r.size}';
  return t;
}

/// Paragraph/painter identities in the current frame (what actually drew).
List<String> _census() {
  final m = <String, int>{};
  for (final ro in _frame) {
    String? k;
    if (ro is RenderParagraph) {
      final t = ro.text.toPlainText();
      k = 'P:${t.substring(0, t.length.clamp(0, 18))}';
    } else if (ro is RenderCustomPaint) {
      k = 'CP:${ro.painter.runtimeType}';
    } else if (ro is RenderImage) {
      k = 'IMAGE';
    }
    if (k != null) m[k] = (m[k] ?? 0) + 1;
  }
  final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return e.take(24).map((x) => '${x.value}×${x.key}').toList();
}

List<String> _roots() {
  final roots = _frame
      .where((ro) => ro.parent == null || !_frame.contains(ro.parent))
      .toList();
  return roots.map((r) {
    final chain = <String>[];
    RenderObject? a = r.parent;
    var d = 0;
    while (a != null && d < 5) {
      if (a is RenderRepaintBoundary) chain.add('RB');
      if (a is RenderCustomPaint) chain.add('CP:${a.painter.runtimeType}');
      a = a.parent;
      d++;
    }
    return '${_desc(r)} up=${chain.join('>')}';
  }).toList();
}

/// Pump [frames] frames after an entrance, printing the timeline and the
/// roots of the heaviest frame past [skip] (the midpoint mount is expected).
Future<void> timeline(
  WidgetTester tester,
  String label, {
  int frames = 120,
  int skip = 30,
}) async {
  final buckets = <int>[];
  var worst = 0;
  var worstFrame = -1;
  List<String> worstRoots = [];
  // The heaviest frame is usually the midpoint mount (expected); the second
  // heaviest tells whether the storm continues.
  var second = 0;
  var secondFrame = -1;
  List<String> secondRoots = [];
  debugOnProfilePaint = _hook;
  try {
    var bucket = 0;
    for (var f = 0; f < frames; f++) {
      _frame.clear();
      _paints = 0;
      await tester.pump(const Duration(milliseconds: 16));
      bucket += _paints;
      if (f >= skip && _paints > worst) {
        second = worst;
        secondFrame = worstFrame;
        secondRoots = worstRoots;
        worst = _paints;
        worstFrame = f;
        worstRoots = [..._roots(), 'CENSUS ${_census().join(' | ')}'];
      } else if (f >= skip && _paints > second) {
        second = _paints;
        secondFrame = f;
        secondRoots = _roots();
      }
      if (f % 10 == 9) {
        buckets.add(bucket);
        bucket = 0;
      }
    }
  } finally {
    debugOnProfilePaint = null;
  }
  // ignore: avoid_print
  print(
    'TIMELINE $label per10=${buckets.join(',')} total=${buckets.fold(0, (a, b) => a + b)}',
  );
  // ignore: avoid_print
  print('WORST $label frame=$worstFrame paints=$worst');
  for (final r in worstRoots) {
    // ignore: avoid_print
    print('  ROOT $r');
  }
  // ignore: avoid_print
  print('SECOND $label frame=$secondFrame paints=$second');
  for (final r in secondRoots) {
    // ignore: avoid_print
    print('  ROOT $r');
  }
}

Future<void> settle(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('entrance timelines: map, combat, reward, rest', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = GameController();
    c.markTutorialSeen();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await settle(tester, 30);
    await timeline(tester, 'title_idle', frames: 30, skip: 0);

    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    await timeline(tester, 'title->${c.phase}');
    final seen0 = <String>{};
    seen0.add('title->${c.phase}');
    // Walk the run with the bot; time every DISTINCT transition once
    // (boon->map, map->player_turn, player_turn->reward, reward->map, ...).
    final seen = <String>{};
    var guard = 0;
    while (guard++ < 600 && seen.length < 10) {
      if (c.phase == 'run_won' || c.phase == 'run_lost') break;
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      final before = c.phase;
      c.apply(cmd);
      final edge = '$before->${c.phase}';
      if (c.phase != before && !seen.contains(edge)) {
        seen.add(edge);
        await timeline(tester, edge, skip: 0);
      } else if (c.phase != before) {
        await settle(tester, 60);
      } else {
        await settle(tester, 3);
      }
    }
    // ignore: avoid_print
    print('PHASES probed: $seen');
  });
}
