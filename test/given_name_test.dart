// test/given_name_test.dart — v0.72.0 "The Given Name": delvers can be
// NAMED by the player (MetaState.charName), with the roster name as the
// untouchable fallback. Design doc: docs/improvements/v0.72.0-lead-scout.md.
//
// Pins:
//   1. Sanitizer: trims, collapses whitespace, strips control chars,
//      clamps to 16; empty result means "no name given".
//   2. Resolver: given name wins; absent key speaks the roster name.
//   3. Setter: naming needs an unlocked delver; empty input un-names
//      (reversible); no-op writes don't dirty the store.
//   4. Save round-trip: charName survives toJson/fromJson; unknown delver
//      ids are dropped and values re-sanitized on decode.
//   5. Cloud merge: fresher side's names win wholesale (charEpithet rule).
//   6. Picker: tapping the name row opens the dialog; Keep renames the
//      card; an emptied field restores the true name.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('given_name_test');
    MetaStore.dirOverride = dir.path;
  });
  tearDown(() async {
    MetaStore.dirOverride = null;
    await dir.delete(recursive: true);
  });

  test('sanitizer: trim, collapse, strip, clamp', () {
    expect(MetaState.sanitizeGivenName('  Ash  Walker  '), 'Ash Walker');
    expect(MetaState.sanitizeGivenName('a\u0000b\u001fc'), 'abc');
    expect(MetaState.sanitizeGivenName('   '), '');
    expect(
      MetaState.sanitizeGivenName('A delver of seventeen letters plus'),
      hasLength(lessThanOrEqualTo(16)),
    );
    // The clamp never leaves a trailing space behind.
    expect(
      MetaState.sanitizeGivenName('Fifteen chars x plus'),
      MetaState.sanitizeGivenName('Fifteen chars x plus').trim(),
    );
  });

  test('resolver: the given name wins, the roster name endures', () {
    final m = MetaState();
    expect(m.nameFor('kindler'), characters['kindler']!.name);
    m.charName['kindler'] = 'Ashka';
    expect(m.nameFor('kindler'), 'Ashka');
    expect(m.nameFor('warden'), characters['warden']!.name);
  });

  test('setter: unlocked only; empty un-names', () {
    final c = GameController(saveDirOverride: dir.path);
    c.setDelverName('warden', 'Bram'); // locked — refused
    expect(c.meta.charName.containsKey('warden'), isFalse);
    c.setDelverName('kindler', '  Ashka  ');
    expect(c.meta.nameFor('kindler'), 'Ashka');
    c.setDelverName('kindler', '   ');
    expect(c.meta.charName.containsKey('kindler'), isFalse);
    expect(c.meta.nameFor('kindler'), characters['kindler']!.name);
  });

  test('save round-trip drops unknown ids and re-sanitizes', () {
    final m = MetaState();
    m.charName['kindler'] = 'Ashka';
    final j = m.toJson();
    j['charName'] = {
      'kindler': '  Ashka  ',
      'no_such_delver': 'Ghost',
      'warden': '   ',
    };
    final back = MetaState.fromJson(Map<String, dynamic>.from(j));
    expect(back.charName, {'kindler': 'Ashka'});
    // An empty map emits no key at all.
    expect(MetaState().toJson().containsKey('charName'), isFalse);
  });

  test('cloud merge: the fresher side names them all', () {
    final a = MetaState()
      ..lifetimeEmbers = 50
      ..charName['kindler'] = 'Ashka';
    final b = MetaState()
      ..lifetimeEmbers = 90
      ..charName['kindler'] = 'Vex';
    final merged = mergeMetaStates(a, b);
    expect(merged.charName['kindler'], 'Vex');
  });

  testWidgets('the picker names a delver, and gives the name back', (
    tester,
  ) async {
    final c = GameController(saveDirOverride: dir.path);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('name-edit-kindler')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Ashka');
    await tester.tap(find.byKey(const ValueKey('name-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Ashka'), findsWidgets);
    expect(c.meta.nameFor('kindler'), 'Ashka');
    // Empty it back out — the true name returns.
    await tester.tap(find.byKey(const ValueKey('name-edit-kindler')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byKey(const ValueKey('name-field')), '');
    await tester.tap(find.byKey(const ValueKey('name-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(c.meta.charName.containsKey('kindler'), isFalse);
    expect(find.text(characters['kindler']!.name), findsWidgets);
  });
}
