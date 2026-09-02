// test/seventh_cycle_test.dart — v0.180.0: the seventh cycle of hearth
// tales closes. Ten tales: the six second-circle chairs (v0.179.0), the two
// widened-rotation weeks, and two Spoken Stones rooms. Every line states a
// fact the game can prove; the two room tales are checked against the
// events they describe.
import 'package:emberdelve/data/events.dart';
import 'package:emberdelve/data/tales.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> cycle7() => hearthTales.sublist(60, 70);

  test('seven whole cycles; hearthgold still frozen at the first', () {
    expect(hearthTales.length, 8 * hearthgoldTales); // v0.180.0 eighth
    expect(hearthgoldTales, 10);
    expect(cycle7(), hasLength(10));
    for (final t in cycle7()) {
      expect(t.length, lessThanOrEqualTo(200), reason: t);
    }
  });

  test('the scale tale tells what the fair scale does', () {
    final tale = hearthTales[68];
    final e = events['the_fair_scale']!;
    expect(tale, contains('scale'));
    expect(tale, contains('embers'));
    expect(tale, contains('healing'));
    expect(e.options.any((o) => o.effects.containsKey('embers')), isTrue);
    expect(e.options.any((o) => o.effects.containsKey('heal_pct')), isTrue);
  });

  test('the marks tale tells what the two marks do', () {
    final tale = hearthTales[69];
    final e = events['the_two_marks']!;
    expect(tale, contains('marks'));
    final cut = e.options.first.effects;
    expect((cut['hp'] as int) < 0, isTrue, reason: 'it costs blood');
    expect((cut['max_hp'] as int) > 0, isTrue, reason: 'more life to hold');
  });

  test('the sequence runs on past the seventh cycle', () {
    // v0.180.0: the Eighth Cycle follows; tale 70 is its first line.
    expect(hearthTale(70), hearthTales[70]);
    expect(hearthTale(69), hearthTales[69]);
  });
}
