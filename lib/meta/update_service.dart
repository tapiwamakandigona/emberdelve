// lib/meta/update_service.dart — The Watchtower (v0.21.0): update awareness
// for GitHub-only distribution.
//
// A sideloaded player has no store, so no update channel — every release we
// ship reaches only new downloaders. This service closes that gap with two
// §Ethics-clean pieces (docs/improvements/v0.21.0-watchtower-design.md):
//
//   1. A MANUAL "Check" button in Settings: one GET to GitHub's public
//      releases API, result shown inline as a neutral fact. Nothing is
//      downloaded; a "Copy link" button puts the releases page on the
//      clipboard (repo precedent: seed/result copy on the summary screen).
//   2. An OPT-IN launch check, OFF by default (Daily-Delve-reminder
//      precedent): silent unless a newer tag exists, then ONE dismissible
//      title-screen line. Never a modal, never a badge; dismissal is
//      remembered per-version.
//
// Same architecture as ReminderService/PlayGamesService: deliberately free
// of plugin and dart:io imports so it stays unit-testable headless. main.dart
// wires the real HTTP fetcher on Android; in tests the fetcher is a fixture.
//
// Consent lives in device-local prefs, NOT MetaState, on purpose: this
// toggle authorizes a NETWORK CALL on this device. Cloud-merging it would
// let a choice made on one phone silently start network requests on
// another — consent must never travel (design deviation from the first
// draft, recorded in the design doc).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/news.dart' show compareVersions, currentAppVersion;

/// Fetches [url] and returns the response body. Throws on any failure
/// (network, non-200, timeout) — the service maps every throw to
/// [UpdateStatus.error] and never crashes.
typedef ReleaseFetcher = Future<String> Function(Uri url);

enum UpdateStatus { unknown, checking, newer, current, error }

class UpdateService {
  /// Process-wide instance. Tests may replace it.
  static UpdateService instance = UpdateService();

  static const _kEnabled = 'update_check_on';
  static const _kSeenTag = 'update_seen_tag';

  /// The only endpoint this service ever talks to.
  static final Uri latestReleaseApi = Uri.parse(
    'https://api.github.com/repos/tapiwamakandigona/emberdelve/releases/latest',
  );

  /// Human page offered via "Copy link" — never auto-opened.
  static const String releasesPageUrl =
      'https://github.com/tapiwamakandigona/emberdelve/releases';

  /// Real HTTP on Android (wired in main.dart); null in tests/headless =>
  /// the whole Settings section hides and every check is a silent no-op.
  ReleaseFetcher? fetcher;

  /// The version name this build compares against; injectable for tests.
  String installedVersion = currentAppVersion;

  /// UI refresh signal (Settings + title screen listen).
  final ValueNotifier<int> tick = ValueNotifier(0);

  SharedPreferences? _prefs;
  bool _enabled = false;
  String _seenTag = '';
  UpdateStatus _status = UpdateStatus.unknown;
  String? _latest; // newest release version name seen (no leading 'v')

  bool get available => fetcher != null;

  /// The remembered opt-in launch-check choice.
  bool get enabled => _enabled;

  /// Result of the most recent check this session.
  UpdateStatus get status => _status;

  /// Newest release version name known (e.g. '0.22.0'), null before any
  /// successful check.
  String? get latest => _latest;

  /// Non-null when the opt-in launch check found a newer, not-yet-dismissed
  /// release: the title screen shows one quiet line for it.
  String? get noticeTag =>
      _enabled && _status == UpdateStatus.newer && _latest != _seenTag
      ? _latest
      : null;

  /// Load remembered choices. Safe to call before the fetcher is wired.
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _enabled = _prefs!.getBool(_kEnabled) ?? false;
      _seenTag = _prefs!.getString(_kSeenTag) ?? '';
    } catch (_) {
      // Prefs unavailable => behave as never-enabled; never crash.
    }
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    try {
      await _prefs?.setBool(_kEnabled, v);
    } catch (_) {}
    tick.value++;
  }

  /// The player dismissed the title-screen notice: remember this version so
  /// it never returns, exactly like the Hearthside Post.
  Future<void> dismissNotice() async {
    final t = _latest;
    if (t == null) return;
    _seenTag = t;
    try {
      await _prefs?.setString(_kSeenTag, t);
    } catch (_) {}
    tick.value++;
  }

  /// One explicit or launch-triggered check. Never throws.
  Future<UpdateStatus> check() async {
    final f = fetcher;
    if (f == null) return _status;
    _status = UpdateStatus.checking;
    tick.value++;
    try {
      final body = await f(latestReleaseApi);
      final tag = _parseTag(body);
      if (tag == null) {
        _status = UpdateStatus.error;
      } else {
        _latest = tag;
        _status = compareVersions(tag, installedVersion) > 0
            ? UpdateStatus.newer
            : UpdateStatus.current;
      }
    } catch (_) {
      _status = UpdateStatus.error;
    }
    tick.value++;
    return _status;
  }

  /// Boot hook: at most ONE silent check per launch, only when opted in.
  Future<void> launchCheckIfEnabled() async {
    if (!_enabled || !available) return;
    await check();
  }

  /// `tag_name` from the releases API response, leading 'v' stripped.
  /// Null when the body isn't the expected shape (=> error, fail quiet).
  static String? _parseTag(String body) {
    try {
      final j = jsonDecode(body);
      final raw = (j as Map)['tag_name'];
      if (raw is! String || raw.isEmpty) return null;
      return raw.startsWith('v') ? raw.substring(1) : raw;
    } catch (_) {
      return null;
    }
  }
}
