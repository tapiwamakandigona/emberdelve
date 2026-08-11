import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/core/rng.dart';

void main() {
  test('deterministic across instances, domain-separated', () {
    final a = Rng.create(42, 'drops');
    final b = Rng.create(42, 'drops');
    final c = Rng.create(42, 'daily');
    final seqA = List.generate(20, (_) => a.range(0, 999));
    final seqB = List.generate(20, (_) => b.range(0, 999));
    final seqC = List.generate(20, (_) => c.range(0, 999));
    expect(seqA, seqB);
    expect(seqA, isNot(seqC));
  });

  test('snapshot/restore resumes the stream exactly', () {
    final r = Rng.create(7, 'combat');
    r.range(1, 6);
    final snap = r.snapshot();
    final next = r.range(1, 1000);
    final restored = Rng.restore(snap.cast<String, dynamic>());
    expect(restored.range(1, 1000), next);
  });

  test('range respects bounds', () {
    final r = Rng.create(1, 'x');
    for (var i = 0; i < 1000; i++) {
      final v = r.range(3, 9);
      expect(v, inInclusiveRange(3, 9));
    }
  });
}
