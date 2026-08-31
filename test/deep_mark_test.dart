// test/deep_mark_test.dart — v0.155.0 The Deep Mark.
//
// A mark carries a tier (1 or 2). Tempering the SAME face with the SAME rune
// again deepens the mark in place — no new custom id — and every rune pays
// one step more when deep: blade/aegis +3, echo arms 2, mend 2, gilt 3,
// surge twice per die per turn. The 'tier' save key is OPTIONAL: pre-v0.155
// custom dice lack it and resolve to tier 1, so old saves keep their exact
// old meaning.
import 'package:emberdelve/sim/assignment.dart';
import 'package:emberdelve/sim/combat.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:flutter_test/flutter_test.dart';

Sim _inCombat(String rune, {int face = 3, int tier = 2}) {
  final sim = Sim(123)..apply({'type': 'start_run'});
  sim.run!['custom_dice'] = {
    'custom_1': {'base': 'd6', 'face': face, 'rune': rune, 'tier': tier},
  };
  sim.player['dice'] = <String>['custom_1'];
  combatBegin(sim, 'cinder_wisp', false, [], layer: 2);
  return sim;
}

void _pinRoll(Sim sim, int face) {
  sim.player['rolled'] = <int>[face];
  sim.player['rolled_face'] = <int>[face];
  sim.player['rolled_max'] = <bool>[false];
  sim.player['combo_bonus'] = <int>[0];
  sim.player['assigned'] = <String, String>{};
}

void main() {
  test('tier is optional in the save shape and bounded when present', () {
    final run = {
      'custom_dice': {
        'custom_1': {'base': 'd6', 'face': 2, 'rune': 'blade'},
        'custom_2': {'base': 'd6', 'face': 2, 'rune': 'blade', 'tier': 2},
        'custom_3': {'base': 'd6', 'face': 2, 'rune': 'blade', 'tier': 3},
        'custom_4': {'base': 'd6', 'face': 2, 'rune': 'blade', 'tier': 'x'},
      },
    };
    // Pre-v0.155 shape (no key) resolves to tier 1 — old saves unchanged.
    expect(resolveRunDie(run, 'custom_1').tier, 1);
    expect(resolveRunDie(run, 'custom_2').tier, 2);
    expect(() => resolveRunDie(run, 'custom_3'), throwsStateError);
    expect(() => resolveRunDie(run, 'custom_4'), throwsStateError);
  });

  test('deep copy exists for every rune and stays honest', () {
    for (final rune in faceRunes) {
      expect(runeDeepBlurb(rune), isNotEmpty, reason: rune);
    }
    expect(runeTierName('blade', 1), 'Blade');
    expect(runeTierName('blade', 2), 'Blade II');
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
    for (final rune in faceRunes) {
      final copy = runeDeepBlurb(rune).toLowerCase();
      for (final word in banned) {
        expect(copy.contains(word), isFalse, reason: '$rune says "$word"');
      }
    }
  });

  test('the same face and rune deepens the mark in place', () {
    final sim = Sim(9)..apply({'type': 'start_run'});
    sim.run!['custom_dice'] = {
      'custom_1': {'base': 'd6', 'face': 4, 'rune': 'blade'},
    };
    final pool = (sim.player['dice'] as List);
    pool[0] = 'custom_1';
    sim.phase = 'rest';
    final events = sim.apply({
      'type': 'temper_face',
      'die': 1,
      'face': 4,
      'rune': 'blade',
    });
    final e = events.firstWhere((e) => e['type'] == 'face_tempered');
    expect(e['tier'], 2);
    expect(e['custom'], 'custom_1', reason: 'no new custom id');
    expect(pool[0], 'custom_1');
    expect(resolveRunDie(sim.run, 'custom_1').tier, 2);
    // The deepen still spends a temper and still banks the rune.
    expect(sim.run!['tempers_used'], 1);
    expect((sim.run!['runes_tempered'] as List).last, 'blade');
  });

  test('a mark already deep rejects honestly', () {
    final sim = Sim(9)..apply({'type': 'start_run'});
    sim.run!['custom_dice'] = {
      'custom_1': {'base': 'd6', 'face': 4, 'rune': 'blade', 'tier': 2},
    };
    (sim.player['dice'] as List)[0] = 'custom_1';
    sim.phase = 'rest';
    final events = sim.apply({
      'type': 'temper_face',
      'die': 1,
      'face': 4,
      'rune': 'blade',
    });
    expect(
      events.any(
        (e) => e['type'] == 'invalid_command' && e['reason'] == 'already_deep',
      ),
      isTrue,
    );
    expect(sim.run!['tempers_used'], 0, reason: 'no temper wasted');
  });

  test('a different face or rune on a marked die re-tempers, tier 1', () {
    final sim = Sim(9)..apply({'type': 'start_run'});
    sim.run!['custom_dice'] = {
      'custom_1': {'base': 'd6', 'face': 4, 'rune': 'blade', 'tier': 2},
    };
    final pool = (sim.player['dice'] as List);
    pool[0] = 'custom_1';
    // The injected mark took the id the counter would mint next.
    sim.run!['next_custom_die'] = 2;
    sim.phase = 'rest';
    final events = sim.apply({
      'type': 'temper_face',
      'die': 1,
      'face': 5,
      'rune': 'gilt',
    });
    final e = events.firstWhere((e) => e['type'] == 'face_tempered');
    expect(e['tier'], 1);
    expect(e['custom'], isNot('custom_1'), reason: 'fresh mark, fresh id');
    expect(resolveRunDie(sim.run, pool[0] as String).tier, 1);
  });

  test('deep blade hits for +3, deep aegis holds +3', () {
    for (final (rune, action) in [('blade', 'attack'), ('aegis', 'block')]) {
      final sim = _inCombat(rune);
      _pinRoll(sim, 3);
      final r = resolveAssignment(
        player: sim.player,
        enemy: sim.enemy!,
        run: sim.run,
        die: 1,
        action: action,
      );
      expect(r.runeBonus, 3, reason: rune);
      expect(r.runeTier, 2, reason: rune);
      // And tier 1 still pays exactly 2 — old marks unchanged.
      final sim1 = _inCombat(rune, tier: 1);
      _pinRoll(sim1, 3);
      final r1 = resolveAssignment(
        player: sim1.player,
        enemy: sim1.enemy!,
        run: sim1.run,
        die: 1,
        action: action,
      );
      expect(r1.runeBonus, 2, reason: rune);
    }
  });

  test('deep mend banks 2, deep gilt pays 3, deep echo arms 2', () {
    final mend = _inCombat('mend');
    mend.player['hp'] = 5;
    _pinRoll(mend, 3);
    mend.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
    expect(mend.player['hp'], 7);

    final gilt = _inCombat('gilt');
    final gold0 = gilt.run!['gold'] as int;
    _pinRoll(gilt, 3);
    gilt.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
    expect(gilt.run!['gold'], gold0 + 3);

    final echo = _inCombat('echo');
    _pinRoll(echo, 3);
    echo.apply({'type': 'assign', 'die': 1, 'action': 'attack'});
    final pending = echo.player['echo_pending'] as Map?;
    expect(pending, isNotNull);
    expect(pending!['amount'], 2);
  });

  test('deep surge returns the reroll twice per die per turn, never thrice', () {
    // Seeded search (face_forge idiom): a tier-2 surge d6 whose opening roll
    // lands the tempered face, then charge rerolls until it lands again.
    // Grants must track landings but cap at the tier: 2.
    var provedSecond = false;
    for (var seed = 1; seed <= 400 && !provedSecond; seed++) {
      final sim = Sim(seed)..apply({'type': 'start_run'});
      sim.run!['custom_dice'] = {
        'custom_1': {'base': 'd6', 'face': 4, 'rune': 'surge', 'tier': 2},
      };
      sim.player['dice'] = <String>['custom_1', 'd6'];
      combatBegin(sim, 'cinder_wisp', false, [], layer: 2);
      final events = sim.apply({'type': 'roll'});
      if (!events.any((e) => e['type'] == 'reroll_gained')) continue;
      var grants = 1;
      var landings = 1;
      for (var i = 0; i < 60; i++) {
        if ((sim.player['rerolls_left'] as int? ?? 0) <= 0) break;
        final evs = sim.apply({'type': 'reroll', 'die': 1});
        if ((sim.player['rolled_face'] as List)[0] == 4) landings++;
        if (evs.any((e) => e['type'] == 'reroll_gained')) grants++;
        // The allowance is exactly the tier: two grants, then silence.
        expect(grants, landings.clamp(0, 2), reason: 'seed $seed');
      }
      if (grants >= 2) provedSecond = true;
    }
    expect(provedSecond, isTrue, reason: 'no seed landed the face twice');
  });
}
