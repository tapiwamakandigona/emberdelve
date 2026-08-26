// test/dressed_delver_test.dart — v0.66.0 "The Dressed Delver": epithets
// are worn PER DELVER (MetaState.charEpithet), with the legacy global
// selection surviving as the fallback for undressed delvers. Design doc:
// docs/improvements/v0.66.0-lead-scout.md.
//
// Pins:
//   1. Resolver: own dress wins; absent key falls back to the legacy
//      selectedEpithet; a per-delver 'none' overrides the fallback.
//   2. Selection: dressing one delver never moves another's title; a locked
//      delver and a locked epithet are both refused.
//   3. Save round-trip: charEpithet survives toJson/fromJson; an empty map
//      emits no key; unknown delver and epithet ids are dropped on decode.
//   4. Cloud merge: the fresher side's dress wins wholesale — same
//      convention as selectedEpithet/activeDye.
//   5. Banking: the run record carries the title worn by the RUN's delver
//      at bank time.
//   6. Picker: each unlocked delver shows their own title; the dress-chip
//      row appears only with more than one delver unlocked, and its taps
//      dress the chip-selected delver alone.
//
// Seeds: 1 wins on easy (kindler, boons — pinned table, post-v0.47.0).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/epithets.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(guard < 4000, isTrue, reason: 'bot run failed to terminate');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dressed_delver_test');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('resolver: own dress, else the legacy fallback, else none', () {
    final m = MetaState();
    expect(m.epithetFor('kindler'), defaultEpithet);
    m.selectedEpithet = 'the_delver'; // pre-v0.66.0 choice
    expect(m.epithetFor('kindler'), 'the_delver');
    expect(m.epithetFor('warden'), 'the_delver');
    m.charEpithet['warden'] = 'the_thorough';
    expect(m.epithetFor('warden'), 'the_thorough');
    expect(m.epithetFor('kindler'), 'the_delver');
    // A per-delver 'none' is a real choice — it overrides the fallback.
    m.charEpithet['kindler'] = defaultEpithet;
    expect(m.epithetFor('kindler'), defaultEpithet);
  });

  test('selection: isolation, locked delver refused, locked title refused', () {
    final c = GameController();
    c.meta.runsWon = 1; // earns the_delver
    c.selectEpithet('the_delver', forChar: 'warden'); // warden locked
    expect(c.meta.charEpithet, isEmpty);
    c.meta.unlockedCharacters.add('warden');
    c.selectEpithet('the_delver', forChar: 'warden');
    expect(c.meta.epithetFor('warden'), 'the_delver');
    expect(c.meta.epithetFor('kindler'), defaultEpithet);
    c.selectEpithet('the_proven', forChar: 'kindler'); // not earned
    expect(c.meta.epithetFor('kindler'), defaultEpithet);
  });

  test('save round-trip; empty map emits no key; unknown ids dropped', () {
    final m = MetaState();
    expect(m.toJson().containsKey('charEpithet'), isFalse);
    m.charEpithet['kindler'] = 'the_delver';
    final back = MetaState.fromJson(m.toJson());
    expect(back.charEpithet, {'kindler': 'the_delver'});
    final j = m.toJson();
    j['charEpithet'] = {
      'kindler': 'the_delver',
      'nonsense_delver': 'the_delver', // unknown delver id
      'warden': 'nonsense_title', // unknown epithet id
    };
    expect(MetaState.fromJson(j).charEpithet, {'kindler': 'the_delver'});
  });

  test('cloud merge: the fresher side dresses everyone', () {
    final local = MetaState()
      ..lifetimeEmbers = 100
      ..charEpithet['kindler'] = 'the_delver';
    final cloud = MetaState()
      ..lifetimeEmbers = 50
      ..charEpithet['warden'] = 'the_thorough';
    final m = mergeMetaStates(local, cloud);
    expect(m.charEpithet, {'kindler': 'the_delver'});
    final m2 = mergeMetaStates(cloud, local);
    expect(m2.charEpithet, {
      'kindler': 'the_delver',
    }, reason: 'freshness, not argument order, picks the dress');
  });

  test('the run record banks the title worn by the RUN delver', () async {
    final c = GameController(saveDirOverride: dir.path);
    await c.boot();
    c.meta.runsWon = 1;
    c.selectEpithet('the_delver', forChar: 'kindler');
    c.meta.unlockedCharacters.add('warden');
    c.meta.charEpithet['warden'] = 'the_thorough'; // someone else's dress
    c.startRun(character: 'kindler', seed: 1, boons: true, difficulty: 'easy');
    driveToTerminal(c);
    expect(c.phase, 'run_won', reason: 'seed 1 must win on easy');
    expect(c.meta.runHistory.first['epithet'], 'the_delver');
    await c.flushSaves();
  });

  testWidgets('the picker shows each delver their own title', (tester) async {
    final c = GameController();
    c.meta.unlockedCharacters.add('warden');
    c.meta.charEpithet['kindler'] = 'the_delver';
    c.meta.charEpithet['warden'] = 'the_thorough';
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    expect(find.text('the Delver'), findsWidgets);
    expect(find.text('the Thorough'), findsWidgets);
  });

  testWidgets('one delver unlocked: no chip row, the shelf reads as before', (
    tester,
  ) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('dress-kindler')), findsNothing);
  });

  testWidgets('the chip row dresses the chip-selected delver alone', (
    tester,
  ) async {
    final c = GameController();
    c.meta
      ..runsWon =
          1 // earns the_delver
      ..unlockedCharacters.add('warden');
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    // The list mounts lazily — scroll the vertical list to the chip row.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dress-warden')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('dress-kindler')), findsOneWidget);
    expect(find.byKey(const ValueKey('dress-warden')), findsOneWidget);
    // Pick the warden, then wear the Delver: only the warden is dressed.
    await tester.tap(find.byKey(const ValueKey('dress-warden')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('epithet-the_delver')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('epithet-the_delver')));
    await tester.pump();
    expect(c.meta.epithetFor('warden'), 'the_delver');
    expect(c.meta.epithetFor('kindler'), defaultEpithet);
  });
}
