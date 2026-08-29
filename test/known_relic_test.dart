// test/known_relic_test.dart — v0.95.0 The Known Relic charter pins.
//
//   1. NO FALLBACKS: every relic in the catalog has its own deliberate
//      relicIcons entry — the lantern fallback is for future ids mid-build,
//      never for shipped relics (14 shipped relics leaned on it pre-0.95).
//   2. READABLE SATCHEL: no icon serves more than two relics, so a full
//      five-relic satchel can never show twins-of-twins.
//   3. NO ORPHANS: every mapped icon name points at a real bundled asset
//      name shape (existence on disk is swept by test/assets_test.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/relics.dart';
import 'package:emberdelve/ui/art.dart';

void main() {
  test('every shipped relic has its own deliberate icon entry', () {
    for (final id in relicsOrder) {
      expect(
        Art.relicIcons.containsKey(id),
        isTrue,
        reason: '$id leans on the lantern fallback',
      );
    }
  });

  test('no icon serves more than two relics', () {
    final counts = <String, List<String>>{};
    for (final id in relicsOrder) {
      counts.putIfAbsent(Art.relicIcons[id]!, () => []).add(id);
    }
    for (final e in counts.entries) {
      expect(
        e.value.length,
        lessThanOrEqualTo(2),
        reason: '${e.key} serves ${e.value}',
      );
    }
    // The lantern now belongs to the Cinder Lantern alone.
    expect(counts['relic_lantern'], ['cinder_lantern']);
  });

  test('no stray map keys for relics that do not exist', () {
    for (final id in Art.relicIcons.keys) {
      expect(relics.containsKey(id), isTrue, reason: id);
    }
  });
}
