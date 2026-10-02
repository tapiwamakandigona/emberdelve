// test/boss_death_drain_test.dart — experimental backlog C4-02, the reduced
// motion half: "no white; the sprite desaturates and fades over 300 ms".
//
// PR #112 removed the white block, but its independent review found that a
// boss slain under Reduce Motion keeps full colour for ~400 ms and then turns
// grey in a single frame. This test lands the same run-ending blow as
// test/boss_death_ember_test.dart (FIXTURE: the seed-1 node and foe are
// re-dressed as the boss and its HP set so the chosen die kills — the sim's
// rules are untouched), steps the production choreography in 40 ms frames
// for 1.6 s and reads, every frame, what the widgets above the foe's sprite
// do to it: how much colour survives the colour-matrix filters (1 = full,
// 0 = grey) and the product of the fades. While the body is visible:
//   • it ends grey;
//   • no single 40 ms frame removes more than 35 % of the colour the death
//     removes in total (the old one-frame grey cut removed all of it);
//   • at least 5 visible frames (>= 200 ms) sit part-way through the drain.

import 'package:emberdelve/sim/assignment.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kill_readout_test.dart' as k;

/// What reaches the screen of the foe's body this frame, read from the
/// widgets that wrap its sprite: `colour` is how much of a pure-red pixel's
/// chroma survives every colour-matrix filter above the sprite (1 = full
/// colour, 0 = grey), `opacity` the product of every fade above it.
({double colour, double opacity}) bodyState(WidgetTester tester, Finder foe) {
  final element = tester.element(foe);
  var px = <double>[1, 0, 0];
  var opacity = 1.0;
  element.visitAncestorElements((e) {
    final w = e.widget;
    if (w is ColorFiltered) {
      final text = w.colorFilter.toString();
      if (text.startsWith('ColorFilter.matrix(')) {
        final m = RegExp(r'-?[0-9.]+(?:e-?[0-9]+)?')
            .allMatches(text.substring('ColorFilter.matrix('.length))
            .map((x) => double.parse(x.group(0)!))
            .toList();
        px = [
          for (var r = 0; r < 3; r++)
            m[r * 5] * px[0] + m[r * 5 + 1] * px[1] + m[r * 5 + 2] * px[2],
        ];
      }
    }
    if (w is FadeTransition) opacity *= w.opacity.value;
    return true;
  });
  final hi = px.reduce((a, b) => a > b ? a : b);
  final lo = px.reduce((a, b) => a < b ? a : b);
  return (colour: hi - lo, opacity: opacity);
}

/// Body state just before the blow (set by [bossKill]).
({double colour, double opacity}) before = (colour: 1, opacity: 1);

/// Per-frame body state of the boss for a run-ending kill.
Future<List<({double colour, double opacity})>> bossKill(
  WidgetTester tester, {
  required bool reduced,
}) async {
  const size = Size(360, 800);
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  addTearDown(() => Motion.instance.update(setting: 'off'));
  Motion.instance.update(setting: reduced ? 'on' : 'off');
  final c = k.makeController();
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: GameRoot(c),
      ),
    ),
  );
  await tester.runAsync(() async {
    await warmSpriteSheets();
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final context = tester.element(find.byType(MaterialApp));
    for (final a in manifest.listAssets().where((a) => a.endsWith('.png'))) {
      await precacheImage(AssetImage(a), context);
    }
  });
  await k.toFight(tester, c);
  final map = c.sim!.map!;
  ((map['nodes'] as Map)['${map['position']}'] as Map)['kind'] = 'boss';
  c.sim!.enemy!['id'] = 'ember_tyrant';
  c.sim!.enemy!['name'] = 'Ember Tyrant';
  c.sim!.enemy!['boss'] = true;
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
  await tester.pump();
  await tester.tap(k.button('Roll'));
  for (var t = 0; t < 2000; t += 40) {
    await tester.pump(const Duration(milliseconds: 40));
  }
  final rolled = (c.sim!.player['rolled'] as List).length;
  var die = 0, value = 0;
  for (var d = 1; d <= rolled; d++) {
    final r = resolveAssignment(
      player: c.sim!.player,
      enemy: c.sim!.enemy!,
      run: c.sim!.run,
      die: d,
      action: 'attack',
    );
    if (r.allowed && r.value >= 2) {
      die = d;
      value = r.value;
      break;
    }
  }
  expect(die, greaterThan(0), reason: 'fixture needs an attack die');
  c.sim!.enemy!['hp'] = value - 1;
  c.sim!.enemy!['block'] = 0;
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
  await tester.pump();
  // The foe's own rect (its sprite box, grown 15 % for knockback travel).
  final foe = find.byWidgetPredicate(
    (w) =>
        w is SpriteView &&
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('enemy-'),
  );
  expect(foe, findsOneWidget);
  before = bodyState(tester, foe);
  await tester.tap(
    find.byWidgetPredicate((w) => w is DieChip && w.value != null).at(die - 1),
  );
  await tester.pump();
  await tester.tap(k.button('Attack'));
  final shares = <({double colour, double opacity})>[];
  for (var ms = 40; ms <= 1600; ms += 40) {
    await tester.pump(const Duration(milliseconds: 40));
    shares.add(
      foe.evaluate().isEmpty
          ? (colour: 0.0, opacity: 0.0) // the foe has left the stage
          : bodyState(tester, foe),
    );
  }
  expect(c.phase, isNot('player_turn'), reason: 'the blow must end the fight');
  await tester.pumpWidget(const SizedBox.shrink());
  for (var t = 0; t < 3000; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return shares;
}

String fmt(List<({double colour, double opacity})> s) => s
    .map((v) => '${v.colour.toStringAsFixed(2)}/${v.opacity.toStringAsFixed(2)}')
    .join(' ');

void main() {
  setUpAll(k.loadRealFonts);

  testWidgets('reduced-motion boss death drains its colour over ~300 ms', (
    tester,
  ) async {
    final s = await bossKill(tester, reduced: true);
    final curve =
        'colour/opacity per 40 ms frame: '
        'pre ${fmt([before])} | ${fmt(s)}';
    final c0 = before.colour;
    // Frames where the body is still visible: the drain must read on screen.
    final seen = [
      for (final f in s)
        if (f.opacity > 0.05) f.colour,
    ];
    final floor = seen.reduce((a, b) => a < b ? a : b);
    final drop = c0 - floor;
    expect(floor, lessThan(0.1), reason: 'the body ends grey: $curve');
    var worst = 0.0;
    for (var i = 0; i < seen.length; i++) {
      final step = (i == 0 ? c0 : seen[i - 1]) - seen[i];
      if (step > worst) worst = step;
    }
    expect(
      worst,
      lessThanOrEqualTo(drop * 0.35),
      reason: 'no one-frame grey cut: $curve',
    );
    final between = seen
        .where((v) => v < c0 - drop * 0.05 && v > floor + drop * 0.05)
        .length;
    expect(
      between,
      greaterThanOrEqualTo(5),
      reason: 'the drain spans >= 200 ms of visible frames: $curve',
    );
  });
}
