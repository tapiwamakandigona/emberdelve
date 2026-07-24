// ui/shop_screen.dart — the 3-tab meta shop (Weapons / Skins / Abilities).
// Reads the catalog, buys/equips against AppState.save through
// lib/meta/economy.dart (which re-checks funds/ownership — the UI never
// trusts itself), applies the Haggler discount, and persists after every
// transaction. Pixel-forest look: Cinzel headers, dark palette.
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../meta/catalog.dart';
import '../meta/economy.dart';
import '../meta/progress_state.dart';
import 'app_state.dart';

const _bg = Color(0xFF141420);
const _panel = Color(0xFF1E1E2E);
const _gold = Color(0xFFE8A33D);
const _green = Color(0xFF3E8948);
const _dim = Colors.white38;

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Wallet get _wallet => Wallet(
      coins: AppState.save.coins, feathers: AppState.save.feathers);

  void _spendFromWallet(Wallet w) {
    AppState.save.coins = w.coins;
    AppState.save.feathers = w.feathers;
  }

  int _priceFor(Currency currency, int price) => effectivePrice(
      currency: currency,
      price: price,
      ownedAbilities: AppState.save.ownedAbilities);

  Future<void> _buy({
    required String id,
    required Currency currency,
    required int price,
    required Set<String> owned,
  }) async {
    final wallet = _wallet;
    final result = buy(
      wallet: wallet,
      currency: currency,
      price: price,
      id: id,
      owned: owned,
      ownedAbilities: AppState.save.ownedAbilities,
    );
    switch (result) {
      case PurchaseResult.ok:
        _spendFromWallet(wallet);
        AudioService.instance?.playSfx('unlock');
        // UI first, disk second: persist() is atomic and best-effort — a
        // pending write must never freeze the shop (or its widget tests).
        unawaited(AppState.persist());
      case PurchaseResult.cantAfford:
        AudioService.instance?.playSfx('block', volume: 0.6);
      case PurchaseResult.alreadyOwned:
        break;
    }
    if (mounted) setState(() {});
  }

  void _equipWeapon(String id) {
    AppState.save.equippedWeapon = id;
    AudioService.instance?.playSfx('ui_tap');
    unawaited(AppState.persist());
    setState(() {});
  }

  void _equipSkin(String id) {
    AppState.save.equippedSkin = id;
    AudioService.instance?.playSfx('ui_tap');
    unawaited(AppState.persist());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('EMBER SHOP',
              style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: _gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3)),
          actions: [WalletChip(wallet: _wallet)],
          bottom: const TabBar(
            indicatorColor: _gold,
            labelColor: _gold,
            unselectedLabelColor: _dim,
            tabs: [
              Tab(text: 'WEAPONS'),
              Tab(text: 'SKINS'),
              Tab(text: 'ABILITIES'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _weaponsTab(),
          _skinsTab(),
          _abilitiesTab(),
        ]),
      ),
    );
  }

  Widget _weaponsTab() {
    final save = AppState.save;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final w in kWeapons)
          _ShopCard(
            key: ValueKey('weapon_${w.id}'),
            title: w.name,
            subtitle:
                'DMG ${w.damage}  ·  CRIT ${w.critPercent}% x${w.critMultiplier}'
                '  ·  RANGE +${w.range.toStringAsFixed(0)}',
            detail: w.specialText,
            owned: save.ownedWeapons.contains(w.id),
            equipped: save.equippedWeapon == w.id,
            currency: w.currency,
            price: _priceFor(w.currency, w.price),
            basePrice: w.price,
            canAfford: _wallet.canAfford(
                w.currency, _priceFor(w.currency, w.price)),
            onBuy: () => _buy(
                id: w.id,
                currency: w.currency,
                price: w.price,
                owned: save.ownedWeapons),
            onEquip: () => _equipWeapon(w.id),
          ),
      ],
    );
  }

  Widget _skinsTab() {
    final save = AppState.save;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final sk in kSkins)
          Builder(builder: (_) {
            final level = skinLevel(save, sk.id);
            final kills = save.skinKills[sk.id] ?? 0;
            final next = level < Skin.maxLevel
                ? '${Skin.killsForLevel(level) - kills} kills to Lv ${level + 1}'
                : 'MAX level';
            return _ShopCard(
              key: ValueKey('skin_${sk.id}'),
              title: sk.name,
              subtitle:
                  'Lv $level  ·  melee power x${sk.powerAt(level).toStringAsFixed(2)}',
              detail: next,
              owned: save.ownedSkins.contains(sk.id),
              equipped: save.equippedSkin == sk.id,
              currency: sk.currency,
              price: _priceFor(sk.currency, sk.price),
              basePrice: sk.price,
              canAfford: _wallet.canAfford(
                  sk.currency, _priceFor(sk.currency, sk.price)),
              onBuy: () => _buy(
                  id: sk.id,
                  currency: sk.currency,
                  price: sk.price,
                  owned: save.ownedSkins),
              onEquip: () => _equipSkin(sk.id),
            );
          }),
      ],
    );
  }

  Widget _abilitiesTab() {
    final save = AppState.save;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final a in kAbilities)
          _ShopCard(
            key: ValueKey('ability_${a.id}'),
            title: a.name,
            subtitle: a.text,
            detail: null,
            owned: save.ownedAbilities.contains(a.id),
            equipped: save.ownedAbilities.contains(a.id), // passive: own = on
            passive: true,
            currency: a.currency,
            price: _priceFor(a.currency, a.price),
            basePrice: a.price,
            canAfford: _wallet.canAfford(
                a.currency, _priceFor(a.currency, a.price)),
            onBuy: () => _buy(
                id: a.id,
                currency: a.currency,
                price: a.price,
                owned: save.ownedAbilities),
            onEquip: () {},
          ),
      ],
    );
  }
}

/// Coin + feather balance chip (shop app bar, level select).
class WalletChip extends StatelessWidget {
  final Wallet wallet;
  const WalletChip({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(children: [
        Image.asset('assets/images/items/coin.png',
            width: 32,
            height: 16,
            alignment: Alignment.centerLeft,
            fit: BoxFit.none,
            filterQuality: FilterQuality.none),
        Text(' ${wallet.coins}   ',
            style: const TextStyle(color: _gold, fontSize: 14)),
        Image.asset('assets/images/items/feather.png',
            width: 17,
            height: 13,
            alignment: Alignment.centerLeft,
            fit: BoxFit.none,
            filterQuality: FilterQuality.none),
        Text(' ${wallet.feathers}',
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ]),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? detail;
  final bool owned;
  final bool equipped;
  final bool passive;
  final Currency currency;
  final int price; // effective (post-haggler)
  final int basePrice;
  final bool canAfford;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _ShopCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.owned,
    required this.equipped,
    this.passive = false,
    required this.currency,
    required this.price,
    required this.basePrice,
    required this.canAfford,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final discounted = price < basePrice;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: equipped ? _gold : Colors.white12,
            width: equipped ? 1.5 : 1),
      ),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontFamily: 'Cinzel',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (detail != null && detail!.isNotEmpty)
              Text(detail!,
                  style: const TextStyle(color: _dim, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 12),
        if (!owned) ...[
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (discounted)
                Text('$basePrice ',
                    style: const TextStyle(
                        color: _dim,
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough)),
              Text(
                  '$price ${currency == Currency.coins ? 'coins' : 'feathers'}',
                  style: TextStyle(
                      color: currency == Currency.coins
                          ? _gold
                          : Colors.white70,
                      fontSize: 13)),
            ]),
            if (discounted)
              const Text('Haggler -10%',
                  style: TextStyle(color: _green, fontSize: 10)),
          ]),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: canAfford ? _green : Colors.white12),
            onPressed: canAfford ? onBuy : null,
            child: const Text('BUY'),
          ),
        ] else if (equipped)
          Text(passive ? 'OWNED' : 'EQUIPPED',
              style: const TextStyle(
                  color: _gold, fontWeight: FontWeight.bold, fontSize: 12))
        else
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _gold), foregroundColor: _gold),
            onPressed: onEquip,
            child: const Text('EQUIP'),
          ),
      ]),
    );
  }
}
