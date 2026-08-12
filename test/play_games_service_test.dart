// test/play_games_service_test.dart — the PlayGamesService gate
// (lib/meta/play_games_service.dart): opt-in only, no-op without backends,
// leaderboard submits only for connected daily/weekly runs, and the
// pull-merge-push cloud sync.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/play_games_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  PlayGamesService fresh() => PlayGamesService();

  group('availability and opt-in gating', () {
    test('no backends wired: not available, everything no-ops', () async {
      final pgs = fresh();
      await pgs.load();
      expect(pgs.available, isFalse);
      expect(pgs.connected, isFalse);
      expect(await pgs.connect(), isFalse);
      // None of these may throw even though nothing is wired.
      await pgs.pushSnapshot(MetaState());
      await pgs.submitRunScore(
        isDaily: true,
        isWeekly: false,
        embersBanked: 10,
      );
      await pgs.showLeaderboards();
    });

    test('resumeIfWanted does nothing without a remembered choice', () async {
      var signIns = 0;
      final pgs = fresh()
        ..signInBackend = (() async {
          signIns++;
          return true;
        });
      await pgs.load();
      await pgs.resumeIfWanted();
      expect(signIns, 0);
      expect(pgs.connected, isFalse);
    });

    test('connect signs in, remembers the choice, and syncs', () async {
      var signIns = 0;
      final saved = <String, String>{};
      final pgs = fresh()
        ..signInBackend = (() async {
          signIns++;
          return true;
        })
        ..saveGameBackend = ((data, name) async => saved[name] = data)
        ..loadGameBackend = ((name) async => null)
        ..loadLocalHook = (() async => MetaState(embers: 42))
        ..adoptMergedHook = ((m) async {});
      await pgs.load();
      expect(await pgs.connect(), isTrue);
      expect(signIns, 1);
      expect(pgs.connected, isTrue);
      // The sync pushed the local snapshot to the named saved game.
      final cloud =
          jsonDecode(saved[PlayGamesService.savedGameName]!)
              as Map<String, dynamic>;
      expect(cloud['embers'], 42);
      // Choice persisted for the next launch.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pgs_connected'), isTrue);
    });

    test('failed sign-in never records the choice', () async {
      final pgs = fresh()..signInBackend = (() async => false);
      await pgs.load();
      expect(await pgs.connect(), isFalse);
      expect(pgs.connected, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pgs_connected'), isNot(isTrue));
    });

    test('a throwing sign-in backend is contained', () async {
      final pgs = fresh()..signInBackend = (() async => throw 'boom');
      await pgs.load();
      expect(await pgs.connect(), isFalse);
      expect(pgs.connected, isFalse);
    });

    test('disconnect forgets the choice and stops traffic', () async {
      final saved = <String, String>{};
      final pgs = fresh()
        ..signInBackend = (() async => true)
        ..saveGameBackend = ((data, name) async => saved[name] = data)
        ..loadGameBackend = ((name) async => null)
        ..loadLocalHook = (() async => MetaState())
        ..adoptMergedHook = ((m) async {});
      await pgs.load();
      await pgs.connect();
      saved.clear();
      await pgs.disconnect();
      expect(pgs.connected, isFalse);
      await pgs.pushSnapshot(MetaState(embers: 9));
      expect(saved, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pgs_connected'), isFalse);
    });

    test(
      'resumeIfWanted resumes silently after a remembered connect',
      () async {
        SharedPreferences.setMockInitialValues({'pgs_connected': true});
        var signIns = 0;
        final pgs = fresh()
          ..signInBackend = (() async {
            signIns++;
            return true;
          })
          ..saveGameBackend = ((data, name) async {})
          ..loadGameBackend = ((name) async => null)
          ..loadLocalHook = (() async => MetaState())
          ..adoptMergedHook = ((m) async {});
        await pgs.load();
        await pgs.resumeIfWanted();
        expect(signIns, 1);
        expect(pgs.connected, isTrue);
      },
    );
  });

  group('cloud sync (pull-merge-push)', () {
    test('cloud progress merges into local on connect', () async {
      MetaState? adopted;
      final cloudState = MetaState(
        lifetimeEmbers: 700,
        embers: 300,
        ownedDieSkins: {'bone', 'gilt'},
        forgeUnlocked: true,
      );
      final saved = <String, String>{};
      final pgs = fresh()
        ..signInBackend = (() async => true)
        ..saveGameBackend = ((data, name) async => saved[name] = data)
        ..loadGameBackend = ((name) async => jsonEncode(cloudState.toJson()))
        ..loadLocalHook = (() async =>
            MetaState(lifetimeEmbers: 100, embers: 10, runsPlayed: 3))
        ..adoptMergedHook = ((m) async => adopted = m);
      await pgs.load();
      await pgs.connect();
      expect(adopted, isNotNull);
      expect(adopted!.embers, 300); // cloud was fresher
      expect(adopted!.runsPlayed, 3); // local counter kept (max)
      expect(adopted!.forgeUnlocked, isTrue);
      // Merged result was pushed back up.
      final pushed =
          jsonDecode(saved[PlayGamesService.savedGameName]!)
              as Map<String, dynamic>;
      expect(pushed['embers'], 300);
    });

    test('unreadable cloud payload: local wins and overwrites cloud', () async {
      MetaState? adopted;
      final saved = <String, String>{};
      final pgs = fresh()
        ..signInBackend = (() async => true)
        ..saveGameBackend = ((data, name) async => saved[name] = data)
        ..loadGameBackend = ((name) async => 'not json {{{')
        ..loadLocalHook = (() async => MetaState(embers: 77))
        ..adoptMergedHook = ((m) async => adopted = m);
      await pgs.load();
      await pgs.connect();
      expect(adopted!.embers, 77);
      final pushed =
          jsonDecode(saved[PlayGamesService.savedGameName]!)
              as Map<String, dynamic>;
      expect(pushed['embers'], 77);
    });
  });

  group('leaderboard submits', () {
    Future<PlayGamesService> connected(List<(String, int)> submits) async {
      final pgs = fresh()
        ..signInBackend = (() async => true)
        ..saveGameBackend = ((data, name) async {})
        ..loadGameBackend = ((name) async => null)
        ..submitScoreBackend = ((id, v) async => submits.add((id, v)))
        ..loadLocalHook = (() async => MetaState())
        ..adoptMergedHook = ((m) async {});
      await pgs.load();
      await pgs.connect();
      return pgs;
    }

    test('daily run goes to the daily board', () async {
      final submits = <(String, int)>[];
      final pgs = await connected(submits);
      await pgs.submitRunScore(
        isDaily: true,
        isWeekly: false,
        embersBanked: 88,
      );
      expect(submits, [(PlayGamesService.dailyLeaderboardId, 88)]);
    });

    test('weekly run goes to the weekly board', () async {
      final submits = <(String, int)>[];
      final pgs = await connected(submits);
      await pgs.submitRunScore(
        isDaily: false,
        isWeekly: true,
        embersBanked: 41,
      );
      expect(submits, [(PlayGamesService.weeklyLeaderboardId, 41)]);
    });

    test('normal runs never submit', () async {
      final submits = <(String, int)>[];
      final pgs = await connected(submits);
      await pgs.submitRunScore(
        isDaily: false,
        isWeekly: false,
        embersBanked: 999,
      );
      expect(submits, isEmpty);
    });

    test('not connected: nothing submits even for a daily', () async {
      final submits = <(String, int)>[];
      final pgs = fresh()
        ..signInBackend = (() async => true)
        ..submitScoreBackend = ((id, v) async => submits.add((id, v)));
      await pgs.load();
      await pgs.submitRunScore(
        isDaily: true,
        isWeekly: false,
        embersBanked: 10,
      );
      expect(submits, isEmpty);
    });
  });
}
