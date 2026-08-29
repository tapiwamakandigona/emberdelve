// test/forge_unlock_test.dart — the Ember Forge gate + billing service
// (spec R8, v0.4.0). Four contracts:
//   1. Persistence: forgeUnlocked round-trips through meta JSON and defaults
//      to false on every pre-Forge save.
//   2. Gating: HARD and ascension>0 are locked without the Forge, open with
//      it, and clampRunParams is the guarantee behind every UI lock.
//   3. Purchase lifecycle: purchased/restored events grant the entitlement
//      exactly once, acknowledge the purchase, and survive pending/cancel/
//      error without granting.
//   4. Startup restore: init() subscribes before querying, restores silently
//      when not owned, and degrades honestly when the store is missing.
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/forge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/store_service.dart';

class FakeGateway implements StoreGateway {
  final controller = StreamController<List<StorePurchaseEvent>>.broadcast();
  bool available;
  StoreProductInfo? product;
  final completed = <StorePurchaseEvent>[];
  final calls = <String>[];
  FakeGateway({this.available = true, this.product});

  @override
  Future<bool> isAvailable() async {
    calls.add('isAvailable');
    return available;
  }

  @override
  Future<StoreProductInfo?> queryProduct(String id) async {
    calls.add('queryProduct:$id');
    return product;
  }

  @override
  Future<void> buy(String id) async => calls.add('buy:$id');

  @override
  Future<void> restore() async => calls.add('restore');

  @override
  Stream<List<StorePurchaseEvent>> get purchases {
    calls.add('subscribe');
    return controller.stream;
  }

  @override
  Future<void> complete(StorePurchaseEvent event) async => completed.add(event);

  void emit(
    StorePurchaseStatus status, {
    String? productId,
    bool needsCompletion = true,
  }) {
    controller.add([
      StorePurchaseEvent(
        productId: productId ?? forgeProductId,
        status: status,
        needsCompletion: needsCompletion,
      ),
    ]);
  }
}

({StoreService service, FakeGateway gateway, MetaState meta, List<int> grants})
_rig({bool available = true, bool withProduct = true, bool owned = false}) {
  final meta = MetaState(forgeUnlocked: owned);
  final gateway = FakeGateway(
    available: available,
    product: withProduct
        ? const StoreProductInfo(id: forgeProductId, price: r'$4.99')
        : null,
  );
  final grants = <int>[];
  final service = StoreService(
    gateway: gateway,
    alreadyOwned: () => meta.forgeUnlocked,
    onEntitled: () async {
      // Mirrors GameController.grantForgeUnlock: idempotent grant + persist.
      if (!meta.forgeUnlocked) grants.add(1);
      meta.forgeUnlocked = true;
    },
  );
  return (service: service, gateway: gateway, meta: meta, grants: grants);
}

void main() {
  group('R8 persistence', () {
    test('defaults to false, including on every pre-Forge save', () {
      expect(MetaState().forgeUnlocked, isFalse);
      // A real pre-v0.4.0 save has no key at all.
      expect(MetaState.fromJson({'embers': 40}).forgeUnlocked, isFalse);
    });

    test('round-trips true through toJson/fromJson', () {
      final m = MetaState(forgeUnlocked: true);
      final back = MetaState.fromJson(Map<String, dynamic>.from(m.toJson()));
      expect(back.forgeUnlocked, isTrue);
    });

    test('locked profiles serialize WITHOUT the key (byte-stable saves)', () {
      expect(MetaState().toJson().containsKey('forgeUnlocked'), isFalse);
    });
  });

  group('R8 gating', () {
    test('easy/normal free; hard is Forge-gated again (v0.6.1)', () {
      final locked = MetaState();
      expect(canSelectDifficulty(locked, 'easy'), isTrue);
      expect(canSelectDifficulty(locked, 'normal'), isTrue);
      expect(canSelectDifficulty(locked, 'hard'), isFalse);
      final open = MetaState(forgeUnlocked: true);
      expect(canSelectDifficulty(open, 'hard'), isTrue);
    });

    test('ascension is rung 0 without the Forge, earned height with it', () {
      final locked = MetaState(bestAscension: 7);
      expect(maxAscensionFor(locked), 0);
      final open = MetaState(bestAscension: 7, forgeUnlocked: true);
      expect(maxAscensionFor(open), 7);
      // The ladder is still EARNED: owning the Forge with no wins is rung 0.
      expect(maxAscensionFor(MetaState(forgeUnlocked: true)), 0);
    });

    test('boot moves a locked profile\'s 0.6.0-era hard pref to normal '
        'visibly (v0.6.1 regression)', () async {
      // A profile that picked hard while v0.6.0 was live must come back to
      // a VISIBLE 'normal' — never a silent downgrade at run start.
      final dir = await Directory.systemTemp.createTemp('relock');
      MetaStore.dirOverride = dir.path;
      try {
        final m = MetaState(runsPlayed: 3)..preferredDifficulty = 'hard';
        await MetaStore.save(m);
        final c = GameController();
        await c.boot();
        expect(c.meta.forgeUnlocked, isFalse);
        expect(c.meta.preferredDifficulty, 'normal');
        // And a Forge owner's hard pref survives boot untouched.
        final owner = MetaState(runsPlayed: 3, forgeUnlocked: true)
          ..preferredDifficulty = 'hard';
        await MetaStore.save(owner);
        final c2 = GameController();
        await c2.boot();
        expect(c2.meta.preferredDifficulty, 'hard');
      } finally {
        MetaStore.dirOverride = null;
        for (var i = 0; i < 10; i++) {
          try {
            await dir.delete(recursive: true);
            break;
          } on FileSystemException {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        }
      }
    });

    test('clampRunParams forces normal + rung 0 for locked profiles', () {
      final locked = MetaState(bestAscension: 5);
      final p = clampRunParams(locked, difficulty: 'hard', ascension: 5);
      expect(p.difficulty, 'normal'); // v0.6.1: hard is the Forge's again
      expect(p.ascension, 0); // and so is the ladder
      // And passes entitled requests through untouched.
      final open = MetaState(bestAscension: 5, forgeUnlocked: true);
      final q = clampRunParams(open, difficulty: 'hard', ascension: 5);
      expect(q.difficulty, 'hard');
      expect(q.ascension, 5);
    });
  });

  group('purchase lifecycle', () {
    test('purchased event grants once, acknowledges, lands on owned', () async {
      final rig = _rig();
      await rig.service.init();
      expect(rig.service.state, ForgeStoreState.ready);
      expect(rig.service.price, r'$4.99');

      await rig.service.buy();
      expect(rig.gateway.calls, contains('buy:$forgeProductId'));
      expect(rig.service.state, ForgeStoreState.pending);

      rig.gateway.emit(StorePurchaseStatus.purchased);
      await Future<void>.delayed(Duration.zero);
      expect(rig.meta.forgeUnlocked, isTrue);
      expect(rig.grants.length, 1);
      expect(
        rig.gateway.completed.length,
        1,
        reason: 'unacknowledged purchases are refunded after 3 days',
      );
      expect(rig.service.state, ForgeStoreState.owned);

      // Redelivery (app died between grant and ack): grant stays idempotent.
      rig.gateway.emit(StorePurchaseStatus.purchased);
      await Future<void>.delayed(Duration.zero);
      expect(rig.grants.length, 1);
      expect(rig.gateway.completed.length, 2);
    });

    test('restored event grants exactly like a purchase', () async {
      final rig = _rig();
      await rig.service.init();
      rig.gateway.emit(StorePurchaseStatus.restored);
      await Future<void>.delayed(Duration.zero);
      expect(rig.meta.forgeUnlocked, isTrue);
      expect(rig.service.state, ForgeStoreState.owned);
    });

    test(
      'pending shows pending; cancel returns to ready with NO grant',
      () async {
        final rig = _rig();
        await rig.service.init();
        rig.gateway.emit(StorePurchaseStatus.pending, needsCompletion: false);
        await Future<void>.delayed(Duration.zero);
        expect(rig.service.state, ForgeStoreState.pending);

        rig.gateway.emit(StorePurchaseStatus.canceled, needsCompletion: false);
        await Future<void>.delayed(Duration.zero);
        expect(rig.service.state, ForgeStoreState.ready);
        expect(rig.meta.forgeUnlocked, isFalse);
        expect(
          rig.service.lastError,
          isNull,
          reason: 'changing your mind is not an error',
        );
      },
    );

    test('error surfaces the no-charge message and never grants', () async {
      final rig = _rig();
      await rig.service.init();
      rig.gateway.emit(StorePurchaseStatus.error);
      await Future<void>.delayed(Duration.zero);
      expect(rig.service.state, ForgeStoreState.ready);
      expect(rig.meta.forgeUnlocked, isFalse);
      expect(rig.service.lastError, contains('nothing was charged'));
    });

    test(
      'events for other products are acknowledged but never grant',
      () async {
        final rig = _rig();
        await rig.service.init();
        rig.gateway.emit(
          StorePurchaseStatus.purchased,
          productId: 'someone_else',
        );
        await Future<void>.delayed(Duration.zero);
        expect(rig.meta.forgeUnlocked, isFalse);
        expect(rig.gateway.completed.length, 1);
      },
    );
  });

  group('startup', () {
    test('subscribes to the stream BEFORE querying the store', () async {
      final rig = _rig();
      await rig.service.init();
      expect(
        rig.gateway.calls.first,
        'subscribe',
        reason: 'a purchase event must never be missable',
      );
    });

    test('runs a silent restore when not owned, skips it when owned', () async {
      final rig = _rig();
      await rig.service.init();
      expect(rig.gateway.calls, contains('restore'));

      final ownedRig = _rig(owned: true);
      await ownedRig.service.init();
      expect(ownedRig.gateway.calls, isNot(contains('restore')));
      expect(ownedRig.service.state, ForgeStoreState.owned);
    });

    test('no store => unavailable, and buy() stays a no-op', () async {
      final rig = _rig(available: false);
      await rig.service.init();
      expect(rig.service.state, ForgeStoreState.unavailable);
      await rig.service.buy();
      expect(rig.gateway.calls.where((c) => c.startsWith('buy')), isEmpty);
    });

    test('product missing => unavailable with a reason', () async {
      final rig = _rig(withProduct: false);
      await rig.service.init();
      expect(rig.service.state, ForgeStoreState.unavailable);
      expect(rig.service.lastError, contains('not found'));
    });

    test('an owned profile is owned even if Play is unreachable', () async {
      final rig = _rig(available: false, owned: true);
      await rig.service.init();
      expect(
        rig.service.state,
        ForgeStoreState.owned,
        reason: 'entitlement is sticky — offline never takes it away',
      );
    });
  });
}
