// test/reminder_service_test.dart — the opt-in Daily Delve reminder (v0.6.0).
//
// What is nailed down and why:
//   1. nextReminderTimes is the whole scheduling contract: strictly-future
//      first slot, correct hour, one per civil day, month/year rollover.
//   2. The service is a silent no-op without backends (tests/web/desktop)
//      and OFF by default — the §Ethics opt-in is structural, not polite.
//   3. enable() only turns on when the OS permission is granted; a denial
//      leaves everything off and schedules nothing.
//   4. Every (re)schedule wipes the previous window first — never stacked
//      duplicate slots — and disable() cancels everything.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emberdelve/meta/reminder_service.dart';

/// Fresh service with fake backends; returns the log of backend calls.
({ReminderService svc, List<String> log}) _rig({bool grant = true}) {
  final log = <String>[];
  final svc = ReminderService();
  svc.permissionBackend = () async {
    log.add('perm');
    return grant;
  };
  svc.scheduleBackend = (id, when, title, body) async {
    log.add('sched:$id:${when.toIso8601String()}');
  };
  svc.cancelAllBackend = () async => log.add('cancelAll');
  return (svc: svc, log: log);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('nextReminderTimes (pure contract)', () {
    test('before the hour: first slot is today at the hour', () {
      final now = DateTime(2026, 8, 11, 7, 30);
      final slots = nextReminderTimes(now);
      expect(slots.first, DateTime(2026, 8, 11, 10));
      expect(slots.length, ReminderService.horizonDays);
    });

    test('at or after the hour: first slot is tomorrow (strictly future)', () {
      expect(
        nextReminderTimes(DateTime(2026, 8, 11, 10)).first,
        DateTime(2026, 8, 12, 10),
      );
      expect(
        nextReminderTimes(DateTime(2026, 8, 11, 23, 59)).first,
        DateTime(2026, 8, 12, 10),
      );
    });

    test('one slot per civil day, all at the reminder hour', () {
      final slots = nextReminderTimes(DateTime(2026, 8, 11, 12));
      for (var i = 0; i < slots.length; i++) {
        expect(slots[i].hour, ReminderService.reminderHour);
        if (i > 0) {
          expect(slots[i].difference(slots[i - 1]).inHours, 24);
        }
      }
    });

    test('rolls cleanly across month and year ends', () {
      final dec = nextReminderTimes(DateTime(2026, 12, 30, 15));
      expect(dec.first, DateTime(2026, 12, 31, 10));
      expect(dec[1], DateTime(2027, 1, 1, 10));
      expect(dec.last, DateTime(2027, 1, 6, 10));
    });
  });

  group('service gate', () {
    test(
      'unavailable without backends; every call is a silent no-op',
      () async {
        final svc = ReminderService();
        expect(svc.available, isFalse);
        expect(await svc.enable(), isFalse);
        await svc.disable();
        await svc.rescheduleIfEnabled(); // must not throw
        expect(svc.enabled, isFalse);
      },
    );

    test('OFF by default after load()', () async {
      final r = _rig();
      await r.svc.load();
      expect(r.svc.enabled, isFalse);
      // Boot reschedule while off schedules nothing.
      await r.svc.rescheduleIfEnabled(DateTime(2026, 8, 11, 7));
      expect(r.log, isEmpty);
    });

    test(
      'enable asks permission, schedules the full window, persists',
      () async {
        final r = _rig();
        await r.svc.load();
        expect(await r.svc.enable(), isTrue);
        expect(r.svc.enabled, isTrue);
        expect(r.log.first, 'perm');
        expect(
          r.log.where((e) => e.startsWith('sched:')).length,
          ReminderService.horizonDays,
        );
        // Persisted: a fresh instance over the same prefs remembers ON.
        final again = ReminderService();
        await again.load();
        expect(again.enabled, isTrue);
      },
    );

    test(
      'denied permission leaves the reminder off and schedules nothing',
      () async {
        final r = _rig(grant: false);
        await r.svc.load();
        expect(await r.svc.enable(), isFalse);
        expect(r.svc.enabled, isFalse);
        expect(r.log, ['perm']); // asked, denied, stopped
      },
    );

    test(
      'a throwing permission backend reads as denied, never crashes',
      () async {
        final svc = ReminderService();
        svc.permissionBackend = () async => throw StateError('boom');
        svc.scheduleBackend = (id, when, t, b) async {};
        svc.cancelAllBackend = () async {};
        await svc.load();
        expect(await svc.enable(), isFalse);
        expect(svc.enabled, isFalse);
      },
    );
  });

  group('scheduling window', () {
    test(
      'every window starts with cancelAll — no stacked duplicates',
      () async {
        final r = _rig();
        await r.svc.load();
        await r.svc.enable();
        r.log.clear();
        await r.svc.rescheduleIfEnabled(DateTime(2026, 8, 11, 7));
        expect(r.log.first, 'cancelAll');
        expect(
          r.log.where((e) => e.startsWith('sched:')).length,
          ReminderService.horizonDays,
        );
      },
    );

    test(
      'slots use sequential ids from baseId and the pure slot times',
      () async {
        final r = _rig();
        await r.svc.load();
        await r.svc.enable();
        r.log.clear();
        final now = DateTime(2026, 8, 11, 7);
        await r.svc.rescheduleIfEnabled(now);
        final expected = nextReminderTimes(now);
        final scheds = r.log.where((e) => e.startsWith('sched:')).toList();
        for (var i = 0; i < expected.length; i++) {
          expect(
            scheds[i],
            'sched:${ReminderService.baseId + i}:'
            '${expected[i].toIso8601String()}',
          );
        }
      },
    );

    test('disable cancels everything and persists OFF', () async {
      final r = _rig();
      await r.svc.load();
      await r.svc.enable();
      r.log.clear();
      await r.svc.disable();
      expect(r.svc.enabled, isFalse);
      expect(r.log, ['cancelAll']);
      final again = ReminderService();
      await again.load();
      expect(again.enabled, isFalse);
      // And a boot reschedule after disable stays silent.
      r.log.clear();
      await r.svc.rescheduleIfEnabled();
      expect(r.log, isEmpty);
    });

    test('copy is a neutral fact — no loss-frame words (§Ethics)', () {
      final all =
          (ReminderService.notificationTitle + ReminderService.notificationBody)
              .toLowerCase();
      for (final banned in [
        'miss',
        'lose',
        'losing',
        'streak',
        'last chance',
        'don\'t forget',
        'expire',
      ]) {
        expect(
          all.contains(banned),
          isFalse,
          reason: 'reminder copy must never use "$banned"',
        );
      }
    });
  });
}
