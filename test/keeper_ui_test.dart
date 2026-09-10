import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/keeper.dart';
import 'package:emberdelve/ui/keeper.dart';
import 'package:emberdelve/ui/screens.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<KeeperService> _service({
  bool owned = true,
  Map<String, dynamic>? data,
}) async {
  final service = KeeperService(
    alreadyOwned: () => owned,
    loadData: () async => data ?? {},
    saveData: (_) async {},
  );
  KeeperService.instance = service;
  await service.load();
  return service;
}

Widget _surface({Widget child = const KeeperTitle()}) => MaterialApp(
  theme: buildEmberTheme(),
  home: Scaffold(
    body: SafeArea(child: SingleChildScrollView(child: child)),
  ),
);

void main() {
  tearDown(() {
    KeeperService.instance?.dispose();
    KeeperService.instance = null;
  });

  testWidgets('legacy owner is thanked inline once; skip never opens a modal', (
    tester,
  ) async {
    final service = await _service();
    await tester.pumpWidget(_surface());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('keeper-invitation')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(service.profile.invitationSeen, isTrue);
    await tester.tap(find.byKey(const ValueKey('keeper-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('keeper-invitation')), findsNothing);
    expect(service.profile.showName, isFalse);
    expect(service.profile.showCrest, isFalse);
    await tester.pumpWidget(_surface(child: const SizedBox()));
    await tester.pumpWidget(_surface());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('keeper-invitation')), findsNothing);
  });

  testWidgets(
    'free players retain the original subtitle, no request or crest',
    (tester) async {
      await _service(owned: false);
      await tester.pumpWidget(_surface());
      await tester.pumpAndSettle();
      expect(find.text('A dice-builder delve into the dark'), findsOneWidget);
      expect(find.byKey(const ValueKey('keeper-invitation')), findsNothing);
      expect(find.byType(KeeperCrest), findsNothing);
    },
  );

  testWidgets('personalise, edit, hide and remove work from visible controls', (
    tester,
  ) async {
    final service = await _service();
    await tester.pumpWidget(
      _surface(
        child: const Column(children: [KeeperTitle(), KeeperSettings()]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keeper-personalise')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('keeper-name')), 'Tariro');
    await tester.tap(find.byKey(const ValueKey('keeper-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('The flame burns brighter thanks to Tariro.'),
      findsOneWidget,
    );
    expect(find.byType(KeeperCrest), findsOneWidget);
    expect(service.profile.name, 'Tariro');
    await tester.tap(find.byKey(const ValueKey('keeper-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keeper-show-name')));
    await tester.tap(find.byKey(const ValueKey('keeper-show-crest')));
    await tester.tap(find.byKey(const ValueKey('keeper-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('keeper-inscription')), findsNothing);
    expect(service.profile.name, 'Tariro');
    await tester.tap(find.byKey(const ValueKey('keeper-remove')));
    await tester.pumpAndSettle();
    expect(service.profile.name, isEmpty);
    expect(service.needsInvitation, isFalse);
  });

  testWidgets('no name required; player can choose only the crest', (
    tester,
  ) async {
    await _service();
    await tester.pumpWidget(_surface());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keeper-personalise')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('keeper-save')));
    await tester.pumpAndSettle();
    expect(find.text('Keeper of the Flame'), findsOneWidget);
    expect(find.byType(KeeperCrest), findsOneWidget);
  });

  testWidgets('active run never presents the title thank-you', (tester) async {
    await _service();
    final c = GameController();
    c.meta.forgeUnlocked = true;
    c.startRun(seed: 421, boons: true);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: GameRoot(c)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.phase, isNotNull);
    expect(find.byType(KeeperTitle), findsNothing);
    expect(find.byKey(const ValueKey('keeper-invitation')), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
    '320px phone and large text retain readable, scrollable controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _service();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildEmberTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(children: [KeeperTitle(), KeeperSettings()]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('keeper-personalise')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('keeper-name')));
      await tester.enterText(
        find.byKey(const ValueKey('keeper-name')),
        'Tapiwa & Tariro',
      );
      await tester.tap(find.byKey(const ValueKey('keeper-save')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Tapiwa & Tariro'), findsOneWidget);
    },
  );

  testWidgets('static crest adds no timer or repaint animation', (
    tester,
  ) async {
    final service = await _service(
      data: {
        'invitationSeen': true,
        'name': 'Tariro',
        'showName': true,
        'showCrest': true,
      },
    );
    await tester.pumpWidget(_surface());
    await tester.pumpAndSettle();
    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(KeeperCrest),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;
    expect(painter.shouldRepaint(painter), isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    expect(service.needsInvitation, isFalse);
  });
}
