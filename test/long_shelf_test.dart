// test/long_shelf_test.dart — v0.180.0 The Long Shelf: two middle rungs so
// the Codex and tale ladders do not jump from 40/10 straight to the whole
// catalog. Targets must sit strictly between the rung below and the
// promise-worded epithet above, and stay inside the live catalogs.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/data/epithets.dart';
import 'package:emberdelve/data/tales.dart';
import 'package:emberdelve/meta/achievements.dart' as ach;
import 'package:emberdelve/meta/meta.dart';

void main() {
  test('the long shelf sits between the forty and the Lettered', () {
    final a = achievements['codex_hundred']!;
    expect(achievementsOrder, contains('codex_hundred'));
    expect(a.stat, 'codex_unsealed');
    expect(a.target, greaterThan(achievements['codex_forty']!.target));
    expect(a.target, lessThan(epithets['the_lettered']!.target));
    expect(a.target, lessThanOrEqualTo(codexEntries.length));
  });

  test('the fireside fixture sits between the regular and the Storied', () {
    final a = achievements['tales_forty']!;
    expect(achievementsOrder, contains('tales_forty'));
    expect(a.stat, 'tales_heard');
    expect(a.target, greaterThan(achievements['tales_ten']!.target));
    expect(a.target, lessThan(epithets['the_storied']!.target));
    expect(a.target, lessThanOrEqualTo(hearthTales.length));
  });

  test('both read the real counters and earn at exactly the target', () {
    final m = MetaState();
    for (var i = 0; i < 100; i++) {
      m.ownedCodex.add(codexEntries[i].id);
    }
    m.hearthTalesHeard = 40;
    expect(ach.isEarned(m, achievements['codex_hundred']!), isTrue);
    expect(ach.isEarned(m, achievements['tales_forty']!), isTrue);
    m.ownedCodex.remove(codexEntries[0].id);
    m.hearthTalesHeard = 39;
    expect(ach.isEarned(m, achievements['codex_hundred']!), isFalse);
    expect(ach.isEarned(m, achievements['tales_forty']!), isFalse);
  });

  test('copy passes the ethics sweep', () {
    const banned = [
      'streak',
      'expire',
      'hurry',
      'miss out',
      'last chance',
      'beat me',
      'bet you',
      'only today',
      "can't",
      'loser',
    ];
    for (final id in ['codex_hundred', 'tales_forty']) {
      final a = achievements[id]!;
      final copy = '${a.name} ${a.text}'.toLowerCase();
      for (final w in banned) {
        expect(copy.contains(w), isFalse, reason: '$id: $w');
      }
    }
  });
}
