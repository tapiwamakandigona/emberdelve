// tool/play_session_test.dart — interactive play harness (tool/, NOT in CI).
// Plays full runs through the REAL UI (real hit-tested taps, real frames),
// screenshots every phase, and records every framework exception. Run:
//
//   flutter test tool/play_session_test.dart
//   EMBER_SESSION_SEED=7 flutter test tool/play_session_test.dart   # other seeds
//
// Plays 4 bot-guided runs end to end via hit-tested taps; screenshots land
// in build/play_session/ with a report.txt of every framework exception.
//
// DETERMINISM (remaining-work §2): run N uses seed EMBER_SESSION_SEED + N
// (default base 1842571558, the golden-anchor seed), injected via
// GameController.debugNextRunSeed. A failure is therefore reproducible from
// the command line printed in the failure message.
//
// ORACLE (remaining-work §2): every loop step checks sim invariants —
// HP/economy bounds, assigned ⊆ rolled, legal phase set and phase-transition
// graph, dead actors imply a phase change. Violations FAIL the test (unlike
// UI-probing warnings, which stay report-only): this file is a fuzz test,
// no longer just a crash-catcher.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';

const outDir = 'build/play_session';
const shotSize = Size(360, 800);
const pixelRatio = 2.0;
final rootKey = GlobalKey();
final List<String> problems = [];
final List<String> violations = []; // invariant/stuck failures — these FAIL
final List<String> log = [];
String ctx = 'start';

/// Base seed for the session; run N (0-based) plays seed [baseSeed] + N.
final int baseSeed =
    int.tryParse(Platform.environment['EMBER_SESSION_SEED'] ?? '') ??
    1842571558; // the long-lived golden-anchor seed

/// Legal sim phase-transition graph (self-loops always allowed). Anchors:
/// start_run → boon|map (run_layer.dart 166/174), boon → map (221),
/// map → player_turn|rest|shop|event (263-465, combatBegin), event may also
/// start a fight (events.dart combatBegin) or return to map (497),
/// rest|shop → map (338/356/452), reward → map (328), combat resolution →
/// reward|run_won|run_lost|map (587-666). 'title' is the controller-level
/// null-sim state; a finished run restarts via startRun (→ boon|map).
const Map<String, Set<String>> legalNext = {
  'title': {'boon', 'map'},
  'idle': {'boon', 'map'},
  'boon': {'map'},
  'map': {'player_turn', 'rest', 'shop', 'event'},
  'player_turn': {'reward', 'map', 'run_won', 'run_lost'},
  'reward': {'map'},
  'rest': {'map'},
  'shop': {'map'},
  'event': {'map', 'player_turn'},
  'run_won': {'title', 'boon', 'map'},
  'run_lost': {'title', 'boon', 'map'},
};

/// Sim-state oracle, checked on every loop step. The sim is synchronous —
/// commands resolve fully before the UI choreographs — so any state the
/// harness observes between taps must already satisfy these.
void checkInvariants(Map<String, Object?>? st, String phase, int step) {
  if (st == null) return;
  void bad(String what) =>
      violations.add('INVARIANT step $step phase $phase: $what');
  final pl = (st['player'] as Map?) ?? const {};
  final hp = pl['hp'] as int?, maxHp = pl['max_hp'] as int?;
  if (hp != null && maxHp != null && hp > maxHp) {
    bad('player hp $hp > max_hp $maxHp');
  }
  if (hp != null && hp <= 0 && phase != 'run_lost') {
    bad('player hp $hp <= 0 outside run_lost (zombie run)');
  }
  if ((pl['block'] as int? ?? 0) < 0) bad('player block ${pl['block']} < 0');
  if ((pl['rerolls_left'] as int? ?? 0) < 0) {
    bad('rerolls_left ${pl['rerolls_left']} < 0');
  }
  final rolled = (pl['rolled'] as List?)?.cast<int>();
  final assigned = (pl['assigned'] as Map?) ?? const {};
  if (assigned.isNotEmpty && rolled == null) {
    bad('assigned dice ${assigned.keys} with no rolled dice');
  }
  for (final k in assigned.keys) {
    final i = int.tryParse('$k');
    if (i == null || i < 1 || (rolled != null && i > rolled.length)) {
      bad('assigned key $k outside rolled range 1..${rolled?.length}');
    }
    final v = assigned[k];
    if (v != 'attack' && v != 'block') bad('assigned[$k] = $v (not a verb)');
  }
  final run = (st['run'] as Map?) ?? const {};
  for (final key in const ['embers', 'gold', 'pending_splash']) {
    final v = run[key] as int?;
    if (v != null && v < 0) bad('run.$key $v < 0');
  }
  final enemy = st['enemy'] as Map?;
  if (enemy != null && phase == 'player_turn') {
    final ehp = enemy['hp'] as int?, emax = enemy['max_hp'] as int?;
    if (ehp != null && ehp <= 0) bad('enemy hp $ehp <= 0 in player_turn');
    if (ehp != null && emax != null && ehp > emax) {
      bad('enemy hp $ehp > max_hp $emax');
    }
    if ((enemy['block'] as int? ?? 0) < 0) {
      bad('enemy block ${enemy['block']} < 0');
    }
  }
}

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final f = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (f.existsSync()) {
      final bytes = f.readAsBytesSync();
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await icons.load();
    }
  }
}

void installHook() {
  final original = FlutterError.onError!;
  FlutterError.onError = (details) {
    final s = details.toString();
    final src =
        RegExp(r'(lib/[\w/]+\.dart:\d+)').firstMatch(s)?.group(1) ?? '?';
    problems.add(
      '$ctx: ${details.exceptionAsString().split('\n').first} @$src',
    );
    original(details);
  };
}

void drain(WidgetTester tester) {
  for (var i = 0; i < 30; i++) {
    if (tester.takeException() == null) break;
  }
}

/// Decode every bundled PNG before taking screenshots. Widget tests decode
/// images asynchronously, so without this the first screenshot of any screen
/// shows blank art (2026-07-24: boon-card die art was invisible in the
/// evidence shots shipped to the owner).
Future<void> precacheAllImages(WidgetTester tester) async {
  final manifest = await tester.binding.runAsync(
    () => AssetManifest.loadFromAssetBundle(rootBundle),
  );
  final keys = manifest!.listAssets().where((k) => k.endsWith('.png')).toList();
  final context = tester.element(find.byType(MaterialApp));
  await tester.binding.runAsync(() async {
    for (final k in keys) {
      try {
        await precacheImage(AssetImage(k), context);
      } catch (_) {
        /* non-image or corrupt asset: ignore */
      }
    }
  });
  await tester.pump();
}

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 50;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
  drain(tester);
}

int _shotN = 0;
final Set<String> _shotTags = {};
Future<void> shot(WidgetTester tester, String tag, {bool once = true}) async {
  if (once && _shotTags.contains(tag)) return;
  _shotTags.add(tag);
  final boundary =
      rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: pixelRatio),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final name = '${(_shotN++).toString().padLeft(3, '0')}_$tag';
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  log.add('shot: $name (phase=$ctx)');
}

Future<bool> tapButton(
  WidgetTester tester,
  String label, {
  bool startsWith = false,
}) async {
  final f = startsWith
      ? find.byWidgetPredicate(
          (w) => w is EmberButton && (w.label).startsWith(label),
        )
      : find.widgetWithText(EmberButton, label);
  if (f.evaluate().isEmpty) return false;
  // Summary achievements and narrow-phone wrapping can place the restart
  // controls several screens below the current viewport. A raw tester.tap
  // only targets the off-screen RenderBox and silently misses when
  // warnIfMissed is false, making a completed run look "stuck". Scroll the
  // real button into view first; this keeps the probe hit-tested without
  // bypassing production callbacks.
  try {
    await tester.ensureVisible(f.first);
    await tester.pump(const Duration(milliseconds: 100));
  } catch (_) {
    // Screens without a Scrollable still have a directly tappable button.
  }
  await tester.tap(f.first, warnIfMissed: false);
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('interactive play session', (tester) async {
    await loadRealFonts();
    installHook();
    tester.view.physicalSize = shotSize * pixelRatio;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.reset);

    // This is a fresh deterministic session, not a resume test. Reusing the
    // previous run's autosave makes step 1 depend on whichever phase the last
    // invocation happened to leave behind (for example title → player_turn).
    final dir = Directory('$outDir/save');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());

    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildEmberTheme(),
          home: GameRoot(c),
        ),
      ),
    );
    await precacheAllImages(tester);
    await pumpFor(tester, 600);
    ctx = 'title';
    await shot(tester, 'title');

    final rng = Random(42);
    var runsFinished = 0;
    var steps = 0;
    String? lastPhase;
    var stuck = 0;
    var lastPhaseName = 'title';
    Object? countedRun; // the sim instance whose finish was already counted
    log.add('base seed: $baseSeed (run N plays seed base+N)');

    while (runsFinished < 4 && steps++ < 2500) {
      final phase = c.phase ?? 'title';
      ctx = phase;
      checkInvariants(c.state, phase, steps);
      if (phase != lastPhaseName) {
        final allowed = legalNext[lastPhaseName];
        if (allowed == null) {
          violations.add('INVARIANT step $steps: unknown phase $lastPhaseName');
        } else if (!allowed.contains(phase)) {
          violations.add(
            'INVARIANT step $steps: illegal transition $lastPhaseName → $phase',
          );
        }
        final seed = c.sim?.runSeed;
        if (lastPhaseName == 'title' ||
            lastPhaseName == 'run_won' ||
            lastPhaseName == 'run_lost') {
          log.add('run $runsFinished started: phase $phase, seed $seed');
        }
        lastPhaseName = phase;
      }
      // Stuck detection keyed on phase + combat turn + rolled/assigned state,
      // so long fights don't false-positive.
      final pl = (c.state?['player'] as Map?) ?? {};
      final stKey =
          '$phase|t${c.state?['turn']}|r${(pl['rolled'] as List?)?.join(',')}'
          '|a${(pl['assigned'] as Map?)?.length}|hp${pl['hp']}|ehp${(c.state?['enemy'] as Map?)?['hp']}';
      if (stKey == lastPhase) {
        stuck++;
      } else {
        stuck = 0;
        if (phase != (lastPhase ?? '|').split('|').first) {
          await shot(tester, 'run${runsFinished}_$phase');
        }
      }
      lastPhase = stKey;
      if (stuck > 40) {
        violations.add(
          'STUCK: $stKey after 40 identical steps (run $runsFinished)',
        );
        await shot(tester, 'STUCK_$phase', once: false);
        break;
      }

      switch (phase) {
        case 'title':
          // First visit: browse ledger + settings once for coverage.
          if (!_shotTags.contains('ledger')) {
            final gear = find.byIcon(Icons.settings);
            final ledger = find.byIcon(Icons.menu_book);
            if (ledger.evaluate().isNotEmpty) {
              await tester.tap(ledger.first, warnIfMissed: false);
              await pumpFor(tester, 700);
              ctx = 'ledger';
              await shot(tester, 'ledger');
              // find a back affordance
              final back = find.byIcon(Icons.arrow_back);
              if (back.evaluate().isNotEmpty) {
                await tester.tap(back.first, warnIfMissed: false);
              } else {
                Navigator.of(tester.element(find.byType(GameRoot))).pop();
              }
              await pumpFor(tester, 500);
            } else {
              _shotTags.add('ledger');
            }
            if (gear.evaluate().isNotEmpty) {
              await tester.tap(gear.first, warnIfMissed: false);
              await pumpFor(tester, 700);
              ctx = 'settings';
              await shot(tester, 'settings');
              final back = find.byIcon(Icons.arrow_back);
              if (back.evaluate().isNotEmpty) {
                await tester.tap(back.first, warnIfMissed: false);
              } else {
                Navigator.of(tester.element(find.byType(GameRoot))).pop();
              }
              await pumpFor(tester, 500);
            }
          }
          // Determinism: the upcoming startRun (via the character screen or
          // the plain Delve button) consumes this one-shot seed, so run N
          // always plays baseSeed + N regardless of the wall clock.
          c.debugNextRunSeed = baseSeed + runsFinished;
          if (await tapButton(tester, 'Choose a delver')) {
            await pumpFor(tester, 700);
            ctx = 'character';
            await shot(tester, 'character');
            if (!await tapButton(tester, 'Delve as ', startsWith: true)) {
              problems.add('character screen: no "Delve as" button found');
            }
            await pumpFor(tester, 700);
          } else if (await tapButton(tester, 'Delve')) {
            await pumpFor(tester, 700);
          } else {
            problems.add('title: no Delve button found');
          }
          break;
        case 'boon':
          // pick a boon card (not skip) most of the time
          if (rng.nextInt(4) == 0) {
            await tapButton(tester, 'Skip', startsWith: true);
          } else {
            final cards = find.byWidgetPredicate(
              (w) => w is GestureDetector && w.onTap != null,
            );
            // Boon screen cards; tap the first non-button detector
            if (cards.evaluate().isNotEmpty) {
              await tester.tap(cards.first, warnIfMissed: false);
            }
          }
          await pumpFor(tester, 600);
          break;
        case 'map':
          // Tap nodes via their stable ValueKey('map-node-<id>') — the old
          // structural finder (GestureDetector around AnimatedBuilder) rotted
          // when the 2026-07-25 perf pass rebuilt the medallion tree, and the
          // harness spent every map visit reporting 'no tappable node'.
          final m = c.state!['map'] as Map;
          final pos = m['position'] as int;
          final reach = ((m['edges'] as Map)['$pos'] as List).cast<int>();
          if (reach.isEmpty) {
            problems.add('map: no reachable node from position $pos');
            await pumpFor(tester, 400);
            break;
          }
          // Follow the sim bot's macro choice when it has one.
          final cmd = botCmd(c.sim!);
          final targetId =
              (cmd?['type'] == 'choose_node' &&
                  reach.contains(cmd!['node'] as int))
              ? cmd['node'] as int
              : reach[rng.nextInt(reach.length)];
          final nodeF = find.byKey(ValueKey('map-node-$targetId'));
          if (nodeF.evaluate().isEmpty) {
            problems.add('map: node $targetId (reachable) not on screen');
            await pumpFor(tester, 400);
            break;
          }
          try {
            await tester.ensureVisible(nodeF.first);
          } catch (_) {
            // The map can be mid-transition (intro sweep / rebuild) when we
            // probe; a failed scroll-into-view just means this step's tap may
            // miss and the next loop step retries. Never a correctness issue.
          }
          await tester.tap(nodeF.first, warnIfMissed: false);
          await pumpFor(tester, 900);
          break;
        case 'player_turn':
          final cmd = botCmd(c.sim!);
          Finder chips() => find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == 'DieChip',
          );
          Future<void> tapChip(int i) async {
            final f = chips();
            if (f.evaluate().length >= i) {
              await tester.tap(f.at(i - 1), warnIfMissed: false);
              await pumpFor(tester, 200);
            } else {
              problems.add('combat: die chip $i missing');
            }
          }
          switch (cmd?['type']) {
            case 'roll':
              await tapButton(tester, 'Roll');
              await pumpFor(tester, 900);
              break;
            case 'assign':
              await tapChip(cmd!['die'] as int);
              await tapButton(
                tester,
                cmd['action'] == 'block' ? 'Block' : 'Attack',
              );
              await pumpFor(tester, 700);
              break;
            case 'reroll':
              await tapChip(cmd!['die'] as int);
              await tapButton(tester, 'Reroll (', startsWith: true);
              await pumpFor(tester, 500);
              break;
            case 'reroll_risky':
              await tapButton(tester, 'Risky reroll', startsWith: true);
              await pumpFor(tester, 300);
              for (final d in (cmd!['dice'] as List).cast<int>()) {
                await tapChip(d);
              }
              await tapButton(tester, 'Reroll (', startsWith: true);
              await pumpFor(tester, 700);
              break;
            case 'end_turn':
              await tapButton(tester, 'End turn');
              await pumpFor(tester, 1800);
              break;
            default:
              await pumpFor(tester, 500);
          }
          break;
        case 'reward':
          final offers = (c.state!['offers'] as List?)?.cast<String>() ?? [];
          await pumpFor(tester, 220 + offers.length * 240 + 700); // flips
          final cmd = botCmd(c.sim!);
          final idx = (cmd?['type'] == 'choose_reward')
              ? cmd!['index'] as int
              : (offers.isEmpty ? 0 : 1);
          if (idx == 0) {
            await tapButton(tester, 'Skip', startsWith: true);
          } else {
            await tester.tap(
              find.byKey(ValueKey('reward-${offers[idx - 1]}-${idx - 1}')),
              warnIfMissed: false,
            );
          }
          await pumpFor(tester, 800);
          break;
        case 'rest':
          if (!await tapButton(tester, 'Rest — heal 30%')) {
            if (!await tapButton(tester, 'Forge')) {
              // fully rested and nothing to forge → move on via map? The rest
              // screen should always offer an exit; probe for it.
              if (!await tapButton(tester, 'Continue', startsWith: true) &&
                  !await tapButton(tester, 'Move on', startsWith: true) &&
                  !await tapButton(tester, 'Leave', startsWith: true)) {
                problems.add(
                  'rest: no actionable button (fullHp, no forgeable?)',
                );
                c.apply({'type': 'leave_rest'});
              }
            }
          }
          await pumpFor(tester, 700);
          break;
        case 'shop':
          // try one purchase then leave
          final buy = find.byWidgetPredicate(
            (w) =>
                w is EmberButton &&
                int.tryParse(w.label) != null &&
                w.onTap != null,
          );
          if (buy.evaluate().isNotEmpty && rng.nextBool()) {
            await tester.tap(buy.first, warnIfMissed: false);
            await pumpFor(tester, 500);
          }
          await tapButton(tester, 'Leave shop');
          await pumpFor(tester, 700);
          break;
        case 'event':
          final opts = find.byWidgetPredicate(
            (w) => w is EmberButton && w.onTap != null,
          );
          final n = opts.evaluate().length;
          if (n > 0) {
            await tester.tap(opts.at(rng.nextInt(n)), warnIfMissed: false);
          }
          await pumpFor(tester, 700);
          break;
        case 'run_won':
        case 'run_lost':
          // Count each finished run ONCE, keyed on the sim instance: if the
          // restart tap below misses (animation still settling), this case
          // re-enters next step and must not double-count. Pre-fix, a missed
          // tap silently skipped a run's seed (0,1,3 in the report).
          if (!identical(c.sim, countedRun)) {
            countedRun = c.sim;
            runsFinished++;
            await pumpFor(tester, 1200);
            await shot(tester, 'summary_$phase', once: false);
          }
          if (runsFinished < 4) {
            // runsFinished was just incremented: seed the NEXT run.
            c.debugNextRunSeed = baseSeed + runsFinished;
            if (!await tapButton(tester, 'Delve again')) {
              await tapButton(tester, 'Back to the fire');
            }
            await pumpFor(tester, 900);
          }
          break;
        default:
          // choreography/enemy phases — just render
          await pumpFor(tester, 500);
      }
    }

    if (steps >= 2500) violations.add('play loop hit step budget (2500)');
    log.add('runs finished: $runsFinished, steps: $steps');
    await pumpFor(
      tester,
      3200,
    ); // drain animations (covers the 2s call-outs, v0.3.10)

    final report = StringBuffer()
      ..writeln('== PLAY SESSION REPORT ==')
      ..writeln(log.join('\n'))
      ..writeln('-- violations (${violations.length}) — these fail the test --')
      ..writeln(violations.join('\n'))
      ..writeln('-- problems (${problems.length}) — report-only warnings --')
      ..writeln(problems.join('\n'));
    File('$outDir/report.txt').writeAsStringSync(report.toString());
    // UI-probing misses (problems) stay report-only; sim-invariant breaks,
    // stuck loops and budget overruns are real failures with a repro line.
    expect(
      violations,
      isEmpty,
      reason:
          'Invariant violations — reproduce with:\n'
          '  EMBER_SESSION_SEED=$baseSeed flutter test tool/play_session_test.dart\n'
          '${violations.join('\n')}',
    );
    if (runsFinished < 4) {
      fail(
        'only $runsFinished/4 runs finished — reproduce with:\n'
        '  EMBER_SESSION_SEED=$baseSeed flutter test tool/play_session_test.dart',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
