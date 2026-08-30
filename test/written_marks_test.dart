// test/written_marks_test.dart — v0.142.0 The Written Marks.
//
// Codex 'rune' kind: six entries, one per temper rune, refIds mirroring
// the live anvil (faceRunes), names resolved through runeName() so a
// rename can never fork the book, priced like dice, standard buy flow.
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('six rune entries mirror the live anvil exactly', () {
    final runes = codexEntries.where((e) => e.kind == 'rune').toList();
    expect(
      runes.map((e) => e.refId).toSet(),
      faceRunes,
      reason: 'one page per rune, no more, no less',
    );
    for (final e in runes) {
      expect(e.costEmbers, 15, reason: 'tools of the trade price like dice');
      expect(e.text.trim(), isNotEmpty);
      expect(
        runeName(e.refId),
        isNot(e.refId),
        reason: 'every refId resolves to a display name',
      );
    }
  });

  test('rune entries buy through the standard codex flow', () {
    final c = GameController();
    c.meta.embers = 25;
    expect(c.buyCodexEntry('rune:surge'), isTrue);
    expect(c.meta.ownedCodex, contains('rune:surge'));
    expect(c.meta.embers, 10);
    expect(c.buyCodexEntry('rune:surge'), isFalse, reason: 'owned refuses');
    expect(c.buyCodexEntry('rune:blade'), isFalse, reason: 'broke refuses');
  });

  test('rune lore is honest (no pressure language)', () {
    const banned = [
      'streak',
      'expire',
      'hurry',
      'miss out',
      'last chance',
      'beat me',
      'bet you',
      'only today',
      "can't",
      'loser',
    ];
    for (final e in codexEntries.where((e) => e.kind == 'rune')) {
      final t = e.text.toLowerCase();
      for (final b in banned) {
        expect(t.contains(b), isFalse, reason: '${e.id} banned: $b');
      }
    }
  });
}
