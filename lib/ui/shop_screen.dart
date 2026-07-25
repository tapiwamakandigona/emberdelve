// ui/shop_screen.dart — the 3-tab meta shop (Weapons / Skins / Abilities).
// Reads the catalog, buys/equips against AppState.save through
// lib/meta/economy.dart (which re-checks funds/ownership — the UI never
// trusts itself), applies the Haggler discount, and persists after every
// transaction. Pixel-forest look: Cinzel headers, dark palette.
import 'dart:async' show Timer, unawaited;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;

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
            leading: _ShopIcon('weapon_${w.id}'),
            stats: _WeaponStats(weapon: w),
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
              leading: SkinPreview(skinId: sk.id),
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
            leading: _ShopIcon('ability_${a.id}'),
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
  final Widget? leading;
  final Widget? stats;
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
    this.leading,
    this.stats,
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
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
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
            if (stats != null) ...[const SizedBox(height: 4), stats!],
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
              Text('$price ',
                  style: TextStyle(
                      color: currency == Currency.coins
                          ? _gold
                          : Colors.white70,
                      fontSize: 13)),
              _CurrencyIcon(currency),
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

/// Pixel icon from assets/images/shop/ (built by tool/build_shop_icons.py).
class _ShopIcon extends StatelessWidget {
  final String id;
  const _ShopIcon(this.id);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF141420),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(6),
      child: Image.asset('assets/images/shop/$id.png',
          filterQuality: FilterQuality.none, fit: BoxFit.contain),
    );
  }
}

/// Coin / feather glyph for price rows.
class _CurrencyIcon extends StatelessWidget {
  final Currency currency;
  const _CurrencyIcon(this.currency);

  @override
  Widget build(BuildContext context) {
    return currency == Currency.coins
        ? Image.asset('assets/images/items/coin.png',
            width: 16,
            height: 16,
            alignment: Alignment.centerLeft,
            fit: BoxFit.none,
            filterQuality: FilterQuality.none)
        : Image.asset('assets/images/items/feather.png',
            width: 15,
            height: 13,
            alignment: Alignment.centerLeft,
            fit: BoxFit.none,
            filterQuality: FilterQuality.none);
  }
}

/// Compact damage/crit/range bars so weapons compare at a glance.
class _WeaponStats extends StatelessWidget {
  final Weapon weapon;
  const _WeaponStats({required this.weapon});

  // Catalog maxima (unit-tested in shop_flow_test to stay in range).
  static const _maxDamage = 10.0;
  static const _maxCrit = 25.0;
  static const _maxRange = 26.0;

  Widget _bar(String label, double t, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
          width: 28,
          child: Text(label,
              style: const TextStyle(color: _dim, fontSize: 9))),
      SizedBox(
        width: 72,
        height: 5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: t.clamp(0.05, 1.0),
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _bar('DMG', weapon.damage / _maxDamage, const Color(0xFFE86A17)),
      const SizedBox(height: 2),
      _bar('CRIT', weapon.critPercent / _maxCrit, _gold),
      const SizedBox(height: 2),
      _bar('RNG', weapon.range / _maxRange, const Color(0xFF6EA0DC)),
    ]);
  }
}

/// Animated idle preview of a skin, straight from the gameplay sheets —
/// what you buy is exactly what renders in a level. Decodes the 5-frame
/// idle strip once and steps frames on a timer (no game engine involved).
class SkinPreview extends StatefulWidget {
  final String skinId;
  const SkinPreview({super.key, required this.skinId});

  @override
  State<SkinPreview> createState() => _SkinPreviewState();
}

class _SkinPreviewState extends State<SkinPreview> {
  ui.Image? _sheet;
  Timer? _timer;
  int _frame = 0;
  static const _frames = 5;
  static const _fw = 22.0, _fh = 24.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ByteData bytes;
    try {
      bytes = await rootBundle.load(widget.skinId == 'red'
          ? 'assets/images/player/idle.png'
          : 'assets/images/player/skins/${widget.skinId}/idle.png');
    } catch (_) {
      // Missing skin sheet (catalog/art drift): preview the base knight
      // rather than crash the shop.
      bytes = await rootBundle.load('assets/images/player/idle.png');
    }
    final codec =
        await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frameInfo = await codec.getNextFrame();
    if (!mounted) {
      frameInfo.image.dispose();
      return;
    }
    setState(() => _sheet = frameInfo.image);
    _timer = Timer.periodic(const Duration(milliseconds: 140), (_) {
      if (mounted) setState(() => _frame = (_frame + 1) % _frames);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sheet?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF141420),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: _sheet == null
          ? const SizedBox.shrink()
          : CustomPaint(
              painter: _SkinFramePainter(_sheet!, _frame, _fw, _fh)),
    );
  }
}

class _SkinFramePainter extends CustomPainter {
  final ui.Image sheet;
  final int frame;
  final double fw, fh;
  _SkinFramePainter(this.sheet, this.frame, this.fw, this.fh);

  @override
  void paint(Canvas canvas, Size size) {
    const scale = 2.0;
    final dst = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: fw * scale,
        height: fh * scale);
    canvas.drawImageRect(
      sheet,
      Rect.fromLTWH(frame * fw, 0, fw, fh),
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_SkinFramePainter old) =>
      old.frame != frame || old.sheet != sheet;
}
