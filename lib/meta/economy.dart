// meta/economy.dart — wallets and shop transactions. Pure Dart, unit-tested.
// Never trusts UI: every purchase re-checks funds and ownership.

import 'catalog.dart';

class Wallet {
  int coins;
  int feathers;
  Wallet({this.coins = 0, this.feathers = 0});

  int of(Currency c) => c == Currency.coins ? coins : feathers;

  void earn(Currency c, int amount) {
    assert(amount >= 0);
    if (c == Currency.coins) {
      coins += amount;
    } else {
      feathers += amount;
    }
  }

  bool canAfford(Currency c, int price) => of(c) >= price;

  /// Returns true and deducts on success; false (no change) otherwise.
  bool spend(Currency c, int price) {
    assert(price >= 0);
    if (!canAfford(c, price)) return false;
    if (c == Currency.coins) {
      coins -= price;
    } else {
      feathers -= price;
    }
    return true;
  }

  Map<String, Object> toJson() => {'coins': coins, 'feathers': feathers};
  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        coins: (j['coins'] as num?)?.toInt() ?? 0,
        feathers: (j['feathers'] as num?)?.toInt() ?? 0,
      );
}

/// Effective coin price after abilities (Haggler = -10%, rounded down,
/// feather prices unaffected).
int effectivePrice({
  required Currency currency,
  required int price,
  required Set<String> ownedAbilities,
}) {
  if (currency == Currency.coins && ownedAbilities.contains('haggler')) {
    return (price * 0.9).floor();
  }
  return price;
}

enum PurchaseResult { ok, alreadyOwned, cantAfford }

PurchaseResult buy({
  required Wallet wallet,
  required Currency currency,
  required int price,
  required String id,
  required Set<String> owned,
  required Set<String> ownedAbilities,
}) {
  if (owned.contains(id)) return PurchaseResult.alreadyOwned;
  final cost = effectivePrice(
      currency: currency, price: price, ownedAbilities: ownedAbilities);
  if (!wallet.spend(currency, cost)) return PurchaseResult.cantAfford;
  owned.add(id);
  return PurchaseResult.ok;
}
