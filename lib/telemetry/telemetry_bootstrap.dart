// lib/telemetry/telemetry_bootstrap.dart — wires Firebase into the
// TelemetryService gate. Called once from main() before runApp.
//
// Designed to work WITHOUT Firebase configured: until SA-A2 drops
// android/app/google-services.json into the repo, Firebase.initializeApp()
// throws, we catch it, and the whole telemetry stack stays a silent no-op
// (the game runs exactly as before — zero network calls).
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'telemetry_service.dart';

/// Load consent prefs, then try to bring Firebase up. Never throws.
Future<void> initTelemetry() async {
  final t = TelemetryService.instance;
  await t.load();
  try {
    // TODO(SA-A2): this uses the default Android config from
    // android/app/google-services.json. Once `flutterfire configure` has been
    // run, prefer: Firebase.initializeApp(options:
    // DefaultFirebaseOptions.currentPlatform) with the generated
    // lib/firebase_options.dart (works on all platforms, not just Android).
    await Firebase.initializeApp();
    t.firebaseAvailable = true;
  } catch (e) {
    debugPrint('telemetry: Firebase unconfigured — telemetry disabled ($e)');
    return; // No config yet: leave every backend null (no-ops).
  }

  final analytics = FirebaseAnalytics.instance;
  final crashlytics = FirebaseCrashlytics.instance;

  t.analyticsBackend =
      (name, params) => analytics.logEvent(name: name, parameters: params);
  t.analyticsCollectionToggle =
      (on) => analytics.setAnalyticsCollectionEnabled(on);
  t.crashlyticsCollectionToggle =
      (on) => crashlytics.setCrashlyticsCollectionEnabled(on);

  // Apply persisted choices. Analytics collection is OFF in the manifest
  // (firebase_analytics_collection_enabled=false) so nothing is buffered or
  // sent before this line runs — it only turns ON after an explicit opt-in.
  try {
    await t.analyticsCollectionToggle!(t.analyticsConsented);
    await t.crashlyticsCollectionToggle!(t.crashlyticsEnabled);
  } catch (e) {
    debugPrint('telemetry: applying collection flags failed: $e');
  }

  // Crash hooks (legitimate interest; respects the Settings opt-out because
  // setCrashlyticsCollectionEnabled(false) drops all reports at the SDK).
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}
