// test/peddlers_shelf_test.dart — v0.144.0 The Peddler's Shelf.
//
// Two skins close the hue audit: green (verdigris) and copper
// (coppervein). Plus the ladder guard the theme shelf got in v0.140 —
// order position never out-prices what follows it.
import 'package:emberdelve/data/skins.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the pair sits at the top of the shelf, priced to climb', () {
    expect(dieSkinsOrder.sublist(dieSkinsOrder.length - 2), [
      'verdigris',
      'coppervein',
    ]);
    expect(dieSkins['verdigris']!.costEmbers, 600);
    expect(dieSkins['coppervein']!.costEmbers, 650);
  });

  test('the shelf ladder never descends', () {
    // A cheaper skin after a dearer one reads as a markdown — the shelf
    // climbs (historical ties allowed, descents are not).
    var prev = 0;
    for (final id in dieSkinsOrder) {
      final cost = dieSkins[id]!.costEmbers;
      expect(
        cost,
        greaterThanOrEqualTo(prev),
        reason: '$id under-prices its shelf position',
      );
      prev = cost;
    }
  });

  test('both buy through the standard shelf flow', () {
    final c = GameController();
    c.meta.embers = 600;
    expect(c.buyDieSkin('verdigris'), isTrue);
    expect(c.meta.ownedDieSkins, contains('verdigris'));
    expect(c.meta.embers, 0);
    expect(c.buyDieSkin('coppervein'), isFalse, reason: 'broke refuses');
    expect(c.buyDieSkin('verdigris'), isFalse, reason: 'owned refuses');
  });
}
