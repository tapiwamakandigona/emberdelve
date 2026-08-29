// test/hearth_tale_test.dart — v0.96.0 The Hearth Tale.
//
// Every rest fire tells one short tale of the world in a fixed lifetime
// sequence. Pins: the indexer (sequential then cycling, negative-safe),
// the copy charter (ethics blacklist, honest lengths), the advance rule
// (exactly once per hollow LEFT — rest, forge, or temper; never on an
// invalid command), and the monotonic cloud merge.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/tales.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart' show tourVersion;
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms / 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pure-controller walk (bot-driven) until the run stands at a rest fire.
GameController atRest({int seed = 3}) {
  final c = GameController();
  c.meta
    ..tutorialSeen = true
    ..tourSeenVersion = tourVersion
    ..tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  c.startRun(character: 'kindler', seed: seed, difficulty: 'easy');
  var guard = 0;
  while (c.phase != 'rest' &&
      c.phase != 'run_won' &&
      c.phase != 'run_lost' &&
      guard++ < 400) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(c.phase, 'rest', reason: 'seed $seed never rested');
  return c;
}

void main() {
  test('indexer: sequential first pass, then the arc comes round', () {
    expect(hearthTale(0), hearthTales.first);
    expect(hearthTale(1), hearthTales[1]);
    expect(hearthTale(hearthTales.length - 1), hearthTales.last);
    expect(hearthTale(hearthTales.length), hearthTales.first);
    expect(hearthTale(hearthTales.length * 3 + 2), hearthTales[2]);
    expect(hearthTale(-5), hearthTales.first); // corrupt save: never throws
  });

  test('copy charter: ethics blacklist and honest lengths', () {
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
    expect(hearthTales.length, greaterThanOrEqualTo(8));
    for (final tale in hearthTales) {
      expect(tale.trim(), isNotEmpty);
      expect(tale.length, lessThanOrEqualTo(200), reason: tale);
      for (final b in banned) {
        expect(tale.toLowerCase(), isNot(contains(b)), reason: '"$b": $tale');
      }
    }
  });

  test('leaving the hollow advances the arc exactly once', () {
    final c = atRest();
    expect(c.meta.hearthTalesHeard, 0);
    // An invalid command keeps the phase and must NOT advance the tale.
    c.apply({'type': 'attack'});
    expect(c.phase, 'rest');
    expect(c.meta.hearthTalesHeard, 0);
    c.apply({'type': 'rest'});
    expect(c.phase, isNot('rest'));
    expect(c.meta.hearthTalesHeard, 1);
  });

  test('cloud merge keeps the deeper arc (monotonic MAX)', () {
    final local = MetaState()..hearthTalesHeard = 4;
    final cloud = MetaState()..hearthTalesHeard = 7;
    expect(mergeMetaStates(local, cloud).hearthTalesHeard, 7);
    expect(mergeMetaStates(cloud, local).hearthTalesHeard, 7);
  });

  test('save round-trip keeps the count; fresh saves omit the key', () {
    final m = MetaState();
    expect(m.toJson().containsKey('hearthTalesHeard'), isFalse);
    m.hearthTalesHeard = 3;
    final back = MetaState.fromJson(Map<String, dynamic>.from(m.toJson()));
    expect(back.hearthTalesHeard, 3);
  });

  testWidgets('the rest fire shows the current tale', (tester) async {
    final c = atRest();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await pumpFor(tester, 600);
    final taleText = tester.widget<Text>(
      find.byKey(const ValueKey('hearth-tale')),
    );
    expect(taleText.data, contains(hearthTales.first));
  });
}
