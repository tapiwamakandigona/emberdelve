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
// Format: `DELVE-XXXXXXXXX` — 44 payload bits in 9 Crockford base32 chars.
//   bits  0..30  seed (1 .. 2^31-2)
//   bits 31..34  delver index into charactersOrder (4 bits)
//   bits 35..36  difficulty (0 easy, 1 normal, 2 hard)
//   bits 37..43  ascension (0..99)
//   bit  44      Short Road (v0.49.0): 1 = six-layer Short Delve. Every
//                pre-v0.49.0 code carries 0 here by construction, so old
//                codes round-trip unchanged; an older build handed a short
//                code simply ignores the bit (a classic delve, same seed).
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
}) {
  final char = charactersOrder.indexOf(character);
  final diff = _difficulties.indexOf(difficulty);
  if (char < 0 || char > 15) return null;
  if (diff < 0) return null;
  if (seed < 1 || seed > 0x7ffffffe) return null;
  final asc = ascension.clamp(0, 99);
  var bits = seed | (char << 31) | (diff << 35) | (asc << 37);
  if (shortRoad) bits |= 1 << 44;
  final chars = List.filled(9, '');
  for (var i = 0; i < 9; i++) {
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
DelveChallenge? decodeDelveCode(String input) {
  var s = input.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  if (s.startsWith('DELVE')) s = s.substring(5);
  if (s.length != 10) return null;
  final payload = s.substring(0, 9);
  if (s[9] != _checksumChar(payload)) return null;
  var bits = 0;
  for (var i = 8; i >= 0; i--) {
    final v = _alphabet.indexOf(payload[i]);
    if (v < 0) return null;
    bits = (bits << 5) | v;
  }
  final seed = bits & 0x7fffffff;
  final char = (bits >> 31) & 15;
  final diff = (bits >> 35) & 3;
  final asc = (bits >> 37) & 127;
  final shortRoad = (bits >> 44) & 1 == 1;
  if (seed < 1 || seed > 0x7ffffffe) return null;
  if (char >= charactersOrder.length) return null;
  if (diff >= _difficulties.length) return null;
  if (asc > 99) return null;
  return DelveChallenge(
    seed: seed,
    character: charactersOrder[char],
    difficulty: _difficulties[diff],
    ascension: asc,
    shortRoad: shortRoad,
  );
}

String _checksumChar(String payload) {
  final h = hashDomainString('emberdelve-code:$payload');
  return _alphabet[h & 31];
}
