// BOOT COST PROBE (2026-09-01) — not part of the regular suite; run
// explicitly with `flutter test tool/boot_cost_probe_test.dart`.
//
// Question: how expensive is the pre-first-frame path for a maxed
// VETERAN save — the worst realistic case — versus a fresh profile?
// The boot path (post-Swifter-Lantern) awaits controller.boot() inside
// a Future.wait before runApp, so meta-file size directly gates time
// to first frame. This probe times:
//   1. MetaStore.load() on a maxed meta file (every codex entry,
//      achievement, tale, tip, track, skin/dye/theme, all 16 delvers'
//      per-character tallies) — read + jsonDecode + fromJson.
//   2. GameController.boot() end-to-end with that file plus a mid-run
//      autosave snapshot to restore.
//   3. First TitleScreen build+layout+paint on a cold widget tree.
// Numbers land in stdout; interpretation goes to progress.md, not
// asserts — timings on CI hardware are indicative, not gates. The one
// hard assert: the maxed meta file itself stays under 64 KB, so a
// veteran save can never grow into a jank-relevant read.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/screens.dart';

import '../test/support/maxed_meta.dart';


Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('boot_probe');
    MetaStore.dirOverride = dir.path;
  });

  tearDown(() {
    MetaStore.dirOverride = null;
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('maxed veteran meta file stays small (hard gate: < 64 KB)', () async {
    final m = maxedMeta();
    final bytes = utf8.encode(jsonEncode(m.toJson())).length;
    // ignore: avoid_print
    print('PROBE maxed meta json size: $bytes bytes');
    expect(bytes, lessThan(64 * 1024),
        reason: 'meta save grew past 64 KB — boot read is on the '
            'first-frame critical path; investigate what ballooned');
  });

  test('MetaStore.load timing on maxed veteran file', () async {
    final m = maxedMeta();
    File('${dir.path}/emberdelve_meta.json')
        .writeAsStringSync(jsonEncode(m.toJson()));
    // Warm the JIT once, then measure a fresh load.
    await MetaStore.load();
    final sw = Stopwatch()..start();
    final loaded = await MetaStore.load();
    sw.stop();
    // ignore: avoid_print
    print('PROBE MetaStore.load (maxed, warm): ${sw.elapsedMicroseconds} us');
    expect(loaded.ownedCodex.length, codexEntries.length);
  });

  testWidgets('boot() + first TitleScreen frame timing (veteran)',
      (tester) async {
    final m = maxedMeta();
    File('${dir.path}/emberdelve_meta.json')
        .writeAsStringSync(jsonEncode(m.toJson()));

    final c = GameController(saveDirOverride: dir.path);
    late Duration bootTime;
    await tester.runAsync(() async {
      final sw = Stopwatch()..start();
      await c.boot();
      sw.stop();
      bootTime = sw.elapsed;
    });
    // ignore: avoid_print
    print('PROBE controller.boot (veteran): ${bootTime.inMicroseconds} us');

    final sw = Stopwatch()..start();
    await tester.pumpWidget(MaterialApp(home: TitleScreen(c)));
    sw.stop();
    // ignore: avoid_print
    print('PROBE first TitleScreen frame: ${sw.elapsedMicroseconds} us');
    expect(find.byType(TitleScreen), findsOneWidget);
  });

  testWidgets('boot() timing (fresh profile, for contrast)', (tester) async {
    final c = GameController(saveDirOverride: dir.path);
    late Duration bootTime;
    await tester.runAsync(() async {
      final sw = Stopwatch()..start();
      await c.boot();
      sw.stop();
      bootTime = sw.elapsed;
    });
    // ignore: avoid_print
    print('PROBE controller.boot (fresh): ${bootTime.inMicroseconds} us');
    expect(c.meta.runsPlayed, 0);
  });
}
