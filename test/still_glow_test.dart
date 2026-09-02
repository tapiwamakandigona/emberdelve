// test/still_glow_test.dart — v0.180.0 The Still Glow.
//
// The map's reachable-node halo breathed on a repeating controller that
// never asked Reduce Motion — the one repeating clock in the UI that did
// not (drift, logo, sprites and weapon sway all stop). Under reduce it now
// holds at mid glow: nodes still read as lit, nothing repaints per frame.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/news.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

GameController stampedOnMap() {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..lastSeenNewsVersion = currentAppVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  c.startRun(character: 'kindler', seed: 6, boons: false, difficulty: 'easy');
  return c;
}

/// Paints of the medallion painter over 60 idle frames, entrance settled.
Future<int> medallionPaints(WidgetTester tester) async {
  for (var i = 0; i < 180; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  var n = 0;
  debugOnProfilePaint = (RenderObject ro) {
    if (ro is RenderCustomPaint &&
        ro.painter.runtimeType.toString() == '_MedallionPainter') {
      n++;
    }
  };
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  debugOnProfilePaint = null;
  return n;
}

void main() {
  testWidgets('reduce motion: the halo holds and stops repainting', (
    tester,
  ) async {
    Motion.instance.update(setting: 'on');
    addTearDown(() => Motion.instance.update(setting: 'system'));
    final c = stampedOnMap();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: MapScreen(c)),
    );
    expect(await medallionPaints(tester), 0);
  });

  testWidgets('motion on: the halo still breathes', (tester) async {
    Motion.instance.update(setting: 'off');
    addTearDown(() => Motion.instance.update(setting: 'system'));
    final c = stampedOnMap();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: MapScreen(c)),
    );
    expect(await medallionPaints(tester), greaterThan(0));
  });

  testWidgets('flipping the setting mid-screen takes effect', (tester) async {
    Motion.instance.update(setting: 'off');
    addTearDown(() => Motion.instance.update(setting: 'system'));
    final c = stampedOnMap();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: MapScreen(c)),
    );
    expect(await medallionPaints(tester), greaterThan(0));
    Motion.instance.update(setting: 'on');
    await tester.pump();
    expect(await medallionPaints(tester), 0);
    Motion.instance.update(setting: 'off');
    await tester.pump();
    expect(await medallionPaints(tester), greaterThan(0));
  });
}
