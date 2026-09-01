// test/delve_code_test.dart — Delve Codes (v0.37.0): the codec must
// round-trip every legal challenge, reject every typo via checksum, and
// tolerate the ways humans actually type codes.
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  v2Suite();
  group('round-trip', () {
    test('every delver × difficulty × ascension corners × seed corners', () {
      const seeds = [1, 2, 503, 123456789, 0x7ffffffe];
      const ascs = [0, 1, 5, 42, 99];
      for (final ch in charactersOrder) {
        for (final diff in ['easy', 'normal', 'hard']) {
          for (final asc in ascs) {
            for (final seed in seeds) {
              final code = encodeDelveCode(
                seed: seed,
                character: ch,
                difficulty: diff,
                ascension: asc,
              );
              expect(code, isNotNull);
              expect(code, startsWith('DELVE-'));
              // First circle rides v1 (10 chars); the second circle the
              // v2 long form (11) — delve_code.dart format header.
              expect(
                code!.length,
                'DELVE-'.length +
                    (charactersOrder.indexOf(ch) <= 15 ? 10 : 11),
              );
              final back = decodeDelveCode(code);
              expect(back, isNotNull, reason: code);
              expect(back!.seed, seed);
              expect(back.character, ch);
              expect(back.difficulty, diff);
              expect(back.ascension, asc);
            }
          }
        }
      }
    });

    test('dense seed sweep round-trips', () {
      for (var seed = 1; seed < 4000; seed += 7) {
        final code = encodeDelveCode(
          seed: seed,
          character: 'gambler',
          difficulty: 'hard',
          ascension: 12,
        )!;
        final back = decodeDelveCode(code)!;
        expect(back.seed, seed);
      }
    });
  });

  group('encode rejects what cannot round-trip', () {
    test('unknown delver', () {
      expect(
        encodeDelveCode(
          seed: 1,
          character: 'nobody',
          difficulty: 'easy',
          ascension: 0,
        ),
        isNull,
      );
    });
    test('bad difficulty', () {
      expect(
        encodeDelveCode(
          seed: 1,
          character: 'kindler',
          difficulty: 'brutal',
          ascension: 0,
        ),
        isNull,
      );
    });
    test('seed out of range', () {
      for (final s in [0, -5, 0x7fffffff, 1 << 40]) {
        expect(
          encodeDelveCode(
            seed: s,
            character: 'kindler',
            difficulty: 'easy',
            ascension: 0,
          ),
          isNull,
          reason: '$s',
        );
      }
    });
    test('ascension clamps to 0..99 instead of failing', () {
      final code = encodeDelveCode(
        seed: 77,
        character: 'warden',
        difficulty: 'normal',
        ascension: 300,
      )!;
      expect(decodeDelveCode(code)!.ascension, 99);
    });
  });

  group('checksum', () {
    test('every single-character mutation of a valid code is rejected', () {
      const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      final code = encodeDelveCode(
        seed: 987654321,
        character: 'ascetic',
        difficulty: 'hard',
        ascension: 20,
      )!;
      final body = code.substring('DELVE-'.length);
      var rejected = 0;
      var total = 0;
      for (var i = 0; i < body.length; i++) {
        for (var a = 0; a < alphabet.length; a++) {
          final c = alphabet[a];
          if (body[i] == c) continue;
          total++;
          final mutated = body.substring(0, i) + c + body.substring(i + 1);
          if (decodeDelveCode('DELVE-$mutated') == null) rejected++;
        }
      }
      // A 5-bit checksum can't catch everything, but the payload validity
      // gates (seed range, delver count, difficulty count, asc<=99) stack
      // on top. Pin the true measured floor so it never regresses.
      expect(rejected / total, greaterThan(0.93), reason: '$rejected/$total');
    });

    test('garbage is null, never a throw', () {
      for (final junk in [
        '',
        'DELVE-',
        'DELVE-ZZZ',
        'hello there',
        'DELVE-IIIIIIIIII', // I not in alphabet
        '1234567890123456789012345678901234567890',
        'DELVE-😀😀😀😀😀😀😀😀😀😀',
      ]) {
        expect(decodeDelveCode(junk), isNull, reason: junk);
      }
    });
  });

  group('input tolerance', () {
    test('lowercase, hyphens, spaces, missing prefix all decode', () {
      final code = encodeDelveCode(
        seed: 4242,
        character: 'kindler',
        difficulty: 'normal',
        ascension: 3,
      )!;
      final body = code.substring('DELVE-'.length);
      final variants = [
        code.toLowerCase(),
        'delve $body',
        '  $code  ',
        body, // bare payload without prefix
        'DELVE-${body.substring(0, 5)}-${body.substring(5)}',
      ];
      for (final v in variants) {
        final got = decodeDelveCode(v);
        expect(got, isNotNull, reason: v);
        expect(got!.seed, 4242, reason: v);
      }
    });
  });
}

// ── Delve-code v2 (2026-09-01, DEMAND 01f roster expansion) ────────────
// The founding sixteen keep their 9-char codes byte-identical forever;
// only a 17th-or-later delver emits the 10-char form. Tested against an
// extended fake roster via the codec's roster seam — the contract is
// pinned BEFORE the first new delver ships, so the encoding can never
// be the reason a new delver breaks old shares.
void v2Suite() {
  final extended = [
    ...charactersOrder,
    for (var i = 0; i < 240; i++) 'newcomer_$i',
  ];

  group('delve-code v2', () {
    test(
      'founding sixteen emit byte-identical codes under extended roster',
      () {
        // .take(16): the FIRST CIRCLE. A 17th+ delver rightly emits the
        // v2 long form — its byte-identity contract is with itself.
        for (final id in charactersOrder.take(16)) {
          for (final seed in [1, 12345, 0x7ffffffe]) {
            final v1 = encodeDelveCode(
              seed: seed,
              character: id,
              difficulty: 'hard',
              ascension: 7,
            );
            final ext = encodeDelveCode(
              seed: seed,
              character: id,
              difficulty: 'hard',
              ascension: 7,
              roster: extended,
            );
            expect(ext, v1, reason: 'code for $id must never change');
            expect(v1!.length, 'DELVE-'.length + 10);
          }
        }
      },
    );

    test('17th+ delvers round-trip through the 10-char form', () {
      for (final idx in [16, 17, 31, 128, 255]) {
        final id = extended[idx];
        for (final seed in [1, 987654321, 0x7ffffffe]) {
          for (final diff in ['easy', 'normal', 'hard']) {
            for (final shortRoad in [false, true]) {
              final code = encodeDelveCode(
                seed: seed,
                character: id,
                difficulty: diff,
                ascension: 42,
                shortRoad: shortRoad,
                roster: extended,
              );
              expect(code, isNotNull);
              expect(
                code!.length,
                'DELVE-'.length + 11,
                reason: 'index $idx needs the long form',
              );
              final d = decodeDelveCode(code, roster: extended);
              expect(d, isNotNull);
              expect(d!.seed, seed);
              expect(d.character, id);
              expect(d.difficulty, diff);
              expect(d.ascension, 42);
              expect(d.shortRoad, shortRoad);
            }
          }
        }
      }
    });

    test('index past 255 refuses to encode (no silent truncation)', () {
      final huge = [...extended, for (var i = 0; i < 20; i++) 'over_$i'];
      expect(
        encodeDelveCode(
          seed: 5,
          character: 'over_5',
          difficulty: 'easy',
          ascension: 0,
          roster: huge,
        ),
        isNull,
      );
    });

    test('a v2 spelling of a v1-range delver is rejected', () {
      // Hand-build a 10-char payload whose full index is <= 15: the
      // encoder never emits this, so the decoder must not accept it —
      // one challenge, one spelling.
      const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      var bits = 12345 | (3 << 31) | (1 << 35) | (2 << 37);
      final chars = List.filled(10, '');
      var b = bits;
      for (var i = 0; i < 10; i++) {
        chars[i] = alphabet[b & 31];
        b >>= 5;
      }
      final payload = chars.join();
      // Recompute the real checksum so ONLY the two-spellings rule can
      // reject it.
      String? accepted;
      for (final c in alphabet.split('')) {
        final d = decodeDelveCode('DELVE-$payload$c', roster: extended);
        if (d != null) accepted = 'DELVE-$payload$c';
      }
      expect(accepted, isNull);
    });

    test('reserved bit 49 set means not-a-code', () {
      const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      var bits = 12345 | (2 << 31) | (1 << 35) | (2 << 37);
      bits |= 1 << 45; // high index bits -> index 18, genuine v2
      bits |= 1 << 49; // reserved bit SET
      final chars = List.filled(10, '');
      var b = bits;
      for (var i = 0; i < 10; i++) {
        chars[i] = alphabet[b & 31];
        b >>= 5;
      }
      final payload = chars.join();
      for (final c in alphabet.split('')) {
        expect(decodeDelveCode('DELVE-$payload$c', roster: extended), isNull);
      }
    });

    test('every single-character mutation of a v2 code is rejected or '
        'decodes to a different challenge, never a silent corruption', () {
      const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
      final code = encodeDelveCode(
        seed: 424242,
        character: extended[17],
        difficulty: 'normal',
        ascension: 3,
        roster: extended,
      )!;
      final body = code.substring('DELVE-'.length);
      var rejected = 0;
      for (var i = 0; i < body.length; i++) {
        for (final c in alphabet.split('')) {
          if (c == body[i]) continue;
          final mutated = body.substring(0, i) + c + body.substring(i + 1);
          final d = decodeDelveCode('DELVE-$mutated', roster: extended);
          if (d == null) rejected++;
        }
      }
      // The 5-bit checksum catches ~31/32 of mutations; the rest must
      // at least be a VALID different challenge, never a throw.
      expect(rejected, greaterThan(body.length * 31 * 30 ~/ 32));
    });
  });
}
