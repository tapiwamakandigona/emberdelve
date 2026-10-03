// test/boss_death_ember_test.dart — experimental backlog C4-02: the boss
// death must not hold a flat pure-white block.
//
// Critic round 4 measured 19–22k px at luma > 235 inside the boss rect on
// every 40 ms frame from t0440 to t0840 of the run-ending kill (normal AND
// reduced motion), then a hard cut to particles. The fix caps the white
// contact beat, turns the body ember-hot, and crumbles from the tinted
// sprite; reduced motion gets no white at all.
//
// This test lands a lethal blow on a final boss through the production
// controls (FIXTURE: the seed-1 node and foe are re-dressed as the boss and
// its HP set so the chosen die kills — the sim's rules are untouched),
// renders every 40 ms frame for 1.6 s with the shipped fonts and sprite
// sheets, and counts bright pixels inside the foe's own rect:
//   • normal: at most 3 frames whose rect is > 12 % luma > 235 (≈ 3 × 40 ms);
//   • reduced: no frame whose rect is > 2.5 % luma > 235.

import 'package:emberdelve/sim/assignment.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kill_readout_test.dart' as k;

/// Share of pixels at luma > 235 inside [rect] (logical px) of [key]'s
/// boundary, rendered at 2x.
Future<double> brightShare(
  WidgetTester tester,
  GlobalKey key,
  Rect rect,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final raw = Uint8List.sublistView((await image.toByteData())!);
    final w = image.width, h = image.height;
    final x0 = (rect.left * 2).floor().clamp(0, w);
    final x1 = (rect.right * 2).ceil().clamp(0, w);
    final y0 = (rect.top * 2).floor().clamp(0, h);
    final y1 = (rect.bottom * 2).ceil().clamp(0, h);
    var bright = 0, total = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = (y * w + x) * 4;
        final l = 0.299 * raw[i] + 0.587 * raw[i + 1] + 0.114 * raw[i + 2];
        if (l > 235) bright++;
        total++;
      }
    }
    image.dispose();
    return total == 0 ? 0.0 : bright / total;
  }))!;
}

/// Per-frame bright shares of the boss rect for a run-ending kill.
Future<List<double>> bossKill(
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
  final r0 = tester.getRect(foe);
  final rect = Rect.fromCenter(
    center: r0.center,
    width: r0.width * 1.15,
    height: r0.height * 1.15,
  );
  final pre = await brightShare(tester, key, rect);
  expect(pre, lessThan(0.025), reason: 'the live boss is not white');
  await tester.tap(
    find.byWidgetPredicate((w) => w is DieChip && w.value != null).at(die - 1),
  );
  await tester.pump();
  await tester.tap(k.button('Attack'));
  final shares = <double>[];
  for (var ms = 40; ms <= 1600; ms += 40) {
    await tester.pump(const Duration(milliseconds: 40));
    shares.add(await brightShare(tester, key, rect));
  }
  expect(c.phase, isNot('player_turn'), reason: 'the blow must end the fight');
  await tester.pumpWidget(const SizedBox.shrink());
  for (var t = 0; t < 3000; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return shares;
}

String fmt(List<double> s) =>
    s.map((v) => (v * 100).toStringAsFixed(1)).join(' ');

void main() {
  setUpAll(k.loadRealFonts);

  testWidgets('boss death: the white contact beat lasts at most 3 frames', (
    tester,
  ) async {
    final s = await bossKill(tester, reduced: false);
    final white = s.where((v) => v > 0.12).length;
    expect(
      white,
      lessThanOrEqualTo(3),
      reason: 'per-frame % bright: ${fmt(s)}',
    );
  });

  testWidgets('boss death under reduced motion shows no white block', (
    tester,
  ) async {
    final s = await bossKill(tester, reduced: true);
    final white = s.where((v) => v > 0.025).length;
    expect(white, 0, reason: 'per-frame % bright: ${fmt(s)}');
  });
}
