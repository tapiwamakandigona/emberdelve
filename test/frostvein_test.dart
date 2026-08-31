// test/frostvein_test.dart — v0.112.0 The Frostvein.
//
// Eighth vista, the first the Weekly feeds: claim the Ember on a doubled
// week (v0.111.0). Fed by meta.doubledWins, a monotonic counter — the
// hearthgold freeze (v0.100.0) taught that a gate which can re-lock is a
// bug, so this one only climbs.
import 'package:emberdelve/data/vistas.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/weekly.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-02-02 is a doubled-week Monday whose weekly seed the bot WINS as
/// the kindler under Cold Quarter (hunted 2026-08-29, deterministic).
final DateTime wonDoubledMonday = DateTime(2026, 2, 2);

void driveToTerminal(GameController c) {
  var guard = 0;
  while (c.phase != 'run_won' && c.phase != 'run_lost' && guard++ < 4000) {
    final cmd = botCmd(c.sim!, mutators: (c.weeklyMutator ?? '').split('+'));
    if (cmd == null) break;
    c.apply(cmd);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frostvein holds its append slot, gated only by doubled wins', () {
    // v0.126.0: forgelight appended after it — the contract was always the
    // INDEX (append-order stability), not literal last place (the tinker
    // 'last' pin lesson, v0.118.0).
    expect(vistasOrder.indexOf('frostvein'), 7);
    expect(vistas['frostvein'], isNotNull);
    bool unlocked(int wins) => vistaUnlockedFor(
      'frostvein',
      runsWon: 99,
      distinctFelled: 99,
      hardWins: 99,
      provingsCleared: 99,
      bestFloor: 99,
      talesHeard: 99,
      doubledWins: wins,
      tempersSet: 0,
      charsUnlocked: 0,
      runesMarked: 0,
    );
    expect(unlocked(0), isFalse, reason: 'blind to every other counter');
    expect(unlocked(1), isTrue);
  });

  test('winning the doubled weekly banks the win and opens the vista', () {
    final c = GameController();
    c.startWeeklyRun(clock: wonDoubledMonday);
    expect(c.weeklyMutator, contains('+'), reason: 'this IS a doubled week');
    driveToTerminal(c);
    expect(c.phase, 'run_won', reason: 'hunted winning seed drifted');
    expect(c.meta.doubledWins, 1);
    expect(c.vistaUnlocked('frostvein'), isTrue);
    expect(c.pendingVistas, contains('frostvein'));
  });

  test('a plain weekly win does not climb the doubled counter', () {
    final c = GameController();
    // 2026-01-05's week deals a single rule (any non-doubled Monday does).
    final idx = weekIndexForDate(DateTime(2026, 1, 5));
    expect(weeklyRuleFor(idx).mutators, hasLength(1));
    c.startWeeklyRun(clock: DateTime(2026, 1, 5));
    driveToTerminal(c);
    expect(c.meta.doubledWins, 0, reason: 'won or lost, singles never count');
  });

  test('doubledWins persists and cloud-merges monotonically', () {
    final m = MetaState()..doubledWins = 2;
    final back = MetaState.fromJson(m.toJson());
    expect(back.doubledWins, 2);
    expect(MetaState.fromJson(MetaState().toJson()).doubledWins, 0);
    final merged = mergeMetaStates(MetaState()..doubledWins = 1, m);
    expect(merged.doubledWins, 2);
  });

  test('frostvein strings are honest (no pressure language)', () {
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
    final v = vistas['frostvein']!;
    final low = '${v.name} ${v.text} ${v.unlockLine}'.toLowerCase();
    for (final b in banned) {
      expect(low.contains(b), isFalse, reason: 'banned: $b');
    }
  });
}
