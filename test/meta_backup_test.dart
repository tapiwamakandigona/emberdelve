// test/meta_backup_test.dart — v0.3.4 save durability (review note #1/#2):
//   1. Every save keeps the PREVIOUS good save as `.bak` (two generations,
//      both promoted/demoted via atomic renames).
//   2. A corrupt or missing main file recovers from `.bak` instead of
//      silently resetting embers/unlocks/stats to zero.
//   3. Recovery heals the main file so it survives an immediate exit.
//   4. Only when BOTH generations are unreadable does load() hand out a
//      fresh profile (the old behavior, now the last resort).
//   5. The schema version is stamped into the file; absent/unknown schemas
//      still load field-tolerantly (v1 files predate the field).
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/meta/meta.dart';

void main() {
  late Directory dir;
  String mainPath() => '${dir.path}/emberdelve_meta.json';
  String bakPath() => '${mainPath()}.bak';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('emberdelve_meta_bak');
    MetaStore.dirOverride = dir.path;
  });

  tearDown(() async {
    MetaStore.dirOverride = null;
    await dir.delete(recursive: true);
  });

  test('save keeps the previous generation as .bak', () async {
    await MetaStore.save(MetaState(embers: 10));
    expect(await File(bakPath()).exists(), isFalse,
        reason: 'first save has no previous generation to demote');

    await MetaStore.save(MetaState(embers: 20));
    expect(await File(bakPath()).exists(), isTrue);
    final bak =
        jsonDecode(await File(bakPath()).readAsString()) as Map<String, dynamic>;
    expect(bak['embers'], 10, reason: '.bak must hold the PREVIOUS save');
    final main = jsonDecode(await File(mainPath()).readAsString())
        as Map<String, dynamic>;
    expect(main['embers'], 20);
  });

  test('corrupt main file recovers from .bak (no silent progress wipe)',
      () async {
    await MetaStore.save(MetaState(embers: 111, runsPlayed: 9, runsWon: 4));
    await MetaStore.save(MetaState(embers: 222, runsPlayed: 10, runsWon: 5));
    // Simulate a crash-corrupted main file (e.g. filesystem truncation).
    await File(mainPath()).writeAsString('{"embers": 999, "runsP');

    final recovered = await MetaStore.load();
    expect(recovered.embers, 111,
        reason: 'must restore the last good generation, not reset');
    expect(recovered.runsPlayed, 9);
    expect(recovered.runsWon, 4);
  });

  test('missing main file recovers from .bak', () async {
    await MetaStore.save(MetaState(embers: 50));
    await MetaStore.save(MetaState(embers: 60));
    // Simulate a crash between the demote and promote renames: main gone,
    // .bak holds the last complete save.
    await File(mainPath()).delete();

    final recovered = await MetaStore.load();
    expect(recovered.embers, 50);
  });

  test('recovery heals the main file (survives immediate exit)', () async {
    await MetaStore.save(MetaState(embers: 77));
    await MetaStore.save(MetaState(embers: 88));
    await File(mainPath()).writeAsString('not json at all');

    final recovered = await MetaStore.load();
    expect(recovered.embers, 77);
    // load() awaits the healing write, so the main file is already whole —
    // and the .bak generation must NOT have been demoted over by the heal.
    final healed = jsonDecode(await File(mainPath()).readAsString())
        as Map<String, dynamic>;
    expect(healed['embers'], 77);
    final bak =
        jsonDecode(await File(bakPath()).readAsString()) as Map<String, dynamic>;
    expect(bak['embers'], 77, reason: '.bak untouched by the heal');
  });

  test('both generations corrupt -> fresh profile, never a crash', () async {
    await File(mainPath()).writeAsString('garbage');
    await File(bakPath()).writeAsString('also garbage');
    final fresh = await MetaStore.load();
    expect(fresh.embers, 0);
    expect(fresh.runsPlayed, 0);
  });

  test('schema version is stamped and old unversioned files still load',
      () async {
    await MetaStore.save(MetaState(embers: 5));
    final written = jsonDecode(await File(mainPath()).readAsString())
        as Map<String, dynamic>;
    expect(written['schema'], metaSchemaVersion);

    // A pre-v0.3.4 file (no schema field) must load unchanged.
    await File(mainPath())
        .writeAsString(jsonEncode({'embers': 42, 'runsPlayed': 3}));
    final legacy = await MetaStore.load();
    expect(legacy.embers, 42);
    expect(legacy.runsPlayed, 3);

    // A FUTURE schema must still parse field-tolerantly (fields it knows).
    await File(mainPath()).writeAsString(
        jsonEncode({'schema': 99, 'embers': 7, 'someFutureField': true}));
    final future = await MetaStore.load();
    expect(future.embers, 7);
  });
}
