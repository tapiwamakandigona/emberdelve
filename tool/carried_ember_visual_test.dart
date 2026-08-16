// ignore_for_file: invalid_use_of_visible_for_testing_member
// tool/carried_ember_visual_test.dart — manual visual-critique plates for the
// v0.24.0 "Carried Ember" settings panel. Not part of CI.
//
//   flutter test tool/carried_ember_visual_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader, SystemChannels;
import 'package:emberdelve/meta/meta.dart';
import 'package:emberdelve/meta/save_transfer.dart';
import 'package:emberdelve/ui/settings_screen.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const outDir = 'build/carried_ember_visual';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync());
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  final inter = FontLoader('Inter')
    ..addFont(asset('assets/fonts/Inter-Regular.ttf'));
  await cinzel.load();
  await inter.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final f = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (f.existsSync()) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      await icons.load();
    }
  }
}

Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.binding.runAsync(
    () => boundary.toImage(pixelRatio: 2),
  );
  final bytes = await tester.binding.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  File('$outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('carried ember plates: panel + confirm dialog', (tester) async {
    await tester.binding.runAsync(loadRealFonts);
    SaveTransfer.loadLocalHook = () async => MetaState(
      runsPlayed: 187,
      runsWon: 96,
      lifetimeEmbers: 9034,
      unlocked: {'kindler', 'warden', 'gambler', 'ascetic'},
    );
    SaveTransfer.adoptMergedHook = (m) async {};
    addTearDown(() {
      SaveTransfer.loadLocalHook = null;
      SaveTransfer.adoptMergedHook = null;
    });

    for (final (name, logical, scale) in [
      ('settings_panel_360x640', const Size(360, 640), 1.0),
      ('settings_panel_320x568_1p3x', const Size(320, 568), 1.3),
    ]) {
      tester.view.physicalSize = logical * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildEmberTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: logical,
                textScaler: TextScaler.linear(scale),
              ),
              child: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('carry-ember-panel')),
        200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 200,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await shoot(tester, key, name);

      // Dialog plate: paste flow with a real code on the fake clipboard.
      if (scale == 1.0) {
        final code = encodeSaveCode(MetaState(
          runsPlayed: 42,
          runsWon: 20,
          lifetimeEmbers: 1400,
          unlocked: {'kindler', 'warden'},
        ));
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async =>
              call.method == 'Clipboard.getData' ? {'text': code} : null,
        );
        await tester.tap(find.byKey(const ValueKey('paste-save-code')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('carry-summary')),
          findsOneWidget,
          reason: 'dialog must be on screen before the plate is shot',
        );
        await shoot(tester, key, 'confirm_dialog_360x640');
        await tester.tap(find.text('Keep as is'));
        await tester.pumpAndSettle();
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
