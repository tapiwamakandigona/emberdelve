// test/update_service_test.dart — The Watchtower (v0.21.0) gates.
//
// What this permanently proves:
//   1. The version check is honest: newer / same / older tags map to the
//      right status against the installed version, and garbage (bad JSON,
//      missing tag, thrown fetch) is a QUIET error — never a crash, never
//      a false "update available".
//   2. Consent is real: with the launch toggle off, launchCheckIfEnabled
//      performs NO network call at all (fetch count stays zero).
//   3. Dismissal sticks per-version: after dismissNotice the title-screen
//      line is gone for that tag, but a genuinely newer tag re-arms it.
//   4. The Settings section renders, checks inline, and copies the
//      releases link — and hides entirely when no fetcher is wired.
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emberdelve/meta/update_service.dart';
import 'package:emberdelve/ui/settings_screen.dart';

String releaseJson(String tag) => '{"tag_name": "$tag", "name": "x"}';

UpdateService service({
  String? body,
  String installed = '0.21.0',
  Object? throwing,
  List<Uri>? calls,
}) {
  final s = UpdateService()..installedVersion = installed;
  s.fetcher = (url) async {
    calls?.add(url);
    if (throwing != null) throw throwing;
    return body!;
  };
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('version check', () {
    test('newer tag => newer, latest exposed, v-prefix stripped', () async {
      final s = service(body: releaseJson('v0.22.0'));
      expect(await s.check(), UpdateStatus.newer);
      expect(s.latest, '0.22.0');
    });

    test('same tag => current', () async {
      final s = service(body: releaseJson('v0.21.0'));
      expect(await s.check(), UpdateStatus.current);
    });

    test('older tag => current (never nags a dev build)', () async {
      final s = service(body: releaseJson('v0.20.0'));
      expect(await s.check(), UpdateStatus.current);
    });

    test('garbage body => error, quietly', () async {
      final s = service(body: 'not json at all {');
      expect(await s.check(), UpdateStatus.error);
      expect(s.latest, isNull);
    });

    test('missing/empty tag_name => error', () async {
      expect(await service(body: '{"name": "x"}').check(), UpdateStatus.error);
      expect(
        await service(body: '{"tag_name": ""}').check(),
        UpdateStatus.error,
      );
    });

    test('thrown fetch (offline / HTTP 500) => error, never throws', () async {
      final s = service(body: null, throwing: Exception('HTTP 500'));
      expect(await s.check(), UpdateStatus.error);
    });

    test('no fetcher wired => check is a no-op', () async {
      final s = UpdateService();
      expect(s.available, isFalse);
      expect(await s.check(), UpdateStatus.unknown);
    });
  });

  group('consent (launch check)', () {
    test('OFF by default; no network call while off', () async {
      final calls = <Uri>[];
      final s = service(body: releaseJson('v9.9.9'), calls: calls);
      await s.load();
      expect(s.enabled, isFalse);
      await s.launchCheckIfEnabled();
      expect(calls, isEmpty, reason: 'no consent => no network, ever');
    });

    test('opted in => exactly one call, notice armed for newer', () async {
      final calls = <Uri>[];
      final s = service(body: releaseJson('v9.9.9'), calls: calls);
      await s.load();
      await s.setEnabled(true);
      await s.launchCheckIfEnabled();
      expect(calls.length, 1);
      expect(calls.single, UpdateService.latestReleaseApi);
      expect(s.noticeTag, '9.9.9');
    });

    test('enabled choice persists across loads', () async {
      final s = service(body: releaseJson('v0.21.0'));
      await s.load();
      await s.setEnabled(true);
      final s2 = service(body: releaseJson('v0.21.0'));
      await s2.load();
      expect(s2.enabled, isTrue);
    });
  });

  group('notice dismissal', () {
    test('dismiss sticks for that version, persists, re-arms on newer',
        () async {
      final s = service(body: releaseJson('v0.22.0'));
      await s.load();
      await s.setEnabled(true);
      await s.check();
      expect(s.noticeTag, '0.22.0');
      await s.dismissNotice();
      expect(s.noticeTag, isNull);

      // Persisted: a fresh service (same prefs) stays quiet for 0.22.0 …
      final s2 = service(body: releaseJson('v0.22.0'));
      await s2.load();
      await s2.setEnabled(true);
      await s2.check();
      expect(s2.noticeTag, isNull);

      // … but a genuinely newer release speaks again.
      final s3 = service(body: releaseJson('v0.23.0'));
      await s3.load();
      await s3.setEnabled(true);
      await s3.check();
      expect(s3.noticeTag, '0.23.0');
    });

    test('no notice when current, or when toggle is off', () async {
      final s = service(body: releaseJson('v0.21.0'));
      await s.load();
      await s.setEnabled(true);
      await s.check();
      expect(s.noticeTag, isNull);

      SharedPreferences.setMockInitialValues({}); // fresh device
      final off = service(body: releaseJson('v9.9.9'));
      await off.load();
      await off.check(); // manual check while launch toggle is off
      expect(
        off.noticeTag,
        isNull,
        reason: 'no launch-check consent => the title screen stays silent',
      );
    });
  });

  group('settings UI', () {
    Future<void> pump(WidgetTester t) async {
      await t.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await t.pumpAndSettle();
    }

    // The settings ListView builds lazily; the UPDATES section sits below
    // the fold in the test viewport, so scroll it into existence first.
    Future<void> reveal(WidgetTester t, Key key) async {
      await t.scrollUntilVisible(
        find.byKey(key),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
    }

    testWidgets('section hidden when no fetcher is wired', (t) async {
      UpdateService.instance = UpdateService();
      await pump(t);
      expect(find.text('UPDATES'), findsNothing);
      expect(find.byKey(const ValueKey('update-check-now')), findsNothing);
    });

    testWidgets('manual check shows the newer line + copies link', (t) async {
      UpdateService.instance = service(body: releaseJson('v0.22.0'));
      await UpdateService.instance.load();
      final copied = <MethodCall>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') copied.add(call);
          return null;
        },
      );
      await pump(t);
      expect(find.text('UPDATES'), findsOneWidget);

      await reveal(t, const ValueKey('update-check-now'));
      await t.tap(find.byKey(const ValueKey('update-check-now')));
      await t.pumpAndSettle();
      expect(find.text('v0.22.0 is out — you have v0.21.0.'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('update-copy-link')));
      await t.pumpAndSettle();
      expect(copied, hasLength(1));
      expect(
        (copied.single.arguments as Map)['text'],
        UpdateService.releasesPageUrl,
      );
      expect(find.text('Copied'), findsOneWidget);
      UpdateService.instance = UpdateService();
    });

    testWidgets('error stays a quiet inline line', (t) async {
      UpdateService.instance = service(body: null, throwing: 'down');
      await UpdateService.instance.load();
      await pump(t);
      await reveal(t, const ValueKey('update-check-now'));
      await t.tap(find.byKey(const ValueKey('update-check-now')));
      await t.pumpAndSettle();
      expect(
        find.text("Couldn't reach the watchtower. Try again later."),
        findsOneWidget,
      );
      UpdateService.instance = UpdateService();
    });

    testWidgets('no overflow at 320x568 with the newer row open', (t) async {
      // The standing overflow sweep can't see this section (it hides
      // without a fetcher), so guard the smallest supported viewport here.
      t.view.physicalSize = const Size(320 * 1.3, 568 * 1.3);
      t.view.devicePixelRatio = 1.3;
      addTearDown(t.view.reset);
      UpdateService.instance = service(body: releaseJson('v0.22.0'));
      await UpdateService.instance.load();
      await pump(t);
      await reveal(t, const ValueKey('update-check-now'));
      await t.tap(find.byKey(const ValueKey('update-check-now')));
      await t.pumpAndSettle();
      await reveal(t, const ValueKey('update-copy-link'));
      expect(t.takeException(), isNull);
      UpdateService.instance = UpdateService();
    });

    testWidgets('launch toggle flips and persists', (t) async {
      UpdateService.instance = service(body: releaseJson('v0.21.0'));
      await UpdateService.instance.load();
      await pump(t);
      expect(UpdateService.instance.enabled, isFalse);
      await reveal(t, const ValueKey('update-launch-check'));
      await t.tap(find.byKey(const ValueKey('update-launch-check')));
      await t.pumpAndSettle();
      expect(UpdateService.instance.enabled, isTrue);
      final fresh = UpdateService();
      await fresh.load();
      expect(fresh.enabled, isTrue);
      UpdateService.instance = UpdateService();
    });
  });
}
