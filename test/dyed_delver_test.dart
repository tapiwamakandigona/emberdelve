// test/dyed_delver_test.dart — v0.67.0 "The Dyed Delver": dyes are worn PER
// DELVER (MetaState.charDye), with the legacy global activeDye surviving as
// the fallback for undressed delvers. Ownership stays global. Design doc:
// docs/improvements/v0.67.0-lead-scout.md.
//
// Pins:
//   1. Resolver: own dye wins; absent key falls back to the legacy
//      activeDye; an explicit 'undyed' overrides the fallback.
//   2. Selection: dyeing one delver never repaints another; a locked delver
//      and an unowned dye are both refused; activeDye is never written.
//   3. Save round-trip: charDye survives toJson/fromJson; an empty map
//      emits no key; unknown delver and dye ids are dropped on decode.
//   4. Cloud merge: the fresher side's coats win wholesale — same
//      convention as charEpithet.
//   5. Wardrobe: the dye-chip row appears only with more than one delver
//      unlocked, and a dye tap dresses the chip-selected delver alone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/attire.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolver: own coat, else the legacy fallback, else undyed', () {
    final m = MetaState();
    expect(m.dyeFor('kindler'), defaultDye);
    m.activeDye = 'emberwash'; // pre-v0.67.0 choice
    expect(m.dyeFor('kindler'), 'emberwash');
    expect(m.dyeFor('warden'), 'emberwash');
    m.charDye['warden'] = 'frostveil';
    expect(m.dyeFor('warden'), 'frostveil');
    expect(m.dyeFor('kindler'), 'emberwash');
    // A per-delver 'undyed' is a real choice — it overrides the fallback.
    m.charDye['kindler'] = defaultDye;
    expect(m.dyeFor('kindler'), defaultDye);
  });

  test('selection: isolation, locked delver and unowned dye refused', () {
    final c = GameController();
    c.meta.ownedDyes.add('emberwash');
    c.setActiveDye('emberwash', forChar: 'warden'); // warden locked
    expect(c.meta.charDye, isEmpty);
    c.meta.unlockedCharacters.add('warden');
    c.setActiveDye('emberwash', forChar: 'warden');
    expect(c.meta.dyeFor('warden'), 'emberwash');
    expect(c.meta.dyeFor('kindler'), defaultDye);
    c.setActiveDye('frostveil', forChar: 'kindler'); // not owned
    expect(c.meta.dyeFor('kindler'), defaultDye);
    expect(c.meta.activeDye, defaultDye, reason: 'legacy field never written');
  });

  test('save round-trip; empty map emits no key; unknown ids dropped', () {
    final m = MetaState();
    expect(m.toJson().containsKey('charDye'), isFalse);
    m.charDye['kindler'] = 'emberwash';
    final back = MetaState.fromJson(m.toJson());
    expect(back.charDye, {'kindler': 'emberwash'});
    final j = m.toJson();
    j['charDye'] = {
      'kindler': 'emberwash',
      'nonsense_delver': 'emberwash', // unknown delver id
      'warden': 'nonsense_dye', // unknown dye id
    };
    expect(MetaState.fromJson(j).charDye, {'kindler': 'emberwash'});
  });

  test('cloud merge: the fresher side coats everyone', () {
    final local = MetaState()
      ..lifetimeEmbers = 100
      ..charDye['kindler'] = 'emberwash';
    final cloud = MetaState()
      ..lifetimeEmbers = 50
      ..charDye['warden'] = 'frostveil';
    final m = mergeMetaStates(local, cloud);
    expect(m.charDye, {'kindler': 'emberwash'});
    final m2 = mergeMetaStates(cloud, local);
    expect(m2.charDye, {
      'kindler': 'emberwash',
    }, reason: 'freshness, not argument order, picks the coat');
  });

  testWidgets('one delver unlocked: no dye chip row', (tester) async {
    final c = GameController();
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('dye-dress-kindler')), findsNothing);
  });

  testWidgets('a dye tap coats the chip-selected delver alone', (tester) async {
    final c = GameController();
    c.meta
      ..ownedDyes.add('emberwash')
      ..unlockedCharacters.add('warden');
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump();
    // The list mounts lazily — scroll the vertical list to the chip row.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dye-dress-warden')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('dye-dress-kindler')), findsOneWidget);
    // Pick the warden, then wear emberwash: only the warden is coated.
    await tester.tap(find.byKey(const ValueKey('dye-dress-warden')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dye-emberwash')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dye-emberwash')));
    await tester.pump();
    expect(c.meta.dyeFor('warden'), 'emberwash');
    expect(c.meta.dyeFor('kindler'), defaultDye);
    expect(c.meta.activeDye, defaultDye);
  });
}
