// test/v7_migration_test.dart — v6 -> v7 boot behaviour and the run-local
// state's survival across save, restore and replay.
//
// The contract is deliberate and blunt: a v6 autosave is DISCARDED, not
// migrated. A tempered die has no v6 representation, so any guess at one would
// be a lie about the player's pool. What must never happen is a crash, a
// zombie half-run, or a lost meta profile.
import 'dart:convert';
import 'dart:io';

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/combat.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ed_v7_migration');
    MetaStore.dirOverride = dir.path;
  });

  tearDown(() async {
    await MetaStore.save(MetaState());
    MetaStore.dirOverride = null;
    for (var i = 0; i < 10; i++) {
      try {
        await dir.delete(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  test('simVersion is 7 — v6 saves are a different generation', () {
    expect(simVersion, 7);
  });

  test('a v6 autosave is discarded at boot, without a crash', () async {
    // A structurally valid v7 snapshot, stamped with the previous version —
    // exactly what a player mid-run on v0.6.1 has on disk.
    final live = Sim(99)..apply({'type': 'start_run'});
    final snap = Map<String, dynamic>.from(live.snapshot());
    snap['version'] = 6;
    final file = File('${dir.path}/emberdelve_run.json');
    await file.writeAsString(jsonEncode(snap));

    final c = GameController(saveDirOverride: dir.path);
    await c.boot();

    expect(c.sim, isNull, reason: 'a stale-version run must not resume');
    expect(c.phase, isNull);
    // The profile itself survives: only the run blob is stale.
    expect(c.meta.runsPlayed, 0);
    await c.flushSaves();
  });

  test('a v7 autosave carrying a tempered die resumes intact', () async {
    final live = Sim(99)..apply({'type': 'start_run'});
    live.phase = 'rest';
    live.apply({'type': 'temper_face', 'die': 1, 'face': 4, 'rune': 'echo'});
    expect(live.run!['tempers_used'], 1);

    final file = File('${dir.path}/emberdelve_run.json');
    await file.writeAsString(jsonEncode(live.snapshot()));

    final c = GameController(saveDirOverride: dir.path);
    await c.boot();

    expect(c.sim, isNotNull, reason: 'a current-version run must resume');
    final run = c.state!['run'] as Map;
    expect(run['tempers_used'], 1);
    expect((run['custom_dice'] as Map)['custom_1'], {
      'base': 'd6',
      'face': 4,
      'rune': 'echo',
    });
    expect(((c.state!['player'] as Map)['dice'] as List).first, 'custom_1');
    expect(c.sim!.stateHash(), live.stateHash());
    await c.flushSaves();
  });

  test('a run carrying runes and a keystone replays byte-identically', () {
    List<Map<String, Object?>> drive(Sim sim) {
      final events = <Map<String, Object?>>[];
      sim.apply({'type': 'start_run'});
      sim.phase = 'rest';
      events.addAll(
        sim.apply({
          'type': 'temper_face',
          'die': 1,
          'face': 3,
          'rune': 'surge',
        }),
      );
      sim.run!['keystones'] = ['twin_bellows'];
      combatBegin(sim, 'cinder_wisp', false, events, layer: 2);
      for (var turn = 0; turn < 6 && sim.phase == 'player_turn'; turn++) {
        events.addAll(sim.apply({'type': 'roll'}));
        final n = (sim.player['dice'] as List).length;
        for (var i = 1; i <= n && sim.phase == 'player_turn'; i++) {
          events.addAll(
            sim.apply({
              'type': 'assign',
              'die': i,
              'action': i.isEven ? 'block' : 'attack',
            }),
          );
        }
        if (sim.phase == 'player_turn') {
          events.addAll(sim.apply({'type': 'end_turn'}));
        }
      }
      return events;
    }

    final a = Sim(4242);
    final b = Sim(4242);
    final eventsA = drive(a);
    final eventsB = drive(b);
    expect(jsonEncode(eventsB), jsonEncode(eventsA));
    expect(b.eventHash, a.eventHash);
    expect(b.stateHash(), a.stateHash());
    expect(
      eventsA.any((e) => e['type'] == 'keystone_triggered'),
      isTrue,
      reason: 'the replay must actually exercise the new machinery',
    );
  });

  test('mid-combat snapshot/restore keeps rune and keystone turn state', () {
    final sim = Sim(77)..apply({'type': 'start_run'});
    sim.phase = 'rest';
    sim.apply({'type': 'temper_face', 'die': 1, 'face': 2, 'rune': 'echo'});
    sim.run!['keystones'] = ['ashen_edge'];
    combatBegin(sim, 'cinder_wisp', false, [], layer: 2);
    sim.apply({'type': 'roll'});
    sim.apply({'type': 'assign', 'die': 1, 'action': 'attack'});

    final resumed = Sim.restore(
      jsonDecode(jsonEncode(sim.snapshot())) as Map<String, dynamic>,
    );
    expect(resumed.stateHash(), sim.stateHash());
    expect(resumed.player['ashen_used'], sim.player['ashen_used']);
    expect(resumed.player['echo_pending'], sim.player['echo_pending']);
    expect(resumed.player['bellows_action'], sim.player['bellows_action']);
    expect(resumed.player['surge_used'], sim.player['surge_used']);

    // And the resumed run keeps resolving identically from here.
    final a = sim.apply({'type': 'assign', 'die': 2, 'action': 'block'});
    final b = resumed.apply({'type': 'assign', 'die': 2, 'action': 'block'});
    expect(jsonEncode(b), jsonEncode(a));
  });

  test('a killing blow never reports negative HP', () {
    // Found by the v7 command fuzz. The HUD prints player_hp verbatim, so a
    // negative value was a visible "-17" on the death frame and in TalkBack.
    final sim = Sim(31)..apply({'type': 'start_run'});
    combatBegin(sim, 'cinder_wisp', false, [], layer: 2);
    sim.player['hp'] = 3;
    sim.player['block'] = 0;
    sim.enemy!['intent'] = {'kind': 'attack', 'amount': 20};

    final events = sim.apply({'type': 'end_turn'});
    final hit = events.firstWhere((e) => e['type'] == 'enemy_attacked');
    expect(hit['damage'], 20, reason: 'the hit that landed stays honest');
    expect(hit['player_hp'], 0, reason: 'reported HP is floored');
    expect(sim.player['hp'], 0, reason: 'stored HP is floored');
    expect(events.any((e) => e['type'] == 'encounter_lost'), isTrue);
  });
}
