// test/content_test.dart — schema validation for data/ (no hardcoded balance
// numbers; assertions reference the data modules themselves).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/relics.dart';
import 'package:emberdelve/data/events.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/boons.dart';

const legalDieMods = {
  'attack_bonus', 'block_bonus', 'min_value', 'on_max_bonus',
  'attack_only', 'block_only'
};
const legalRelicHooks = {
  'max_hp', 'turn_block', 'attack_flat', 'block_flat', 'min_roll',
  'on_max_gold', 'thorns', 'heal_after_fight', 'gold_bonus', 'ember_bonus',
  'elite_damage', 'rest_bonus', 'rerolls', 'shop_discount'
};
const legalBoonEffects = {'gold', 'max_hp', 'gain_die', 'embers'};
const legalEffects = {
  'gold', 'gold_after', 'hp', 'max_hp', 'embers', 'heal_pct', 'gain_die',
  'gain_random_die', 'lose_random_die', 'gain_random_relic'
};

void main() {
  test('dice: order matches map, legal mods, valid forgeTo, >=10 ids', () {
    expect(diceOrder.toSet(), equals(dice.keys.toSet()));
    expect(dice.length, greaterThanOrEqualTo(10));
    dice.forEach((id, d) {
      expect(d.id, equals(id));
      expect(d.size, greaterThanOrEqualTo(4));
      expect([1, 2, 3].contains(d.tier), isTrue);
      for (final k in d.mods.keys) {
        expect(legalDieMods.contains(k), isTrue, reason: '$id bad mod $k');
      }
      for (final ft in d.forgeTo) {
        expect(dice.containsKey(ft), isTrue, reason: '$id forges to unknown $ft');
      }
    });
    expect(dice.containsKey('d6'), isTrue); // starter must exist
  });

  test('enemies: order matches, >=3 regular + >=1 elite + exactly 3 bosses', () {
    expect(enemiesOrder.toSet(), equals(enemies.keys.toSet()));
    var regs = 0, elites = 0, bosses = 0;
    enemies.forEach((id, e) {
      expect(e.id, equals(id));
      expect(e.hp, greaterThan(0));
      expect(e.pattern.isNotEmpty, isTrue);
      for (final it in e.pattern) {
        expect(['attack', 'block', 'attack_block'].contains(it.kind), isTrue);
        expect(it.amount, greaterThanOrEqualTo(0));
      }
      if (e.boss) {
        bosses++;
      } else if (e.elite) {
        elites++;
      } else {
        regs++;
      }
    });
    expect(regs, greaterThanOrEqualTo(3));
    expect(elites, greaterThanOrEqualTo(1));
    expect(bosses, equals(3));
  });

  test('relics: order matches, legal hooks, >=20 ids', () {
    expect(relicsOrder.toSet(), equals(relics.keys.toSet()));
    expect(relics.length, greaterThanOrEqualTo(20));
    relics.forEach((id, r) {
      expect(r.id, equals(id));
      expect(r.hooks.isNotEmpty, isTrue);
      for (final k in r.hooks.keys) {
        expect(legalRelicHooks.contains(k), isTrue, reason: '$id bad hook $k');
      }
    });
  });

  test('events: order matches, legal effects, valid gain_die ids, >=12 ids', () {
    expect(eventsOrder.toSet(), equals(events.keys.toSet()));
    expect(events.length, greaterThanOrEqualTo(12));
    events.forEach((id, e) {
      expect(e.id, equals(id));
      expect(e.options.isNotEmpty, isTrue);
      for (final o in e.options) {
        for (final k in o.effects.keys) {
          expect(legalEffects.contains(k), isTrue, reason: '$id bad effect $k');
        }
        final gd = o.effects['gain_die'];
        if (gd != null) {
          expect(dice.containsKey(gd), isTrue, reason: '$id gain_die unknown $gd');
        }
      }
    });
  });

  test('boons: order matches, legal effects, valid gain_die ids, >=6 ids', () {
    expect(boonsOrder.toSet(), equals(boons.keys.toSet()));
    expect(boons.length, greaterThanOrEqualTo(6));
    boons.forEach((id, b) {
      expect(b.id, equals(id));
      expect(b.name.isNotEmpty, isTrue);
      expect(b.effects.isNotEmpty, isTrue);
      for (final k in b.effects.keys) {
        expect(legalBoonEffects.contains(k), isTrue, reason: '$id bad effect $k');
      }
      final gd = b.effects['gain_die'];
      if (gd != null) {
        expect(dice.containsKey(gd), isTrue, reason: '$id gain_die unknown $gd');
      }
    });
  });

  test('characters: default exists, valid start dice + relics', () {
    expect(characters.containsKey(defaultCharacter), isTrue);
    expect(charactersOrder.toSet(), equals(characters.keys.toSet()));
    characters.forEach((id, c) {
      expect(c.maxHp, greaterThanOrEqualTo(10));
      for (final d in c.startDice) {
        expect(dice.containsKey(d), isTrue, reason: '$id start die unknown $d');
      }
      if (c.startRelic != null) {
        expect(relics.containsKey(c.startRelic), isTrue);
      }
    });
    expect(characters[defaultCharacter]!.unlockEmbers, equals(0));
  });
}
