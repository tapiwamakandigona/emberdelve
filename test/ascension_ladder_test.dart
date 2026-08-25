// test/ascension_ladder_test.dart — v0.20.0 "The Living Ladder" gates.
//
// The ladder's contract: rung N+1 unlocks only by WINNING rung N, so every
// rung 1..20 must be (a) strictly a challenge step and (b) actually
// winnable. Before v0.20.0 the flat +rung bonus measured 0.0% bot win at
// A12+ for all characters — rungs 13-20 were sold but unreachable.
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/sim/combat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rung 0 is byte-neutral (golden anchor safety)', () {
    for (final layer in [1, 2, 3, 4, 5, 6, 7, 8, 99]) {
      expect(ascensionAttackBonus(0, layer), 0);
    }
    expect(ascensionHpScalar(0), 1.0);
  });

  test('attack ramp is layer-scaled and monotone in rung', () {
    // The door stays open: early layers take at most +3 even at A20.
    expect(ascensionAttackBonus(20, 2), 3);
    expect(ascensionAttackBonus(20, 5), 5);
    expect(ascensionAttackBonus(20, 8), 7);
    expect(ascensionAttackBonus(20, 99), 7); // boss default bracket
    for (final layer in [2, 5, 8]) {
      for (var rung = 1; rung <= 20; rung++) {
        expect(
          ascensionAttackBonus(rung, layer),
          greaterThanOrEqualTo(ascensionAttackBonus(rung - 1, layer)),
          reason: 'rung $rung layer $layer regressed',
        );
      }
    }
  });

  test('every rung changes the fight (HP term strictly climbs)', () {
    for (var rung = 1; rung <= 20; rung++) {
      expect(
        ascensionHpScalar(rung),
        greaterThan(ascensionHpScalar(rung - 1)),
        reason: 'rung $rung must be tougher than rung ${rung - 1}',
      );
    }
  });

  test('the ladder is alive: A20 is winnable for every character', () {
    // Pinned bot-won seeds (tool/asc_seed_hunt_test.dart, 2026-08-16). The
    // bot is a lower bound on humans: if it can win A20, the climb exists.
    // A balance change that kills these seeds must re-hunt and re-pin —
    // and prove the new curve still clears tool/ascension_sweep_probe.dart.
    // Re-pinned for v0.22.0: the 8-boss remap (bossForSeed = seed % 8)
    // changes which boss every seed draws, which flipped the old pins
    // (kindler 10, warden 4, gambler 10, ascetic 10). Re-hunted after the
    // remap AND the fairness tunes (kindler won 6/10/13, warden 4/6/13,
    // gambler 6/13/39, ascetic 6/10/39); four DISTINCT seeds pinned
    // deliberately so the four proofs ride four different maps/bosses, not
    // one lucky layout.
    // Re-pinned for v0.25.0 ("The Unquiet Deep" content drop): deck/relic
    // growth re-rolls every seeded run, which killed the old kindler/gambler/
    // ascetic pins. Re-hunted (kindler won 39/40/90, warden 4/20/24,
    // gambler 40/69/90, ascetic 39/40/106); four DISTINCT seeds kept.
    // Re-pinned for v0.46.0 ("The Delvers Before" content drop, events
    // 39->45 / relics 32->36): same cause, all four old pins re-rolled.
    // Re-hunted (kindler won 6/10, warden 4/6, gambler 6/10, ascetic
    // 6/10/20/40/66); four DISTINCT seeds kept.
    // Re-pinned for v0.47.0 ("The Answered Blow", enemy pool 39->42): the
    // pool growth re-rolled every seeded run. Re-hunted
    // (tool/reanchor_v0470_probe_test.dart: kindler 6/10, warden 4/6,
    // gambler 6/10, ascetic 6/10/66); four DISTINCT seeds kept.
    const seeds = {
      'kindler': 6,
      'warden': 4,
      'gambler': 10,
      'ascetic': 66,
    };
    seeds.forEach((ch, seed) {
      final r = playRun(seed, character: ch, difficulty: 'hard', ascension: 20);
      expect(
        r.sim.phase,
        'run_won',
        reason: '$ch seed $seed no longer wins at A20 — the ladder may be '
            'dead again; re-run the sweep and seed hunt',
      );
    });
  });
}
