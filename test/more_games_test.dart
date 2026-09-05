// Owner directive 2026-09-05b: one quiet "More from Tsoro Studios" row in
// Settings, below the Redeem row. Pyregrove hidden behind its flag.
import 'package:emberdelve/ui/more_games.dart';
import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('entries: Fliptide always, Pyregrove only behind the flag', () {
    expect(moreGames(showPyregrove: false).map((g) => g.name), ['Fliptide']);
    expect(moreGames(showPyregrove: true).map((g) => g.name), [
      'Fliptide',
      'Pyregrove',
    ]);
    expect(kShowPyregrove, isFalse, reason: 'flip once the listing is public');
    expect(kFliptide.httpsUri.toString(), 'https://tsorostudios.itch.io/fliptide');
    expect(
      kPyregrove.marketUri.toString(),
      'market://details?id=com.tsorostudios.pyregrove&referrer=utm_source%3Demberdelve',
    );
  });

  test('Android tries market:// first and falls back to https', () async {
    final tried = <Uri>[];
    Future<bool> failMarket(
      Uri u, {
      LaunchMode mode = LaunchMode.platformDefault,
    }) async {
      tried.add(u);
      expect(mode, LaunchMode.externalApplication);
      return u.scheme != 'market';
    }

    expect(
      await openMoreGame(
        kPyregrove,
        launcher: failMarket,
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      isTrue,
    );
    expect(tried.map((u) => u.scheme), ['market', 'https']);
    tried.clear();
    // Fliptide is not on Play yet: straight to itch, even on Android.
    expect(
      await openMoreGame(
        kFliptide,
        launcher: failMarket,
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      isTrue,
    );
    expect(tried, [kFliptide.httpsUri]);
    tried.clear();
    expect(
      await openMoreGame(
        kPyregrove,
        launcher: failMarket,
        platform: TargetPlatform.android,
        isWeb: true,
      ),
      isTrue,
    );
    expect(tried.map((u) => u.scheme), ['https'], reason: 'web never market://');
  });

  testWidgets('Settings shows the row directly below Redeem, no Pyregrove', (
    tester,
  ) async {
    // Tall viewport: the lazy ListView builds every section, so the row and
    // the Redeem button can be measured together without scrolling.
    tester.view.physicalSize = const Size(412, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: const SettingsScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('MORE FROM TSORO STUDIOS'), findsOneWidget);
    expect(find.textContaining('Fliptide'), findsOneWidget);
    expect(find.textContaining('Pyregrove'), findsNothing);
    final redeem = tester.getBottomLeft(
      find.byKey(const ValueKey('redeem-unlock-code')),
    );
    final row = tester.getTopLeft(find.byKey(const Key('more-from-tsoro')));
    expect(row.dy, greaterThan(redeem.dy), reason: 'row sits below Redeem');
  });

  testWidgets('tapping an entry calls the opener once with that game', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildEmberTheme(),
        home: Scaffold(
          body: MoreFromTsoro(
            onOpen: (g) async {
              opened.add(g.name);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('more-com.tsorostudios.fliptide')));
    await tester.pump();
    expect(opened, ['Fliptide']);
  });
}
