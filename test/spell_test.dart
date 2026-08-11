// Spell slot (AKP-4d, owner-confirmed 2026-07-25): one equipped spell, one
// cast per level run. Effects are session-level: Ember Burst (AoE + ignite,
// pierces Rotshield block), Stone Veil (timed immunity), Hearth Light
// (heal, clamped to max hearts). No spell equipped = no cast, no button.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/core/save.dart';
import 'package:emberwood/game/core_loadout.dart';
import 'package:emberwood/game/input_intent.dart';
import 'package:emberwood/game/level/level_data.dart';
import 'package:emberwood/game/session.dart';
import 'package:emberwood/game/tuning.dart';
import 'package:emberwood/meta/catalog.dart';

const dt = 1 / 120;

void stepSession(LevelSession s, double seconds) {
  final frames = (seconds / dt).round();
  final intent = InputIntent();
  for (var i = 0; i < frames; i++) {
    intent.clearEdges();
    s.update(dt, intent);
  }
}

Loadout withSpell(String id) => Loadout(
      weapon: weaponById('squire_blade'),
      maxHearts: 3,
      meleePower: 1.0,
      extraAirJumps: 0,
      appleCapacity: 10,
      coinMagnet: false,
      skinId: 'red',
      spell: spellById(id),
    );

LevelSession boot(String ascii, {Loadout? loadout}) {
  final s = LevelSession(LevelData.parse(ascii), loadout ?? Loadout.starter(),
      seed: 3);
  stepSession(s, 0.3); // settle spawn physics
  s.takeEvents();
  return s;
}

// Thornling right next to the player (well inside kSpellBurstRadius).
const nearEnemy = '''
....................
.P.T...............E
####################
''';

void main() {
  test('no spell equipped: not ready, cast refused', () {
    final s = boot(nearEnemy);
    expect(s.spellReady, isFalse);
    expect(s.castSpell(), isFalse);
    expect(s.takeEvents().map((e) => e.kind),
        isNot(contains(SessionEventKind.spellCast)));
  });

  test('ember burst damages + ignites nearby enemies and pierces range',
      () {
    final s = boot(nearEnemy, loadout: withSpell('ember_burst'));
    final enemy = s.enemies.single;
    final hpBefore = enemy.hp;
    expect(s.spellReady, isTrue);
    expect(s.castSpell(), isTrue);
    expect(enemy.hp, hpBefore - kSpellBurstDamage);
    if (enemy.alive) {
      expect(enemy.burnLeft, greaterThan(0),
          reason: 'burst ignites survivors');
    }
    final kinds = s.takeEvents().map((e) => e.kind).toList();
    expect(kinds, contains(SessionEventKind.spellCast));
    expect(kinds, contains(SessionEventKind.enemyHit));
  });

  test('ember burst ignores enemies outside the radius', () {
    // Enemy ~9 tiles (144px) away — outside kSpellBurstRadius (56px).
    final s = boot('''
....................
.P.........T.......E
####################
''', loadout: withSpell('ember_burst'));
    final enemy = s.enemies.single;
    final hpBefore = enemy.hp;
    expect(s.castSpell(), isTrue);
    expect(enemy.hp, hpBefore, reason: 'out of range: untouched');
  });

  test('stone veil grants timed immunity', () {
    final s = boot(nearEnemy, loadout: withSpell('stone_veil'));
    expect(s.castSpell(), isTrue);
    expect(s.player.iFrames, kSpellVeilSeconds);
    expect(s.player.damage(1, from: s.player.body.centerX + 5), isFalse);
    expect(s.player.hearts, s.player.maxHearts);
  });

  test('hearth light heals and clamps to max hearts', () {
    final s = boot(nearEnemy, loadout: withSpell('hearth_light'));
    s.player.hearts = 1;
    expect(s.castSpell(), isTrue);
    expect(s.player.hearts, (1 + kSpellHealHearts).clamp(0, 3));
    // A full-health cast (fresh session) must not overheal.
    final s2 = boot(nearEnemy, loadout: withSpell('hearth_light'));
    expect(s2.castSpell(), isTrue);
    expect(s2.player.hearts, s2.player.maxHearts);
  });

  test('exactly one cast per run', () {
    final s = boot(nearEnemy, loadout: withSpell('stone_veil'));
    expect(s.castSpell(), isTrue);
    expect(s.spellReady, isFalse);
    expect(s.castSpell(), isFalse, reason: 'single charge per level run');
  });

  test('loadout builds the spell from save; unowned equip is ignored', () {
    // Owned + equipped -> spell present.
    expect(
        Loadout.fromSave(SaveData(
                ownedSpells: {'ember_burst'}, equippedSpell: 'ember_burst'))
            .spell
            ?.id,
        'ember_burst');
    // Equipped but NOT owned (corrupt/hacked save) -> null, no free spell.
    expect(
        Loadout.fromSave(SaveData(equippedSpell: 'ember_burst')).spell,
        isNull);
    // Nothing equipped -> null.
    expect(Loadout.fromSave(SaveData(ownedSpells: {'ember_burst'})).spell,
        isNull);
  });

  test('spell save fields round-trip through json', () {
    final save =
        SaveData(ownedSpells: {'stone_veil'}, equippedSpell: 'stone_veil');
    final back = SaveData.fromJson(
        (save.toJson()).map((k, v) => MapEntry(k, v as dynamic)));
    expect(back.ownedSpells, {'stone_veil'});
    expect(back.equippedSpell, 'stone_veil');
  });
}
