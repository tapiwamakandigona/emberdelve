// Actual Flutter evidence for every playable character. Controlled visual
// fixtures are labelled; this is not a physical-phone or gameplay-balance test.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/sim/combos.dart';
import 'package:emberdelve/sim/relic_hooks.dart';
import 'package:emberdelve/sim/run_dice.dart';
import 'package:emberdelve/ui/blood_effects.dart';
import 'package:emberdelve/ui/combat_articulation.dart';
import 'package:emberdelve/ui/combat_figure.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _out = 'build/roster_review';
const _clipIds = {'hedger', 'bearer', 'gambler', 'runesmith', 'peddler', 'flintwright'};
const _sizes = [Size(320, 568), Size(360, 640), Size(412, 892)];

Future<void> _fonts() async {
  for (final entry in {
    'Cinzel': 'assets/fonts/Cinzel-Variable.ttf',
    'Inter': 'assets/fonts/Inter-Regular.ttf',
    'MaterialIcons': '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  }.entries) {
    await (FontLoader(entry.key)..addFont(Future.value(
      ByteData.sublistView(File(entry.value).readAsBytesSync()),
    ))).load();
  }
}

Future<void> _pump(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 20) {
    await tester.pump(Duration(milliseconds: (ms - t).clamp(0, 20)));
  }
}

Future<void> _png(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes.buffer.asUint8List());
    image.dispose();
  });
}

Finder _button(String label) => find.byWidgetPredicate(
    (w) => w is EmberButton && w.label == label && w.onTap != null);
Finder _chips() => find.byWidgetPredicate((w) => w is DieChip && w.value != null);
SpriteView _hero(WidgetTester tester, String id) => tester.widgetList<SpriteView>(
    find.byWidgetPredicate((w) => w is SpriteView && w.spriteId == id)).last;
StatBar _bar(WidgetTester tester, String name) => tester.widgetList<StatBar>(
    find.byType(StatBar)).firstWhere((b) => b.label.startsWith(name));

void _notify(GameController c) {
  // Deliberate, labelled fixture setup only. No new application mutation path.
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  c.notifyListeners();
}

void _layout(WidgetTester tester) {
  final viewport = Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  for (final finder in [find.byType(StatBar), _chips(), _button('Attack'), _button('Block')]) {
    for (final element in finder.evaluate()) {
      final rect = tester.getRect(find.byElementPredicate((e) => identical(e, element)));
      expect(rect.left, greaterThanOrEqualTo(viewport.left - 0.1));
      expect(rect.right, lessThanOrEqualTo(viewport.right + 0.1));
      expect(rect.top, greaterThanOrEqualTo(viewport.top - 0.1));
      expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + 0.1));
    }
  }
  expect(tester.takeException(), isNull);
}

Map<String, Object?> _observe(WidgetTester tester, String id, GameController c) {
  // A 60ms hit-flash AnimatedSwitcher legitimately paints outgoing AND
  // incoming figures. Check every rendered trio, not unrelated .single
  // matches across both trees or an unverified arbitrary duplicate.
  final figures = find.byWidgetPredicate(
      (w) => w is CombatFigure && w.rig.id == id).evaluate().toList();
  expect(figures, isNotEmpty);
  late SpriteView sprite;
  late WeaponView weapon;
  var error = 0.0;
  for (final figure in figures) {
    final root = find.byElementPredicate((e) => identical(e, figure));
    sprite = tester.widget<SpriteView>(
        find.descendant(of: root, matching: find.byType(SpriteView)));
    weapon = tester.widget<WeaponView>(
        find.descendant(of: root, matching: find.byType(WeaponView)));
    final hand = tester.widget<SpriteGripOverlay>(
        find.descendant(of: root, matching: find.byType(SpriteGripOverlay)));
    expect(sprite.articulation, isNotNull);
    expect(identical(sprite.articulation, weapon.articulation), isTrue);
    expect(identical(sprite.articulation, hand.articulation), isTrue);
    final sample = sprite.articulation!.value;
    final distance = (sample.weaponGrip(sprite.height) -
        sample.part(RigPart.hand).map(sample.rig.wrist) *
            (sprite.height / 40)).distance;
    expect(distance, lessThan(1e-7));
    if (distance > error) error = distance;
  }
  final s = sprite.articulation!.value;
  final player = _bar(tester, 'YOUR HP'), enemy = _bar(tester, 'ENEMY HP');
  return {
    'player_hp_sim': c.sim!.player['hp'], 'enemy_hp_sim': c.sim!.enemy?['hp'],
    'player_hp_display': player.value, 'enemy_hp_display': enemy.value,
    'player_block_display': player.block, 'phase': weapon.phase.name,
    'family': weapon.plan!.family.name, 'tier': weapon.plan!.tier.name,
    'native_wrist': [s.wrist.dx, s.wrist.dy], 'angle': s.weaponAngle,
    'grip_error_logical_px': error, 'sprite_height': sprite.height,
    'rendered_figure_copies_checked': figures.length,
    'blood': BloodEffects.enabled.value, 'reduced': Motion.instance.reduced,
  };
}

Future<void> _warm(WidgetTester tester) async {
  await tester.runAsync(() async {
    await warmSpriteSheets();
    final context = tester.element(find.byType(MaterialApp));
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final asset in manifest.listAssets().where((a) => a.endsWith('.png'))) {
      await precacheImage(AssetImage(asset), context);
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_fonts);
  tearDown(() {
    Motion.instance.update(setting: 'system', systemFlag: false);
    BloodEffects.enabled.value = true;
  });

  for (final id in charactersOrder) {
    for (final size in _sizes) {
      testWidgets('roster phone $id ${size.width.toInt()}', (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        Motion.instance.update(setting: 'off');
        final c = GameController();
        c.meta..tutorialSeen = true..tourSeenVersion = tourVersion
          ..tipsSeen.addAll(ContextTips.all);
        c.tipDirector = TipDirector(c.meta.tipsSeen);
        c.tour = TourDirector(seenVersion: tourVersion);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(), home: GameRoot(c)),
        ));
        await _warm(tester);
        c.startRun(character: id, boons: true, seed: 1, difficulty: 'easy');
        c.apply({'type': 'choose_boon', 'index': 0});
        c.apply({'type': 'choose_node', 'node': 2});
        await _pump(tester, 2600);
        expect(c.phase, 'player_turn');
        expect(c.sim!.enemy!['id'], 'flue_crawler');
        final kits = (c.sim!.player['dice'] as List).cast<String>();
        final runDice = kits.map((d) => resolveRunDie(c.sim!.run, d)).toList();
        expect(runDice.map((d) => d.baseId),
            orderedEquals(characters[id]!.startDice));
        for (final temper in characters[id]!.startTempers) {
          final die = runDice[(temper['die'] as int) - 1];
          expect(die.temperedFace, temper['face']);
          expect(die.rune, temper['rune']);
          expect(die.tier, temper['tier'] ?? 1);
        }
        expect(_hero(tester, id).articulation, isNotNull);
        final dir = '$id-${size.width.toInt()}';
        await _png(tester, key, '$dir-natural-ready');
        final observations = <Map<String, Object?>>[];
        var frame = 0;
        final timeOrigin = tester.binding.clock.now();
        final relicFloor = relicSum(c.sim!, 'min_roll');
        int effectiveFace(RunDie die, int raw) {
          final floor = die.def.mods['min_value'] as int? ?? 1;
          return raw.clamp(floor > relicFloor ? floor : relicFloor, die.def.size);
        }
        final attackIndex = runDice.indexWhere((d) =>
            d.def.mods['block_only'] != true &&
            tierFor(effectiveFace(d, 1), d.def.size) == DieTier.low);
        expect(attackIndex, greaterThanOrEqualTo(0),
            reason: 'a legal low-tier action must exist in the unchanged kit');
        final blockIndex = runDice.asMap().entries.firstWhere(
          (d) => d.key != attackIndex && d.value.def.mods['attack_only'] != true,
        ).key;
        final nativeRolls = <List<int>>[];
        final fixtureFaces = <Map<String, Object?>>[];

        Future<void> captureFrames(int count, String label) async {
          for (var i = 0; i < count; i++) {
            await tester.pump(const Duration(milliseconds: 40));
            _layout(tester);
            observations.add({'frame': frame, 'sampled_ms': (frame + 1) * 40,
              'elapsed_fixture_ms': tester.binding.clock.now()
                  .difference(timeOrigin).inMilliseconds, 'label': label,
              ..._observe(tester, id, c)});
            if ((size.width == 360 && _clipIds.contains(id)) ||
                i == 0 || i == 3 || i == 7 || i == count - 1) {
              await _png(tester, key, '$dir/${frame.toString().padLeft(3, '0')}-$label');
            }
            frame++;
          }
        }

        // Fixture intentionally extends enemy HP and chooses legal rolled
        // values to exercise low/high choreography in EVERY unchanged kit.
        // This is not a naturally earned encounter or a balance demonstration.
        for (final tier in [DieTier.low, DieTier.high]) {
          await tester.tap(_button('Roll'));
          await _pump(tester, 2200);
          nativeRolls.add(List<int>.from(c.sim!.player['rolled'] as List));
          c.sim!.player['hp'] = c.sim!.player['max_hp'];
          c.sim!.enemy!['hp'] = 999;
          c.sim!.enemy!['max_hp'] = 999;
          c.sim!.enemy!['block'] = 0;
          c.sim!.enemy!['intent'] = {'kind': 'attack', 'amount': 7};
          final die = runDice[attackIndex], sides = die.def.size;
          final raw = tier == DieTier.low ? 1 : sides - 1;
          final face = effectiveFace(die, raw);
          expect(tierFor(face, sides), tier);
          (c.sim!.player['rolled'] as List)[attackIndex] = face;
          (c.sim!.player['rolled_face'] as List)[attackIndex] = raw;
          (c.sim!.player['rolled_max'] as List)[attackIndex] = raw == sides;
          final combo = detectCombos(
              (c.sim!.player['rolled'] as List).cast<int>());
          c.sim!.player['combo_bonus'] = combo.bonus;
          c.sim!.player['ignited'] = combo.hasTriple;
          c.sim!.player['free_reroll_next'] = combo.hasStraight;
          c.sim!.enemy!['burn'] = combo.hasTriple ? igniteBurnStacks : 0;
          fixtureFaces.add({'tier': tier.name, 'raw_face': raw,
            'effective_face': face, 'sides': sides});
          _notify(c);
          await _pump(tester, 240);
          await tester.tap(_chips().at(attackIndex));
          await captureFrames(5, '${tier.name}-selected');
          final hpBefore = _bar(tester, 'ENEMY HP').value;
          await tester.tap(_button('Attack'));
          await captureFrames(8, '${tier.name}-precontact');
          expect(_bar(tester, 'ENEMY HP').value, hpBefore); // 320ms < 340ms
          final weapon = tester.widget<WeaponView>(find.byType(WeaponView));
          expect(weapon.plan!.tier, tier);
          expect(weapon.plan!.family, familyForWeapon(weaponFor(id).id));
          await captureFrames(1, '${tier.name}-contact'); // 360ms
          expect(_bar(tester, 'ENEMY HP').value, c.sim!.enemy!['hp']);
          expect(_bar(tester, 'ENEMY HP').value, lessThan(hpBefore));
          await captureFrames(16, '${tier.name}-recovery');
          await tester.tap(_chips().at(blockIndex));
          await tester.pump();
          await tester.tap(_button('Block'));
          await captureFrames(10, '${tier.name}-guard');
          final guard = _bar(tester, 'YOUR HP').block;
          expect(guard, greaterThan(0));
          await tester.tap(_button('End turn'));
          await captureFrames(10, '${tier.name}-incoming-before'); //400ms
          expect(_bar(tester, 'YOUR HP').block, guard);
          await captureFrames(2, '${tier.name}-incoming-contact');
          await captureFrames(43, '${tier.name}-next-turn');
          expect(c.phase, 'player_turn');
        }

        c.sim!.player['hp'] = (c.sim!.player['max_hp'] as int) ~/ 5;
        c.sim!.enemy!['hp'] = (c.sim!.enemy!['max_hp'] as int) ~/ 5;
        _notify(c);
        await _pump(tester, 600);
        await _png(tester, key, '$dir-forced-fatigue-blood-on');
        BloodEffects.enabled.value = false;
        await tester.pump();
        await _png(tester, key, '$dir-forced-fatigue-blood-off');
        Motion.instance.update(setting: 'on');
        await _pump(tester, 400);
        await _png(tester, key, '$dir-reduced');
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(tester, 200);
        _layout(tester);
        await _png(tester, key, '$dir-text-1.3');
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        File('$_out/$dir/observations.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'character': id, 'viewport': [size.width, size.height],
            'seed': 1, 'difficulty': 'easy', 'unchanged_runtime_kit': kits,
            'unchanged_base_kit': runDice.map((d) => d.baseId).toList(),
            'natural_rolls_before_fixture': nativeRolls,
            'forced_attack_faces': fixtureFaces,
            'attack_index': attackIndex, 'block_index': blockIndex,
            'fixtures': 'enemy HP/max999; forced raw attack faces 1/sides-1 '
                'with original die/relic floors; matching combo flags/burn; '
                'incoming attack7; HP restored between turns; fatigue20%; '
                'other natural roll-triggered effects retained; not a balance demo',
            'interval_ms': 40, 'frames': observations,
            'clip_edit': 'low/high action segments joined; intervening roll/fixture setup omitted',
            'device_fps': 'NOT MEASURED',
          }),
        );
        expect(observations.length, 190);
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, 2200);
      });
    }
  }

  for (final height in [72.0, 96.0, 104.0]) {
    testWidgets('all-roster particle-free native ${height.toInt()}', (tester) async {
      tester.view.physicalSize = const Size(1440, 1560);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.runAsync(warmSpriteSheets);
      Motion.instance.update(setting: 'on');
      for (var group = 0; group < 4; group++) {
        final ids = charactersOrder.skip(group * 6).take(6).toList();
        final key = GlobalKey();
        var phase = WeaponPhase.idle;
        var health = 1.0;
        var recoil = false;
        late StateSetter update;
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(),
            home: Scaffold(body: StatefulBuilder(builder: (context, set) {
              update = set;
              return Column(children: [
                const SizedBox(height: 16),
                const Text('EMBERDELVE / THE WHOLE COMPANY', style: EmberText.h2),
                Text('NATIVE ${height.toInt()}px / NO HIT EFFECTS / '
                    '${health == 1 ? "HEALTHY" : "FORCED 20% HP, BLOOD OFF"}',
                    style: EmberText.micro),
                const SizedBox(height: 24),
                for (final id in ids)
                  Expanded(child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(width: 154, child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SpriteView(id, height: 56, animate: false),
                          Text(id.toUpperCase(), style: EmberText.micro),
                        ],
                      )),
                      for (final tier in [DieTier.low, DieTier.high])
                        SizedBox(width: 210, child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            CombatFigure(rig: CombatRig.forId(id)!, height: height,
                              phase: phase,
                              plan: planStrike(familyForWeapon(weaponFor(id).id), tier),
                              condition: Condition(health), showWounds: false,
                              knock: recoil),
                            Text(tier.name.toUpperCase(), style: EmberText.micro),
                          ],
                        )),
                    ],
                  )),
                const SizedBox(height: 16),
              ]);
            })),
          ),
        ));
        Future<void> plate(String name) async {
          await _pump(tester, 500);
          expect(tester.takeException(), isNull);
          expect(tester.widgetList<CombatFigure>(find.byType(CombatFigure)).length,
              ids.length * 2);
          await _png(tester, key, 'native-${height.toInt()}-group-$group-$name');
        }
        await plate('ready');
        for (final next in [WeaponPhase.raise, WeaponPhase.swing, WeaponPhase.guard]) {
          update(() => phase = next);
          await plate(next.name);
        }
        update(() { phase = WeaponPhase.idle; recoil = true; });
        await plate('recoil');
        update(() { recoil = false; health = 0.2; });
        await plate('fatigue');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  for (final size in _sizes) {
    testWidgets('whole-roster selection portraits ${size.width.toInt()}', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      Motion.instance.update(setting: 'on');
      final c = GameController();
      c.meta.unlockedCharacters.addAll(charactersOrder);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key,
        child: MaterialApp(debugShowCheckedModeBanner: false,
          theme: buildEmberTheme(), home: CharacterScreen(c)),
      ));
      await _warm(tester);
      await _pump(tester, 400);
      final scroll = find.descendant(of: find.byType(ListView),
          matching: find.byType(Scrollable)).first;
      for (final id in charactersOrder) {
        // Wardrobe controls later in the same ListView repeat the names.
        // Select the actual card heading, not a global text singleton.
        final name = find.byWidgetPredicate((w) => w is Text &&
            w.data == characters[id]!.name && w.style == EmberText.h2);
        await tester.scrollUntilVisible(name, 240, scrollable: scroll, maxScrolls: 100);
        await _pump(tester, 200);
        final y = tester.getTopLeft(name).dy;
        await tester.drag(scroll, Offset(0, 116 - y), warnIfMissed: false);
        await _pump(tester, 200);
        final sprite = _hero(tester, id);
        expect(sprite.height, 56);
        expect(sprite.articulation, isNull);
        final spriteFinder = find.byWidgetPredicate(
            (w) => w is SpriteView && w.spriteId == id && w.height == 56);
        final rect = tester.getRect(spriteFinder);
        expect(rect.top, greaterThanOrEqualTo(56));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        // This supplemental Flutter test lives under tool/, not test/.
        // ignore: invalid_use_of_visible_for_testing_member
        expect(debugSpriteSheetCached(id), isTrue);
        expect(tester.takeException(), isNull);
        await _png(tester, key, 'picker-${size.width.toInt()}-$id');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
