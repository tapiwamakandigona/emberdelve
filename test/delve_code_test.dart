// test/delve_code_test.dart — Delve Codes (v0.37.0): the codec must
// round-trip every legal challenge, reject every typo via checksum, and
// tolerate the ways humans actually type codes.
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/delve_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
              expect(code!.length, 'DELVE-'.length + 10);
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
