// test/review_service_test.dart — charter tests for the one-ask-ever
// in-app review gate (lib/meta/review_service.dart). Headless: the plugin
// backend is injected, so these prove the eligibility logic and the stamp
// semantics without any platform channel.
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/review_service.dart';

void main() {
  group('ReviewService.eligible', () {
    test('never asks twice: reviewAsked blocks everything', () {
      final m = MetaState(runsWon: 10, reviewAsked: true);
      expect(
        ReviewService.eligible(
          m,
          wonThisRun: true,
          wonDailyOrWeekly: true,
          tourActive: false,
        ),
        isFalse,
      );
    });

    test('never asks while the tour runs', () {
      final m = MetaState(runsWon: 5);
      expect(
        ReviewService.eligible(
          m,
          wonThisRun: true,
          wonDailyOrWeekly: true,
          tourActive: true,
        ),
        isFalse,
      );
    });

    test('first win alone does not ask (tour-adjacent)', () {
      final m = MetaState(runsWon: 1);
      expect(
        ReviewService.eligible(
          m,
          wonThisRun: true,
          wonDailyOrWeekly: false,
          tourActive: false,
        ),
        isFalse,
      );
    });

    test('v0.180.0: the FIRST run never asks on any route', () {
      final first = MetaState(runsWon: 1, runsPlayed: 1);
      // Won daily as the very first run.
      expect(
        ReviewService.eligible(
          first,
          wonThisRun: true,
          wonDailyOrWeekly: true,
          tourActive: false,
        ),
        isFalse,
      );
      // Strong first clear that climbs straight into Sparktender.
      expect(
        ReviewService.eligible(
          first,
          wonThisRun: true,
          wonDailyOrWeekly: false,
          tourActive: false,
          rankedUpToMarks: 24,
        ),
        isFalse,
      );
      // The same climb on the second run asks.
      final second = MetaState(runsWon: 1, runsPlayed: 2);
      expect(
        ReviewService.eligible(
          second,
          wonThisRun: true,
          wonDailyOrWeekly: false,
          tourActive: false,
          rankedUpToMarks: 24,
        ),
        isTrue,
      );
    });

    test('second win asks', () {
      final m = MetaState(runsWon: 2, runsPlayed: 2);
      expect(
        ReviewService.eligible(
          m,
          wonThisRun: true,
          wonDailyOrWeekly: false,
          tourActive: false,
        ),
        isTrue,
      );
    });

    test('a lost run never asks, whatever the counters say', () {
      final m = MetaState(runsWon: 9);
      expect(
        ReviewService.eligible(
          m,
          wonThisRun: false,
          wonDailyOrWeekly: false,
          tourActive: false,
        ),
        isFalse,
      );
    });

    test('a won daily/weekly asks even before the 2nd freeplay win', () {
      final m = MetaState(runsWon: 1, runsPlayed: 2);
      expect(
        ReviewService.eligible(
          m,
          wonThisRun: true,
          wonDailyOrWeekly: true,
          tourActive: false,
        ),
        isTrue,
      );
    });
  });

  group('ReviewService.maybeAsk', () {
    test('stamps reviewAsked and fires the backend exactly once', () async {
      var calls = 0;
      final svc = ReviewService.instance;
      svc.backend = () async => calls++;
      final m = MetaState(runsWon: 2, runsPlayed: 2);
      final fired = svc.maybeAsk(
        m,
        wonThisRun: true,
        wonDailyOrWeekly: false,
        tourActive: false,
      );
      expect(fired, isTrue);
      expect(m.reviewAsked, isTrue);
      // A later, equally-proud moment must be a no-op.
      final again = svc.maybeAsk(
        m,
        wonThisRun: true,
        wonDailyOrWeekly: true,
        tourActive: false,
      );
      expect(again, isFalse);
      await Future<void>.delayed(Duration.zero); // let unawaited() settle
      expect(calls, 1);
      svc.backend = null;
    });

    test('no backend (tests/web/desktop) still stamps quietly', () {
      final svc = ReviewService.instance;
      svc.backend = null;
      final m = MetaState(runsWon: 3, runsPlayed: 3);
      expect(
        svc.maybeAsk(
          m,
          wonThisRun: true,
          wonDailyOrWeekly: false,
          tourActive: false,
        ),
        isTrue,
      );
      expect(m.reviewAsked, isTrue);
    });
  });

  group('rank-climb ask (v0.7.0 reachability fix)', () {
    test('climbing into Sparktender asks, with no win at all', () {
      final m = MetaState(runsPlayed: 6);
      expect(
        ReviewService.eligible(
          m,
          wonThisRun: false,
          wonDailyOrWeekly: false,
          tourActive: false,
          rankedUpToMarks: ReviewService.rankAskFloorMarks,
        ),
        isTrue,
      );
    });

    test('climbing into Tinderhand (8) is too early to ask', () {
      final m = MetaState(runsPlayed: 3);
      expect(
        ReviewService.eligible(
          m,
          wonThisRun: false,
          wonDailyOrWeekly: false,
          tourActive: false,
          rankedUpToMarks: 8,
        ),
        isFalse,
      );
    });

    test('a bank that is not a rank-up never asks on the rank path', () {
      final m = MetaState(runsPlayed: 30);
      expect(
        ReviewService.eligible(
          m,
          wonThisRun: false,
          wonDailyOrWeekly: false,
          tourActive: false,
          rankedUpToMarks: null,
        ),
        isFalse,
      );
    });

    test('a high rank climb still never asks twice, or during the tour', () {
      expect(
        ReviewService.eligible(
          MetaState(reviewAsked: true),
          wonThisRun: false,
          wonDailyOrWeekly: false,
          tourActive: false,
          rankedUpToMarks: 240,
        ),
        isFalse,
      );
      expect(
        ReviewService.eligible(
          MetaState(),
          wonThisRun: false,
          wonDailyOrWeekly: false,
          tourActive: true,
          rankedUpToMarks: 240,
        ),
        isFalse,
      );
    });

    test('rank climb stamps the flag exactly once', () {
      final m = MetaState(runsPlayed: 9);
      final svc = ReviewService.instance;
      expect(
        svc.maybeAsk(
          m,
          wonThisRun: false,
          wonDailyOrWeekly: false,
          tourActive: false,
          rankedUpToMarks: 60,
        ),
        isTrue,
      );
      expect(m.reviewAsked, isTrue);
      expect(
        svc.maybeAsk(
          m,
          wonThisRun: false,
          wonDailyOrWeekly: false,
          tourActive: false,
          rankedUpToMarks: 120,
        ),
        isFalse,
      );
    });
  });

  group('persistence + merge', () {
    test('reviewAsked round-trips through JSON and defaults false', () {
      final m = MetaState(reviewAsked: true);
      final back = MetaState.fromJson(m.toJson());
      expect(back.reviewAsked, isTrue);
      expect(MetaState.fromJson(MetaState().toJson()).reviewAsked, isFalse);
      // Compactness charter: an unasked profile writes no key at all.
      expect(MetaState().toJson().containsKey('reviewAsked'), isFalse);
    });

    test('cloud merge is sticky OR — asked anywhere is asked everywhere', () {
      final local = MetaState(reviewAsked: true);
      final cloud = MetaState();
      expect(mergeMetaStates(local, cloud).reviewAsked, isTrue);
      expect(mergeMetaStates(cloud, local).reviewAsked, isTrue);
      expect(mergeMetaStates(MetaState(), MetaState()).reviewAsked, isFalse);
    });
  });
}
