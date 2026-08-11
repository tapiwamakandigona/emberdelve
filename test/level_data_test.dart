import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/game/level/level_data.dart';

const _good = '''
meta: name=Test Grove
meta: par_s=45
..........
..P....c.E
##########
''';

void main() {
  group('LevelData.parse', () {
    test('parses grid, meta, and spawns', () {
      final l = LevelData.parse(_good);
      expect(l.name, 'Test Grove');
      expect(l.parSeconds, 45);
      expect(l.width, 10);
      expect(l.height, 3);
      expect(l.playerSpawn.x, 2);
      expect(l.playerSpawn.y, 1);
      expect(l.exit.x, 9);
      expect(l.solidAt(0, 2), isTrue);
      expect(l.solidAt(0, 1), isFalse);
      expect(l.spawns.where((s) => s.kind == SpawnKind.coin).length, 1);
    });

    test('out-of-bounds: sides solid, sky and pit open', () {
      final l = LevelData.parse(_good);
      expect(l.solidAt(-1, 1), isTrue);
      expect(l.solidAt(10, 1), isTrue);
      expect(l.tileAt(2, -5), TileKind.empty);
      expect(l.tileAt(2, 99), TileKind.empty);
    });

    test('pads short rows with empty', () {
      final l = LevelData.parse('P.E\n###\n#');
      expect(l.width, 3);
      expect(l.tileAt(2, 2), TileKind.empty);
    });

    test('rejects unknown characters', () {
      expect(() => LevelData.parse('P?E\n###'),
          throwsA(isA<LevelParseException>()));
    });

    test('rejects missing/duplicate player or exit', () {
      expect(() => LevelData.parse('..E\n###'),
          throwsA(isA<LevelParseException>()));
      expect(() => LevelData.parse('P.P.E\n#####'),
          throwsA(isA<LevelParseException>()));
      expect(() => LevelData.parse('P....\n#####'),
          throwsA(isA<LevelParseException>()));
    });

    test('rejects spawn with no safe ground below', () {
      expect(() => LevelData.parse('P.E\n^##'),
          throwsA(isA<LevelParseException>()));
    });

    test('secret chests count as chests and secrets', () {
      final l = LevelData.parse('P.X.C.E\n#######');
      expect(l.chestCount, 2);
      expect(l.secretCount, 1);
    });
  });

  group('shipped levels', () {
    test('every asset level parses and lints clean', () {
      final dir = Directory('assets/levels');
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.txt'))
          .toList();
      expect(files, isNotEmpty,
          reason: 'assets/levels must contain at least one level');
      for (final f in files) {
        final l = LevelData.parse(f.readAsStringSync());
        expect(l.chestCount, greaterThanOrEqualTo(0));
        // Tutorial promise (PROJECT.md §8): w1_l1 must carry signposts.
        if (f.path.endsWith('w1_l1.txt')) {
          expect(l.spawns.where((s) => s.kind == SpawnKind.sign).length,
              greaterThanOrEqualTo(2),
              reason: 'w1_l1 is the tutorial level — needs signs');
        }
      }
    });
  });
}
