// test/honest_road_test.dart — v0.180.0 The Honest Road.
//
// A death-screen insight must never coach a read the game does not offer
// (§Ethics: insights never lie). The early bucket told players to "fight the
// low-HP enemies first when a path branches" — the map marks a node's KIND
// (Fight, Rest site, Shop, Event, Elite fight, Boss) and never an enemy or
// its HP. The line now says what the map does show. Pins: no early line
// mentions HP or enemy identity; the new line is present; its claims hold
// against map_gen (rests and events can sit on floors 2–3; elites cannot,
// so the early bucket must not mention them).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/data/insights.dart';
import 'package:emberdelve/sim/map_gen.dart';

void main() {
  test('the early bucket coaches only what the map shows', () {
    final early = insights['early']!;
    expect(early.length, 3, reason: 'draw shape frozen');
    for (final line in early) {
      final l = line.toLowerCase();
      expect(l.contains('hp'), isFalse, reason: line);
      expect(l.contains('low-hp'), isFalse, reason: line);
      expect(l.contains('elite'), isFalse, reason: 'elites start on floor 4');
    }
    expect(
      early,
      contains(startsWith('Every room ahead is marked on the map.')),
    );
  });

  test('the new line\'s claims hold against the map grammar', () {
    const cfg = MapCfg();
    // Early deaths are floors 1–3 (insightBucket); elites start later.
    expect(insightBucket(3, false), 'early');
    expect(insightBucket(4, false), 'mid');
    expect(cfg.eliteFromLayer, greaterThan(3));
    // A rest fire can sit on an early floor: rests carry no layer gate in
    // the kind roll, and events open on floor 2.
    expect(cfg.eventFromLayer, lessThanOrEqualTo(3));
    expect(restLo, lessThan(restHi));
  });
}
