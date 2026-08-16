// test/semantics_probe_test.dart — TalkBack readiness gate (v0.19.0).
// Walks the same phase route as overflow_probe_test.dart with semantics
// enabled and fails if any TAPPABLE semantics node has no spoken label:
// a screen-reader user would hear "double tap to activate" with no idea
// what the control does. Also fails on duplicate sibling labels for
// interactive nodes where position is the only differentiator the eye
// gets but the ear does not (dice tray is exempt: dice announce value+face).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/game/tips.dart';

final List<String> problems = [];
int tappableSeen = 0; // vacuity guard: a probe that audits nothing proves nothing
String _ctx = 'start';
void ctx(String c) => _ctx = c;

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
    tester.takeException(); // layout gate lives in overflow_probe_test
  }
}

/// Collect every semantics node that has a tap action but nothing to speak.
void auditTree(WidgetTester tester) {
  // The root pipeline owner is a synthetic parent with no semantics owner of
  // its own; real semantics owners live on the per-view child pipeline
  // owners. (First draft read rootPipelineOwner.semanticsOwner — always null
  // in tests — and passed vacuously. The tappableSeen guard caught it.)
  final roots = <SemanticsNode>[];
  tester.binding.rootPipelineOwner.visitChildren((child) {
    final r = child.semanticsOwner?.rootSemanticsNode;
    if (r != null) roots.add(r);
  });
  void visit(SemanticsNode node) {
    if (!node.isMergedIntoParent && !node.getSemanticsData().flagsCollection.isHidden) {
      final data = node.getSemanticsData();
      final tappable = data.hasAction(SemanticsAction.tap);
      if (tappable) tappableSeen++;
      final spoken = '${data.label} ${data.tooltip} ${data.value}'.trim();
      if (tappable && spoken.isEmpty) {
        problems.add('$_ctx: tappable node #${node.id} has no label '
            '(rect ${node.rect.size.width.round()}x'
            '${node.rect.size.height.round()})');
      }
    }
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  roots.forEach(visit);
}

Future<void> walk(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  final c = GameController();
  c.meta.tutorialSeen = true;
  c.meta.tipsSeen.addAll(ContextTips.all);
  ctx('title');
  await tester.pumpWidget(MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)));
  await pumpFor(tester, 400);
  auditTree(tester);

  c.startRun(character: 'kindler', seed: 7, boons: true);
  ctx('boon');
  await pumpFor(tester, 500);
  auditTree(tester);

  c.apply({'type': 'choose_boon', 'index': 1});
  ctx('map');
  await pumpFor(tester, 500);
  auditTree(tester);

  var guard = 0;
  var sawCombat = false, sawShop = false, sawEvent = false, sawRest = false;
  while (guard++ < 24 && c.phase != null && c.phase != 'run_lost') {
    final phase = c.phase;
    if (phase == 'map') {
      final map = c.state!['map'] as Map;
      final position = map['position'] as int;
      final edges = ((map['edges'] as Map)['$position'] as List).cast<int>();
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
      await pumpFor(tester, 600);
      auditTree(tester);
    } else if (phase == 'player_turn') {
      sawCombat = true;
      ctx('combat');
      c.apply({'type': 'roll'});
      await pumpFor(tester, 700);
      auditTree(tester);
      final player = c.state!['player'] as Map;
      final n = (player['dice'] as List).length;
      for (var i = 1; i <= n && c.phase == 'player_turn'; i++) {
        c.apply({
          'type': 'assign',
          'die': i,
          'action': i.isEven ? 'block' : 'attack',
        });
      }
      await pumpFor(tester, 400);
      auditTree(tester);
      if (c.phase == 'player_turn') {
        c.apply({'type': 'end_turn'});
        await pumpFor(tester, 900);
      }
      await pumpFor(tester, 1600);
    } else if (phase == 'keystone') {
      ctx('keystone');
      await pumpFor(tester, 400);
      auditTree(tester);
      c.apply({'type': 'choose_keystone', 'index': 1});
      await pumpFor(tester, 300);
    } else if (phase == 'reward') {
      ctx('reward');
      await pumpFor(tester, 400);
      auditTree(tester);
      c.apply({'type': 'choose_reward', 'index': 1});
      await pumpFor(tester, 300);
    } else if (phase == 'rest') {
      sawRest = true;
      ctx('rest');
      await pumpFor(tester, 400);
      auditTree(tester);
      c.apply({'type': 'rest'});
      await pumpFor(tester, 300);
    } else if (phase == 'shop') {
      sawShop = true;
      ctx('shop');
      await pumpFor(tester, 400);
      auditTree(tester);
      c.apply({'type': 'leave_shop'});
      await pumpFor(tester, 300);
    } else if (phase == 'event') {
      sawEvent = true;
      ctx('event');
      await pumpFor(tester, 400);
      auditTree(tester);
      c.apply({'type': 'event_choose', 'option': 1});
      await pumpFor(tester, 300);
    } else {
      break;
    }
  }
  ctx('summary');
  await pumpFor(tester, 600);
  auditTree(tester);
  await pumpFor(tester, 2000);
}

void main() {
  testWidgets('every tappable control announces a label (run walk)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    problems.clear();
    tappableSeen = 0;
    await walk(tester);
    handle.dispose();
    // Vacuity guard: the run walk passes title, boon, map, combat, reward &c.
    // — dozens of buttons. Seeing fewer than 30 means semantics were off or
    // the audit never ran, and a green result would be meaningless.
    expect(tappableSeen, greaterThan(30),
        reason: 'audit saw only $tappableSeen tappable nodes — vacuous run');
    expect(
      problems.toSet(),
      isEmpty,
      reason: 'unlabeled tappables:\n${problems.toSet().join('\n')}',
    );
  });

  testWidgets('every tappable control announces a label (meta screens)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    problems.clear();
    tappableSeen = 0;
    tester.view.physicalSize =
        const Size(412, 915) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    final c = GameController();
    for (final entry in {
      'settings': () => const SettingsScreen(),
      'ledger': () => LedgerScreen(c),
      'codex': () => CodexScreen(c),
    }.entries) {
      ctx(entry.key);
      await tester.pumpWidget(
        MaterialApp(theme: buildEmberTheme(), home: entry.value()),
      );
      await pumpFor(tester, 400);
      auditTree(tester);
    }
    handle.dispose();
    expect(tappableSeen, greaterThan(10),
        reason: 'audit saw only $tappableSeen tappable nodes — vacuous run');
    expect(
      problems.toSet(),
      isEmpty,
      reason: 'unlabeled tappables:\n${problems.toSet().join('\n')}',
    );
  });
}
