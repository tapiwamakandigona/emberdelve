// Bit-parity of lib/sim/rng.dart against Lua-generated vectors
// (test/fixtures/rng_vectors.json, produced by tool/parity/gen_fixtures.lua).
import 'dart:convert';
import 'dart:io';

import 'package:emberdelve/sim/rng.dart';
import 'package:test/test.dart';

void main() {
  final fixture = jsonDecode(
          File('test/fixtures/rng_vectors.json').readAsStringSync())
      as Map<String, dynamic>;
  final cases = fixture['cases'] as List;

  test('rng vectors: ${cases.length} Lua cases reproduce bit-identically', () {
    expect(cases, isNotEmpty);
    for (final c in cases.cast<Map<String, dynamic>>()) {
      final rng = Rng(c['seed'] as int, c['domain'] as String);
      final raws = (c['raws'] as List).cast<int>();
      for (var i = 0; i < raws.length; i++) {
        expect(rng.nextRaw(), raws[i],
            reason: 'seed=${c['seed']} domain=${c['domain']} raw #${i + 1}');
      }
      for (final r in (c['ranges'] as List).cast<Map<String, dynamic>>()) {
        expect(rng.range(r['lo'] as int, r['hi'] as int), r['value'],
            reason:
                'seed=${c['seed']} domain=${c['domain']} range ${r['lo']}..${r['hi']}');
      }
      final want = c['final'] as Map<String, dynamic>;
      expect(rng.snapshot(), want,
          reason: 'seed=${c['seed']} domain=${c['domain']} final snapshot');
    }
  });

  test('rng snapshot/restore round-trip continues identically', () {
    final a = Rng(20260723, 'combat');
    for (var i = 0; i < 7; i++) {
      a.nextRaw();
    }
    final b = Rng.restore(jsonDecode(jsonEncode(a.snapshot())) as Map<String, dynamic>);
    for (var i = 0; i < 50; i++) {
      expect(b.nextRaw(), a.nextRaw());
    }
  });

  test('streams are independent', () {
    final a = Rng(42, 'map');
    final b = Rng(42, 'combat');
    final bFresh = Rng(42, 'combat');
    for (var i = 0; i < 100; i++) {
      a.nextRaw(); // consuming map must not shift combat
    }
    for (var i = 0; i < 20; i++) {
      expect(b.nextRaw(), bFresh.nextRaw());
    }
  });
}
