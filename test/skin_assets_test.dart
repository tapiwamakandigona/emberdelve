// Skin/catalog drift guard: every purchasable skin in the catalog must ship
// complete sprite sheets (all 9 animation strips), or players would pay for
// an invisible cosmetic. 'red' is the base sheet set in images/player/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:emberwood/meta/catalog.dart';

const _anims = [
  'idle', 'run', 'jump', 'fall', 'hit', 'roll',
  'attack1', 'attack2', 'attack3',
];

void main() {
  test('every catalog skin has all animation sheets bundled', () {
    final missing = <String>[];
    for (final skin in kSkins) {
      final dir = skin.id == 'red'
          ? 'assets/images/player'
          : 'assets/images/player/skins/${skin.id}';
      for (final anim in _anims) {
        final f = File('$dir/$anim.png');
        if (!f.existsSync()) missing.add('${skin.id}: $dir/$anim.png');
      }
    }
    expect(missing, isEmpty,
        reason: 'catalog skins without complete sheets: $missing');
  });

  test('skin sheets match the base sheet dimensions', () {
    // Same frame grid as the base knight: a mismatched sheet would render
    // garbage frames. Cheap header check (PNG IHDR width/height).
    (int, int) pngSize(File f) {
      final b = f.readAsBytesSync();
      int be32(int o) =>
          (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
      return (be32(16), be32(20));
    }

    final bad = <String>[];
    for (final skin in kSkins.where((s) => s.id != 'red')) {
      for (final anim in _anims) {
        final base = pngSize(File('assets/images/player/$anim.png'));
        final skinned =
            pngSize(File('assets/images/player/skins/${skin.id}/$anim.png'));
        if (base != skinned) bad.add('${skin.id}/$anim: $skinned != $base');
      }
    }
    expect(bad, isEmpty, reason: 'sheet size drift: $bad');
  });
}
