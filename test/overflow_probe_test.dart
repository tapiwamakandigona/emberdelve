// test/overflow_probe_test.dart — layout robustness gate.
// Pumps every screen at small / narrow / tall phone sizes and fails on any
// RenderFlex overflow ("words being cut off" bugs) or build/layout exception.
// Exceptions are drained with tester.takeException() after every pump step so
// the walk continues and later screens still get probed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/theme.dart';

/// Logical sizes that cover the Android spread: tiny legacy phone, narrow
/// 18:9, the common 360dp bucket, and a large tall phone.
const sizes = <Size>[
  Size(320, 568),
  Size(320, 640),
  Size(360, 640),
  Size(360, 800),
  Size(412, 915),
];

final List<String> problems = [];
String _probeContext = 'start';

void ctx(String context) => _probeContext = context;

/// Chained error hook: records rich diagnostics (incl. the error-causing
/// widget's source location) then delegates to the framework handler, so the
/// binding's pending-exception bookkeeping stays intact and _drain can still
/// swallow the error to keep the walk going.
void installDetailHook() {
  final original = FlutterError.onError!;
  FlutterError.onError = (details) {
    final s = details.toString();
    final src =
        RegExp(r'(lib/ui/\w+\.dart:\d+)').firstMatch(s)?.group(1) ?? '';
    _details.add('$_probeContext: ${details.exceptionAsString().split('\n').first} @$src');
    original(details);
  };
}

final List<String> _details = [];

void _drain(WidgetTester tester) {
  for (var i = 0; i < 20; i++) {
    final e = tester.takeException();
    if (e == null) break;
    final s = e.toString();
    problems.add(_details.isNotEmpty
        ? _details.removeAt(0)
        : '$_probeContext: ${s.split('\n').first}');
  }
  _details.clear();
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
    _drain(tester);
  }
}

Future<void> probeAllPhases(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  final c = GameController();
  c.meta.tutorialSeen = true;
  installDetailHook();
  ctx('title@$size');
  await tester.pumpWidget(MaterialApp(
    theme: buildEmberTheme(),
    home: GameRoot(c),
  ));
  _drain(tester);
  await pumpFor(tester, 400);

  // Boon screen.
  c.startRun(character: 'kindler', seed: 7, boons: true);
  ctx('boon@$size');
  await pumpFor(tester, 500);

  c.apply({'type': 'choose_boon', 'index': 1});
  ctx('map@$size');
  await pumpFor(tester, 500);

  // Walk the map, probing every phase we land in. Give the player a large
  // dice pool so the combat tray wraps to several rows (worst case).
  (c.state!['player'] as Map)['dice'] = <String>[
    'd6', 'd6', 'd6', 'd8_aegis', 'd10_blade', 'd12', 'd4_lucky', 'd8'
  ];
  var guard = 0;
  var sawCombat = false, sawShop = false, sawEvent = false, sawRest = false;
  while (guard++ < 24 && c.phase != null && c.phase != 'run_lost') {
    final phase = c.phase;
    if (phase == 'map') {
      final map = c.state!['map'] as Map;
      final position = map['position'] as int;
      final edges =
          ((map['edges'] as Map)['$position'] as List).cast<int>();
      // Prefer node kinds we have not probed yet.
      final nodes = (map['nodes'] as Map).cast<String, Map>();
      int pick = edges.first;
      for (final e in edges) {
        final kind = nodes['$e']!['kind'] as String;
        if ((kind == 'shop' && !sawShop) ||
            (kind == 'event' && !sawEvent) ||
            (kind == 'rest' && !sawRest) ||
            ((kind == 'fight' || kind == 'elite') && !sawCombat)) {
          pick = e;
          break;
        }
      }
      c.apply({'type': 'choose_node', 'node': pick});
      ctx('after-map-move@$size');
      await pumpFor(tester, 600);
    } else if (phase == 'player_turn') {
      sawCombat = true;
      ctx('combat@$size');
      c.apply({'type': 'roll'});
      await pumpFor(tester, 700);
      // Assign everything to attack/block, then end turn — a few turns.
      final player = c.state!['player'] as Map;
      final n = (player['dice'] as List).length;
      for (var i = 1; i <= n && c.phase == 'player_turn'; i++) {
        c.apply({'type': 'assign', 'die': i, 'action': i.isEven ? 'block' : 'attack'});
      }
      await pumpFor(tester, 400);
      if (c.phase == 'player_turn') {
        c.apply({'type': 'end_turn'});
        await pumpFor(tester, 900);
      }
      await pumpFor(tester, 1600);
    } else if (phase == 'reward') {
      ctx('reward@$size');
      await pumpFor(tester, 400);
      c.apply({'type': 'choose_reward', 'index': 1});
      await pumpFor(tester, 300);
    } else if (phase == 'rest') {
      sawRest = true;
      ctx('rest@$size');
      await pumpFor(tester, 400);
      c.apply({'type': 'rest'});
      await pumpFor(tester, 300);
    } else if (phase == 'shop') {
      sawShop = true;
      ctx('shop@$size');
      await pumpFor(tester, 400);
      c.apply({'type': 'leave_shop'});
      await pumpFor(tester, 300);
    } else if (phase == 'event') {
      sawEvent = true;
      ctx('event@$size');
      await pumpFor(tester, 400);
      c.apply({'type': 'event_choose', 'option': 1});
      await pumpFor(tester, 300);
    } else {
      break; // run_won / run_lost / anything else
    }
  }
  ctx('summary@$size');
  await pumpFor(tester, 600);
  // Drain pending timers (terminal-hold notifies, tumble delays).
  await pumpFor(tester, 2000);
}

void main() {
  for (final size in sizes) {
    testWidgets('no layout errors across phases at $size',
        (tester) async {
      problems.clear();
      await probeAllPhases(tester, size);
      expect(problems, isEmpty,
          reason: 'layout problems:\n${problems.join('\n')}');
    });

    testWidgets('settings screen fits at $size', (tester) async {
      tester.view.physicalSize = size * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      problems.clear();
      ctx('settings@$size');
      await tester.pumpWidget(MaterialApp(
        theme: buildEmberTheme(),
        home: const SettingsScreen(),
      ));
      _drain(tester);
      await pumpFor(tester, 400);
      expect(problems, isEmpty,
          reason: 'layout problems:\n${problems.join('\n')}');
    });
  }
}
