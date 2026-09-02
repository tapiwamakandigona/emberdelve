// test/storied_lettered_test.dart — v0.180.0 The Storied and the Lettered.
//
// Two promise-worded epithets ('every tale', 'every page') whose targets
// must track the live catalogs, plus the Bossbane honesty fix: its unlock
// line said 'all three bosses' while the bestiary holds eight. General pin:
// no epithet's unlock line may claim 'all' or 'every' of something its
// target does not actually cover.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/epithets.dart';
import 'package:emberdelve/data/tales.dart';

void main() {
  test('the Storied asks for exactly one pass through the tales', () {
    final e = epithets['the_storied']!;
    expect(e.stat, 'tales_heard');
    expect(e.target, hearthTales.length, reason: 'promise-worded');
    // Sequential walk: after `length` hollows every tale was heard once.
    final heard = <String>{};
    for (var i = 0; i < hearthTales.length; i++) {
      heard.add(hearthTale(i));
    }
    expect(heard.length, hearthTales.length);
  });

  test('the Lettered asks for the whole Codex', () {
    final e = epithets['the_lettered']!;
    expect(e.stat, 'codex_unsealed');
    expect(e.target, codexEntries.length, reason: 'promise-worded');
  });

  test('both sit before the Proven, which stays last', () {
    expect(epithetsOrder.last, 'the_proven');
    expect(
      epithetsOrder.indexOf('the_storied'),
      lessThan(epithetsOrder.length - 1),
    );
    expect(
      epithetsOrder.indexOf('the_lettered'),
      lessThan(epithetsOrder.length - 1),
    );
    for (final id in epithetsOrder) {
      expect(epithets.containsKey(id), isTrue, reason: id);
    }
    expect(epithets.length, epithetsOrder.length);
  });

  test('the Bossbane no longer claims all of a bestiary it does not cover', () {
    final e = epithets['the_bossbane']!;
    final bosses = enemies.values.where((d) => d.boss).length;
    expect(bosses, 8);
    expect(e.target, 3, reason: 'a worn title never re-locks');
    expect(e.unlockLine.toLowerCase().contains('all'), isFalse);
    expect(e.unlockLine.contains('three'), isTrue);
  });

  test('no unlock line says "all"/"every" of a catalog its target skips', () {
    // Catalogs an epithet could promise in full, by stat.
    final full = <String, int>{
      'tales_heard': hearthTales.length,
      'codex_unsealed': codexEntries.length,
      'bosses_beaten': enemies.values.where((d) => d.boss).length,
    };
    for (final e in epithets.values) {
      final l = e.unlockLine.toLowerCase();
      final promises = l.contains('every') || l.contains(' all ');
      if (promises && full.containsKey(e.stat)) {
        expect(e.target, full[e.stat], reason: '${e.id}: "${e.unlockLine}"');
      }
    }
  });
}
