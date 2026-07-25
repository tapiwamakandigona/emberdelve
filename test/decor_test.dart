// Decor legend (b/r/m/t): purely visual set dressing — parser + lint rules.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/game/level/level_data.dart';

void main() {
  test('decor chars parse into the decor list, not spawns', () {
    final l = LevelData.parse('''
meta: name=T
P..b.r.m..t..E
##############
''');
    expect(l.decor.length, 4);
    expect(l.decor.map((d) => d.kind).toSet(), {
      DecorKind.bush,
      DecorKind.rock,
      DecorKind.shrooms,
      DecorKind.tree,
    });
    // Decor never leaks into gameplay spawns.
    expect(l.spawns.length, 2); // player + exit only
  });

  test('decor must not float: solid ground required below', () {
    expect(
      () => LevelData.parse('''
meta: name=T
....b....
P.......E
#########
'''),
      throwsA(isA<LevelParseException>()),
    );
  });

  test('decor tiles are non-colliding empties', () {
    final l = LevelData.parse('''
meta: name=T
P..b....E
#########
''');
    expect(l.tileAt(3, 0), TileKind.empty);
    expect(l.solidAt(3, 0), isFalse);
  });

  test('every shipped World 1 level parses with its decor', () {
    for (final f in Directory('assets/levels')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'))) {
      final l = LevelData.parse(f.readAsStringSync());
      // Decor pass: every campaign level got at least some set dressing.
      expect(l.decor, isNotEmpty,
          reason: '${f.path} shipped without decoration');
    }
  });
}
