// lib/meta/save_transfer.dart — the Carried Ember (v0.24.0): the whole
// MetaState as a pasteable text code, so a sideloaded install can move to a
// new device without Play Games. Pure codec — no plugin imports, no
// filesystem, no network (same charter as cloud_merge.dart); dart:io is used
// only for the gzip codec.
//
// Code shape:   EMBER1.<base64url(gzip(utf8(meta json)))>.<fnv1a64 hex>
//
// The checksum is FNV-1a 64 over the COMPRESSED payload bytes. It guards
// against clipboard truncation and messenger mangling, not against forgery —
// the code carries only the player's own progress. The one thing it must
// never carry is the paid unlock: `forgeUnlocked` is stripped on encode
// (a shareable line of text must not be a copy-paste of the one purchase;
// Play Billing restore is the honest re-grant path). Import merges through
// mergeMetaStates, so a pasted code can ADD progress but never revoke
// anything local — including a locally owned Forge.
import 'dart:convert';
import 'dart:io' show gzip;

import 'meta.dart';

/// Version prefix. Bump ONLY if the payload contract changes incompatibly;
/// MetaState.fromJson is field-tolerant, so added fields never need a bump.
const String saveCodePrefix = 'EMBER1';

/// FNV-1a 64-bit over [bytes], rendered as fixed-width lowercase hex.
String fnv1a64Hex(List<int> bytes) {
  var hash = 0xcbf29ce484222325;
  for (final b in bytes) {
    hash ^= b & 0xff;
    // VM ints are 64-bit and wrap on multiply — exactly FNV's mod 2^64.
    hash = hash * 0x100000001b3;
  }
  // Render as unsigned: Dart ints are signed, so print the two 32-bit
  // halves (>>> keeps the top half non-negative).
  final hi = hash >>> 32;
  final lo = hash & 0xFFFFFFFF;
  return hi.toRadixString(16).padLeft(8, '0') +
      lo.toRadixString(16).padLeft(8, '0');
}

/// One pasteable line carrying [m]'s whole ledger — minus the paid unlock
/// (see file header). Deterministic for a given state.
String encodeSaveCode(MetaState m) {
  final j = m.toJson();
  j.remove('forgeUnlocked'); // the purchase travels via Play Billing only
  final payload = gzip.encode(utf8.encode(jsonEncode(j)));
  final body = base64UrlEncode(payload);
  return '$saveCodePrefix.$body.${fnv1a64Hex(payload)}';
}

/// Decode a pasted code back into a MetaState, or null on ANY malformation
/// (wrong prefix, damaged base64/gzip/json, checksum mismatch). Whitespace
/// anywhere in the paste is tolerated — messengers wrap long lines. Never
/// throws: a paste box must not crash on garbage.
MetaState? decodeSaveCode(String raw) {
  try {
    final code = raw.replaceAll(RegExp(r'\s+'), '');
    final parts = code.split('.');
    if (parts.length != 3 || parts[0] != saveCodePrefix) return null;
    final payload = base64Url.decode(base64.normalize(parts[1]));
    if (fnv1a64Hex(payload) != parts[2].toLowerCase()) return null;
    final decoded = jsonDecode(utf8.decode(gzip.decode(payload)));
    if (decoded is! Map<String, dynamic>) return null;
    decoded.remove('forgeUnlocked'); // belt-and-braces: never grant via code
    return MetaState.fromJson(decoded);
  } catch (_) {
    return null; // any codec/format failure reads as "not a save code"
  }
}

/// Honest one-glance summary for the import confirm dialog — states what the
/// code holds, nothing more.
String saveCodeSummary(MetaState m) {
  return '${m.runsPlayed} ${m.runsPlayed == 1 ? 'delve' : 'delves'}, '
      '${m.runsWon} won · ${m.lifetimeEmbers} embers banked · '
      '${m.unlockedCharacters.length} '
      '${m.unlockedCharacters.length == 1 ? 'delver' : 'delvers'}';
}
