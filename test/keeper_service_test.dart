// Additive checks only. Existing purchase/sim tests are unchanged.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:emberdelve/meta/forge.dart';
import 'package:emberdelve/meta/keeper.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/save_transfer.dart';
import 'package:emberdelve/meta/store_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

class _Gateway implements StoreGateway {
  final events = StreamController<List<StorePurchaseEvent>>.broadcast();
  final completed = <StorePurchaseEvent>[];
  int restores = 0;

  @override
  Stream<List<StorePurchaseEvent>> get purchases => events.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<StoreProductInfo?> queryProduct(String id) async =>
      StoreProductInfo(id: id, price: r'$4.99');
  @override
  Future<void> buy(String id) async {}
  @override
  Future<void> restore() async {
    restores++;
  }

  @override
  Future<void> complete(StorePurchaseEvent event) async {
    completed.add(event);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('absent or malformed cosmetic values are safe and opt-in', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'name': 123, 'showName': 'true', 'showCrest': 4, 'invitationSeen': []},
    ]) {
      final profile = KeeperProfile.fromJson(json);
      expect(profile.name, '');
      expect(profile.showName, isFalse);
      expect(profile.showCrest, isFalse);
      expect(profile.invitationSeen, isFalse);
    }
  });

  test(
    'names trim whitespace, remove controls and preserve grapheme clusters',
    () {
      expect(KeeperProfile.sanitizeName('  Tadiwa   Moyo \n'), 'Tadiwa Moyo');
      expect(KeeperProfile.sanitizeName('A\u202eB\u0000C'), 'A B C');
      const family = '👩‍👩‍👧‍👦';
      final long = List.filled(40, family).join();
      final clean = KeeperProfile.sanitizeName(long);
      expect(clean.characters.length, KeeperProfile.maxNameLength);
      expect(clean, List.filled(24, family).join());
      expect(
        KeeperProfile.sanitizeName('José • Tariro • نور'),
        'José • Tariro • نور',
      );
    },
  );

  test(
    'legacy Forge owner receives invitation without another purchase',
    () async {
      final oldSave = MetaState.fromJson({'forgeUnlocked': true, 'embers': 91});
      final service = KeeperService(
        alreadyOwned: () => oldSave.forgeUnlocked,
        loadData: () async => {},
        saveData: (_) async {},
      );
      addTearDown(service.dispose);
      expect(service.needsInvitation, isFalse, reason: 'load not finished');
      await service.load();
      expect(service.needsInvitation, isTrue);
      expect(oldSave.embers, 91);
      await service.markInvited();
      expect(service.needsInvitation, isFalse);
    },
  );

  test('free profile cannot create a tribute or an entitlement', () async {
    var writes = 0;
    final meta = MetaState();
    final service = KeeperService(
      alreadyOwned: () => meta.forgeUnlocked,
      loadData: () async => {},
      saveData: (_) async {
        writes++;
      },
    );
    addTearDown(service.dispose);
    await service.load();
    expect(service.needsInvitation, isFalse);
    expect(
      await service.personalise(
        name: 'Not owned',
        showName: true,
        showCrest: true,
      ),
      isFalse,
    );
    expect(await service.markInvited(), isFalse);
    expect(writes, 0);
    expect(meta.forgeUnlocked, isFalse);
  });

  test('stored tribute, hide, remove and seen flag survive reloads', () async {
    var saved = <String, dynamic>{};
    KeeperService make() => KeeperService(
      alreadyOwned: () => true,
      loadData: () async => saved,
      saveData: (data) async => saved = Map.from(data),
    );
    final a = make();
    addTearDown(a.dispose);
    await a.load();
    expect(
      await a.personalise(name: 'Tariro', showName: true, showCrest: true),
      isTrue,
    );
    final b = make();
    addTearDown(b.dispose);
    await b.load();
    expect(b.profile.name, 'Tariro');
    expect(b.profile.showName, isTrue);
    expect(b.profile.showCrest, isTrue);
    expect(b.needsInvitation, isFalse);
    await b.personalise(
      name: b.profile.name,
      showName: false,
      showCrest: false,
    );
    expect(b.profile.name, 'Tariro', reason: 'hide is reversible');
    expect(b.profile.showName, isFalse);
    await b.removeName();
    expect(b.profile.name, isEmpty);
    expect(jsonEncode(saved), isNot(contains('Tariro')));
    final c = make();
    addTearDown(c.dispose);
    await c.load();
    expect(c.needsInvitation, isFalse, reason: 'removal does not cause a nag');
    expect(c.profile.name, isEmpty);
  });

  test('concurrent writes serialize snapshots and never interleave', () async {
    final firstWrite = Completer<void>();
    final names = <String>[];
    final service = KeeperService(
      alreadyOwned: () => true,
      loadData: () async => {},
      saveData: (data) async {
        names.add(data['name'] as String);
        if (names.length == 1) await firstWrite.future;
      },
    );
    addTearDown(service.dispose);
    await service.load();
    final one = service.personalise(
      name: 'First',
      showName: true,
      showCrest: true,
    );
    final two = service.personalise(
      name: 'Second',
      showName: false,
      showCrest: false,
    );
    await Future<void>.delayed(Duration.zero);
    expect(names, ['First']);
    firstWrite.complete();
    expect(await one, isTrue);
    expect(await two, isTrue);
    expect(names, ['First', 'Second']);
  });

  test(
    'storage error is returned, with no ownership loss or thrown name',
    () async {
      final service = KeeperService(
        alreadyOwned: () => true,
        loadData: () async => throw const FormatException('corrupt'),
        saveData: (_) async => throw const FileSystemException('read only'),
      );
      addTearDown(service.dispose);
      await service.load();
      expect(service.needsInvitation, isTrue);
      expect(
        await service.personalise(
          name: 'Private',
          showName: true,
          showCrest: false,
        ),
        isFalse,
      );
      expect(service.entitled, isTrue);
      expect(
        service.profile.name,
        'Private',
        reason: 'current session still works',
      );
    },
  );

  test(
    'pending/cancel/error never qualify; real purchase statuses and restore do',
    () async {
      for (final status in StorePurchaseStatus.values) {
        final meta = MetaState();
        final changes = ValueNotifier<int>(0);
        final gateway = _Gateway();
        final keeper = KeeperService(
          alreadyOwned: () => meta.forgeUnlocked,
          entitlementChanges: changes,
          loadData: () async => {},
          saveData: (_) async {},
        );
        final store = StoreService(
          gateway: gateway,
          alreadyOwned: () => meta.forgeUnlocked,
          onEntitled: () async {
            meta.forgeUnlocked = true;
            changes.value++;
          },
        );
        await keeper.load();
        await store.init();
        expect(gateway.restores, 1);
        gateway.events.add([
          StorePurchaseEvent(
            productId: forgeProductId,
            status: status,
            needsCompletion: false,
          ),
        ]);
        await Future<void>.delayed(Duration.zero);
        final entitled =
            status == StorePurchaseStatus.purchased ||
            status == StorePurchaseStatus.restored;
        expect(keeper.needsInvitation, entitled, reason: status.name);
        keeper.dispose();
        store.dispose();
        changes.dispose();
        await gateway.events.close();
      }
    },
  );

  test(
    'name stays out of meta/cloud/manual saves and Android backup include lists',
    () {
      const marker = 'PRIVATE_NICKNAME_ONLY';
      const profile = KeeperProfile(name: marker, showName: true);
      expect(jsonEncode(profile.toJson()), contains(marker));
      final meta = MetaState(forgeUnlocked: true);
      expect(jsonEncode(meta.toJson()), isNot(contains(marker)));
      expect(encodeSaveCode(meta), isNot(contains(marker)));
      for (final file in ['backup_rules.xml', 'data_extraction_rules.xml']) {
        final xml = File(
          'android/app/src/main/res/xml/$file',
        ).readAsStringSync();
        expect(xml, contains('<include'));
        expect(xml, isNot(contains(KeeperService.fileName)));
        expect(
          xml,
          isNot(contains('path="."')),
          reason: 'no wildcard file include',
        );
      }
    },
  );
}
