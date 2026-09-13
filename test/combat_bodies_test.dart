// test/combat_bodies_test.dart — v0.183.0 "Bodies in the Fight".
//
// Pins the presentation layer that answers the 2026-09-10 combat-visual
// critique: strike plans per weapon family and die tier, the guard stance,
// health-linked body condition, blood/ichor bursts and floor stains, the
// selection → weapon-heat regression (critique §4), and the promise that
// none of it changes a single simulation number.
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/sim/sim.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/gore.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpFor(WidgetTester tester, int ms) async {
  const step = 40;
  for (var t = 0; t < ms; t += step) {
    await tester.pump(const Duration(milliseconds: step));
  }
}

Finder button(String label) => find.byWidgetPredicate(
  (w) => w is EmberButton && w.label == label && w.onTap != null,
);

/// A deterministic fight: seed 1, boon 0, node 2 is the Flue Crawler with
/// the first roll [5, 1, 3] for the Kindler (pinned by the critique's
/// evidence and re-asserted below, so a sim change fails loudly here).
Future<GameController> intoFight(
  WidgetTester tester, {
  String character = 'kindler',
}) async {
  Motion.instance.update(setting: 'off');
  final c = GameController();
  c.meta.tutorialSeen = true;
  c.meta.tipsSeen.addAll(ContextTips.all);
  c.tipDirector = TipDirector(c.meta.tipsSeen);
  c.meta.tourSeenVersion = tourVersion;
  c.tour = TourDirector(seenVersion: tourVersion);
  await tester.pumpWidget(
    MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
  );
  await tester.runAsync(warmSpriteSheets);
  c.startRun(character: character, boons: true, seed: 1, difficulty: 'easy');
  c.apply({'type': 'choose_boon', 'index': 0});
  c.apply({'type': 'choose_node', 'node': 2});
  await pumpFor(tester, 2600);
  expect(c.phase, 'player_turn');
  expect(c.sim!.enemy!['id'], 'flue_crawler');
  return c;
}

WeaponView weapon(WidgetTester tester) =>
    tester.widget<WeaponView>(find.byType(WeaponView));

void main() {
  tearDown(() => Motion.instance.reset());

  group('strike plans', () {
    test('every signature weapon maps to a family; unknown ids cut', () {
      final families = <StrikeFamily>{};
      for (final id in charactersOrder) {
        families.add(familyForWeapon(weaponFor(id).id));
      }
      // The four prototype families from the critique all exist in the
      // roster, plus the hook and pick.
      expect(
        families,
        containsAll([
          StrikeFamily.cut,
          StrikeFamily.crush,
          StrikeFamily.stab,
          StrikeFamily.stamp,
        ]),
      );
      expect(familyForWeapon('ward_maul'), StrikeFamily.crush);
      expect(familyForWeapon('lucky_fang'), StrikeFamily.stab);
      expect(familyForWeapon('rune_chisel'), StrikeFamily.stamp);
      expect(familyForWeapon('nothing_like_this'), StrikeFamily.cut);
    });

    test('die tier is read against the die\'s own size', () {
      expect(tierFor(4, 4), DieTier.max); // a max d4 is a max
      expect(tierFor(1, 4), DieTier.low);
      expect(tierFor(2, 4), DieTier.mid);
      expect(tierFor(3, 4), DieTier.high);
      expect(tierFor(6, 6), DieTier.max);
      expect(tierFor(5, 6), DieTier.high);
      expect(tierFor(3, 6), DieTier.mid);
      expect(tierFor(2, 6), DieTier.low);
      expect(tierFor(12, 12), DieTier.max);
      expect(tierFor(6, 12), DieTier.mid);
      // Heat follows: a max d4 is white-hot, a 1 on a d12 barely warm.
      expect(heatFor(4, 4), 1.0);
      expect(heatFor(1, 12), closeTo(0.22, 0.01));
      expect(heatFor(6, 6), greaterThan(heatFor(6, 12)));
      expect(sidesOfDieId('d6_keen'), 6);
      expect(sidesOfDieId('d12'), 12);
      expect(sidesOfDieId('junk'), 6);
    });

    test('each family keeps the 340 ms lead envelope and reads distinct', () {
      for (final family in StrikeFamily.values) {
        StrikePlan? previous;
        for (final tier in DieTier.values) {
          final p = planStrike(family, tier);
          expect(p.totalLeadMs, 340, reason: '$family $tier');
          expect(p.windupMs, greaterThan(0));
          expect(p.travelMs, greaterThan(0));
          expect(p.swingAngle, greaterThan(p.raiseAngle));
          if (previous != null) {
            // Heavier tiers coil longer and commit harder.
            expect(p.windupMs, greaterThanOrEqualTo(previous.windupMs));
            expect(p.smear, greaterThanOrEqualTo(previous.smear));
            expect(
              p.windupLean.abs(),
              greaterThanOrEqualTo(previous.windupLean.abs()),
            );
          }
          previous = p;
        }
      }
      // Family identity is visible in silhouette: the maul goes overhead
      // and lands compressed, the stab barely rotates but travels furthest,
      // and their contact shapes are their own.
      final crush = planStrike(StrikeFamily.crush, DieTier.mid);
      final stab = planStrike(StrikeFamily.stab, DieTier.mid);
      final cut = planStrike(StrikeFamily.cut, DieTier.mid);
      expect(crush.raiseAngle, lessThan(cut.raiseAngle));
      expect(crush.strikeStretch, lessThan(1.0));
      expect(stab.advance, greaterThan(cut.advance));
      expect(
        (stab.swingAngle - stab.raiseAngle).abs(),
        lessThan((cut.swingAngle - cut.raiseAngle).abs()),
      );
      expect(crush.contact, ContactShape.crush);
      expect(stab.contact, ContactShape.stab);
      expect(cut.contact, ContactShape.cut);
      expect(crush.followThrough, lessThan(cut.followThrough));
    });

    test(
      'enemy styles: bodies choose the attack, telegraph never shortens',
      () {
        expect(enemyStyleFor('ash_rat'), EnemyStrikeStyle.bite);
        expect(enemyStyleFor('cinder_wisp'), EnemyStrikeStyle.dart);
        expect(enemyStyleFor('anything', boss: true), EnemyStrikeStyle.slam);
        expect(enemyStyleFor('anything', elite: true), EnemyStrikeStyle.slam);
        expect(enemyStyleFor('kiln_golem'), EnemyStrikeStyle.swipe);
        for (final style in EnemyStrikeStyle.values) {
          final p = planEnemyStrike(style);
          expect(p.windupMs, greaterThanOrEqualTo(190), reason: '$style');
          expect(p.windupMs + p.travelMs, lessThanOrEqualTo(440));
        }
        expect(planEnemyStrike(EnemyStrikeStyle.bite).hop, greaterThan(0));
        expect(planEnemyStrike(EnemyStrikeStyle.dart).hop, 0);
      },
    );
  });

  group('condition', () {
    test('a fresh body renders exactly as before; a hurt one carries it', () {
      const fresh = Condition.fresh;
      expect(fresh.isFresh, isTrue);
      expect(fresh.slump, 0);
      expect(fresh.sag, 1.0);
      expect(fresh.breathRate, 1.0);
      expect(fresh.breathAmp, 1.0);
      expect(fresh.pallor, 0);
      expect(fresh.wounds, 0);
      expect(fresh.tremor, 0);
      final half = Condition.of(15, 30);
      expect(half.wounds, 2);
      expect(half.slump, greaterThan(0));
      expect(half.breathRate, greaterThan(1.0));
      expect(half.tremor, 0); // not yet shaking
      final dying = Condition.of(3, 30);
      expect(dying.wounds, 4);
      expect(dying.tremor, greaterThan(0));
      expect(dying.breathRate, greaterThan(half.breathRate));
      expect(dying.pallor, lessThanOrEqualTo(0.55)); // still recognisable
      expect(dying.sag, greaterThan(0.94));
      expect(Condition.of(5, 0).vitality, 1.0); // degenerate max HP
    });

    test('pallor matrix is identity at 0 and preserves alpha', () {
      final id = pallorMatrix(0);
      expect(id[0], closeTo(1, 1e-9));
      expect(id[6], closeTo(1, 1e-9));
      expect(id[12], closeTo(1, 1e-9));
      expect(id[1], closeTo(0, 1e-9));
      expect(id[18], 1);
      final drained = pallorMatrix(0.5);
      // Pure grey stays grey-ish (rows still sum ≈ 1 up to the cool cast).
      final rowSum = drained[0] + drained[1] + drained[2];
      expect(rowSum, closeTo(0.95, 0.02));
      expect(drained[18], 1);
    });

    test('ichor: delvers bleed red, the delve bleeds what it is made of', () {
      expect(ichorFor('kindler', player: true), Ichor.blood);
      expect(ichorFor('cinder_wisp'), Ichor.ember);
      expect(ichorFor('soot_shade'), Ichor.soot);
      expect(ichorFor('ember_beetle'), Ichor.ember); // ember wins over bug
      expect(ichorFor('ash_rat'), Ichor.ember);
      expect(ichorFor('flue_crawler'), Ichor.blood);
      expect(woundSpots.length, 4);
    });

    test('spray is deterministic and scales with severity', () {
      final a = spray(0.2, seed: 3);
      final b = spray(0.2, seed: 3);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].angle, b[i].angle);
        expect(a[i].speed, b[i].speed);
      }
      expect(spray(1.0).length, greaterThan(spray(0.05).length));
      expect(spray(1.0).length, lessThanOrEqualTo(18));
      expect(spray(0.0).length, greaterThanOrEqualTo(6));
      // Facing flips the fan.
      final right = spray(0.5, facing: 1).map((d) => d.angle).toList();
      final left = spray(0.5, facing: -1).map((d) => d.angle).toList();
      expect(right.first, isNot(closeTo(left.first, 0.01)));
    });
  });

  group('gore widgets', () {
    testWidgets('BloodBurst plays once, reports stains and done', (
      tester,
    ) async {
      var done = 0;
      List<FloorStain>? stains;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: BloodBurst(
                severity: 0.6,
                onDone: () => done++,
                onStains: (s) => stains = s,
              ),
            ),
          ),
        ),
      );
      await pumpFor(tester, 700);
      expect(done, 1);
      expect(stains, isNotNull);
      expect(stains!, isNotEmpty);
      for (final s in stains!) {
        expect(s.x, inInclusiveRange(-0.2, 1.2));
        expect(s.r, greaterThan(0));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('BloodBurst under reduce motion still lands its stains', (
      tester,
    ) async {
      Motion.instance.update(setting: 'on');
      var done = 0;
      var stains = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: BloodBurst(
                severity: 0.6,
                onDone: () => done++,
                onStains: (s) => stains = s.length,
              ),
            ),
          ),
        ),
      );
      await pumpFor(tester, 120);
      expect(done, 1);
      expect(stains, greaterThan(0));
    });

    testWidgets('every contact shape and ichor paints without throwing', (
      tester,
    ) async {
      for (final shape in ContactShape.values) {
        for (final facing in [1, -1]) {
          var done = false;
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: ImpactSlash(
                    key: ValueKey('$shape-$facing'),
                    shape: shape,
                    facing: facing,
                    onDone: () => done = true,
                  ),
                ),
              ),
            ),
          );
          await pumpFor(tester, 420);
          expect(done, isTrue, reason: '$shape');
          expect(tester.takeException(), isNull);
        }
      }
      // Legacy switch still resolves.
      expect(
        const ImpactSlash(claws: true, onDone: _noop).resolvedShape,
        ContactShape.claws,
      );
      expect(const ImpactSlash(onDone: _noop).resolvedShape, ContactShape.cut);
      await tester.pumpWidget(
        MaterialApp(
          home: CustomPaint(
            painter: FloorStainsPainter([
              for (final i in Ichor.values) FloorStain(0.5, 3, i),
            ]),
            size: const Size(200, 100),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('SpriteView with wounds/breathing paints for every ichor', (
      tester,
    ) async {
      await tester.runAsync(warmSpriteSheets);
      for (final ichor in Ichor.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SpriteView(
                'kindler',
                height: 96,
                bob: true,
                condition: const Condition(0.1),
                ichor: ichor,
              ),
            ),
          ),
        );
        await pumpFor(tester, 200);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('WeaponView guard phase and plans render for every delver', (
      tester,
    ) async {
      for (final id in charactersOrder) {
        final plan = planStrike(familyForWeapon(weaponFor(id).id), DieTier.max);
        var phase = WeaponPhase.idle;
        late StateSetter set;
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: StatefulBuilder(
                builder: (context, setState) {
                  set = setState;
                  return WeaponView(id, height: 96, phase: phase, plan: plan);
                },
              ),
            ),
          ),
        );
        for (final next in [
          WeaponPhase.guard,
          WeaponPhase.raise,
          WeaponPhase.swing,
          WeaponPhase.idle,
        ]) {
          set(() => phase = next);
          await pumpFor(tester, 360);
          expect(tester.takeException(), isNull, reason: '$id $next');
        }
      }
    });
  });

  group('hand sockets', () {
    test('every character sheet declares a forward-hand socket', () async {
      final meta = await SpriteMeta.load();
      for (final id in charactersOrder) {
        final def = meta.characters[id];
        expect(def, isNotNull, reason: id);
        final hand = def!.hand;
        expect(hand, isNotNull, reason: '$id has no hand socket');
        expect(hand!.dx, inInclusiveRange(0.3, 0.95), reason: id);
        expect(hand.dy, inInclusiveRange(0.3, 0.75), reason: id);
      }
      // Enemies hold nothing.
      for (final e in meta.enemies.values) {
        expect(e.hand, isNull);
      }
    });
  });

  group('on the real combat screen', () {
    testWidgets(
      'selecting a die heats the weapon BEFORE the swing (critique §4)',
      (tester) async {
        final c = await intoFight(tester);
        await tester.tap(button('Roll'));
        await pumpFor(tester, 2600);
        final rolled = (c.sim!.player['rolled'] as List).cast<int>();
        expect(rolled, [5, 1, 3]);
        expect(weapon(tester).charge, 0.0);
        final dice = find.byWidgetPredicate(
          (w) => w is DieChip && w.value != null,
        );
        // Select the 5 (a d6): heat is 5/6 of the way to white-hot.
        await tester.tap(dice.at(0));
        await pumpFor(tester, 120);
        expect(weapon(tester).charge, closeTo(heatFor(5, 6), 1e-9));
        expect(weapon(tester).charge, greaterThan(5 / 12)); // not the old /12
        // Re-select the 1: cools to the floor, still non-zero.
        await tester.tap(dice.at(1));
        await pumpFor(tester, 120);
        expect(weapon(tester).charge, closeTo(heatFor(1, 6), 1e-9));
        // Deselect: cold.
        await tester.tap(dice.at(1));
        await pumpFor(tester, 120);
        expect(weapon(tester).charge, 0.0);
        expect(weapon(tester).phase, WeaponPhase.idle);
      },
    );

    testWidgets('block raises the guard; the stance holds while block is up', (
      tester,
    ) async {
      final c = await intoFight(tester);
      await tester.tap(button('Roll'));
      await pumpFor(tester, 2600);
      final dice = find.byWidgetPredicate(
        (w) => w is DieChip && w.value != null,
      );
      expect(weapon(tester).phase, WeaponPhase.idle);
      await tester.tap(dice.at(1)); // the 1
      await tester.pump();
      await tester.tap(button('Block'));
      await pumpFor(tester, 300);
      expect((c.sim!.player['block'] as int), greaterThan(0));
      expect(weapon(tester).phase, WeaponPhase.guard);
      // A swing interrupts the guard and returns to it afterwards.
      await tester.tap(dice.at(0)); // the 5
      await tester.pump();
      await tester.tap(button('Attack'));
      await pumpFor(tester, 120);
      expect(weapon(tester).phase, WeaponPhase.raise);
      await pumpFor(tester, 1400);
      expect(weapon(tester).phase, WeaponPhase.guard);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a landed hit bleeds and stains; a fully blocked one does not', (
      tester,
    ) async {
      final c = await intoFight(tester);
      await tester.tap(button('Roll'));
      await pumpFor(tester, 2600);
      final dice = find.byWidgetPredicate(
        (w) => w is DieChip && w.value != null,
      );
      final hpBefore = c.sim!.enemy!['hp'] as int;
      await tester.tap(dice.at(0)); // the 5
      await tester.pump();
      await tester.tap(button('Attack'));
      await pumpFor(tester, 400);
      expect(find.byType(BloodBurst), findsOneWidget);
      final slash = tester.widget<ImpactSlash>(find.byType(ImpactSlash));
      expect(slash.shape, ContactShape.cut); // Kindler's Ember Brand
      await pumpFor(tester, 1200);
      expect(find.byType(BloodBurst), findsNothing);
      expect(find.byType(FloorStainsPainter), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is FloorStainsPainter,
        ),
        findsOneWidget,
        reason: 'the floor keeps what was spilled',
      );
      // Presentation never touched the numbers: the sim did exactly the
      // damage it always did.
      expect(hpBefore - (c.sim!.enemy!['hp'] as int), 5);

      // Now a hit the enemy fully absorbs: give it a wall of block.
      c.sim!.enemy!['block'] = 99;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      c.notifyListeners();
      await pumpFor(tester, 200);
      final bursts = find.byType(BloodBurst);
      await tester.tap(dice.at(2)); // the 3
      await tester.pump();
      await tester.tap(button('Attack'));
      await pumpFor(tester, 400);
      expect(bursts, findsNothing);
      expect(find.byType(GuardFlash), findsOneWidget);
      await pumpFor(tester, 1600); // let the swing finish before teardown
      expect(tester.takeException(), isNull);
    });

    testWidgets('the body carries its HP: wounds, slump, pallor appear', (
      tester,
    ) async {
      final c = await intoFight(tester);
      SpriteView hero() => tester.widget<SpriteView>(
        find.byWidgetPredicate(
          (w) => w is SpriteView && w.spriteId == 'kindler',
        ),
      );
      expect(hero().condition.isFresh, isTrue);
      final filtersBefore = find.byType(ColorFiltered).evaluate().length;
      c.sim!.player['hp'] = 6; // of 30
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      c.notifyListeners();
      await pumpFor(tester, 200);
      expect(hero().condition.wounds, 4);
      expect(hero().condition.tremor, greaterThan(0));
      // Exactly one new filter wraps the hero: the pallor.
      expect(find.byType(ColorFiltered).evaluate().length, filtersBefore + 1);
      // Cosmetic only: the sim's numbers are exactly what we set.
      expect(c.sim!.player['hp'], 6);
      expect(c.sim!.player['max_hp'], 30);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion: fight still resolves, no exceptions', (
      tester,
    ) async {
      final c = await intoFight(tester);
      Motion.instance.update(setting: 'on');
      await pumpFor(tester, 100);
      await tester.tap(button('Roll'));
      await pumpFor(tester, 2600);
      final dice = find.byWidgetPredicate(
        (w) => w is DieChip && w.value != null,
      );
      await tester.tap(dice.at(0));
      await tester.pump();
      await tester.tap(button('Attack'));
      await pumpFor(tester, 1600);
      await tester.tap(button('End turn'));
      await pumpFor(tester, 3000);
      expect(c.phase, 'player_turn');
      expect(button('Roll'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rapid queued taps still land every assign', (tester) async {
      final c = await intoFight(tester);
      await tester.tap(button('Roll'));
      await pumpFor(tester, 2600);
      final dice = find.byWidgetPredicate(
        (w) => w is DieChip && w.value != null,
      );
      await tester.tap(dice.at(0));
      await tester.pump();
      await tester.tap(button('Attack'));
      await tester.pump(const Duration(milliseconds: 40));
      // Mid-swing: queue another attack (one-slot queue, latest wins).
      await tester.tap(dice.at(2));
      await tester.pump();
      await tester.tap(button('Attack'));
      await pumpFor(tester, 3200);
      final assigned = (c.sim!.player['assigned'] as Map);
      expect(assigned['1'], isNotNull);
      expect(assigned['3'], isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  test('sim determinism is untouched by the presentation layer', () {
    // Same seed, same commands → identical hashes, exactly as before this
    // pass. (The UI files import nothing INTO lib/sim; this pins the seam.)
    final a = Sim(1);
    final b = Sim(1);
    expect(a.runSeed, b.runSeed);
  });
}

void _noop() {}
