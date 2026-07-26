// lib/telemetry/telemetry_bootstrap.dart — wires Firebase Analytics into
// the TelemetryService gate. Called once from main() before runApp.
//
// Designed to work WITHOUT Firebase configured: if
// android/app/google-services.json is absent, Firebase.initializeApp()
// throws, we catch it, and the whole telemetry stack stays a silent no-op
// (the game runs exactly as before — zero network calls).
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'telemetry_service.dart';

/// Load consent prefs, then try to bring Firebase up. Never throws.
Future<void> initTelemetry() async {
  final t = TelemetryService.instance;
  await t.load();
  try {
    // Uses the default Android config from android/app/google-services.json
    // (Firebase project "Emberdelve", gen-lang-client-0980262477).
    await Firebase.initializeApp();
    t.firebaseAvailable = true;
  } catch (e) {
    debugPrint('telemetry: Firebase unconfigured — telemetry disabled ($e)');
    return; // No config: leave every backend null (no-ops).
  }

  final analytics = FirebaseAnalytics.instance;
  t.analyticsBackend =
      (name, params) => analytics.logEvent(name: name, parameters: params);
  t.analyticsCollectionToggle =
      (on) => analytics.setAnalyticsCollectionEnabled(on);

  // Apply the persisted choice. Analytics collection is OFF in the manifest
  // (firebase_analytics_collection_enabled=false) so nothing is buffered or
  // sent before this line runs — it only turns ON after an explicit opt-in.
  try {
    await t.analyticsCollectionToggle!(t.analyticsConsented);
  } catch (e) {
    debugPrint('telemetry: applying collection flag failed: $e');
  }
}
