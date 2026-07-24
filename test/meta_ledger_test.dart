// test/meta_ledger_test.dart — v0.3.3 macro-loop features:
//   1. MetaState round-trips the new ledger fields; pre-v0.3.3 saves load
//      with safe defaults (veterans are never steered to easy).
//   2. First-run on-ramp: brand-new profiles steer to easy, one explicit
//      tap ends it forever, old profiles are untouched.
//   3. Ledger stats: exact-kill count/streak from sim events, per-character
//      runs/wins and lifetime embers banked at run end.
//   4. Hearth colors: ember-priced purchase logic (deduct, refuse, activate).
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/themes.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/sim/autoplay.dart';

void main() {
  test('meta json round-trips all v0.3.3 ledger fields', () {
    final m = MetaState(
      embers: 77,
      bestAscension: 2,
      runsPlayed: 12,
      runsWon: 5,
      tutorialSeen: true,
      preferredDifficulty: 'hard',
      difficultyChosen: true,
      charRuns: {'kindler': 8, 'warden': 4},
      charWins: {'kindler': 4, 'warden': 1},
      lifetimeEmbers: 913,
      exactKills: 23,
      exactStreak: 2,
      bestExactStreak: 6,
      ownedThemes: {defaultTheme, 'frostfire'},
      activeTheme: 'frostfire',
    );
    final back = MetaState.fromJson(
        jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
    expect(back.toJson(), m.toJson());
  });

  test('pre-v0.3.3 saves load with safe defaults', () {
    // A veteran's v0.3.2 save: no ledger fields, runs already played.
    final veteran = MetaState.fromJson({
      'embers': 200,
      'runsPlayed': 9,
      'runsWon': 4,
      'preferredDifficulty': 'normal',
    });
    expect(veteran.difficultyChosen, isTrue,
        reason: 'veterans must never be steered to easy');
    expect(veteran.steerToEasy, isFalse);
    expect(veteran.lifetimeEmbers, 0);
    expect(veteran.charRuns, isEmpty);
    expect(veteran.ownedThemes, {defaultTheme});
    expect(veteran.activeTheme, defaultTheme);
    // Unknown active theme falls back instead of crashing the title.
    final junk = MetaState.fromJson({'activeTheme': 'plasma'});
    expect(junk.activeTheme, defaultTheme);
  });

  test('first-run on-ramp: new profile steers to easy, one tap ends it',
      () async {
    final c = GameController();
    await c.boot(); // fresh profile: runsPlayed == 0, never chosen
    expect(c.meta.steerToEasy, isTrue);
    expect(c.meta.preferredDifficulty, 'easy',
        reason: 'the VISIBLE selector moves — never a silent switch');
    expect(c.meta.effectiveDifficulty, 'easy');

    // Tapping the already-highlighted EASY still counts as an explicit
    // choice — the recommendation caption must not survive a decision.
    c.setPreferredDifficulty('easy');
    expect(c.meta.difficultyChosen, isTrue);
    expect(c.meta.steerToEasy, isFalse);

    // And an explicit different pick sticks.
    c.setPreferredDifficulty('hard');
    expect(c.meta.effectiveDifficulty, 'hard');
  });

  test('steered first run actually starts on easy', () async {
    final c = GameController();
    await c.boot();
    c.startRun(seed: 42, boons: false);
    expect(c.sim!.run!['difficulty'], 'easy');
  });

  test('exact-kill count and streak follow sim events', () {
    final c = GameController();
    void fight({required bool exact}) => c.recordCombatStats([
          if (exact) {'type': 'exact_kill', 'embers': 5},
          {'type': 'encounter_won', 'turns': 3},
        ]);

    fight(exact: true);
    fight(exact: true);
    expect(c.meta.exactKills, 2);
    expect(c.meta.exactStreak, 2);
    fight(exact: false); // a plain win breaks the streak
    expect(c.meta.exactStreak, 0);
    expect(c.meta.bestExactStreak, 2);
    fight(exact: true);
    expect(c.meta.exactStreak, 1);
    expect(c.meta.bestExactStreak, 2, reason: 'best is a high-water mark');
    // An exact kill without encounter_won (multi-event edge) still counts
    // the kill but leaves the streak to the fight's outcome event.
    c.recordCombatStats([{'type': 'exact_kill', 'embers': 5}]);
    expect(c.meta.exactKills, 4);
    expect(c.meta.exactStreak, 1);
  });

  test('run end banks per-character stats and lifetime embers', () {
    final c = GameController();
    c.startRun(character: 'kindler', seed: 11, boons: true);
    // Drive the run to a terminal phase with the shared greedy bot.
    var guard = 0;
    while (guard++ < 400 &&
        c.phase != 'run_won' &&
        c.phase != 'run_lost') {
      final cmd = botCmd(c.sim!);
      if (cmd == null) break;
      c.apply(cmd);
    }
    expect({'run_won', 'run_lost'}.contains(c.phase), isTrue,
        reason: 'bot must reach a terminal phase (guard=$guard)');
    expect(c.meta.charRuns['kindler'], 1);
    expect(c.meta.runsPlayed, 1);
    final banked = c.sim!.run!['embers'] as int;
    expect(c.meta.lifetimeEmbers, banked);
    expect(c.meta.embers, banked);
    if (c.phase == 'run_won') {
      expect(c.meta.charWins['kindler'], 1);
    } else {
      expect(c.meta.charWins['kindler'], isNull);
    }
  });

  test('hearth colors: buy deducts embers, refuses when broke or owned', () {
    final m = MetaState(embers: 70);
    expect(m.tryBuyTheme('frostfire'), isTrue); // costs 60
    expect(m.embers, 10);
    expect(m.ownedThemes, contains('frostfire'));
    expect(m.tryBuyTheme('frostfire'), isFalse,
        reason: 'owned themes are never sold twice');
    expect(m.tryBuyTheme('goldvein'), isFalse,
        reason: '10 embers cannot buy a 100-ember theme');
    expect(m.embers, 10, reason: 'failed buys must not touch the purse');
    expect(m.tryBuyTheme('plasma'), isFalse, reason: 'unknown id');

    // Controller wiring: buy + activate, and activation needs ownership.
    final c = GameController();
    c.meta.embers = 60;
    expect(c.buyTheme('frostfire'), isTrue);
    c.setActiveTheme('frostfire');
    expect(c.meta.activeTheme, 'frostfire');
    c.setActiveTheme('goldvein'); // not owned: ignored
    expect(c.meta.activeTheme, 'frostfire');
  });

  test('every hearth theme is well-formed and the default is free', () {
    expect(hearthThemesOrder.toSet(), hearthThemes.keys.toSet());
    expect(hearthThemeDef(defaultTheme).costEmbers, 0);
    for (final t in hearthThemes.values) {
      expect(t.name, isNotEmpty);
      expect(t.costEmbers, greaterThanOrEqualTo(0));
    }
  });

  test('meta save is atomic and serialized (queue, temp+rename, snapshot)',
      () async {
    final dir = await Directory.systemTemp.createTemp('emberdelve_meta');
    MetaStore.dirOverride = dir.path;
    try {
      // Rapid-fire saves (bank + unlock + theme buy in one frame): the
      // snapshot is captured at call time, so mutating the state AFTER the
      // un-awaited save must not leak into that write, and the last save
      // must win.
      final m = MetaState(embers: 10);
      final first = MetaStore.save(m); // not awaited: queued
      m.embers = 20;
      MetaStore.save(m);
      m.embers = 30;
      await MetaStore.save(m); // queue drains in order
      await first;
      final loaded = await MetaStore.load();
      expect(loaded.embers, 30, reason: 'last queued save must win');

      // No temp file left behind: the write landed via rename.
      expect(
          await File('${dir.path}/emberdelve_meta.json.tmp').exists(), isFalse,
          reason: 'temp file must be renamed into place');

      // A truncated/corrupt file (crash mid-write of a NON-atomic writer)
      // must never crash load — it falls back to a fresh MetaState.
      await File('${dir.path}/emberdelve_meta.json')
          .writeAsString('{"embers": 5, "unlo');
      final recovered = await MetaStore.load();
      expect(recovered.embers, 0);
    } finally {
      MetaStore.dirOverride = null;
      await dir.delete(recursive: true);
    }
  });
}
