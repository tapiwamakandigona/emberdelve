// test/save_transfer_ui_test.dart — the Carried Ember settings panel:
// copy puts a decodable code on the clipboard, paste walks the honest
// confirm dialog into a non-destructive merge, garbage states a neutral
// fact, and every new line of copy honors the §Ethics banned-word list.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/save_transfer.dart';
import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? clipboardText; // what the fake platform clipboard holds

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return clipboardText == null ? null : {'text': clipboardText};
          }
          return null;
        });
    SaveTransfer.loadLocalHook = null;
    SaveTransfer.adoptMergedHook = null;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    SaveTransfer.loadLocalHook = null;
    SaveTransfer.adoptMergedHook = null;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: buildEmberTheme(), home: const SettingsScreen()),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('copy-save-code')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('copy puts a decodable code for the live meta on the clipboard',
      (tester) async {
    final local = MetaState(runsPlayed: 42, runsWon: 20, lifetimeEmbers: 900);
    SaveTransfer.loadLocalHook = () async => local;
    await pumpSettings(tester);

    await tester.tap(find.byKey(const ValueKey('copy-save-code')));
    await tester.pumpAndSettle();

    expect(clipboardText, isNotNull);
    final decoded = decodeSaveCode(clipboardText!);
    expect(decoded, isNotNull);
    expect(decoded!.runsPlayed, 42);
    expect(decoded.lifetimeEmbers, 900);
    expect(find.byKey(const ValueKey('transfer-line')), findsOneWidget);
  });

  testWidgets('paste -> confirm -> merge adopts the best of both sides',
      (tester) async {
    final local = MetaState(
      runsPlayed: 10,
      runsWon: 4,
      lifetimeEmbers: 200,
      unlocked: {'kindler'},
      forgeUnlocked: true,
    );
    MetaState? adopted;
    SaveTransfer.loadLocalHook = () async => local;
    SaveTransfer.adoptMergedHook = (m) async => adopted = m;
    clipboardText = encodeSaveCode(
      MetaState(
        runsPlayed: 30,
        runsWon: 12,
        lifetimeEmbers: 800,
        unlocked: {'kindler', 'warden'},
      ),
    );
    await pumpSettings(tester);

    await tester.tap(find.byKey(const ValueKey('paste-save-code')));
    await tester.pumpAndSettle();
    // The dialog states the code's facts before anything is touched.
    expect(find.byKey(const ValueKey('carry-summary')), findsOneWidget);
    expect(adopted, isNull);

    await tester.tap(find.byKey(const ValueKey('carry-merge')));
    await tester.pumpAndSettle();

    expect(adopted, isNotNull);
    expect(adopted!.runsPlayed, 30, reason: 'MAX counters');
    expect(adopted!.unlockedCharacters, containsAll({'kindler', 'warden'}));
    expect(adopted!.forgeUnlocked, isTrue,
        reason: 'a pasted code never revokes the local unlock');
  });

  testWidgets('keep-as-is backs out without adopting anything',
      (tester) async {
    MetaState? adopted;
    SaveTransfer.loadLocalHook = () async => MetaState();
    SaveTransfer.adoptMergedHook = (m) async => adopted = m;
    clipboardText = encodeSaveCode(MetaState(runsPlayed: 5));
    await pumpSettings(tester);

    await tester.tap(find.byKey(const ValueKey('paste-save-code')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep as is'));
    await tester.pumpAndSettle();

    expect(adopted, isNull);
  });

  testWidgets('garbage on the clipboard reads as a neutral fact',
      (tester) async {
    SaveTransfer.loadLocalHook = () async => MetaState();
    SaveTransfer.adoptMergedHook = (m) async {};
    clipboardText = 'definitely not a save code';
    await pumpSettings(tester);

    await tester.tap(find.byKey(const ValueKey('paste-save-code')));
    await tester.pumpAndSettle();

    expect(
      find.text('The clipboard does not hold a save code.'),
      findsOneWidget,
    );
  });

  testWidgets('panel copy honors the banned-word list', (tester) async {
    SaveTransfer.loadLocalHook = () async => MetaState();
    await pumpSettings(tester);
    const banned = [
      'streak', 'expire', 'hurry', 'miss out', 'last chance', 'beat me',
      'bet you', 'only today', "can't", 'loser', //
    ];
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase())
        .toList();
    for (final word in banned) {
      for (final t in texts) {
        expect(t.contains(word), isFalse,
            reason: 'banned word "$word" in settings copy: "$t"');
      }
    }
  });
}
