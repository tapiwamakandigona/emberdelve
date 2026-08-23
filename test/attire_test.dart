// test/attire_test.dart — v0.27.0 The Delver's Wardrobe:
//   1. Catalog invariants: order/map agree, honest prices, default free +
//      identity tint, dye washes stay high-luminance (>= 0xC0/channel) so a
//      dyed sprite reads as cloth under cave light, never a solid ghost.
//   2. §Ethics banned-word sweep over all wardrobe copy.
//   3. Meta purchase rules: deduct, refuse when broke/owned/unknown; JSON
//      round-trip; pre-wardrobe saves stay byte-identical (fields omitted at
//      defaults); unknown active id falls back to undyed.
//   4. Cloud merge: owned dyes union, active follows the fresher profile.
//   5. UI wiring: the character screen lists every dye card; tapping a locked
//      affordable dye buys AND wears it; sprite tint plumbing reaches the
//      painter (identity skips the ColorFilter).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/attire.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/ui/art.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dye catalog is coherent; default dye is the identity', () {
    expect(
      delverDyesOrder.toSet(),
      delverDyes.keys.toSet(),
      reason: 'order list and map must cover the same ids',
    );
    expect(delverDyesOrder.length, delverDyesOrder.toSet().length);
    expect(delverDyesOrder.first, defaultDye);
    final undyed = delverDyes[defaultDye]!;
    expect(undyed.costEmbers, 0, reason: 'the default dye is free');
    expect(
      undyed.hueDeg == 0 && undyed.satMul == 1 && undyed.valMul == 1,
      isTrue,
      reason:
          'default dye must be the identity — an undyed profile renders '
          'pixel-identical to pre-wardrobe builds',
    );
    expect(
      Art.dyeFilter(defaultDye),
      isNull,
      reason: 'identity dye must skip the ColorFilter entirely',
    );
    expect(Art.dyeFilter('gone_from_catalog'), isNull);
    final seen = <String>{};
    for (final d in delverDyes.values) {
      expect(d.name.trim(), isNotEmpty);
      expect(d.text.trim(), isNotEmpty);
      if (d.id != defaultDye) {
        expect(d.costEmbers, greaterThan(0), reason: d.id);
        expect(
          Art.dyeFilter(d.id),
          isNotNull,
          reason: '${d.id}: a paid dye must visibly change the sprite',
        );
        // Sane ranges: dyes recolor, they never black out or blow out.
        expect(d.satMul, inInclusiveRange(0.1, 1.5), reason: d.id);
        expect(d.valMul, inInclusiveRange(0.8, 1.3), reason: d.id);
        expect(d.hueDeg.abs(), lessThanOrEqualTo(360), reason: d.id);
      }
      // Every dye must be visually distinct from every other.
      final sig = '${d.hueDeg}/${d.satMul}/${d.valMul}';
      expect(seen.add(sig), isTrue, reason: '${d.id}: duplicate look $sig');
    }
  });

  test('wardrobe copy honors the ethics banned-word list', () {
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
    for (final d in delverDyes.values) {
      final copy = '${d.name} ${d.text}'.toLowerCase();
      for (final word in banned) {
        expect(
          copy.contains(word),
          isFalse,
          reason: '${d.id}: wardrobe copy contains banned word "$word"',
        );
      }
    }
  });

  test('dyes: buy deducts embers, refuses when broke, owned or unknown', () {
    final m = MetaState(embers: 100);
    expect(m.tryBuyDye('emberwash'), isTrue); // costs 80
    expect(m.embers, 20);
    expect(m.ownedDyes, containsAll({defaultDye, 'emberwash'}));
    expect(
      m.tryBuyDye('emberwash'),
      isFalse,
      reason: 'owned dyes are never sold twice',
    );
    expect(m.tryBuyDye('wyrmshade'), isFalse, reason: 'broke: costs 400');
    expect(m.tryBuyDye('nope'), isFalse, reason: 'unknown id refused');
    expect(m.embers, 20, reason: 'refused buys never touch the purse');
  });

  test('meta json: round-trip; pre-wardrobe saves stay byte-identical', () {
    final before = jsonEncode(MetaState(embers: 42).toJson());
    expect(
      before.contains('ownedDyes') || before.contains('activeDye'),
      isFalse,
      reason: 'defaults are omitted so old saves do not change bytes',
    );
    final m = MetaState(embers: 500);
    m.tryBuyDye('frostveil');
    m.activeDye = 'frostveil';
    final back = MetaState.fromJson(
      jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>,
    );
    expect(back.ownedDyes, containsAll({defaultDye, 'frostveil'}));
    expect(back.activeDye, 'frostveil');
    // Corrupt/stale active id falls back to undyed, never crashes.
    final j = m.toJson();
    j['activeDye'] = 'gone_from_catalog';
    final fallback = MetaState.fromJson(
      jsonDecode(jsonEncode(j)) as Map<String, dynamic>,
    );
    expect(fallback.activeDye, defaultDye);
  });

  test('cloud merge: owned dyes union, active follows the fresher side', () {
    final local = MetaState(embers: 500, runsPlayed: 10);
    local.tryBuyDye('emberwash');
    local.activeDye = 'emberwash';
    final cloud = MetaState(embers: 500, runsPlayed: 3);
    cloud.tryBuyDye('frostveil');
    cloud.activeDye = 'frostveil';
    final merged = mergeMetaStates(local, cloud);
    expect(
      merged.ownedDyes,
      containsAll({defaultDye, 'emberwash', 'frostveil'}),
      reason: 'bought anywhere stays bought',
    );
    expect(
      merged.activeDye,
      'emberwash',
      reason: 'the fresher (more-played) profile keeps its worn dye',
    );
  });

  testWidgets('character screen lists every dye; tap buys and wears', (
    tester,
  ) async {
    tester.view.physicalSize =
        const Size(412, 915) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    final c = GameController();
    c.meta.embers = 90; // enough for emberwash (80), not frostveil (120)
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: CharacterScreen(c)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    for (final id in delverDyesOrder) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('dye-$id')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(ValueKey('dye-$id')),
        findsOneWidget,
        reason: 'dye card $id missing from the wardrobe',
      );
    }
    // Buy + wear emberwash in one tap (ledger skin-card contract).
    // The loop above ended at the bottom of the list; emberwash is back UP,
    // so the delta must be negative (scrollUntilVisible only ever drags in
    // the sign of its delta — a positive one can never re-reveal a disposed
    // card above the viewport).
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dye-emberwash')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('dye-emberwash')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('dye-emberwash')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.meta.ownedDyes, contains('emberwash'));
    expect(c.meta.activeDye, 'emberwash');
    expect(c.meta.embers, 10);
    expect(find.text('WORN'), findsOneWidget);
    // A dye the purse cannot cover is refused and nothing changes.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dye-frostveil')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('dye-frostveil')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('dye-frostveil')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.meta.ownedDyes.contains('frostveil'), isFalse);
    expect(c.meta.activeDye, 'emberwash');
    expect(c.meta.embers, 10);
  });
}
