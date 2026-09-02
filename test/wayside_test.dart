// test/wayside_test.dart — v0.180.0 The Wayside.
//
// The map's question-mark rooms get their own place-words in the Codex:
// priced like every place, shelved with them, named beside the lore, and
// honest — the entry names what the rooms can hold without pricing any of
// it (rooms stay free to read in play).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/data/events.dart';

void main() {
  test('the wayside is a place: named, priced at 10, on the world shelf', () {
    expect(placeNames['the_wayside'], 'The Wayside');
    final e = codexEntries.singleWhere((e) => e.id == 'place:the_wayside');
    expect(e.kind, 'place');
    expect(e.costEmbers, 10);
    expect(
      giftedCodex.contains(e.id),
      isFalse,
      reason: 'only the delve is gifted',
    );
    // Sits on the contiguous world shelf, after the vistas (the stall and
    // the book follow it, v0.180.0).
    final places = codexEntries.where((e) => e.kind == 'place').toList();
    expect(places.map((e) => e.refId), contains('the_wayside'));
    expect(placeNames.length, 11);
  });

  test('its words are true of the rooms that exist', () {
    final e = codexEntries.singleWhere((e) => e.id == 'place:the_wayside');
    // A scale, a lantern: the Spoken Stones it alludes to are real rooms.
    expect(events.containsKey('the_fair_scale'), isTrue);
    expect(events.containsKey('the_first_lantern'), isTrue);
    expect(e.text, contains('scale'));
    expect(e.text, contains('lantern'));
    expect(e.text.length, lessThan(340));
  });
}
