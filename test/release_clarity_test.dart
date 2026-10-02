import 'dart:io';

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/forge.dart';
import 'package:emberdelve/meta/store_service.dart';
import 'package:emberdelve/ui/forge_sheet.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'forge_unlock_test.dart' show FakeGateway;

const _spendCopy =
    'Roll, then tap a die. ATTACK and BLOCK show a preview before you '
    'spend it. Choose one: that die is used for this turn. When you are '
    'ready, END TURN lets the enemy make the move shown above its head.';

Future<void> _openForge(
  WidgetTester tester,
  GameController c, {
  double scale = 1,
  double height = 568,
}) async {
  tester.view.physicalSize = Size(320, height);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildEmberTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showForgeSheet(context, c),
              child: const Text('Open forge'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open forge'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() async {
    await StoreService.instance?.dispose();
    StoreService.instance = null;
  });

  for (final scale in [1.0, 1.3, 1.8]) {
    testWidgets('Forge stays readable at 320px and ${scale}x text', (
      tester,
    ) async {
      final c = GameController();
      await _openForge(tester, c, scale: scale);
      expect(tester.takeException(), isNull);
      final later = find.byKey(const ValueKey('forge-not-now'));
      await tester.ensureVisible(later);
      await tester.pumpAndSettle();
      expect(later.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(later);
      await tester.pumpAndSettle();
      expect(find.byType(ForgeSheet), findsNothing);
      expect(c.meta.forgeUnlocked, isFalse);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }

  testWidgets('Forge explains free play and a permanent non-subscription', (
    tester,
  ) async {
    final c = GameController();
    final gateway = FakeGateway(
      product: const StoreProductInfo(
        id: forgeProductId,
        price: '4,99 €',
      ),
    );
    final store = StoreService(
      gateway: gateway,
      alreadyOwned: () => c.meta.forgeUnlocked,
      onEntitled: () async {
        c.meta.forgeUnlocked = true;
      },
    );
    StoreService.instance = store;
    await store.init();
    await _openForge(tester, c);
    expect(find.text('FREE TO PLAY'), findsOneWidget);
    expect(find.text('ONE PURCHASE OPENS THE ENDGAME'), findsOneWidget);
    expect(
      find.text('Pay once. Keep it. No subscription.'),
      findsOneWidget,
    );
    final buy = find.byKey(const ValueKey('forge-buy'));
    await tester.ensureVisible(buy);
    await tester.pumpAndSettle();
    expect(find.textContaining('4,99 €'), findsOneWidget);
    expect(gateway.calls.where((s) => s.startsWith('buy:')), isEmpty);
    final later = find.byKey(const ValueKey('forge-not-now'));
    await tester.ensureVisible(later);
    await tester.pumpAndSettle();
    await tester.tap(later);
    await tester.pumpAndSettle();
    expect(gateway.calls.where((s) => s.startsWith('buy:')), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await gateway.controller.close();
    c.dispose();
  });

  testWidgets('pending purchase offers no second buy and can be closed', (
    tester,
  ) async {
    final c = GameController();
    final gateway = FakeGateway(
      product: const StoreProductInfo(id: forgeProductId, price: r'$3.99'),
    );
    final store = StoreService(
      gateway: gateway,
      alreadyOwned: () => c.meta.forgeUnlocked,
      onEntitled: () async {
        c.meta.forgeUnlocked = true;
      },
    );
    StoreService.instance = store;
    await store.init();
    await _openForge(tester, c);
    final buy = find.byKey(const ValueKey('forge-buy'));
    await tester.ensureVisible(buy);
    await tester.pumpAndSettle();
    await tester.tap(buy);
    await tester.pump();
    expect(store.state, ForgeStoreState.pending);
    expect(find.byKey(const ValueKey('forge-buy')), findsNothing);
    final later = find.byKey(const ValueKey('forge-not-now'));
    await tester.ensureVisible(later);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(later);
    await tester.pumpAndSettle();
    expect(gateway.calls.where((s) => s.startsWith('buy:')).length, 1);
    expect(c.meta.forgeUnlocked, isFalse);
    await tester.pumpWidget(const SizedBox());
    await gateway.controller.close();
    c.dispose();
  });

  testWidgets('manual teaches preview and enemy turn before extra rules', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: const PrimerScreen()),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('ROLL, THEN SPEND'), findsOneWidget);
    expect(find.text(_spendCopy), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('startup explicitly requests edge-to-edge without opting out', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('SystemUiMode.edgeToEdge'));
    for (final path in [
      'android/app/src/main/res/values/styles.xml',
      'android/app/src/main/res/values-night/styles.xml',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('windowOptOutEdgeToEdgeEnforcement')),
      );
    }
  });
}
