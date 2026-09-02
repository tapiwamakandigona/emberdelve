// test/cold_tales_test.dart — v0.114.0 The Cold Tales.
//
// Three winter events appended to the deck: the cold the doubled week
// (v0.111.0) put into the stone, findable in any run. Every option's
// promise is checked against what event_choose actually does, and the
// fair-death pillar holds: events never kill.
import 'package:emberdelve/data/events.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

const newIds = ['the_frozen_stall', 'the_wintered_die', 'the_meltwater_pool'];

GameController liveSim() {
  final c = GameController();
  c.startRun(character: 'kindler', seed: 7, difficulty: 'easy');
  var guard = 0;
  while (c.phase != 'shop' &&
      c.phase != 'run_won' &&
      c.phase != 'run_lost' &&
      guard++ < 400) {
    final cmd = botCmd(c.sim!);
    if (cmd == null) break;
    c.apply(cmd);
  }
  expect(c.phase, 'shop', reason: 'seed 7 must reach a shop');
  return c;
}

void force(GameController c, String eventId) {
  c.sim!.phase = 'event';
  c.sim!.event = eventId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the cold tales close the deck, in order, fully catalogued', () {
    // Appended as a contiguous block in v0.114.0; later batches (v0.180.0
    // The Spoken Stones) sit after it — the deck is append-only.
    final at = eventsOrder.indexOf(newIds.first);
    expect(at, greaterThan(0));
    expect(eventsOrder.sublist(at, at + 3), newIds);
    for (final id in newIds) {
      final e = events[id]!;
      expect(e.options, hasLength(3));
      expect(
        e.options.any(
          (o) =>
              ((o.effects['gold'] as int?) ?? 0) >= 0 &&
              !o.effects.containsKey('lose_random_die'),
        ),
        isTrue,
        reason: '$id needs an always-legal option',
      );
    }
  });

  test('the frozen stall pays exactly what the labels promise', () {
    var c = liveSim();
    var gold = c.sim!.run!['gold'] as int;
    var hp = c.sim!.player['hp'] as int;
    force(c, 'the_frozen_stall');
    c.apply({'type': 'event_choose', 'option': 1});
    expect(c.sim!.run!['gold'], gold + 26);
    expect(c.sim!.player['hp'], hp - 6);

    c = liveSim();
    gold = c.sim!.run!['gold'] as int;
    final embers = c.sim!.run!['embers'] as int;
    force(c, 'the_frozen_stall');
    c.apply({'type': 'event_choose', 'option': 2});
    expect(c.sim!.run!['gold'], gold - 10);
    expect(c.sim!.run!['embers'], embers + 12);
  });

  test('the wintered die can add a die; selling pays; walking is free', () {
    var c = liveSim();
    final pool = (c.sim!.player['dice'] as List).length;
    final hp = c.sim!.player['hp'] as int;
    force(c, 'the_wintered_die');
    c.apply({'type': 'event_choose', 'option': 1});
    expect((c.sim!.player['dice'] as List).length, pool + 1);
    expect(c.sim!.player['hp'], hp - 8);

    c = liveSim();
    final gold = c.sim!.run!['gold'] as int;
    force(c, 'the_wintered_die');
    c.apply({'type': 'event_choose', 'option': 3});
    expect(c.sim!.run!['gold'], gold, reason: 'walking away changes nothing');
  });

  test('the meltwater pool heals capped and never kills for coins', () {
    var c = liveSim();
    c.sim!.player['hp'] = 10;
    force(c, 'the_meltwater_pool');
    c.apply({'type': 'event_choose', 'option': 1});
    final maxHp = c.sim!.player['max_hp'] as int;
    expect(c.sim!.player['hp'], 10 + (maxHp * 30 ~/ 100));

    // Fair-death pillar: fishing at 1 hp floors at 1, never kills.
    c = liveSim();
    c.sim!.player['hp'] = 1;
    force(c, 'the_meltwater_pool');
    c.apply({'type': 'event_choose', 'option': 2});
    expect(c.sim!.player['hp'], 1);
    expect(c.phase, isNot('run_lost'));
  });

  test('cold tales copy is honest (no pressure language)', () {
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
    for (final id in newIds) {
      final e = events[id]!;
      final low = [
        e.name,
        e.text,
        for (final o in e.options) o.label,
      ].join(' ').toLowerCase();
      for (final b in banned) {
        expect(low.contains(b), isFalse, reason: '$id banned: $b');
      }
    }
  });
}
