// test/written_rules_test.dart — v0.131.0 The Written Rules.
//
// Codex 'rule' kind: six entries, one per weekly rule, names mirroring
// the live mutator catalog (a renamed rule can never drift from its
// codex page), priced like places, buyable through the standard flow.
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/data/mutators.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/weekly.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('six rule entries: five singles mirroring mutators + the quarter', () {
    final rules = codexEntries.where((e) => e.kind == 'rule').toList();
    expect(rules.map((e) => e.refId).toList(), [
      ...mutatorsOrder,
      'cold_quarter',
      'lean_road',
      'hard_march',
    ]);
    for (final e in rules) {
      expect(e.costEmbers, 10, reason: 'calendar words price like places');
      expect(e.text.trim(), isNotEmpty);
    }
  });

  test('rule display names mirror the live rotation names', () {
    for (final id in mutatorsOrder) {
      expect(
        ruleNames[id],
        mutatorDef(id).name,
        reason: 'codex name must not drift from the mutator catalog',
      );
    }
    expect(ruleNames['cold_quarter'], doubledWeek.name);
    expect(ruleNames['lean_road'], leanRoad.name);
    expect(ruleNames['hard_march'], hardMarch.name);
  });

  test('rule entries buy through the standard codex flow', () {
    final c = GameController();
    c.meta.embers = 25;
    expect(c.buyCodexEntry('rule:all_d4'), isTrue);
    expect(c.meta.ownedCodex, contains('rule:all_d4'));
    expect(c.meta.embers, 15);
    expect(c.buyCodexEntry('rule:all_d4'), isFalse, reason: 'owned refuses');
    c.meta.embers = 5;
    expect(c.buyCodexEntry('rule:no_rests'), isFalse, reason: 'broke refuses');
  });

  test('rule lore is honest (no pressure language)', () {
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
    for (final e in codexEntries.where((e) => e.kind == 'rule')) {
      final t = e.text.toLowerCase();
      for (final b in banned) {
        expect(t.contains(b), isFalse, reason: '${e.id} banned: $b');
      }
    }
  });
}
