// tool/play_session_test.dart — interactive play harness (tool/, NOT in CI).
// Plays full runs through the REAL UI (real hit-tested taps, real frames),
// screenshots every phase, and records every framework exception. Run:
//
//   flutter test tool/play_session_test.dart
//
// Plays 4 bot-guided runs end to end via hit-tested taps; screenshots land
// in build/play_session/ with a report.txt of every framework exception.
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
final List<String> log = [];
String ctx = 'start';

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
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
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
    problems.add('$ctx: ${details.exceptionAsString().split('\n').first} @$src');
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
  final manifest = await tester.binding
      .runAsync(() => AssetManifest.loadFromAssetBundle(rootBundle));
  final keys =
      manifest!.listAssets().where((k) => k.endsWith('.png')).toList();
  final context = tester.element(find.byType(MaterialApp));
  await tester.binding.runAsync(() async {
    for (final k in keys) {
      try {
        await precacheImage(AssetImage(k), context);
      } catch (_) {/* non-image or corrupt asset: ignore */}
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
Future<void> shot(WidgetTester tester, String tag,
    {bool once = true}) async {
  if (once && _shotTags.contains(tag)) return;
  _shotTags.add(tag);
  final boundary =
      rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image =
      await tester.binding.runAsync(() => boundary.toImage(pixelRatio: pixelRatio));
  final bytes = await tester.binding
      .runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final name = '${(_shotN++).toString().padLeft(3, '0')}_$tag';
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
  log.add('shot: $name (phase=$ctx)');
}

Future<bool> tapButton(WidgetTester tester, String label,
    {bool startsWith = false}) async {
  final f = startsWith
      ? find.byWidgetPredicate((w) =>
          w is EmberButton && (w.label).startsWith(label))
      : find.widgetWithText(EmberButton, label);
  if (f.evaluate().isEmpty) return false;
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

    final dir = Directory('$outDir/save')..createSync(recursive: true);
    final c = GameController(saveDirOverride: dir.path);
    await tester.binding.runAsync(() => c.boot());

    await tester.pumpWidget(RepaintBoundary(
      key: rootKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildEmberTheme(),
        home: GameRoot(c),
      ),
    ));
    await precacheAllImages(tester);
    await pumpFor(tester, 600);
    ctx = 'title';
    await shot(tester, 'title');

    final rng = Random(42);
    var runsFinished = 0;
    var steps = 0;
    String? lastPhase;
    var stuck = 0;

    while (runsFinished < 4 && steps++ < 2500) {
      final phase = c.phase ?? 'title';
      ctx = phase;
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
        problems.add('STUCK: $stKey after 40 identical steps (run $runsFinished)');
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
            final cards = find.byWidgetPredicate((w) =>
                w is GestureDetector && w.onTap != null);
            // Boon screen cards; tap the first non-button detector
            if (cards.evaluate().isNotEmpty) {
              await tester.tap(cards.first, warnIfMissed: false);
            }
          }
          await pumpFor(tester, 600);
          break;
        case 'map':
          final nodesF = find.byWidgetPredicate((w) =>
              w is GestureDetector &&
              w.onTap != null &&
              w.child is AnimatedBuilder);
          final n = nodesF.evaluate().length;
          if (n == 0) {
            problems.add('map: no tappable node found');
            await pumpFor(tester, 400);
            break;
          }
          // Follow the sim bot's macro choice: map its target node id to the
          // build-order index among reachable nodes.
          var tapIndex = rng.nextInt(n);
          final cmd = botCmd(c.sim!);
          if (cmd?['type'] == 'choose_node') {
            final m = c.state!['map'] as Map;
            final pos = m['position'] as int;
            final reach = ((m['edges'] as Map)['$pos'] as List).cast<int>();
            final ordered = [
              for (final k in (m['nodes'] as Map).keys)
                ((m['nodes'] as Map)[k] as Map)['id'] as int
            ].where(reach.contains).toList();
            final want = ordered.indexOf(cmd!['node'] as int);
            if (want >= 0 && want < n) tapIndex = want;
          }
          await tester.tap(nodesF.at(tapIndex), warnIfMissed: false);
          await pumpFor(tester, 900);
          break;
        case 'player_turn':
          final cmd = botCmd(c.sim!);
          Finder chips() => find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == 'DieChip');
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
              await tapButton(tester,
                  cmd['action'] == 'block' ? 'Block' : 'Attack');
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
                warnIfMissed: false);
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
                problems.add('rest: no actionable button (fullHp, no forgeable?)');
                c.apply({'type': 'leave_rest'});
              }
            }
          }
          await pumpFor(tester, 700);
          break;
        case 'shop':
          // try one purchase then leave
          final buy = find.byWidgetPredicate((w) =>
              w is EmberButton &&
              int.tryParse(w.label) != null &&
              w.onTap != null);
          if (buy.evaluate().isNotEmpty && rng.nextBool()) {
            await tester.tap(buy.first, warnIfMissed: false);
            await pumpFor(tester, 500);
          }
          await tapButton(tester, 'Leave shop');
          await pumpFor(tester, 700);
          break;
        case 'event':
          final opts = find.byWidgetPredicate(
              (w) => w is EmberButton && w.onTap != null);
          final n = opts.evaluate().length;
          if (n > 0) {
            await tester.tap(opts.at(rng.nextInt(n)), warnIfMissed: false);
          }
          await pumpFor(tester, 700);
          break;
        case 'run_won':
        case 'run_lost':
          await pumpFor(tester, 1200);
          await shot(tester, 'summary_$phase', once: false);
          runsFinished++;
          if (runsFinished < 4) {
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

    if (steps >= 900) problems.add('play loop hit step budget (900)');
    log.add('runs finished: $runsFinished, steps: $steps');
    await pumpFor(tester, 1500); // drain animations

    final report = StringBuffer()
      ..writeln('== PLAY SESSION REPORT ==')
      ..writeln(log.join('\n'))
      ..writeln('-- problems (${problems.length}) --')
      ..writeln(problems.join('\n'));
    File('$outDir/report.txt').writeAsStringSync(report.toString());
    // Never fail: this is a reconnaissance harness.
    expect(true, isTrue);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
