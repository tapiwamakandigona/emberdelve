// Environment selection (World 2 'Cinder Depths'): meta env=cave picks the
// cave tile atlas + parallax family; default stays forest. Asset drift guard:
// every known environment ships a complete art set.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/game/level/level_data.dart';

void main() {
  test('environment defaults to forest, cave via meta', () {
    final forest = LevelData.parse('P..E\n####\n');
    expect(forest.environment, 'forest');
    final cave = LevelData.parse('meta: env=cave\nP..E\n####\n');
    expect(cave.environment, 'cave');
  });

  test('every environment ships a full art set', () {
    for (final env in ['forest', 'cave']) {
      final atlas = env == 'forest'
          ? 'assets/images/tiles/tileset.png'
          : 'assets/images/tiles/tileset_cave.png';
      expect(File(atlas).existsSync(), isTrue, reason: 'missing $atlas');
      for (final layer in ['back', 'middle', 'lights', 'front']) {
        final f = 'assets/images/bg/${env}_$layer.png';
        expect(File(f).existsSync(), isTrue, reason: 'missing $f');
      }
    }
  });
}
