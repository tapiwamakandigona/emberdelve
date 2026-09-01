// lib/game/delve_code.dart — Delve Codes (v0.37.0): a compact, shareable
// code that packs the whole challenge — seed, delver, difficulty,
// ascension — so a friend plays YOUR run, not one like it.
//
// Charter (docs/improvements/v0.37.0-delve-codes-design.md):
//   • Pure codec, no Flutter imports (mirrors seed_input.dart). NO sim
//     change — a code only feeds existing startRun params; simVersion 7
//     stays sealed.
//   • Platform-neutral virality: a code travels anywhere text does
//     (WhatsApp, SMS, Discord), works offline, needs no deep-link infra.
//   • Redeeming never sells anything: locked difficulty/ascension clamps
//     down via the existing clampRunParams guarantee (spec §Ethics).
//
// Format v1: `DELVE-XXXXXXXXX` — 45 payload bits in 9 Crockford base32 chars.
//   bits  0..30  seed (1 .. 2^31-2)
//   bits 31..34  delver index into charactersOrder, LOW 4 bits
//   bits 35..36  difficulty (0 easy, 1 normal, 2 hard)
//   bits 37..43  ascension (0..99)
//   bit  44      Short Road (v0.49.0): 1 = six-layer Short Delve. Every
//                pre-v0.49.0 code carries 0 here by construction, so old
//                codes round-trip unchanged; an older build handed a short
//                code simply ignores the bit (a classic delve, same seed).
// Format v2 (2026-09-01, DEMAND 01f roster expansion): ten payload chars.
//   bits 0..44   exactly as v1 — the layout never forks;
//   bits 45..48  delver index HIGH 4 bits (index = high << 4 | low, 0..255)
//   bit  49      reserved, must be 0 (decode rejects 1: it's a future
//                format signal, not a delver bit).
// COMPATIBILITY CONTRACT: a delver with index 0..15 ALWAYS emits the
// 9-char v1 form — every code ever shared stays byte-identical, and v1
// codes decode forever. Only a 17th-or-later delver emits the 10-char
// form; an OLD build handed one sees length != 10 and politely says
// "not a code" (the caller falls back to seed parsing) — never a wrong
// delve, never a crash.
// plus a 5-bit checksum char (domain-hashed) so typos fail politely.
// Crockford base32: no I/L/O/U — codes can't spell most slurs and survive
// handwriting. Input is case-insensitive; hyphens/spaces are ignored.
import '../data/characters.dart';
import '../sim/rng.dart';

/// A decoded challenge. Plain params for [GameController.startRun]; the
/// Ember Forge clamp downstream stays the guarantee for locked tiers.
class DelveChallenge {
  final int seed;
  final String character; // id from charactersOrder
  final String difficulty; // 'easy' | 'normal' | 'hard'
  final int ascension;
  final bool shortRoad; // v0.49.0: six-layer Short Delve format
  const DelveChallenge({
    required this.seed,
    required this.character,
    required this.difficulty,
    required this.ascension,
    this.shortRoad = false,
  });
}

const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

const List<String> _difficulties = ['easy', 'normal', 'hard'];

/// Encode a challenge as `DELVE-XXXXXXXXX` (9 payload chars + 1 checksum).
/// Returns null for params that cannot round-trip (unknown delver, seed out
/// of range) — callers simply omit the code line rather than lie.
String? encodeDelveCode({
  required int seed,
  required String character,
  required String difficulty,
  required int ascension,
  bool shortRoad = false,
  // Test seam: the codec is pure over a roster list. Production always
  // uses charactersOrder; tests pass an extended roster to exercise the
  // v2 path before a 17th delver ships.
  List<String> roster = charactersOrder,
}) {
  final char = roster.indexOf(character);
  final diff = _difficulties.indexOf(difficulty);
  if (char < 0 || char > 255) return null;
  if (diff < 0) return null;
  if (seed < 1 || seed > 0x7ffffffe) return null;
  final asc = ascension.clamp(0, 99);
  var bits = seed | ((char & 15) << 31) | (diff << 35) | (asc << 37);
  if (shortRoad) bits |= 1 << 44;
  // v1 (9 chars) for the founding sixteen — shared codes stay identical.
  // v2 (10 chars) only when the index needs the high bits.
  final long = char > 15;
  if (long) bits |= (char >> 4) << 45;
  final n = long ? 10 : 9;
  final chars = List.filled(n, '');
  for (var i = 0; i < n; i++) {
    chars[i] = _alphabet[bits & 31];
    bits >>= 5;
  }
  final payload = chars.join();
  return 'DELVE-$payload${_checksumChar(payload)}';
}

/// Decode any user-typed string. Accepts lowercase, stray hyphens/spaces,
/// and a missing `DELVE-` prefix. Returns null unless the checksum holds —
/// a typo becomes "not a code" (the caller falls back to seed parsing),
/// never a surprise wrong delve.
DelveChallenge? decodeDelveCode(
  String input, {
  // Test seam, mirroring encodeDelveCode.
  List<String> roster = charactersOrder,
}) {
  var s = input.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  if (s.startsWith('DELVE')) s = s.substring(5);
  // v1 = 9 payload chars + checksum; v2 = 10 + checksum.
  if (s.length != 10 && s.length != 11) return null;
  final payload = s.substring(0, s.length - 1);
  if (s[s.length - 1] != _checksumChar(payload)) return null;
  var bits = 0;
  for (var i = payload.length - 1; i >= 0; i--) {
    final v = _alphabet.indexOf(payload[i]);
    if (v < 0) return null;
    bits = (bits << 5) | v;
  }
  final seed = bits & 0x7fffffff;
  var char = (bits >> 31) & 15;
  final diff = (bits >> 35) & 3;
  final asc = (bits >> 37) & 127;
  final shortRoad = (bits >> 44) & 1 == 1;
  if (payload.length == 10) {
    // v2: high index bits + the reserved bit, which MUST be zero.
    if ((bits >> 49) & 1 == 1) return null;
    char |= ((bits >> 45) & 15) << 4;
    // A v2 code that fits in v1 is not one this encoder ever made —
    // reject rather than accept two spellings of the same challenge.
    if (char <= 15) return null;
  }
  if (seed < 1 || seed > 0x7ffffffe) return null;
  if (char >= roster.length) return null;
  if (diff >= _difficulties.length) return null;
  if (asc > 99) return null;
  return DelveChallenge(
    seed: seed,
    character: roster[char],
    difficulty: _difficulties[diff],
    ascension: asc,
    shortRoad: shortRoad,
  );
}

String _checksumChar(String payload) {
  final h = hashDomainString('emberdelve-code:$payload');
  return _alphabet[h & 31];
}
