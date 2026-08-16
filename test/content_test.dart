// test/content_test.dart — schema validation for data/ (no hardcoded balance
// numbers; assertions reference the data modules themselves).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/dice.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/relics.dart';
import 'package:emberdelve/data/events.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/boons.dart';
import 'package:emberdelve/sim/run_layer.dart';

/// The seed the long-lived golden replay is anchored to (see test/sim_test.dart).
const int goldenAnchorSeed = 20260723;

const legalDieMods = {
  'attack_bonus',
  'block_bonus',
  'min_value',
  'on_max_bonus',
  'attack_only',
  'block_only',
};
const legalRelicHooks = {
  'max_hp',
  'turn_block',
  'attack_flat',
  'block_flat',
  'min_roll',
  'on_max_gold',
  'thorns',
  'heal_after_fight',
  'gold_bonus',
  'ember_bonus',
  'elite_damage',
  'rest_bonus',
  'rerolls',
  'shop_discount',
};
const legalBoonEffects = {'gold', 'max_hp', 'gain_die', 'embers'};
const legalEffects = {
  'gold',
  'gold_after',
  'hp',
  'max_hp',
  'embers',
  'heal_pct',
  'gain_die',
  'gain_random_die',
  'lose_random_die',
  'gain_random_relic',
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
        expect(
          dice.containsKey(ft),
          isTrue,
          reason: '$id forges to unknown $ft',
        );
      }
    });
    expect(dice.containsKey('d6'), isTrue); // starter must exist
  });

  test('enemies: order matches, bands populated, boss count is seed-safe', () {
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
    // v0.5.0: 3 -> 6 bosses. The old assertion pinned the literal 3, which was
    // really guarding something else: bossForSeed indexes the boss list by
    // `seed % bossCount`, so changing the count re-maps every seed to a
    // different boss and invalidates the golden replays. Assert THAT instead of
    // a magic number — this now fails for the real reason (the golden anchor
    // seed would change boss) rather than merely because content grew.
    // v0.22.0: 6 -> 8 bosses. 20260723 % 8 == 3, so the anchor seed now
    // draws the Cinder Hierophant — a DELIBERATE re-anchor (the third),
    // recorded in docs/improvements/v0.22.0-crowned-deep-design.md with all
    // goldens re-measured twice from real runs. The pin below keeps doing
    // its real job: the NEXT boss-count change must trip here and be
    // re-anchored just as deliberately.
    expect(bosses, equals(8));
    expect(
      bossForSeed(goldenAnchorSeed),
      equals('cinder_hierophant'),
      reason:
          'boss count changed under the golden anchor seed: re-anchor '
          'the golden replays deliberately before shipping this',
    );
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

  test(
    'events: order matches, legal effects, valid gain_die ids, >=12 ids',
    () {
      expect(eventsOrder.toSet(), equals(events.keys.toSet()));
      expect(events.length, greaterThanOrEqualTo(12));
      events.forEach((id, e) {
        expect(e.id, equals(id));
        expect(e.options.isNotEmpty, isTrue);
        for (final o in e.options) {
          for (final k in o.effects.keys) {
            expect(
              legalEffects.contains(k),
              isTrue,
              reason: '$id bad effect $k',
            );
          }
          final gd = o.effects['gain_die'];
          if (gd != null) {
            expect(
              dice.containsKey(gd),
              isTrue,
              reason: '$id gain_die unknown $gd',
            );
          }
        }
      });
    },
  );

  test('events: every event keeps at least one always-legal option', () {
    // Soft-lock guard: an option is refused when it costs gold the player
    // lacks or sheds a die at the 3-die floor. If EVERY option of an event
    // could be refused at once, a broke 3-die player would be stuck on the
    // event screen with nothing to tap. Each event must keep one option
    // that is legal in any state (no gold cost, no lose_random_die).
    events.forEach((id, e) {
      final alwaysLegal = e.options.any(
        (o) =>
            ((o.effects['gold'] as int?) ?? 0) >= 0 &&
            !o.effects.containsKey('lose_random_die'),
      );
      expect(
        alwaysLegal,
        isTrue,
        reason: '$id could soft-lock a player with 0 gold and 3 dice',
      );
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
        expect(
          legalBoonEffects.contains(k),
          isTrue,
          reason: '$id bad effect $k',
        );
      }
      final gd = b.effects['gain_die'];
      if (gd != null) {
        expect(
          dice.containsKey(gd),
          isTrue,
          reason: '$id gain_die unknown $gd',
        );
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
