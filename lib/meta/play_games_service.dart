// lib/meta/play_games_service.dart — the single gate for Play Games Services
// (P4 cloud save + P5 leaderboards). Same architecture as TelemetryService:
// this class is deliberately free of plugin imports so it stays unit-testable
// headless. main.dart wires the real games_services backends in on Android;
// everywhere else (tests, web, desktop) every call is a silent no-op.
//
// Consent model (§Ethics, same charter as analytics): CONNECTING IS OPT-IN.
// Nothing signs in, saves to the cloud, or submits a score until the player
// taps "Connect" in Settings. The choice is remembered; on later launches a
// remembered "connected" quietly resumes (that is what the player asked for),
// and "Disconnect" stops everything with one tap. Auto sign-in is disabled at
// the manifest level (PlayGamesInitProvider removed) so PGS never pops UI the
// player didn't ask for.
//
// Cloud save contract (P4): the WHOLE MetaState snapshot is one named PGS
// saved game ('emberdelve_meta'). Sync = pull cloud -> mergeMetaStates with
// local (see cloud_merge.dart) -> persist merged locally -> push merged back.
// Runs after connect and after every banked run. Local remains the source of
// truth for play; the cloud copy is a backup that follows the player.
//
// Leaderboards (P5): score = EMBERS BANKED by a finished Daily/Weekly Delve —
// a number the summary screen already shows the player, never a hidden
// formula. Submitted only for daily/weekly runs (the shared-seed modes where
// comparison is fair) and only while connected.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_merge.dart';
import 'meta.dart';

/// Signs the player in; resolves true when signed in.
typedef PgsSignIn = Future<bool> Function();

/// Uploads [data] under the saved-game [name].
typedef PgsSaveGame = Future<void> Function(String data, String name);

/// Downloads the saved game [name]; null when none exists.
typedef PgsLoadGame = Future<String?> Function(String name);

/// Submits [value] to the Android leaderboard [leaderboardId].
typedef PgsSubmitScore = Future<void> Function(String leaderboardId, int value);

/// Opens the platform leaderboards UI (one board when [leaderboardId] set).
typedef PgsShowLeaderboards = Future<void> Function(String? leaderboardId);

class PlayGamesService {
  /// Process-wide instance. Tests may replace it.
  static PlayGamesService instance = PlayGamesService();

  static const _kConnected = 'pgs_connected';
  static const savedGameName = 'emberdelve_meta';

  /// Play Console leaderboard IDs (Grow > Play Games Services > Leaderboards).
  static const dailyLeaderboardId = 'CgkIhL-el7YREAIQAQ';
  static const weeklyLeaderboardId = 'CgkIhL-el7YREAIQAg';

  // Backends; all null off-Android => every call below no-ops.
  PgsSignIn? signInBackend;
  PgsSaveGame? saveGameBackend;
  PgsLoadGame? loadGameBackend;
  PgsSubmitScore? submitScoreBackend;
  PgsShowLeaderboards? showLeaderboardsBackend;

  /// UI refresh signal (Settings listens): bumps on connect state changes.
  final ValueNotifier<int> tick = ValueNotifier(0);

  /// Sync hooks, wired by main.dart: how to read the live local profile and
  /// how to adopt a cloud-merged one. Kept on the instance so Settings can
  /// trigger [connect] without holding a GameController reference.
  Future<MetaState> Function()? loadLocalHook;
  Future<void> Function(MetaState merged)? adoptMergedHook;

  SharedPreferences? _prefs;
  bool _wantsConnection = false; // the remembered player choice
  bool _signedIn = false; // live session state

  /// True when the platform backends are wired (i.e. this build can talk to
  /// Play Games at all). Settings hides the section entirely when false.
  bool get available => signInBackend != null;

  /// The player has opted in AND the session is live.
  bool get connected => _wantsConnection && _signedIn;

  /// The remembered opt-in choice (may be true while a sign-in is pending).
  bool get wantsConnection => _wantsConnection;

  /// Load the remembered choice. Safe to call before any backend is wired.
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _wantsConnection = _prefs!.getBool(_kConnected) ?? false;
    } catch (_) {
      // Prefs unavailable => behave as never-connected; never crash.
    }
  }

  /// Resume a remembered connection at startup (silent; no UI if it fails).
  /// Then pull-merge-push the cloud save so a fresh install lands on the
  /// player's real progress before the title screen shows it.
  Future<void> resumeIfWanted() async {
    if (!_wantsConnection || !available) return;
    try {
      _signedIn = await signInBackend!.call();
    } catch (_) {
      _signedIn = false;
    }
    tick.value++;
    if (_signedIn) await _syncCloudSave();
  }

  /// Explicit player tap in Settings. Returns true when the session is live.
  Future<bool> connect() async {
    if (!available) return false;
    try {
      _signedIn = await signInBackend!.call();
    } catch (_) {
      _signedIn = false;
    }
    if (_signedIn) {
      _wantsConnection = true;
      try {
        await _prefs?.setBool(_kConnected, true);
      } catch (_) {}
      await _syncCloudSave();
    }
    tick.value++;
    return _signedIn;
  }

  /// Explicit player tap in Settings. Stops all cloud/leaderboard traffic.
  /// (PGS has no programmatic sign-out in the v2 SDK; forgetting the choice
  /// is the contract — nothing further is read or written.)
  Future<void> disconnect() async {
    _wantsConnection = false;
    _signedIn = false;
    try {
      await _prefs?.setBool(_kConnected, false);
    } catch (_) {}
    tick.value++;
  }

  /// Pull cloud -> merge with local -> adopt merged locally -> push merged.
  /// Every step is best-effort: a network hiccup must never cost progress or
  /// crash the game (local stays authoritative until a merge lands).
  Future<void> _syncCloudSave() async {
    final loadLocal = loadLocalHook;
    final adoptMerged = adoptMergedHook;
    if (loadLocal == null || adoptMerged == null) return;
    try {
      final local = await loadLocal();
      MetaState merged = local;
      final raw = await loadGameBackend?.call(savedGameName);
      if (raw != null && raw.isNotEmpty) {
        try {
          final cloud =
              MetaState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          merged = mergeMetaStates(local, cloud);
        } catch (_) {
          // Unreadable cloud payload: keep local, overwrite cloud below.
        }
      }
      await adoptMerged(merged);
      await saveGameBackend?.call(jsonEncode(merged.toJson()), savedGameName);
    } catch (_) {/* best-effort */}
  }

  /// Push the current meta snapshot to the cloud (no pull). Called after a
  /// banked run: local was just updated and is strictly fresher.
  Future<void> pushSnapshot(MetaState state) async {
    if (!connected) return;
    try {
      await saveGameBackend?.call(jsonEncode(state.toJson()), savedGameName);
    } catch (_) {/* best-effort */}
  }

  /// Submit a finished Daily/Weekly Delve to its leaderboard. No-op for
  /// normal runs (both ids null) or while not connected.
  Future<void> submitRunScore(
      {required bool isDaily,
      required bool isWeekly,
      required int embersBanked}) async {
    if (!connected) return;
    final id = isDaily
        ? dailyLeaderboardId
        : isWeekly
            ? weeklyLeaderboardId
            : null;
    if (id == null) return;
    try {
      await submitScoreBackend?.call(id, embersBanked);
    } catch (_) {/* best-effort */}
  }

  /// Open the platform leaderboards UI.
  Future<void> showLeaderboards({String? leaderboardId}) async {
    if (!connected) return;
    try {
      await showLeaderboardsBackend?.call(leaderboardId);
    } catch (_) {/* best-effort */}
  }
}

