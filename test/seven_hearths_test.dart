// THE SEVEN HEARTHS (v0.178.0): the first-week arc — one hearth per
// distinct played day, seventh settles 60 embers exactly once, row
// retires after the settlement day. §Ethics: no streaks, no expiry,
// no loss-framed copy.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/daily_share.dart';
import 'package:emberdelve/game/hearths.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

const banned = [
  'streak',
  'expire',
  'hurry',
  'miss out',
  'last chance',
  'beat me',
  'bet you',
  'only today',
  "can't",
  'loser',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hearth lines carry no pressure words and cover 0..7', () {
    for (var i = 0; i <= hearthCount; i++) {
      final line = hearthLine(i).toLowerCase();
      expect(line, isNotEmpty);
      for (final w in banned) {
        expect(line.contains(w), isFalse, reason: '"$w" in hearthLine($i)');
      }
    }
    expect(hearthLine(0), contains('no hearth ever goes out'));
    expect(hearthLine(hearthCount), contains('$hearthGrantEmbers embers'));
  });

  test('meta fields round-trip through json', () {
    final m = MetaState(
      hearthDaysLit: 3,
      lastHearthDay: '2026-09-01',
      sevenHearthsSettled: false,
    );
    final back = MetaState.fromJson(m.toJson());
    expect(back.hearthDaysLit, 3);
    expect(back.lastHearthDay, '2026-09-01');
    expect(back.sevenHearthsSettled, isFalse);
    // Fresh profile: nothing serialized, nothing lit.
    expect(MetaState.fromJson(MetaState().toJson()).hearthDaysLit, 0);
  });

  test('cloud merge takes MAX days and ORs the settlement', () {
    final local = MetaState(hearthDaysLit: 2, lastHearthDay: '2026-09-01');
    final cloud = MetaState(
      hearthDaysLit: 7,
      lastHearthDay: '2026-08-20',
      sevenHearthsSettled: true,
    );
    final merged = mergeMetaStates(local, cloud);
    expect(merged.hearthDaysLit, 7);
    expect(merged.lastHearthDay, '2026-08-20');
    expect(merged.sevenHearthsSettled, isTrue);
    final backMerge = mergeMetaStates(cloud, local);
    expect(backMerge.hearthDaysLit, 7);
    expect(backMerge.sevenHearthsSettled, isTrue);
  });

  group('controller lighting', () {
    late Directory dir;
    late GameController c;

    Future<void> fresh() async {
      dir = await Directory.systemTemp.createTemp('hearths');
      c = GameController(saveDirOverride: dir.path);
      await c.boot();
    }

    /// Finish one full run with the autoplay bot (any terminal result).
    void playOut({int seed = 1}) {
      c.startRun(character: 'kindler', seed: seed, difficulty: 'easy');
      var guard = 0;
      while (c.sim != null &&
          !{'run_won', 'run_lost'}.contains(c.phase) &&
          guard++ < 600) {
        final cmd = botCmd(c.sim!);
        if (cmd == null) break;
        c.apply(cmd);
      }
      c.endToTitle();
    }

    test('one hearth per local day, however many runs end', () async {
      await fresh();
      playOut(seed: 1);
      expect(c.meta.hearthDaysLit, 1);
      expect(c.meta.lastHearthDay, dailyKey(DateTime.now()));
      playOut(seed: 18); // second run, same day: no second light
      expect(c.meta.hearthDaysLit, 1);
      dir.deleteSync(recursive: true);
    });

    test('abandoning still lights the day', () async {
      await fresh();
      c.startRun(character: 'kindler', seed: 7, difficulty: 'easy');
      c.abandonRun();
      expect(c.meta.hearthDaysLit, 1);
      dir.deleteSync(recursive: true);
    });

    test('seventh day settles 60 embers exactly once', () async {
      await fresh();
      // Six prior days already lit (as if played across two weeks).
      c.meta
        ..hearthDaysLit = 6
        ..lastHearthDay = '2026-08-20';
      final before = c.meta.embers;
      playOut(seed: 1);
      expect(c.meta.hearthDaysLit, 7);
      expect(c.meta.sevenHearthsSettled, isTrue);
      // Grant is on top of whatever the run itself banked.
      final runBanked = c.meta.lifetimeEmbers;
      expect(c.meta.embers, before + runBanked + hearthGrantEmbers);
      // A merge or replay can never pay twice: day 8 changes nothing.
      c.meta.lastHearthDay = '2026-08-31';
      final after = c.meta.embers;
      playOut(seed: 18);
      expect(c.meta.hearthDaysLit, 7);
      expect(c.meta.embers - after, c.meta.lifetimeEmbers - runBanked);
      dir.deleteSync(recursive: true);
    });
  });

  group('title row', () {
    // NOTE: no boot() here — awaiting real I/O inside a widget test's
    // FakeAsync zone hangs until the 10-minute timeout. The title row
    // reads only meta, so an unbooted controller is the right fixture
    // (same pattern as waymark_line_test.dart).
    Future<GameController> boot(WidgetTester tester) async {
      final c = GameController();
      c.meta
        ..tutorialSeen = true
        ..tourSeenVersion = tourVersion
        ..tipsSeen.addAll(ContextTips.all);
      c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
      return c;
    }

    Future<void> mount(WidgetTester tester, GameController c) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: TitleScreen(c)),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 25));
      }
    }

    testWidgets('unsettled profile shows the row and the 0-line', (
      tester,
    ) async {
      final c = await boot(tester);
      await mount(tester, c);
      final row = find.byKey(const ValueKey('hearth-row'));
      await tester.scrollUntilVisible(row, 80);
      expect(row, findsOneWidget);
      expect(find.text(hearthLine(0)), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('settled profile from an earlier day retires the row', (
      tester,
    ) async {
      final c = await boot(tester);
      c.meta
        ..hearthDaysLit = 7
        ..sevenHearthsSettled = true
        ..lastHearthDay = '2026-08-20'; // not today
      await mount(tester, c);
      expect(find.byKey(const ValueKey('hearth-row')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('settlement day still shows the burning row', (tester) async {
      final c = await boot(tester);
      c.meta
        ..hearthDaysLit = 7
        ..sevenHearthsSettled = true
        ..lastHearthDay = dailyKey(DateTime.now());
      await mount(tester, c);
      final line = find.byKey(const ValueKey('hearth-line'));
      await tester.scrollUntilVisible(line, 80);
      expect(find.text(hearthLine(7)), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
