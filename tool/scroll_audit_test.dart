// tool/scroll_audit_test.dart — THE MEASURED PAGE: does any screen force a
// scroll it shouldn't? (Owner directive 2026-08-31: "I don't know if people
// like having to scroll at all in any part of the app.")
//
// Report-only probe (not in CI): mounts the main run-loop screens at two
// device sizes (common 360x800 and small 320x640, dpr 1.0, default text
// scale) and reports every scrollable's maxScrollExtent. Doctrine for
// reading the numbers:
//   - Lists that ARE the content (codex, settings, summary ledger) may
//     scroll: that is browsing, not cramping.
//   - Decision screens (boon, rest, combat, map viewport chrome) should
//     fit: a scroll to see your third boon card is a defect.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
}

GameController _seasoned() {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  return c;
}

void _drive(GameController c, String phase) {
  c.startRun(character: 'kindler', seed: 6, boons: true, difficulty: 'easy');
  var guard = 0;
  while (c.phase != phase && guard++ < 80) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
}

Future<void> _report(
  WidgetTester tester,
  String name,
  Widget screen,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: screen,
    ),
  );
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  final scrollables = find.byType(Scrollable).evaluate();
  if (scrollables.isEmpty) {
    // ignore: avoid_print
    print('SCROLL $name @${size.width.toInt()}x${size.height.toInt()}: '
        'no scrollable');
    return;
  }
  var i = 0;
  for (final el in scrollables) {
    final st = (el as StatefulElement).state as ScrollableState;
    final extent = st.position.hasContentDimensions
        ? st.position.maxScrollExtent
        : double.nan;
    // ignore: avoid_print
    print('SCROLL $name @${size.width.toInt()}x${size.height.toInt()} '
        '#$i: maxExtent=${extent.toStringAsFixed(0)} '
        'widget=${el.widget.runtimeType} '
        'ctx=${el.findAncestorWidgetOfExactType<ListView>() != null ? "ListView" : "other"}');
    i++;
  }
}

void main() {
  for (final size in const [Size(360, 800), Size(320, 640)]) {
    testWidgets('scroll audit @${size.width.toInt()}', (tester) async {
      await loadRealFonts();
      addTearDown(tester.view.reset);

      var c = _seasoned();
      _drive(c, 'boon');
      await _report(tester, 'boon', BoonScreen(c), size);

      c = _seasoned();
      _drive(c, 'map');
      await _report(tester, 'map', MapScreen(c), size);

      c = _seasoned();
      _drive(c, 'rest');
      await _report(tester, 'rest', RestScreen(c), size);

      c = _seasoned();
      await _report(tester, 'title', TitleScreen(c), size);
    });
  }
}
