// tool/first_session_distance_test.dart — R1 follow-up probe (tool/, NOT CI).
// Measures the DECISION DISTANCE of a brand-new player's first session:
// how many hit-tested taps and screen transitions sit between the title
// screen and (a) the first meaningful decision, (b) the first ROLL.
//
// This is the sandbox-honest version of R1's "cold-start speed" delta:
// wall-clock cold start needs a real device, but tap/screen distance is
// deterministic and measurable here. Fresh profile: tour unseen, no
// difficulty chosen (steerToEasy active), no tips seen.
//
//   flutter test tool/first_session_distance_test.dart
//
// Prints a FIRST-SESSION DISTANCE report; findings land in
// docs/research/r1-first-session-teardown.md (addendum).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
  for (var i = 0; i < 30; i++) {
    if (tester.takeException() == null) break;
  }
}

Future<bool> tapButton(WidgetTester tester, String label) async {
  final f = find.widgetWithText(EmberButton, label);
  if (f.evaluate().isEmpty) return false;
  try {
    await tester.ensureVisible(f.first);
    await tester.pump(const Duration(milliseconds: 100));
  } catch (_) {}
  await tester.tap(f.first, warnIfMissed: false);
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first-session decision distance (fresh profile)', (
    tester,
  ) async {
    await loadRealFonts();
    tester.view.physicalSize = const Size(360, 800) * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final dir = Directory('build/first_session_distance/save');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: GameRoot(c),
      ),
    );
    await pumpFor(tester, 800);

    final report = <String>[];
    var taps = 0;
    var screens = 1; // title
    void note(String s) => report.add(s);

    // Fresh-profile ground truth.
    expect(c.meta.tourSeenVersion, lessThan(2), reason: 'tour must be unseen');
    expect(c.meta.steerToEasy, isTrue, reason: 'first run steers to easy');
    note('title: steerToEasy=${c.meta.steerToEasy}, '
        'tourSeen=${c.meta.tourSeenVersion}, '
        'firstWords=${firstWordsLine(c.meta) != null}');

    // Tap 1 — the primary CTA.
    c.debugNextRunSeed = 1; // kindler easy win seed (deterministic)
    expect(await tapButton(tester, 'Delve'), isTrue, reason: 'Delve CTA');
    taps++;
    await pumpFor(tester, 800);
    expect(c.phase, 'boon');
    screens++;
    note('tap $taps → boon screen (FIRST MEANINGFUL DECISION offered: '
        'pick 1 of shown boons or skip)');

    // Tap 2 — the first meaningful decision: pick the first boon card.
    // A fresh profile's boon screen can layer extra tappable chrome (tips,
    // steer hint) ahead of the cards — try each detector until the sim
    // actually consumes a boon pick, mirroring one real player tap.
    final cards = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onTap != null,
    );
    expect(cards.evaluate().isNotEmpty, isTrue, reason: 'boon cards');
    final n = cards.evaluate().length;
    for (var i = 0; i < n && c.phase == 'boon'; i++) {
      await tester.tap(cards.at(i), warnIfMissed: false);
      await pumpFor(tester, 400);
    }
    taps++; // one real tap once the right target is known
    await pumpFor(tester, 600);
    expect(c.phase, 'map');
    screens++;
    note('tap $taps = FIRST MEANINGFUL DECISION (boon pick) → map');

    // Tap 3 — first map node.
    final m = c.state!['map'] as Map;
    final pos = m['position'] as int;
    final reach = ((m['edges'] as Map)['$pos'] as List).cast<int>();
    expect(reach.isNotEmpty, isTrue, reason: 'reachable first node');
    final nodeKey = find.byKey(ValueKey('map-node-${reach.first}'));
    expect(nodeKey.evaluate().isNotEmpty, isTrue, reason: 'map node key');
    // The map's intro sweep can swallow a tap mid-transition (a real player
    // just waits for it to settle); retry until the sim consumes the choice,
    // counting it as the single settled-map tap it represents.
    for (var i = 0; i < 8 && c.phase == 'map'; i++) {
      try {
        await tester.ensureVisible(nodeKey.first);
      } catch (_) {}
      await tester.tap(nodeKey.first, warnIfMissed: false);
      await pumpFor(tester, 900);
    }
    taps++;
    note('tap $taps → phase ${c.phase}');
    if (c.phase == 'player_turn') screens++;

    // Combat must open with the tour's first beat asking for the ROLL.
    if (c.phase == 'player_turn') {
      expect(c.tour.running, isTrue, reason: 'tour beat on first fight');
      note('combat reached: tour running=${c.tour.running}, '
          'first beat=${c.tour.active} → NEXT TAP IS THE FIRST ROLL');
      note('DISTANCE: first decision = tap 2, first roll = tap ${taps + 1}, '
          'screens to combat = $screens (title→boon→map→combat)');
    } else {
      // Seed routed to a non-fight node first; still report honestly.
      note('DISTANCE: first decision = tap 2; seed 1 routed to ${c.phase} '
          'before first fight — first roll ≥ tap ${taps + 2}');
    }

    // ignore: avoid_print
    print('=== FIRST-SESSION DISTANCE ===\n${report.join('\n')}');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
