// test/telemetry_test.dart — consent gating for TelemetryService: no event
// may reach the backend until (a) the player opted in AND (b) Firebase is
// configured. Also covers persistence of both choices.
import 'package:emberdelve/telemetry/telemetry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TelemetryService t;
  late List<String> sent;

  Future<void> setUpService({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    t = TelemetryService();
    sent = [];
    t.analyticsBackend = (name, params) async => sent.add(name);
    await t.load();
  }

  test('fresh install: needs dialog, events are no-ops', () async {
    await setUpService();
    t.firebaseAvailable = true;
    expect(t.needsConsentDialog, isTrue);
    expect(t.analyticsConsented, isFalse);
    t.logEvent('app_open');
    expect(sent, isEmpty, reason: 'no event before an explicit opt-in');
  });

  test('declined consent stays a no-op and is persisted', () async {
    await setUpService();
    t.firebaseAvailable = true;
    await t.setAnalyticsConsent(false);
    t.logEvent('run_started');
    expect(sent, isEmpty);
    expect(t.needsConsentDialog, isFalse, reason: 'never re-nag after a choice');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('telemetry_analytics_consent'), isFalse);
  });

  test('granted consent lets events through (and persists)', () async {
    await setUpService();
    t.firebaseAvailable = true;
    await t.setAnalyticsConsent(true);
    t.logEvent('run_started', {'difficulty': 'normal'});
    expect(sent, ['run_started']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('telemetry_analytics_consent'), isTrue);
  });

  test('consent without Firebase config is still a no-op', () async {
    await setUpService();
    t.firebaseAvailable = false; // no google-services.json
    await t.setAnalyticsConsent(true);
    t.logEvent('app_open');
    expect(sent, isEmpty, reason: 'unconfigured Firebase must never emit');
  });

  test('persisted opt-in is honored on next launch', () async {
    await setUpService(prefs: {'telemetry_analytics_consent': true});
    t.firebaseAvailable = true;
    expect(t.needsConsentDialog, isFalse);
    t.logEvent('app_open');
    expect(sent, ['app_open']);
  });

  test('consent can be revoked from Settings', () async {
    await setUpService(prefs: {'telemetry_analytics_consent': true});
    t.firebaseAvailable = true;
    var collectionOn = true;
    t.analyticsCollectionToggle = (on) async => collectionOn = on;
    await t.setAnalyticsConsent(false);
    t.logEvent('run_ended');
    expect(sent, isEmpty);
    expect(collectionOn, isFalse,
        reason: 'revoking must flip the SDK collection flag off');
  });

  test('crashlytics opt-out persists and flips the SDK toggle', () async {
    await setUpService();
    t.firebaseAvailable = true;
    expect(t.crashlyticsEnabled, isTrue, reason: 'legitimate-interest default');
    var collectionOn = true;
    t.crashlyticsCollectionToggle = (on) async => collectionOn = on;
    await t.setCrashlyticsEnabled(false);
    expect(t.crashlyticsEnabled, isFalse);
    expect(collectionOn, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('telemetry_crashlytics_enabled'), isFalse);
  });
}
