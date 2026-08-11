// lib/meta/reminder_service.dart — the opt-in Daily Delve reminder (v0.6.0).
//
// Same architecture as TelemetryService/PlayGamesService: this class is
// deliberately free of plugin imports so it stays unit-testable headless.
// main.dart wires the real flutter_local_notifications backends on Android;
// everywhere else (tests, web, desktop) every call is a silent no-op.
//
// Consent model (§Ethics, retention doc 2026-08-11 "Do not build" caveat):
// the reminder is OFF by default, enabled only by an explicit Settings tap,
// and the copy is a neutral fact — "a new Daily Delve seed is live" — never
// a loss frame, never "your delvers miss you". Turning it on asks the OS
// notification permission; a denied permission simply leaves it off.
//
// Scheduling contract: we schedule the next [horizonDays] daily slots at
// [reminderHour] local time as ONE-OFF inexact notifications, and reschedule
// the whole window on every app launch. Two deliberate consequences:
//   1. No exact-alarm permission — inexact delivery is fine for "sometime
//      after the seed rolls over".
//   2. A player who stops opening the game stops getting reminders after
//      [horizonDays] days. The reminder follows engagement; it never nags
//      a lapsed player indefinitely (that would be §Ethics loss-framing in
//      disguise).
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks the OS for notification permission; resolves true when granted.
typedef ReminderPermissionRequest = Future<bool> Function();

/// Schedules a one-off notification [id] at [when] with [title]/[body].
typedef ReminderScheduleAt = Future<void> Function(
    int id, DateTime when, String title, String body);

/// Cancels every notification this app has scheduled.
typedef ReminderCancelAll = Future<void> Function();

class ReminderService {
  /// Process-wide instance. Tests may replace it.
  static ReminderService instance = ReminderService();

  static const _kEnabled = 'daily_reminder_on';

  /// Local hour (24h) the reminder fires at — after the daily seed rollover.
  static const reminderHour = 10;

  /// How many upcoming slots are scheduled per launch.
  static const horizonDays = 7;

  /// Base notification id; slots use [baseId]..[baseId]+[horizonDays]-1.
  static const baseId = 1000;

  /// Neutral-fact copy (§Ethics: no loss frame, no guilt, no streak threat).
  static const notificationTitle = "Today's Delve is ready";
  static const notificationBody =
      'A fresh Daily Delve seed is live. One run, one shared map.';

  // Backends; all null off-Android => every call below no-ops.
  ReminderPermissionRequest? permissionBackend;
  ReminderScheduleAt? scheduleBackend;
  ReminderCancelAll? cancelAllBackend;

  /// UI refresh signal (Settings listens): bumps on enabled-state changes.
  final ValueNotifier<int> tick = ValueNotifier(0);

  SharedPreferences? _prefs;
  bool _enabled = false;

  /// True when the platform backends are wired (i.e. this build can post
  /// notifications at all). Settings hides the section entirely when false.
  bool get available => scheduleBackend != null;

  /// The remembered opt-in choice.
  bool get enabled => _enabled;

  /// Load the remembered choice. Safe to call before any backend is wired.
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _enabled = _prefs!.getBool(_kEnabled) ?? false;
    } catch (_) {
      // Prefs unavailable => behave as never-enabled; never crash.
    }
  }

  /// Explicit player tap in Settings. Asks the OS permission first; only a
  /// granted permission turns the reminder on. Returns the resulting state.
  Future<bool> enable() async {
    if (!available) return false;
    bool granted = false;
    try {
      granted = await permissionBackend?.call() ?? true;
    } catch (_) {
      granted = false;
    }
    if (!granted) return false;
    _enabled = true;
    try {
      await _prefs?.setBool(_kEnabled, true);
    } catch (_) {}
    await _scheduleWindow(DateTime.now());
    tick.value++;
    return true;
  }

  /// Explicit player tap in Settings. Cancels everything scheduled.
  Future<void> disable() async {
    _enabled = false;
    try {
      await _prefs?.setBool(_kEnabled, false);
    } catch (_) {}
    try {
      await cancelAllBackend?.call();
    } catch (_) {}
    tick.value++;
  }

  /// Boot hook: refresh the scheduled window so it always extends
  /// [horizonDays] ahead of the most recent launch. No-op while off.
  Future<void> rescheduleIfEnabled([DateTime? now]) async {
    if (!_enabled || !available) return;
    await _scheduleWindow(now ?? DateTime.now());
  }

  Future<void> _scheduleWindow(DateTime now) async {
    try {
      await cancelAllBackend?.call(); // never stack duplicate slots
      final slots = nextReminderTimes(now);
      for (var i = 0; i < slots.length; i++) {
        await scheduleBackend?.call(
            baseId + i, slots[i], notificationTitle, notificationBody);
      }
    } catch (_) {/* best-effort — a failed schedule must never crash */}
  }
}

/// The next [count] daily reminder slots at [hour]:00 strictly after [now].
/// Pure and deterministic — the scheduling contract lives here, tested
/// headless without any notification plugin.
List<DateTime> nextReminderTimes(DateTime now,
    {int count = ReminderService.horizonDays,
    int hour = ReminderService.reminderHour}) {
  var first = DateTime(now.year, now.month, now.day, hour);
  if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
  // Build successive civil days via the date constructor (not Duration
  // addition) so a DST shift never drifts the wall-clock hour.
  return [
    for (var i = 0; i < count; i++)
      DateTime(first.year, first.month, first.day + i, hour),
  ];
}
