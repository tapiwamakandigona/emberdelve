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
    // THE FIRST WORDS: the_delve is the book's gift now — never for sale,
    // never charged. A paid place entry still sells normally.
    expect(c.buyCodexEntry('place:the_delve'), isFalse, reason: 'gifted');
    expect(c.meta.embers, 25, reason: 'a gift never touches the purse');
    expect(c.meta.codexOwned('place:the_delve'), isTrue);
    expect(
      c.meta.ownedCodex.contains('place:the_delve'),
      isFalse,
      reason: 'a gift is not an earned unseal',
    );
    expect(c.buyCodexEntry('place:the_ember'), isTrue);
    expect(c.meta.embers, 15);
    expect(c.meta.ownedCodex.contains('place:the_ember'), isTrue);
  });

  testWidgets('the first words: the delve entry opens the book unsealed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = GameController(); // fresh profile, zero embers
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CodexScreen(c)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final delve = codexById['place:the_delve']!;
    // The lore is readable with nothing bought and nothing spent.
    expect(find.text(delve.text), findsOneWidget);
    expect(c.meta.embers, 0);
    // The header counts the gift honestly.
    expect(
      find.textContaining('1 of ${codexEntries.length} UNSEALED'),
      findsOneWidget,
    );
    // Tapping a gift sells nothing and changes nothing.
    await tester.tap(find.byKey(const ValueKey('codex-place:the_delve')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.meta.ownedCodex, isEmpty);
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
    // v0.110.0: find the first enemy by kind, not by index — the company
    // section now sits between the world and the enemies.
    final firstEnemy = codexEntries.firstWhere((e) => e.kind == 'enemy');
    final firstEnemyY = tester
        .getTopLeft(find.byKey(ValueKey('codex-${firstEnemy.id}')))
        .dy;
    expect(delveY, lessThan(firstEnemyY));
  });
}
