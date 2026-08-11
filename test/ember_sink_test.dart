// test/ember_sink_test.dart — v0.4.3 P1 ember sink:
//   1. Content invariants: the theme/skin/codex catalogs are coherent —
//      order lists match maps, prices are honest (> 0 unless the default),
//      and the Codex covers every enemy and relic exactly once so new
//      content cannot silently ship without lore.
//   2. The default dice skin is the identity paint: body tint 0xFFFFFFFF
//      and the original bone ink, so unskinned dice render as before.
//   3. Meta purchase rules: deduct, refuse when broke/owned/unknown, and
//      full JSON round-trip of the new ownership fields.
//   4. UI wiring: the Ledger lists every skin card, and the Codex screen
//      sells a locked entry on tap and reveals its lore.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/data/enemies.dart';
import 'package:emberdelve/data/relics.dart';
import 'package:emberdelve/data/skins.dart';
import 'package:emberdelve/data/themes.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/codex_screen.dart';
import 'package:emberdelve/ui/ledger_screen.dart';
import 'package:emberdelve/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hearth theme catalog is coherent and honestly priced', () {
    expect(hearthThemesOrder.toSet(), hearthThemes.keys.toSet(),
        reason: 'order list and map must cover the same ids');
    expect(hearthThemesOrder.length, hearthThemesOrder.toSet().length,
        reason: 'no duplicate ids in the order list');
    expect(hearthThemes.length, greaterThanOrEqualTo(12),
        reason: 'P1 ember sink ships at least 12 hearth colors');
    for (final t in hearthThemes.values) {
      expect(t.name.trim(), isNotEmpty);
      expect(t.text.trim(), isNotEmpty);
      if (t.id == defaultTheme) {
        expect(t.costEmbers, 0, reason: 'the default color is free');
      } else {
        expect(t.costEmbers, greaterThan(0),
            reason: '${t.id}: a locked color must have a real price');
      }
    }
  });

  test('dice skin catalog is coherent; default skin is the identity paint',
      () {
    expect(dieSkinsOrder.toSet(), dieSkins.keys.toSet());
    expect(dieSkinsOrder.length, dieSkinsOrder.toSet().length);
    final bone = dieSkins[defaultDieSkin]!;
    expect(bone.costEmbers, 0);
    expect(bone.bodyArgb, 0xFFFFFFFF,
        reason: 'default body tint must be the multiply identity — an '
            'unskinned profile renders pixel-identical to pre-skin builds');
    expect(bone.inkArgb, 0xFF241407,
        reason: 'default ink must equal the original _FacePainter ink');
    for (final s in dieSkins.values) {
      expect(s.name.trim(), isNotEmpty);
      expect(s.text.trim(), isNotEmpty);
      if (s.id != defaultDieSkin) {
        expect(s.costEmbers, greaterThan(0), reason: s.id);
      }
    }
    expect(dieSkinDef('nope').id, defaultDieSkin,
        reason: 'unknown ids fall back to the default skin');
    expect(dieSkinDef(null).id, defaultDieSkin);
  });

  test('codex covers every enemy and every relic exactly once', () {
    final enemyRefs = codexEntries
        .where((e) => e.kind == 'enemy')
        .map((e) => e.refId)
        .toList();
    final relicRefs = codexEntries
        .where((e) => e.kind == 'relic')
        .map((e) => e.refId)
        .toList();
    expect(enemyRefs.toSet(), enemies.keys.toSet(),
        reason: 'every enemy needs lore; no orphan entries allowed');
    expect(relicRefs.toSet(), relics.keys.toSet(),
        reason: 'every relic needs lore; no orphan entries allowed');
    expect(enemyRefs.length, enemyRefs.toSet().length);
    expect(relicRefs.length, relicRefs.toSet().length);
    for (final e in codexEntries) {
      expect(e.id, '${e.kind}:${e.refId}',
          reason: 'entry ids are namespaced kind:refId');
      expect(e.text.trim().length, greaterThan(40),
          reason: '${e.id}: lore must be real writing, not a stub');
      expect(e.costEmbers, greaterThan(0), reason: e.id);
    }
    expect(codexById.length, codexEntries.length);
  });

  test('dice skins: buy deducts embers, refuses when broke or owned', () {
    final m = MetaState(embers: 160);
    expect(m.tryBuyDieSkin('embertide'), isTrue); // costs 150
    expect(m.embers, 10);
    expect(m.ownedDieSkins, containsAll({defaultDieSkin, 'embertide'}));
    expect(m.tryBuyDieSkin('embertide'), isFalse,
        reason: 'owned skins are never sold twice');
    expect(m.tryBuyDieSkin('obsidian'), isFalse,
        reason: '10 embers cannot buy a 400-ember skin');
    expect(m.embers, 10, reason: 'failed buys must not touch the purse');
    expect(m.tryBuyDieSkin('chrome'), isFalse, reason: 'unknown id');

    // Controller wiring: buy + activate, and activation needs ownership.
    final c = GameController();
    c.meta.embers = 150;
    expect(c.buyDieSkin('frostbound'), isTrue);
    c.setActiveDieSkin('frostbound');
    expect(c.meta.activeDieSkin, 'frostbound');
    c.setActiveDieSkin('obsidian'); // not owned: ignored
    expect(c.meta.activeDieSkin, 'frostbound');
  });

  test('codex: buy deducts embers, refuses when broke or owned', () {
    final m = MetaState(embers: 20);
    expect(m.tryBuyCodex('enemy:cinder_wisp'), isTrue); // costs 15
    expect(m.embers, 5);
    expect(m.tryBuyCodex('enemy:cinder_wisp'), isFalse,
        reason: 'unsealed entries are never sold twice');
    expect(m.tryBuyCodex('relic:ember_ring'), isFalse,
        reason: '5 embers cannot buy a 20-ember entry');
    expect(m.embers, 5);
    expect(m.tryBuyCodex('enemy:not_a_thing'), isFalse, reason: 'unknown id');

    final c = GameController();
    c.meta.embers = 30;
    expect(c.buyCodexEntry('enemy:ember_tyrant'), isTrue); // boss, 30
    expect(c.meta.embers, 0);
    expect(c.buyCodexEntry('relic:bedroll'), isFalse, reason: 'broke');
  });

  test('meta json round-trips skins and codex ownership', () {
    final m = MetaState(
      embers: 500,
      ownedDieSkins: {defaultDieSkin, 'gilded', 'obsidian'},
      activeDieSkin: 'obsidian',
      ownedCodex: {'enemy:cinder_wisp', 'relic:bedroll'},
    );
    final back = MetaState.fromJson(
        jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
    expect(back.toJson(), m.toJson());
    expect(back.ownedDieSkins, m.ownedDieSkins);
    expect(back.activeDieSkin, 'obsidian');
    expect(back.ownedCodex, m.ownedCodex);

    // Pre-v0.4.3 saves lack every new field: safe defaults, no crash.
    final old = MetaState.fromJson({'embers': 9});
    expect(old.ownedDieSkins, {defaultDieSkin});
    expect(old.activeDieSkin, defaultDieSkin);
    expect(old.ownedCodex, isEmpty);

    // A save citing a deleted/unknown skin falls back to the default
    // instead of rendering from a missing def.
    final weird = MetaState.fromJson({
      'activeDieSkin': 'plasma',
      'ownedDieSkins': ['plasma'],
    });
    expect(weird.activeDieSkin, defaultDieSkin);
    expect(weird.ownedDieSkins, contains(defaultDieSkin));
  });

  testWidgets('ledger lists every dice skin card', (tester) async {
    tester.view.physicalSize =
        const Size(412, 915) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    final c = GameController();
    c.meta.embers = 1000;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: LedgerScreen(c)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // The Ledger is a lazy ListView — scroll each card into build range
    // before asserting (offstage lookups can't see unbuilt children).
    for (final id in dieSkinsOrder) {
      await tester.scrollUntilVisible(
          find.byKey(ValueKey('skin-$id')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(ValueKey('skin-$id')), findsOneWidget,
          reason: 'skin card $id missing from the Ledger');
    }
    await tester.scrollUntilVisible(find.text('The Codex'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('The Codex'), findsOneWidget,
        reason: 'the Codex entry point lives on the Ledger');
  });

  testWidgets('codex screen sells a locked entry and reveals its lore',
      (tester) async {
    tester.view.physicalSize =
        const Size(412, 915) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    final c = GameController();
    c.meta.embers = 15;
    final entry = codexById['enemy:cinder_wisp']!;
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CodexScreen(c)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // Locked: lore hidden, price shown.
    expect(find.text(entry.text), findsNothing);
    await tester.tap(find.byKey(ValueKey('codex-${entry.id}')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.meta.ownedCodex, contains(entry.id));
    expect(c.meta.embers, 0);
    expect(find.text(entry.text, skipOffstage: false), findsOneWidget,
        reason: 'paid lore must be readable immediately');
    // Broke now: a second locked entry refuses without touching the purse.
    await tester.tap(find.byKey(const ValueKey('codex-enemy:ash_rat')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.meta.ownedCodex, hasLength(1));
    expect(c.meta.embers, 0);
  });
}
