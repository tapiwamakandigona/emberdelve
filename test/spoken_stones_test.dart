// test/spoken_stones_test.dart — v0.180.0 The Spoken Stones.
//
// Three events appended to the deck, themed to the release's teaching line
// ("the dark fights fair"): every price is written on the wall before it is
// paid. Each option's label is checked against what event_choose actually
// does, and the fair-death pillar holds: events never kill.
import 'package:emberdelve/data/events.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:flutter_test/flutter_test.dart';

const newIds = ['the_fair_scale', 'the_two_marks', 'the_first_lantern'];

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

  test('the spoken stones close the deck, in order, fully catalogued', () {
    expect(eventsOrder.sublist(eventsOrder.length - 3), newIds);
    expect(events.length, eventsOrder.length);
    for (final id in newIds) {
      final e = events[id]!;
      expect(e.options, hasLength(3));
      expect(e.text.length, inInclusiveRange(80, 200));
      expect(
        e.options.any(
          (o) =>
              ((o.effects['gold'] as int?) ?? 0) >= 0 &&
              !o.effects.containsKey('lose_random_die'),
        ),
        isTrue,
        reason: '$id needs an always-legal option',
      );
      expect(e.options.last.effects, isEmpty, reason: 'walking away is free');
    }
  });

  test('the fair scale pays exactly what the labels promise', () {
    var c = liveSim();
    var gold = c.sim!.run!['gold'] as int;
    final embers = c.sim!.run!['embers'] as int;
    force(c, 'the_fair_scale');
    c.apply({'type': 'event_choose', 'option': 1});
    expect(c.sim!.run!['gold'], gold - 15);
    expect(c.sim!.run!['embers'], embers + 14);

    c = liveSim();
    c.sim!.player['hp'] = 1;
    final maxHp = c.sim!.player['max_hp'] as int;
    force(c, 'the_fair_scale');
    c.apply({'type': 'event_choose', 'option': 2});
    expect(c.sim!.player['hp'], 1 + (maxHp * 20 ~/ 100));
    expect(c.phase, isNot('event'));
  });

  test('the two marks cost hp for max hp, never below 1', () {
    var c = liveSim();
    final maxHp = c.sim!.player['max_hp'] as int;
    final hp = c.sim!.player['hp'] as int;
    force(c, 'the_two_marks');
    c.apply({'type': 'event_choose', 'option': 1});
    expect(c.sim!.player['max_hp'], maxHp + 3);
    // Sim rule (run_layer max_hp): raising the ceiling raises current hp by
    // the same amount, as every "+N max hp" option in the deck does.
    expect(c.sim!.player['hp'], hp - 5 + 3);

    c = liveSim();
    c.sim!.player['hp'] = 2;
    force(c, 'the_two_marks');
    c.apply({'type': 'event_choose', 'option': 1});
    // -5 floors at 1 (events never kill), then the +3 ceiling lift applies.
    expect(c.sim!.player['hp'], 4, reason: 'events never kill');

    c = liveSim();
    final gold = c.sim!.run!['gold'] as int;
    force(c, 'the_two_marks');
    c.apply({'type': 'event_choose', 'option': 2});
    expect(c.sim!.run!['gold'], gold + 18);
  });

  test('the first lantern trades gold for a relic; refuses when broke', () {
    var c = liveSim();
    c.sim!.run!['gold'] = 30;
    final relics = (c.sim!.run!['relics'] as List).length;
    force(c, 'the_first_lantern');
    c.apply({'type': 'event_choose', 'option': 1});
    expect(c.sim!.run!['gold'], 0);
    expect((c.sim!.run!['relics'] as List).length, relics + 1);

    c = liveSim();
    c.sim!.run!['gold'] = 29;
    force(c, 'the_first_lantern');
    c.apply({'type': 'event_choose', 'option': 1});
    expect(c.phase, 'event', reason: 'unaffordable option is not a command');
    expect(c.sim!.run!['gold'], 29);

    c = liveSim();
    c.sim!.player['hp'] = 1;
    final maxHp = c.sim!.player['max_hp'] as int;
    force(c, 'the_first_lantern');
    c.apply({'type': 'event_choose', 'option': 2});
    expect(c.sim!.player['hp'], 1 + (maxHp * 30 ~/ 100));
  });
}
