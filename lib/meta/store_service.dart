// lib/meta/store_service.dart — Play Billing for the Ember Forge (spec R8).
//
// Layering:
//   StoreGateway  — a thin seam over the store plugin. The real gateway wraps
//                   package:in_app_purchase; tests inject a fake and never
//                   touch a platform channel.
//   StoreService  — owns the purchase lifecycle: availability, the localized
//                   price, buy/restore, and turning a *confirmed* purchase
//                   event into the persisted entitlement (via onEntitled).
//
// Contracts (documented so they never regress):
//   1. The purchase stream is subscribed BEFORE any query/buy call, so an
//      event can never be missed (in_app_purchase delivery contract).
//   2. Every delivered purchase with pendingCompletePurchase is completed
//      (acknowledged) — Google refunds unacknowledged purchases after 3 days.
//   3. Entitlement is granted on PURCHASED and RESTORED, and never revoked
//      here (see MetaState.forgeUnlocked — sticky by design).
//   4. A silent restore runs once at startup so a reinstall or a new device
//      heals itself without the player hunting for a button. The button in
//      Settings stays anyway (spec R8: restorable, visibly).
//   5. Failures degrade honestly: no store => the Forge sheet says so;
//      a canceled purchase is not an error; a pending (slow) purchase shows
//      as pending until Play resolves it.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'forge.dart';

/// Store-agnostic purchase status (mirror of the plugin's, plugin-free for
/// tests).
enum StorePurchaseStatus { pending, purchased, restored, error, canceled }

/// One purchase event as seen by the service.
class StorePurchaseEvent {
  final String productId;
  final StorePurchaseStatus status;
  final bool needsCompletion;
  final Object? raw; // the plugin's PurchaseDetails, when real
  const StorePurchaseEvent({
    required this.productId,
    required this.status,
    this.needsCompletion = false,
    this.raw,
  });
}

/// A queried product: id + localized, symbol-correct price string.
class StoreProductInfo {
  final String id;
  final String price;
  const StoreProductInfo({required this.id, required this.price});
}

/// The seam. Real impl: [PlayStoreGateway]. Tests: a fake.
abstract class StoreGateway {
  Future<bool> isAvailable();
  Future<StoreProductInfo?> queryProduct(String id);
  Future<void> buy(String id);
  Future<void> restore();
  Stream<List<StorePurchaseEvent>> get purchases;
  Future<void> complete(StorePurchaseEvent event);
}

/// Production gateway over package:in_app_purchase.
class PlayStoreGateway implements StoreGateway {
  final InAppPurchase _iap = InAppPurchase.instance;
  ProductDetails? _details; // cached for buy()

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<StoreProductInfo?> queryProduct(String id) async {
    final resp = await _iap.queryProductDetails({id});
    if (resp.productDetails.isEmpty) return null;
    _details = resp.productDetails.first;
    return StoreProductInfo(id: _details!.id, price: _details!.price);
  }

  @override
  Future<void> buy(String id) async {
    final details = _details;
    if (details == null || details.id != id) {
      throw StateError('queryProduct($id) must succeed before buy()');
    }
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Stream<List<StorePurchaseEvent>> get purchases =>
      _iap.purchaseStream.map((batch) => [
            for (final p in batch)
              StorePurchaseEvent(
                productId: p.productID,
                status: switch (p.status) {
                  PurchaseStatus.pending => StorePurchaseStatus.pending,
                  PurchaseStatus.purchased => StorePurchaseStatus.purchased,
                  PurchaseStatus.restored => StorePurchaseStatus.restored,
                  PurchaseStatus.error => StorePurchaseStatus.error,
                  PurchaseStatus.canceled => StorePurchaseStatus.canceled,
                },
                needsCompletion: p.pendingCompletePurchase,
                raw: p,
              ),
          ]);

  @override
  Future<void> complete(StorePurchaseEvent event) {
    final raw = event.raw;
    if (raw is PurchaseDetails) return _iap.completePurchase(raw);
    return Future.value();
  }
}

/// UI-facing state of the Forge store.
enum ForgeStoreState {
  /// Startup: availability/product not resolved yet.
  unknown,

  /// Billing unavailable (no Play, no network at first query, sideload...).
  unavailable,

  /// Product known, price loaded, ready to buy.
  ready,

  /// A purchase is in flight (sheet shows a spinner, buttons disabled).
  pending,

  /// Entitled — bought or restored (or already owned per MetaState).
  owned,
}

class StoreService {
  /// Same optional-singleton convention as AudioService: null in unit tests
  /// that don't care about the store.
  static StoreService? instance;

  final StoreGateway gateway;

  /// Called exactly when a confirmed purchase/restore of the Forge lands.
  /// The owner (GameController) grants + persists + notifies.
  final Future<void> Function() onEntitled;

  /// True if the profile already owns the Forge (drives the initial state).
  final bool Function() alreadyOwned;

  /// Bumps whenever [state], [price] or [lastError] change (same ValueNotifier
  /// tick idiom the controller uses).
  final ValueNotifier<int> tick = ValueNotifier(0);

  ForgeStoreState _state = ForgeStoreState.unknown;
  String? _price;
  String? _lastError;
  StreamSubscription<List<StorePurchaseEvent>>? _sub;

  StoreService({
    required this.gateway,
    required this.onEntitled,
    required this.alreadyOwned,
  });

  ForgeStoreState get state =>
      alreadyOwned() ? ForgeStoreState.owned : _state;
  String? get price => _price;
  String? get lastError => _lastError;

  void _set(ForgeStoreState s, {String? error}) {
    _state = s;
    _lastError = error;
    tick.value++;
  }

  /// Subscribe + query + silent restore. Never throws; never blocks startup
  /// (call unawaited from main).
  Future<void> init() async {
    // Contract 1: listen before anything else can produce an event.
    _sub = gateway.purchases.listen(_onPurchases, onError: (Object e) {
      // Stream errors are transient platform hiccups; keep the last good
      // state but surface the message for the sheet's small print.
      _lastError = '$e';
      tick.value++;
    });
    try {
      if (!await gateway.isAvailable()) {
        _set(ForgeStoreState.unavailable);
        return;
      }
      final product = await gateway.queryProduct(forgeProductId);
      if (product == null) {
        _set(ForgeStoreState.unavailable,
            error: 'Product not found on this store');
        return;
      }
      _price = product.price;
      _set(ForgeStoreState.ready);
      // Contract 4: heal entitlement on reinstall/new device, silently.
      if (!alreadyOwned()) await gateway.restore();
    } catch (e) {
      _set(ForgeStoreState.unavailable, error: '$e');
    }
  }

  Future<void> _onPurchases(List<StorePurchaseEvent> batch) async {
    for (final event in batch) {
      if (event.productId != forgeProductId) {
        // Unknown product: still complete it so nothing dangles unacked.
        if (event.needsCompletion) await gateway.complete(event);
        continue;
      }
      switch (event.status) {
        case StorePurchaseStatus.pending:
          _set(ForgeStoreState.pending);
        case StorePurchaseStatus.purchased || StorePurchaseStatus.restored:
          // Contract 3: grant first, then acknowledge — if the app dies
          // between the two, Play redelivers the purchase and both steps
          // rerun (grant is idempotent).
          await onEntitled();
          if (event.needsCompletion) await gateway.complete(event);
          _set(ForgeStoreState.owned);
        case StorePurchaseStatus.canceled:
          // Not an error: the player changed their mind. Back to ready.
          if (event.needsCompletion) await gateway.complete(event);
          _set(_price != null
              ? ForgeStoreState.ready
              : ForgeStoreState.unavailable);
        case StorePurchaseStatus.error:
          if (event.needsCompletion) await gateway.complete(event);
          _set(
            _price != null
                ? ForgeStoreState.ready
                : ForgeStoreState.unavailable,
            error: 'Purchase failed — nothing was charged. Try again.',
          );
      }
    }
  }

  /// Launch the Play purchase flow. No-ops unless [state] is ready.
  Future<void> buy() async {
    if (state != ForgeStoreState.ready) return;
    _set(ForgeStoreState.pending);
    try {
      await gateway.buy(forgeProductId);
      // Outcome arrives on the purchase stream.
    } catch (e) {
      _set(ForgeStoreState.ready, error: '$e');
    }
  }

  /// Explicit restore (Settings + Forge sheet). Outcome arrives on the
  /// stream; if nothing is owned, Play simply delivers no event, so we drop
  /// back to ready after the call instead of spinning forever.
  Future<void> restore() async {
    if (state == ForgeStoreState.owned) return;
    try {
      await gateway.restore();
      if (!alreadyOwned() && _state == ForgeStoreState.pending) {
        _set(ForgeStoreState.ready);
      }
    } catch (e) {
      _set(_state, error: '$e');
    }
  }

  Future<void> dispose() async => _sub?.cancel();
}
