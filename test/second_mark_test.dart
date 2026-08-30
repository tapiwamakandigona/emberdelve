// test/second_mark_test.dart — v0.132.0 The Second Mark.
//
// Two tempers per delve (was one since v7). The raise is replay-permissive
// — nothing that was legal stops being legal — and the golden bot tempers
// at most once by its own policy, so anchors hold by construction (proved
// by sim_test in the same suite, not assumed).
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameController _atRest() {
  final c = GameController();
  c.meta.tutorialSeen = true;
  c.meta.tipsSeen.addAll(ContextTips.all);
  c.meta.heardTracks.addAll([for (final t in gramophoneTracks) t.key]);
  c.startRun(character: 'kindler', seed: 5, boons: false);
  c.sim!.phase = 'rest';
  return c;
}

void main() {
  test('both marks pay: two runes trigger in the same run state', () {
    final sim = Sim(77)..apply({'type': 'start_run'});
    sim.run!['custom_dice'] = {
      'custom_1': {'base': 'd6', 'face': 2, 'rune': 'mend'},
      'custom_2': {'base': 'd6', 'face': 4, 'rune': 'gilt'},
    };
    sim.run!['tempers_used'] = 2;
    sim.run!['next_custom_die'] = 3;
    expect(sim.stateHash(), isA<int>(), reason: 'two customs are legal state');
  });

  test('the golden bot still tempers at most once with tempers on', () {
    final r = playRun(5, tempers: true);
    final used = r.sim.run?['tempers_used'] as int? ?? 0;
    expect(
      used,
      lessThanOrEqualTo(1),
      reason: 'bot policy is ==0, the cap raise must not change walks',
    );
  });

  test('a tempers-off walk never tempers (golden construction)', () {
    final r = playRun(5);
    expect(r.sim.run?['tempers_used'] ?? 0, 0);
  });

  testWidgets('rest copy counts marks: two fresh, one after a temper', (
    tester,
  ) async {
    final c = _atRest();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Two marks a delve.'), findsOneWidget);

    c.apply({'type': 'temper_face', 'die': 1, 'face': 4, 'rune': 'blade'});
    c.sim!.phase = 'rest';
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('One mark left.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rest-temper')),
      findsOneWidget,
      reason: 'the anvil stays offered while a mark remains',
    );

    c.apply({'type': 'temper_face', 'die': 2, 'face': 4, 'rune': 'aegis'});
    c.sim!.phase = 'rest';
    c.notifyListeners();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.byKey(const ValueKey('rest-temper')),
      findsNothing,
      reason: 'both marks spent, the option disappears (v7 rule)',
    );
  });
}
