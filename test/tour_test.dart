// test/tour_test.dart — v0.8.0 "The Guided Delve": anchored tour director.
//
// Pure-logic contract for TourDirector (order, action gating, info taps,
// skip, soft-lock immunity) plus MetaState.tourSeenVersion persistence and
// cloud-merge max — the "everyone sees v2 once, including veterans" rule.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/tour.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';

void main() {
  group('TourDirector', () {
    test('fresh profile runs and starts at the roll beat', () {
      final d = TourDirector(seenVersion: 0);
      expect(d.running, isTrue);
      expect(d.active, TourBeats.roll);
      expect(d.activeIsInfo, isFalse);
    });

    test('current-version profile does not run', () {
      final d = TourDirector(seenVersion: tourVersion);
      expect(d.running, isFalse);
      expect(d.active, isNull);
    });

    test('veteran of the old wall (version 0) still runs — the point', () {
      // Old saves have tutorialSeen=true but tourSeenVersion=0.
      final d = TourDirector(seenVersion: 0);
      expect(d.running, isTrue);
    });

    test('replay flag runs the tour even when already seen', () {
      final d = TourDirector(seenVersion: tourVersion, replay: true);
      expect(d.running, isTrue);
      expect(d.active, TourBeats.roll);
    });

    test('action beats advance only on their matching moment', () {
      final d = TourDirector(seenVersion: 0);
      // Wrong moments are ignored — no soft-lock, no accidental skip.
      expect(d.onMoment(TourMoment.diePicked), isFalse);
      expect(d.active, TourBeats.roll);
      expect(d.onMoment(TourMoment.rolled), isFalse);
      expect(d.active, TourBeats.pick);
      expect(d.onMoment(TourMoment.diePicked), isFalse);
      expect(d.active, TourBeats.spend);
      expect(d.onMoment(TourMoment.actionSpent), isFalse);
      expect(d.active, TourBeats.intent);
    });

    test('info beats ignore actions and advance on tap', () {
      final d = TourDirector(seenVersion: 0);
      d.onMoment(TourMoment.rolled);
      d.onMoment(TourMoment.diePicked);
      d.onMoment(TourMoment.actionSpent);
      expect(d.active, TourBeats.intent);
      expect(d.activeIsInfo, isTrue);
      // Rolling again during an info beat changes nothing.
      expect(d.onMoment(TourMoment.rolled), isFalse);
      expect(d.active, TourBeats.intent);
      expect(d.advanceInfo(), isFalse);
      expect(d.active, TourBeats.reroll);
      // Last beat: finishing returns true so the caller stamps + persists.
      expect(d.advanceInfo(), isTrue);
      expect(d.running, isFalse);
      expect(d.active, isNull);
    });

    test('advanceInfo is a no-op on action beats', () {
      final d = TourDirector(seenVersion: 0);
      expect(d.advanceInfo(), isFalse);
      expect(d.active, TourBeats.roll);
    });

    test('skip ends the tour from any beat and reports completion', () {
      final d = TourDirector(seenVersion: 0);
      d.onMoment(TourMoment.rolled);
      expect(d.skip(), isTrue);
      expect(d.running, isFalse);
      expect(d.active, isNull);
    });

    test('step/total drive the "n of 5" label', () {
      final d = TourDirector(seenVersion: 0);
      expect(d.total, TourBeats.all.length);
      expect(d.step, 0);
      d.onMoment(TourMoment.rolled);
      expect(d.step, 1);
    });
  });

  group('MetaState.tourSeenVersion', () {
    test('defaults to 0, round-trips through json', () {
      final m = MetaState();
      expect(m.tourSeenVersion, 0);
      // 0 is omitted from json to keep old-save byte-compat.
      expect(m.toJson().containsKey('tourSeenVersion'), isFalse);
      m.tourSeenVersion = tourVersion;
      final back = MetaState.fromJson(m.toJson());
      expect(back.tourSeenVersion, tourVersion);
    });

    test('old save json (no key) deserializes to 0 — veterans re-tour', () {
      final old = MetaState(tutorialSeen: true).toJson();
      old.remove('tourSeenVersion');
      expect(MetaState.fromJson(old).tourSeenVersion, 0);
    });

    test('cloud merge keeps the max stamp both ways', () {
      final a = MetaState(tourSeenVersion: tourVersion);
      final b = MetaState();
      expect(mergeMetaStates(a, b).tourSeenVersion, tourVersion);
      expect(mergeMetaStates(b, a).tourSeenVersion, tourVersion);
    });
  });
}
