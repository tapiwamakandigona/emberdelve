// test/unlock_codes_test.dart — offline signed unlock codes
// (lib/meta/unlock_codes.dart, docs/launch/UNLOCK-CODES-SPEC.md). Contracts:
//   1. Spec acceptance: the published example code verifies against the
//      embedded production key, and ANY single-byte change to payload or
//      signature fails.
//   2. The example code's nonce is blocklisted: it can never grant.
//   3. Redeem lifecycle (test-key seam): a valid code grants through the
//      same flag as a Play purchase, persists its nonce, and re-entry is
//      idempotent; garbage grants nothing.
//   4. Persistence: redeemedCodes round-trips through meta JSON compactly
//      and cloud-merges as a union.
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/unlock_codes.dart';

/// The public acceptance code from UNLOCK-CODES-SPEC.md (nonce bd1b5eea —
/// blocklisted at build time, so it proves the crypto without giving a
/// free unlock).
const specCode =
    'EMBR1.eyJkIjoiMjAyNi0wOC0xNiIsIm4iOiJiZDFiNWVlYSIsInAiOiJlbWJlcl9mb3JnZV91bmxvY2sifQ.1__y7C4NuXeHfsKEe6uw7H6tE9WfkbNmpE71W-hZ5n1FsAfT2rl0VY1Lhy64TcfOyLYoyB75-brplfRXK2uiAg';

/// Mint a code with a throwaway test keypair (the private production key
/// lives outside every repo — tests must never need it).
Future<(String code, String publicKeyHex)> mintTestCode({
  String product = unlockProductForge,
  String nonce = 'a1b2c3d4',
  String date = '2026-08-25',
}) async {
  final algo = Ed25519();
  final kp = await algo.newKeyPair();
  final payload = utf8.encode(
    jsonEncode({'d': date, 'n': nonce, 'p': product}),
  );
  final sig = await algo.sign(payload, keyPair: kp);
  final pub = await kp.extractPublicKey();
  final hex = pub.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final code =
      'EMBR1.${base64Url.encode(payload).replaceAll('=', '')}.${base64Url.encode(sig.bytes).replaceAll('=', '')}';
  return (code, hex);
}

void main() {
  group('spec acceptance (production key)', () {
    test('the published example verifies and parses', () async {
      final c = await verifyUnlockCode(specCode);
      expect(c, isNotNull);
      expect(c!.product, unlockProductForge);
      expect(c.nonce, 'bd1b5eea');
      expect(c.date, '2026-08-16');
    });

    test('whitespace around a code is forgiven', () async {
      expect(await verifyUnlockCode('  $specCode\n'), isNotNull);
    });

    test('any single-character change to the payload fails', () async {
      final parts = specCode.split('.');
      final p = parts[1];
      // Flip one character at several positions across the payload.
      for (final i in [0, p.length ~/ 2, p.length - 1]) {
        final flipped = p.replaceRange(i, i + 1, p[i] == 'A' ? 'B' : 'A');
        expect(
          await verifyUnlockCode('${parts[0]}.$flipped.${parts[2]}'),
          isNull,
          reason: 'payload flip at $i must fail',
        );
      }
    });

    test('any single-character change to the signature fails', () async {
      final parts = specCode.split('.');
      final sg = parts[2];
      for (final i in [0, sg.length ~/ 2, sg.length - 1]) {
        final flipped = sg.replaceRange(i, i + 1, sg[i] == 'A' ? 'B' : 'A');
        expect(
          await verifyUnlockCode('${parts[0]}.${parts[1]}.$flipped'),
          isNull,
          reason: 'signature flip at $i must fail',
        );
      }
    });

    test('structural garbage fails without throwing', () async {
      for (final bad in [
        '',
        'EMBR1',
        'EMBR1.only-two',
        'EMBR2.${specCode.split('.')[1]}.${specCode.split('.')[2]}',
        'EMBR1.!!!.???',
        specCode.replaceFirst('EMBR1', 'embr1'),
      ]) {
        expect(await verifyUnlockCode(bad), isNull, reason: bad);
      }
    });
  });

  group('redeem lifecycle', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('unlock_test');
      MetaStore.dirOverride = tmp.path;
    });
    tearDown(() async {
      MetaStore.dirOverride = null;
      for (var i = 0; i < 10; i++) {
        try {
          await tmp.delete(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
    });

    test('the blocklisted example never grants', () async {
      final c = GameController();
      await c.boot();
      expect(await c.redeemUnlockCode(specCode), UnlockRedeemResult.blocked);
      expect(c.meta.forgeUnlocked, isFalse);
      expect(c.meta.redeemedCodes, isEmpty);
    });

    test('a valid code grants once, then reports alreadyOwned', () async {
      final (code, pubHex) = await mintTestCode();
      final c = GameController();
      await c.boot();
      expect(
        await c.redeemUnlockCode(code, publicKeyHex: pubHex),
        UnlockRedeemResult.granted,
      );
      expect(c.meta.forgeUnlocked, isTrue);
      expect(c.meta.redeemedCodes, contains('a1b2c3d4'));
      expect(
        await c.redeemUnlockCode(code, publicKeyHex: pubHex),
        UnlockRedeemResult.alreadyOwned,
      );
    });

    test('a wrong-product code is invalid even when well signed', () async {
      final (code, pubHex) = await mintTestCode(product: 'something_else');
      final c = GameController();
      await c.boot();
      expect(
        await c.redeemUnlockCode(code, publicKeyHex: pubHex),
        UnlockRedeemResult.invalid,
      );
      expect(c.meta.forgeUnlocked, isFalse);
    });

    test('garbage is invalid and changes nothing', () async {
      final c = GameController();
      await c.boot();
      expect(
        await c.redeemUnlockCode('not a code'),
        UnlockRedeemResult.invalid,
      );
      expect(c.meta.forgeUnlocked, isFalse);
    });
  });

  group('persistence + merge', () {
    test('redeemedCodes round-trips and stays compact when empty', () {
      final m = MetaState(redeemedCodes: {'a1b2c3d4', '99999999'});
      final back = MetaState.fromJson(m.toJson());
      expect(back.redeemedCodes, {'a1b2c3d4', '99999999'});
      expect(MetaState().toJson().containsKey('redeemedCodes'), isFalse);
    });

    test('cloud merge unions redeemed nonces', () {
      final merged = mergeMetaStates(
        MetaState(redeemedCodes: {'aaaa1111'}),
        MetaState(redeemedCodes: {'bbbb2222'}),
      );
      expect(merged.redeemedCodes, {'aaaa1111', 'bbbb2222'});
    });
  });
}
