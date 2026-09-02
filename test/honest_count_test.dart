// test/honest_count_test.dart — v0.180.0 The Honest Count.
//
// Hearth tale 5 is the first thing the fire says about the company, and
// the v0.120.0 rule stands: position 5 must never state a count the delver
// picker disproves one screen away. It said "Sixteen keep this fire" while
// the picker showed twenty-two chairs under two circle headers. It now
// counts twenty-two in two circles — and this test ties the words to the
// roster so the next chair trips the tale, not a player.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/epithets.dart';
import 'package:emberdelve/data/tales.dart';

const _words = {6: 'six', 16: 'sixteen', 22: 'twenty-two', 23: 'twenty-three'};

void main() {
  test('tale 5 counts the live roster, in two circles', () {
    final tale = hearthTales[4].toLowerCase();
    final n = characters.length;
    expect(
      _words[n],
      isNotNull,
      reason: 'roster is $n: add its word here and re-tell tale 5',
    );
    expect(tale, startsWith(_words[n]!), reason: tale);
    expect(tale, contains('two circles'));
    expect(tale, contains('sixteen'), reason: 'the first circle is named');
    // The first circle is sixteen exactly; the second holds the rest.
    expect(charactersOrder.indexOf('hearthkeeper'), 15);
    expect(_words[n - 16] ?? '${n - 16}', 'six');
    expect(tale, contains('six who drew the second'));
    expect(hearthTales[4].length, lessThanOrEqualTo(200));
  });

  test('the Many-Handed tale asks as many ways down as the honor does', () {
    final i = hearthTales.indexWhere((t) => t.contains('Many-Handed'));
    expect(i, greaterThan(0));
    final tale = hearthTales[i].toLowerCase();
    final n = characters.length;
    expect(epithets['the_six_handed']!.target, n, reason: 'promise-worded');
    expect(tale, contains('${_words[n]} ways down'), reason: tale);
  });
}
