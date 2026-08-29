// test/delve_itself_test.dart — v0.104.0 The Delve Itself.
//
// The Codex answered 'who is this enemy' and 'what is this relic' but never
// the first question a new delver actually asks — 'what is a delve?'
// (verbatim from a player review). A third kind, 'place', holds the world's
// own words: eight entries, cheapest price in the book, shelved FIRST.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('places: named, priced at 10, shelved first, the delve on top', () {
    final places = codexEntries.where((e) => e.kind == 'place').toList();
    expect(places, hasLength(placeNames.length));
    expect(
      places.map((e) => e.refId).toSet(),
      placeNames.keys.toSet(),
      reason: 'every place needs a name; no orphan names allowed',
    );
    for (final e in places) {
      expect(e.costEmbers, 10, reason: '${e.id}: places are the cheapest');
      expect(e.id, 'place:${e.refId}');
    }
    // The world opens the book, and 'what is a delve?' opens the world.
    expect(codexEntries.first.id, 'place:the_delve');
    final firstNonPlace = codexEntries.indexWhere((e) => e.kind != 'place');
    expect(
      codexEntries.take(firstNonPlace).every((e) => e.kind == 'place'),
      isTrue,
      reason: 'places are one contiguous shelf at the top',
    );
  });

  test('place lore passes the ethics copy sweep', () {
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
    for (final e in codexEntries.where((e) => e.kind == 'place')) {
      final lower = e.text.toLowerCase();
      for (final word in banned) {
        expect(lower.contains(word), isFalse, reason: '${e.id}: "$word"');
      }
    }
  });

  test('buying a place entry works through the normal codex path', () {
    final c = GameController();
    c.meta.embers = 25;
    expect(c.buyCodexEntry('place:the_delve'), isTrue);
    expect(c.meta.embers, 15);
    expect(c.meta.ownedCodex.contains('place:the_delve'), isTrue);
    expect(c.buyCodexEntry('place:the_delve'), isFalse, reason: 'owned');
  });

  testWidgets('codex screen opens on THE WORLD, The Delve first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CodexScreen(c)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('THE WORLD'), findsOneWidget);
    expect(find.text('The Delve'), findsOneWidget);
    final delveY = tester
        .getTopLeft(find.byKey(const ValueKey('codex-place:the_delve')))
        .dy;
    final firstEnemyY = tester
        .getTopLeft(find.byKey(ValueKey('codex-${codexEntries[8].id}')))
        .dy;
    expect(delveY, lessThan(firstEnemyY));
  });
}
