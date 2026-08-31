// DEMAND quality gate, automated (alpha.16): "Overflow sweep for Flutter UI
// screens at small phone + 1.3× text." Every meta screen is pumped on a
// small-phone surface (portrait 320×568 and landscape 568×320 logical px)
// with TextScaler 1.3. RenderFlex/positioned overflows are reported through
// FlutterError during layout, which fails the owning testWidgets case — so
// a red case here IS an overflow (or a real build crash) on that screen at
// that size.
//
// GameScreen is exempt per the M2c escape hatch (GameWidget frame loops are
// flaky headless); its HUD/overlay layout is covered by hud_layout_test and
// the release look-pass instead.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/core/save.dart';
import 'package:emberwood/ui/app_state.dart';
import 'package:emberwood/ui/credits_screen.dart';
import 'package:emberwood/ui/level_select_screen.dart';
import 'package:emberwood/ui/settings_screen.dart';
import 'package:emberwood/ui/shop_screen.dart';
import 'package:emberwood/ui/title_screen.dart';

/// Small-phone surfaces (logical px). 320×568 is the iPhone SE1 class —
/// the smallest surface still in the wild; landscape is the game's own
/// preferred orientation for the meta screens reached from gameplay.
const _portrait = Size(320, 568);
const _landscape = Size(568, 320);
const _textScale = TextScaler.linear(1.3);

Widget _host(Widget screen) => MaterialApp(
  home: MediaQuery(
    // MaterialApp installs its own MediaQuery from the view; override
    // below it so the scaler survives route transitions.
    data: MediaQueryData(size: _portrait, textScaler: _textScale),
    child: screen,
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: _textScale),
    child: child!,
  ),
);

/// Bounded pump: flush a fling's ballistic scroll without pumpAndSettle
/// (screens with looping animations never settle).
Future<void> _pumpBallistics(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget screen, {
  bool settles = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(screen));
  if (settles) {
    await tester.pumpAndSettle();
  } else {
    // Screens with looping animations (title parallax) never settle.
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ember_overflow_');
    AppState.init(
      store: SaveStore(baseDirOverride: tmp),
      save: SaveData(),
    );
    AppState.diskWrites = false;
  });
  tearDown(() {
    AppState.diskWrites = true;
    tmp.deleteSync(recursive: true);
  });

  /// A save with maximal UI load: full wallet (widest coin counter), every
  /// level finished with 3 medals (every badge row rendered), so the sweep
  /// exercises the widest text the screens can ever show.
  void loadedSave() {
    final save = AppState.save;
    save.coins = 999999;
    for (final w in ['w1', 'w2']) {
      for (final l in ['l1', 'l2', 'l3', 'l4', 'l5', 'boss']) {
        save.recordFor('${w}_$l')
          ..finished = true
          ..allChests = true
          ..lowDamage = true;
      }
    }
  }

  for (final entry in {
    'portrait 320x568': _portrait,
    'landscape 568x320': _landscape,
  }.entries) {
    final size = entry.value;

    group('overflow sweep @1.3x text, ${entry.key}:', () {
      testWidgets('title screen', (tester) async {
        await _pumpAt(tester, size, const TitleScreen(), settles: false);
        expect(find.text('EMBERDELVE'), findsOneWidget);
      });

      testWidgets('level select (loaded save)', (tester) async {
        loadedSave();
        await _pumpAt(tester, size, const LevelSelectScreen());
        expect(find.text('WORLD 1 — EMBERWOOD'), findsOneWidget);
        // Drive the lazy list to the bottom so every card lays out.
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
          2000,
        );
        await _pumpBallistics(tester);
      });

      testWidgets('shop (loaded save)', (tester) async {
        loadedSave();
        await _pumpAt(tester, size, const ShopScreen());
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
          2000,
        );
        await _pumpBallistics(tester);
      });

      testWidgets('settings', (tester) async {
        await _pumpAt(tester, size, const SettingsScreen());
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
          2000,
        );
        await _pumpBallistics(tester);
      });

      testWidgets('credits', (tester) async {
        // Pre-warm the bundle cache under real async FIRST: a loadString
        // issued from inside the FakeAsync zone can starve when it is the
        // suite's second credits pump. The screen's own loadString then
        // resolves from cache on the next pump.
        await tester.runAsync(() => rootBundle.loadString('CREDITS.md'));
        // settles:false — the loading spinner animates until the future
        // resolves, so pumpAndSettle can hang here.
        await _pumpAt(tester, size, const CreditsScreen(), settles: false);
        // rootBundle load needs a real-async flush (FakeAsync starves it);
        // retry until the document's Scrollable is actually up — one fixed
        // delay proved flaky depending on suite order / bundle cache.
        for (
          var i = 0;
          i < 20 && find.byType(Scrollable).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }
        expect(find.byType(Scrollable), findsWidgets);
        await tester.fling(
          find.byType(Scrollable).first,
          const Offset(0, -6000),
          2000,
        );
        await _pumpBallistics(tester);
      });
    });
  }
}
