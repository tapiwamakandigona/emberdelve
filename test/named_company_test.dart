// test/named_company_test.dart — v0.110.0 The Named Company.
//
// Codex 'delver' entries: one story per roster delver, priced like common
// lore, named from the characters catalog so a rename can never leave the
// Codex lying. Flavor only — kits and numbers stay on the picker, free.
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('codex covers every roster delver exactly once, in roster order', () {
    final refs = codexEntries
        .where((e) => e.kind == 'delver')
        .map((e) => e.refId)
        .toList();
    expect(refs, charactersOrder, reason: 'one story per delver, in order');
    for (final e in codexEntries.where((e) => e.kind == 'delver')) {
      expect(e.id, 'delver:${e.refId}');
      expect(e.costEmbers, 15);
      expect(e.text.trim().length, greaterThan(40));
      // The name authority is the characters catalog — this throws on an
      // unknown ref, so a typo'd delver id can never ship.
      expect(characterDef(e.refId).name, isNotEmpty);
    }
  });

  test('buying a delver story spends embers and unseals it', () {
    final c = GameController();
    c.meta.embers = 20;
    expect(c.buyCodexEntry('delver:kindler'), isTrue);
    expect(c.meta.embers, 5);
    expect(c.meta.ownedCodex, contains('delver:kindler'));
    expect(c.buyCodexEntry('delver:warden'), isFalse, reason: 'broke');
  });

  testWidgets('THE COMPANY sits between the world and the enemies', (
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
    expect(find.text('THE COMPANY'), findsOneWidget);
    expect(find.text('The Kindler'), findsOneWidget);
    final worldY = tester.getTopLeft(find.text('THE WORLD')).dy;
    final companyY = tester.getTopLeft(find.text('THE COMPANY')).dy;
    expect(worldY, lessThan(companyY));
  });
}
