// test/provings_test.dart — The Provings (v0.38.0): data integrity, the
// winnability proof (every proving's exact run is won by the autoplay bot,
// which plays worse than a person), clear-marking through the controller,
// persistence, cloud merge, and the screen.
import 'dart:io';

import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/provings.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/provings_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 400) {
    final cmd = botCmd(
      c.sim!,
      character: c.sim!.run?['character'] as String?,
      difficulty: c.sim!.run?['difficulty'] as String? ?? 'normal',
      ascension: c.sim!.run?['ascension'] as int? ?? 0,
    );
    if (cmd == null) break;
    c.apply(cmd);
  }
}

void main() {
  group('data integrity', () {
    test('eight provings, unique ids, valid params, all encodable', () {
      expect(provings.length, 8);
      expect(provings.map((p) => p.id).toSet().length, 8);
      for (final p in provings) {
        expect(characters.containsKey(p.character), isTrue, reason: p.id);
        expect(['easy', 'normal', 'hard'], contains(p.difficulty));
        expect(p.ascension, inInclusiveRange(0, 20));
        expect(p.title, isNotEmpty);
        expect(p.blurb, isNotEmpty);
        final code = encodeDelveCode(
          seed: p.seed,
          character: p.character,
          difficulty: p.difficulty,
          ascension: p.ascension,
        );
        expect(code, isNotNull, reason: '${p.id} must have a Delve Code');
        final back = decodeDelveCode(code!)!;
        expect(back.seed, p.seed);
        expect(back.character, p.character);
        expect(back.difficulty, p.difficulty);
        expect(back.ascension, p.ascension);
      }
      expect(provingById('first_flame')!.seed, 1);
      expect(provingById('nope'), isNull);
    });

    test('every proving is bot-winnable (the winnability proof)', () {
      for (final p in provings) {
        final r = playRun(
          p.seed,
          character: p.character,
          difficulty: p.difficulty,
          ascension: p.ascension,
        );
        expect(
          r.sim.phase,
          'run_won',
          reason: '${p.id} (seed ${p.seed}) must stay winnable',
        );
      }
    });

    test('copy carries no pressure language (§Ethics)', () {
      final all = provings
          .map((p) => '${p.title} ${p.blurb}')
          .join(' ')
          .toLowerCase();
      for (final banned in [
        'streak', 'expire', 'hurry', 'miss out', 'last chance', 'beat me',
        'bet you', 'only today', "can't", 'loser',
      ]) {
        expect(all.contains(banned), isFalse, reason: 'found "$banned"');
      }
    });
  });

  group('clear marking through the controller', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late Directory dir;
    late GameController c;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('provings');
      c = GameController(saveDirOverride: dir.path);
      await c.boot();
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('winning the exact run marks the proving cleared', () async {
      final p = provingById('first_flame')!; // kindler easy seed 1: bot win
      c.startRun(
        character: p.character,
        seed: p.seed,
        difficulty: p.difficulty,
        ascension: p.ascension,
      );
      driveToTerminal(c);
      expect(c.phase, 'run_won');
      expect(c.meta.provingsCleared, contains('first_flame'));
      // Idempotent: winning it again keeps one mark, not two.
      c.startRun(
        character: p.character,
        seed: p.seed,
        difficulty: p.difficulty,
      );
      driveToTerminal(c);
      expect(c.meta.provingsCleared.length, 1);
    });

    test('same seed, wrong delver does not mark', () async {
      // Seed 1 wins on easy as the kindler; the proving names the kindler,
      // so an ascetic run on the same seed marks nothing even if it wins.
      c.meta.unlockedCharacters.add('ascetic');
      c.startRun(character: 'ascetic', seed: 1, difficulty: 'easy');
      driveToTerminal(c);
      expect(c.meta.provingsCleared, isEmpty);
    });

    test('provingsCleared survives save/load and cloud merge unions', () {
      final m = MetaState()..provingsCleared.addAll({'first_flame'});
      final back = MetaState.fromJson(m.toJson());
      expect(back.provingsCleared, {'first_flame'});
      final other = MetaState()..provingsCleared.add('shield_oath');
      final merged = mergeMetaStates(back, other);
      expect(merged.provingsCleared, {'first_flame', 'shield_oath'});
    });
  });

  group('the screen', () {
    testWidgets('lists all eight; locked ones state the requirement', (
      tester,
    ) async {
      final c = GameController();
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: ProvingsScreen(c)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('The First Flame'), findsOneWidget);
      expect(find.textContaining('0 of 8'), findsOneWidget);
      // Fresh meta: only the kindler is unlocked and hard is forge-gated,
      // so The Shield Oath (warden) states its delver requirement...
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('proving-req-shield_oath')),
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 60,
      );
      expect(
        find.textContaining('Needs The Warden'),
        findsOneWidget,
      );
      // ...and The First Flame (kindler, easy) is startable.
      expect(
        find.byKey(const ValueKey('proving-start-first_flame')),
        findsOneWidget,
      );
    });

    testWidgets('start button launches the exact run', (tester) async {
      final c = GameController();
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: ProvingsScreen(c)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('proving-start-first_flame')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.sim!.runSeed, 1);
      expect(c.sim!.run!['character'], 'kindler');
      expect(c.sim!.run!['difficulty'], 'easy');
    });

    testWidgets('cleared proving wears the mark', (tester) async {
      final c = GameController();
      c.meta.provingsCleared.add('first_flame');
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: ProvingsScreen(c)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('CLEARED'), findsOneWidget);
      expect(find.textContaining('1 of 8'), findsOneWidget);
      expect(find.text('Delve it again'), findsOneWidget);
    });
  });
}
