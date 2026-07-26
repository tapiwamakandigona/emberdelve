// lib/telemetry/telemetry_service.dart — the single gate every telemetry
// call goes through (docs/telemetry-events.md is the schema of record).
//
// Consent model (Play prominent-disclosure + GDPR):
//   • Gameplay analytics: OPT-IN. Nothing is sent until the player taps
//     "Allow" on the first-launch disclosure dialog. Toggleable in Settings.
//
// This class is deliberately free of Firebase imports so it stays unit-
// testable headless: `main.dart` wires the real Firebase backends in via
// [analyticsBackend] AFTER Firebase.initializeApp() succeeds. If Firebase is
// unconfigured (google-services.json missing) the backends stay null and
// every call is a silent no-op — the game never depends on telemetry.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sends one analytics event. Wired to FirebaseAnalytics.logEvent in
/// telemetry_bootstrap.dart.
typedef AnalyticsEventSink = Future<void> Function(
    String name, Map<String, Object>? params);

/// Enables/disables the analytics collection backend.
typedef CollectionToggle = Future<void> Function(bool enabled);

class TelemetryService {
  /// Process-wide instance. Tests may replace it.
  static TelemetryService instance = TelemetryService();

  static const _kAnalyticsConsent = 'telemetry_analytics_consent';

  /// True once Firebase.initializeApp() succeeded (google-services.json
  /// present and valid). False => every backend call is skipped.
  bool firebaseAvailable = false;

  /// null = never asked (show the disclosure dialog); true/false = decided.
  bool? _analyticsConsent;

  AnalyticsEventSink? analyticsBackend;
  CollectionToggle? analyticsCollectionToggle;

  SharedPreferences? _prefs;

  /// Load persisted choices. Safe to call before Firebase init.
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _analyticsConsent = _prefs!.containsKey(_kAnalyticsConsent)
          ? _prefs!.getBool(_kAnalyticsConsent)
          : null;
    } catch (_) {
      // Prefs unavailable => behave as never-asked; never crash.
    }
  }

  /// Show the first-launch prominent-disclosure dialog?
  bool get needsConsentDialog => _analyticsConsent == null;

  /// Player's analytics choice (false when undecided — undecided means OFF).
  bool get analyticsConsented => _analyticsConsent ?? false;

  /// Events actually flow only when consented AND Firebase is configured.
  bool get analyticsActive => firebaseAvailable && analyticsConsented;

  /// Record the player's analytics decision (dialog or Settings toggle) and
  /// push it into the Firebase Analytics collection flag.
  Future<void> setAnalyticsConsent(bool granted) async {
    _analyticsConsent = granted;
    try {
      await _prefs?.setBool(_kAnalyticsConsent, granted);
    } catch (_) {}
    if (firebaseAvailable) {
      try {
        await analyticsCollectionToggle?.call(granted);
      } catch (_) {}
    }
  }

  /// Log one analytics event. No-op until the player has opted in AND
  /// Firebase is configured. Event names snake_case; params must never
  /// contain PII (docs/telemetry-events.md is the schema of record).
  void logEvent(String name, [Map<String, Object>? params]) {
    if (!analyticsActive) return;
    final sink = analyticsBackend;
    if (sink == null) return;
    sink(name, params).catchError((Object e) {
      // Telemetry must never break gameplay.
      debugPrint('telemetry: $name failed: $e');
    });
  }
}
