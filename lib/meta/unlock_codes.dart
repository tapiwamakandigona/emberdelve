// lib/meta/unlock_codes.dart — offline signed unlock codes, the app side of
// docs/launch/UNLOCK-CODES-SPEC.md. GitHub/sideload players (where Play
// billing does not exist) can unlock the Ember Forge with a code that is
// verified fully offline: no server, no account, no network — the game's
// "works offline" promise holds even for the one paid thing.
//
// Format: `EMBR1.<base64url(payload)>.<base64url(signature)>`
//   payload   = canonical JSON {"d":"YYYY-MM-DD","n":"<8-char>","p":"<product>"}
//   signature = Ed25519 over the exact payload bytes
// Only the PUBLIC key ships here. The private key lives outside every repo
// on the ops side; nothing in this app can mint a code.
//
// Trust rules (deliberately boring):
//   • verify signature against the embedded key — nothing else grants;
//   • the published example code's nonce is blocklisted at build time so
//     documentation can never be a free unlock;
//   • redeemed nonces persist in MetaState (idempotent re-entry, cloud-merge
//     union) — see meta.dart / cloud_merge.dart;
//   • invalid input gets an honest error and no lockouts, ever.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Production Ed25519 public key (raw, hex) — UNLOCK-CODES-SPEC.md.
const String unlockPublicKeyHex =
    '38f5e51148855c5690fd5824080e66cac2ac70b6c8ebf1382e26f38f25929aad';

/// The product a code may unlock. One product, one flag (spec v1).
const String unlockProductForge = 'ember_forge_unlock';

/// Nonces that must never grant: the public example code from the spec.
const Set<String> blockedUnlockNonces = {'bd1b5eea'};

/// A structurally valid, signature-verified code (may still be blocklisted
/// or already redeemed — the CALLER owns those decisions).
class UnlockCode {
  final String product;
  final String nonce;
  final String date;
  const UnlockCode({
    required this.product,
    required this.nonce,
    required this.date,
  });
}

/// How a redeem attempt ended, for honest UI copy.
enum UnlockRedeemResult {
  /// Not a code, or the signature does not verify. Nothing happened.
  invalid,

  /// A published example/blocklisted code. Nothing happened.
  blocked,

  /// The Forge is already lit on this profile (purchase or earlier code).
  alreadyOwned,

  /// The code verified and the Forge is now unlocked.
  granted,
}

/// Settings reaches the controller through this hook (same pattern as
/// SaveTransfer): main.dart wires it to GameController.redeemUnlockCode.
typedef RedeemUnlockCodeFn = Future<UnlockRedeemResult> Function(String raw);

class UnlockRedeem {
  UnlockRedeem._();
  static RedeemUnlockCodeFn? redeemHook;
}

List<int> _hexToBytes(String hex) => [
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

List<int>? _b64urlDecode(String s) {
  try {
    return base64Url.decode(base64Url.normalize(s));
  } on FormatException {
    return null;
  }
}

/// Verifies [raw] against the embedded public key. Returns the parsed code
/// on success, null on ANY structural or cryptographic failure — a single
/// changed byte in payload or signature must land here (spec acceptance).
/// [publicKeyHex] is overridable for tests only; production callers use the
/// default.
Future<UnlockCode?> verifyUnlockCode(
  String raw, {
  String publicKeyHex = unlockPublicKeyHex,
}) async {
  final parts = raw.trim().split('.');
  if (parts.length != 3 || parts[0] != 'EMBR1') return null;
  final payload = _b64urlDecode(parts[1]);
  final sig = _b64urlDecode(parts[2]);
  if (payload == null || sig == null || sig.length != 64) return null;
  final ok = await Ed25519().verify(
    payload,
    signature: Signature(
      sig,
      publicKey: SimplePublicKey(
        _hexToBytes(publicKeyHex),
        type: KeyPairType.ed25519,
      ),
    ),
  );
  if (!ok) return null;
  try {
    final j = jsonDecode(utf8.decode(payload));
    if (j is! Map) return null;
    final product = j['p'], nonce = j['n'], date = j['d'];
    if (product is! String || nonce is! String || date is! String) return null;
    if (product.isEmpty || nonce.isEmpty) return null;
    return UnlockCode(product: product, nonce: nonce, date: date);
  } on FormatException {
    return null;
  }
}
