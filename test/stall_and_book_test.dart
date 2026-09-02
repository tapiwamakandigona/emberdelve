// test/stall_and_book_test.dart — v0.180.0 The Stall and the Book.
//
// The two rooms every delver visits that had no page: the Ashmonger's stall
// on the way down and the Ledger at the top of the stairs. Priced like every
// place, shelved with them, named beside the lore — and honest about the
// mechanics they describe (three dice, two relics, one plate of rations;
// embers spent on delvers, hearth colors, dice skins and Codex pages).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/data/epithets.dart';

void main() {
  test('the stall and the book are places: named, priced at 10, shelved', () {
    expect(placeNames['the_ashmonger'], 'The Ashmonger');
    expect(placeNames['the_ledger'], 'The Ledger');
    for (final id in ['the_ashmonger', 'the_ledger']) {
      final e = codexEntries.singleWhere((e) => e.id == 'place:$id');
      expect(e.kind, 'place');
      expect(e.costEmbers, 10);
      expect(giftedCodex.contains(e.id), isFalse, reason: 'only the delve');
      expect(e.text.length, lessThan(340));
      expect(e.text, isNot(contains('..')));
    }
    // The world shelf stays contiguous and ends on the book.
    final kinds = codexEntries.map((e) => e.kind).toList();
    final first = kinds.indexOf('place');
    final last = kinds.lastIndexOf('place');
    expect(kinds.sublist(first, last + 1).every((k) => k == 'place'), isTrue);
    expect(codexEntries[last].refId, 'the_ledger');
    expect(placeNames.length, 11);
  });

  test('their words match the rooms: stall stock and Ledger shelves', () {
    final stall = codexEntries.singleWhere(
      (e) => e.id == 'place:the_ashmonger',
    );
    // run_layer stocks exactly three dice, two relics and one heal, in gold.
    expect(stall.text, contains('three dice'));
    expect(stall.text, contains('two relics'));
    expect(stall.text, contains('rations'));
    expect(stall.text, contains('gold'));
    final book = codexEntries.singleWhere((e) => e.id == 'place:the_ledger');
    expect(book.text, contains('Embers'));
    expect(book.text, contains('delvers'));
    expect(book.text, contains('Codex'));
  });

  test('the Lettered still asks for every page', () {
    final e = epithets['the_lettered']!;
    expect(e.target, codexEntries.length);
    expect(codexEntries.length, 134);
  });
}
