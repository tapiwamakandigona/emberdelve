// test/temper_ui_test.dart — the v7 Face Forge reaches the player: the rest
// screen offers a temper, the sheet commits exactly one, and every screen
// that renders the pool survives a run-local custom die.
import 'package:emberdelve/data/events.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/temper_sheet.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A controller parked in a rest, which is the only phase a temper is legal.
GameController _atRest() {
  final c = GameController();
  c.meta.tutorialSeen = true;
  c.meta.tipsSeen.addAll(ContextTips.all);
  c.startRun(character: 'kindler', seed: 5, boons: false);
  // Drive straight to a rest node rather than hoping the seed offers one.
  c.sim!.phase = 'rest';
  return c;
}

void main() {
  testWidgets('rest offers a temper, and the sheet commits exactly one', (
    tester,
  ) async {
    final c = _atRest();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('rest-temper')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rest-temper')));
    await _settle(tester);

    // The confirm button refuses to fire until all three choices exist.
    await tester.tap(find.byKey(const ValueKey('temper-confirm')));
    await _settle(tester);
    expect(find.byType(TemperSheet), findsOneWidget);
    expect(c.state!['run']!, isA<Map>());
    expect((c.state!['run'] as Map)['tempers_used'] ?? 0, 0);

    await tester.tap(find.byKey(const ValueKey('temper-die-1')));
    await _settle(tester, 300);
    await tester.tap(find.byKey(const ValueKey('temper-face-4')));
    await _settle(tester, 300);
    await tester.tap(find.byKey(const ValueKey('temper-rune-blade')));
    await _settle(tester, 300);
    await tester.tap(find.byKey(const ValueKey('temper-confirm')));
    await _settle(tester);

    final run = c.state!['run'] as Map;
    expect(run['tempers_used'], 1);
    final custom = (run['custom_dice'] as Map)['custom_1'] as Map;
    expect(custom['face'], 4);
    expect(custom['rune'], 'blade');
    expect(
      ((c.state!['player'] as Map)['dice'] as List).first,
      'custom_1',
      reason: 'the tempered die replaced its slot in the pool',
    );
    // The temper is the rest's one action, so the run moves on.
    expect(c.phase, 'map');
  });

  testWidgets('a tempered die renders everywhere the pool is drawn', (
    tester,
  ) async {
    final c = _atRest();
    c.apply({'type': 'temper_face', 'die': 1, 'face': 3, 'rune': 'surge'});
    expect((c.state!['run'] as Map)['tempers_used'], 1);

    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // Walk into a fight so the combat tray paints the custom die.
    var guard = 0;
    while (c.phase != 'player_turn' && guard++ < 30) {
      if (c.phase == 'map') {
        final map = c.state!['map'] as Map;
        final pos = map['position'] as int;
        final edges = ((map['edges'] as Map)['$pos'] as List).cast<int>();
        c.apply({'type': 'choose_node', 'node': edges.first});
      } else if (c.phase == 'rest') {
        c.apply({'type': 'rest'});
      } else if (c.phase == 'shop') {
        c.apply({'type': 'leave_shop'});
      } else if (c.phase == 'event') {
        // Option 1 can be a gold-costing choice the run cannot afford (the
        // v0.12.0 deck growth surfaced this latent fragility: an invalid
        // command leaves the phase stuck at 'event'). Walk the options from
        // the last (conventionally the free decline) until one resolves.
        final n = eventDef(c.state!['event'] as String).options.length;
        for (var o = n; o >= 1 && c.phase == 'event'; o--) {
          c.apply({'type': 'event_choose', 'option': o});
        }
      } else {
        break;
      }
      await _settle(tester, 400);
    }
    expect(c.phase, 'player_turn', reason: 'never reached a fight');
    c.apply({'type': 'roll'});
    await _settle(tester, 900);
    expect(tester.takeException(), isNull);
    expect(find.byType(DieChip), findsWidgets);

    // The rune mark is spoken, not just painted.
    final semantics = tester.getSemantics(find.byType(DieChip).first);
    expect(semantics.label, contains('tempered Surge on 3'));
  });

  testWidgets('the temper option disappears once the run has spent it', (
    tester,
  ) async {
    final c = _atRest();
    c.apply({'type': 'temper_face', 'die': 1, 'face': 2, 'rune': 'aegis'});
    c.sim!.phase = 'rest';

    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('rest-temper')), findsNothing);
  });

  testWidgets('the effects you cannot read off a die are announced', (
    tester,
  ) async {
    final c = _atRest();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    await _settle(tester);

    c.apply({'type': 'temper_face', 'die': 1, 'face': 3, 'rune': 'echo'});
    expect(c.flash, 'Echo tempered onto 3');

    // Living Bastion's carry is invisible on the board, so it speaks.
    final sim = c.sim!;
    sim.run!['keystones'] = ['living_bastion'];
    sim.phase = 'player_turn';
    sim.enemy = {
      'id': 'cinder_wisp',
      'hp': 20,
      'max_hp': 20,
      'block': 0,
      'burn': 0,
      'intent': {'kind': 'attack', 'amount': 1},
      'pattern': [
        {'kind': 'attack', 'amount': 1},
      ],
      'pattern_index': 1,
    };
    sim.player['block'] = 9;
    c.apply({'type': 'end_turn'});
    expect(c.flash, 'Living Bastion — 4 block carried');
  });
}
