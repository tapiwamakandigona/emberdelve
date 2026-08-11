// M4 shop flows: headless buy/equip against the save (economy + save
// round-trip, haggler discount), plus ShopScreen widget tests covering the
// Buy → Equip state machine that testers actually tap through.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/core/save.dart';
import 'package:emberwood/meta/catalog.dart';
import 'package:emberwood/meta/economy.dart';
import 'package:emberwood/meta/progress_state.dart';
import 'package:emberwood/ui/app_state.dart';
import 'package:emberwood/ui/shop_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late SaveStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ember_shop_');
    store = SaveStore(baseDirOverride: tmp);
    AppState.init(store: store, save: SaveData());
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('headless buy/equip + save round-trip', () {
    test('buying a weapon deducts coins, persists, survives reload',
        () async {
      final save = AppState.save;
      save.coins = 500;
      final axe = weaponById('woodsman_axe');
      final wallet = Wallet(coins: save.coins, feathers: save.feathers);
      final result = buy(
        wallet: wallet,
        currency: axe.currency,
        price: axe.price,
        id: axe.id,
        owned: save.ownedWeapons,
        ownedAbilities: save.ownedAbilities,
      );
      expect(result, PurchaseResult.ok);
      save.coins = wallet.coins;
      save.equippedWeapon = axe.id;
      await AppState.persist();

      final reloaded = await store.load();
      expect(reloaded.coins, 50); // 500 - 450
      expect(reloaded.ownedWeapons, contains('woodsman_axe'));
      expect(reloaded.equippedWeapon, 'woodsman_axe');
    });

    test('haggler applies -10% to coin prices only', () {
      final owned = {'haggler'};
      expect(
          effectivePrice(
              currency: Currency.coins, price: 1000, ownedAbilities: owned),
          900);
      expect(
          effectivePrice(
              currency: Currency.feathers, price: 12, ownedAbilities: owned),
          12);
    });

    test('cannot buy without funds; cannot rebuy owned', () {
      final save = AppState.save;
      final wallet = Wallet(coins: 10);
      final axe = weaponById('woodsman_axe');
      expect(
          buy(
              wallet: wallet,
              currency: axe.currency,
              price: axe.price,
              id: axe.id,
              owned: save.ownedWeapons,
              ownedAbilities: save.ownedAbilities),
          PurchaseResult.cantAfford);
      expect(wallet.coins, 10);
      expect(
          buy(
              wallet: wallet,
              currency: Currency.coins,
              price: 0,
              id: 'squire_blade', // starter is pre-owned
              owned: save.ownedWeapons,
              ownedAbilities: save.ownedAbilities),
          PurchaseResult.alreadyOwned);
    });

    test('skin level + melee power reflect recorded kills', () {
      final save = AppState.save;
      save.skinKills['red'] = 25; // exactly killsForLevel(1)
      expect(skinLevel(save, 'red'), 2);
      expect(meleePower(save), closeTo(1.03, 1e-9));
    });
  });

  group('ShopScreen widget', () {
    setUp(() => AppState.diskWrites = false); // see AppState.diskWrites
    tearDown(() => AppState.diskWrites = true);

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ShopScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('shows all three tabs with catalog content', (tester) async {
      await pump(tester);
      expect(find.text('WEAPONS'), findsOneWidget);
      expect(find.text('SKINS'), findsOneWidget);
      expect(find.text('ABILITIES'), findsOneWidget);
      expect(find.text("Squire's Blade"), findsOneWidget);
      expect(find.text("Woodsman's Axe"), findsOneWidget);
      // Stats line rendered.
      expect(find.textContaining('DMG 5'), findsWidgets);
    });

    testWidgets('buy flow: BUY becomes EQUIP, wallet drops, save persists',
        (tester) async {
      AppState.save.coins = 500;
      await pump(tester);
      final axeCard = find.byKey(const ValueKey('weapon_woodsman_axe'));
      expect(axeCard, findsOneWidget);
      final buyBtn = find.descendant(
          of: axeCard, matching: find.widgetWithText(FilledButton, 'BUY'));
      expect(buyBtn, findsOneWidget);
      await tester.tap(buyBtn);
      await tester.pumpAndSettle();
      expect(AppState.save.ownedWeapons, contains('woodsman_axe'));
      expect(AppState.save.coins, 50);
      // Now shows EQUIP; tap it.
      final equipBtn = find.descendant(
          of: axeCard,
          matching: find.widgetWithText(OutlinedButton, 'EQUIP'));
      expect(equipBtn, findsOneWidget);
      await tester.tap(equipBtn);
      await tester.pumpAndSettle();
      expect(AppState.save.equippedWeapon, 'woodsman_axe');
      expect(find.descendant(of: axeCard, matching: find.text('EQUIPPED')),
          findsOneWidget);
      // Disk round-trip is covered headlessly ('buying a weapon...' and the
      // persist-queue test); widget tests run with diskWrites disabled.
    });

    testWidgets('unaffordable items have BUY disabled', (tester) async {
      AppState.save.coins = 0;
      await pump(tester);
      final axeCard = find.byKey(const ValueKey('weapon_woodsman_axe'));
      final btn = tester.widget<FilledButton>(find.descendant(
          of: axeCard, matching: find.byType(FilledButton)));
      expect(btn.onPressed, isNull);
    });

    testWidgets('haggler discount is visible on coin prices', (tester) async {
      AppState.save.ownedAbilities.add('haggler');
      AppState.save.coins = 10000;
      await pump(tester);
      // Price text is now '<n> ' + a coin glyph (icons replaced the words).
      expect(find.text('405 '), findsOneWidget); // 450 * 0.9
      expect(find.textContaining('Haggler -10%'), findsWidgets);
    });

    testWidgets('skins tab shows level, power multiplier and kills-to-next',
        (tester) async {
      AppState.save.skinKills['red'] = 30;
      await pump(tester);
      await tester.tap(find.text('SKINS'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Lv 2'), findsWidgets);
      expect(find.textContaining('x1.03'), findsOneWidget);
      // killsForLevel(2)=100, has 30 -> 70 to Lv 3.
      expect(find.textContaining('70 kills to Lv 3'), findsOneWidget);
    });
  });
}
