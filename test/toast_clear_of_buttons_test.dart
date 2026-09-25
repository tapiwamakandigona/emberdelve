// test/toast_clear_of_buttons_test.dart — experimental C2-01.
//
// Critic round 2: the floating toast (a stock SnackBar in the bottom zone)
// hid the screen's primary button for 1.4 s — DELVE AGAIN on the loss
// summary, LEAVE SHOP, ROLL — and swallowed the tap.
//
// Pinned here, over every screen a bot-driven run reaches, at three phone
// sizes (320x568, 360x800, 412x915):
//   1. the toast's rect does not intersect any on-screen button rect;
//   2. a tap on the toast's centre does not hit the toast (taps pass through).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/sim/autoplay.dart';
import 'package:emberdelve/ui/flash_toast.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';

// Long enough to wrap on a narrow phone: the worst case for overlap.
const probe = 'Forged into a stronger die — the pool grows';

Future<void> pumpFrames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The toast's rect, or null if no toast is on screen.
Rect? toastRect(WidgetTester tester) {
  final keyed = find.byKey(kFlashToastKey);
  if (keyed.evaluate().isNotEmpty) return tester.getRect(keyed);
  // Pre-C2-01 toast: a SnackBar.
  final snack = find.byType(SnackBar);
  if (snack.evaluate().isNotEmpty) return tester.getRect(snack.first);
  return null;
}

/// Every tappable control on screen, with a label for failure messages.
/// Full-screen tap catchers ("tap anywhere to continue", scrims) are
/// skipped: any rect intersects them, and they are not buttons.
Map<String, Rect> buttonRects(WidgetTester tester, Size screen) {
  final out = <String, Rect>{};
  final screenRect = Offset.zero & screen;
  var i = 0;
  void add(Element e, String kind) {
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.hasSize || !ro.attached) return;
    final r = ro.localToGlobal(Offset.zero) & ro.size;
    if (r.isEmpty || !r.overlaps(screenRect)) return;
    if (r.width * r.height > 0.4 * screen.width * screen.height) return;
    // Inside the toast itself (old SnackBar internals) — not a target.
    if (find
        .ancestor(
          of: find.byElementPredicate((x) => x == e),
          matching: find.byType(SnackBar),
        )
        .evaluate()
        .isNotEmpty) {
      return;
    }
    out['$kind#${i++} $r'] = r;
  }

  for (final e in find.byType(ButtonStyleButton).evaluate()) {
    add(e, 'button');
  }
  for (final e in find.byType(IconButton).evaluate()) {
    add(e, 'icon');
  }
  for (final e in find.byType(DieChip).evaluate()) {
    add(e, 'die');
  }
  for (final e
      in find
          .byWidgetPredicate((w) => w is InkWell && w.onTap != null)
          .evaluate()) {
    add(e, 'ink');
  }
  for (final e
      in find
          .byWidgetPredicate((w) => w is GestureDetector && w.onTap != null)
          .evaluate()) {
    add(e, 'tap');
  }
  return out;
}

/// True when a pointer at [p] would hit the toast's render objects.
bool toastTakesTap(WidgetTester tester, Offset p) {
  final keyed = find.byKey(kFlashToastKey);
  final target = keyed.evaluate().isNotEmpty
      ? keyed
      : find.byType(SnackBar).first;
  final toastRos = <RenderObject>{};
  void walk(Element e) {
    final ro = e.renderObject;
    if (ro != null) toastRos.add(ro);
    e.visitChildren(walk);
  }

  walk(target.evaluate().first);
  final result = HitTestResult();
  // ignore: deprecated_member_use
  tester.binding.hitTestInView(result, p, tester.view.viewId);
  return result.path.any((entry) => toastRos.contains(entry.target));
}

void main() {
  const sizes = [Size(320, 568), Size(360, 800), Size(412, 915)];
  for (final size in sizes) {
    testWidgets(
      'toast never covers a button (${size.width.toInt()}x${size.height.toInt()})',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final c = GameController();
        c.markTutorialSeen();
        await tester.pumpWidget(
          MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
        );
        await pumpFrames(tester, 20);

        final checked = <String>{};
        final failures = <String>[];

        Future<void> probeScreen(String label) async {
          c.announce(probe);
          await pumpFrames(tester, 25); // fade/slide in, fully readable
          final t = toastRect(tester);
          if (t == null) {
            failures.add('$label: no toast on screen');
            return;
          }
          for (final entry in buttonRects(tester, size).entries) {
            if (t.overlaps(entry.value)) {
              failures.add('$label: toast $t covers ${entry.key}');
            }
          }
          if (toastTakesTap(tester, t.center)) {
            failures.add('$label: a tap on the toast is swallowed by it');
          }
          await pumpFrames(tester, 140); // let it leave
        }

        await probeScreen('title');
        checked.add('title');

        // Walk bot runs until every screen kind has been probed once.
        const wanted = {
          'boon',
          'map',
          'player_turn',
          'keystone',
          'reward',
          'rest',
          'shop',
          'event',
          'run_lost',
        };
        for (var seed = 18; seed < 26 && !checked.containsAll(wanted); seed++) {
          c.startRun(
            character: 'kindler',
            seed: seed,
            boons: true,
            difficulty: 'easy',
          );
          await pumpFrames(tester, 30);
          var guard = 0;
          while (guard++ < 600) {
            final phase = c.phase ?? 'title';
            final key = phase == 'run_won' ? 'run_lost' : phase;
            if (!checked.contains(key)) {
              checked.add(key);
              await pumpFrames(tester, 40); // entrance settled
              await probeScreen('seed $seed $phase');
            }
            if (phase == 'run_lost' || phase == 'run_won') break;
            final cmd = botCmd(c.sim!);
            if (cmd == null) break;
            c.apply(cmd);
            await pumpFrames(tester, 2);
          }
        }
        // Let the entrance choreography and any toast finish.
        await pumpFrames(tester, 200);

        expect(
          checked.containsAll({'title', ...wanted}),
          isTrue,
          reason: 'the walk must reach every screen kind: $checked',
        );
        expect(failures, isEmpty, reason: failures.join('\n'));
      },
    );
  }
}
