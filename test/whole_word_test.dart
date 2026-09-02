// test/whole_word_test.dart — v0.180.0 The Whole Word.
//
// At 320 px the ATTACK / BLOCK pair shares one row: each button gets 138 px,
// and with xl side padding Cinzel broke "ATTACK" into "ATTAC / K" (seen on
// the fresh-profile plates at 320×568). Narrow buttons keep l padding so a
// one-word label stays one line. Measured with the shipped fonts.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';

Future<void> loadRealFonts() async {
  Future<ByteData> asset(String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync());
  final cinzel = FontLoader('Cinzel')
    ..addFont(asset('assets/fonts/Cinzel-Variable.ttf'));
  await cinzel.load();
}

/// Line count of a laid-out label: its height over one line's height.
int linesOf(WidgetTester tester, String label) {
  final p = tester.renderObject<RenderParagraph>(find.text(label));
  final one = TextPainter(
    text: p.text,
    textDirection: TextDirection.ltr,
    textScaler: p.textScaler,
  )..layout();
  return (p.size.height / one.height).round();
}

Widget pair() => MaterialApp(
  theme: buildEmberTheme(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          child: Row(
            children: [
              Expanded(
                child: EmberButton(
                  'Attack',
                  icon: Icons.gps_fixed,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: EmberButton('Block', icon: Icons.shield, onTap: () {}),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(loadRealFonts);

  testWidgets('ATTACK and BLOCK stay whole words at 320', (tester) async {
    tester.view.physicalSize = const Size(320, 568) * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(pair());
    await tester.pump();
    expect(linesOf(tester, 'Attack'), 1);
    expect(linesOf(tester, 'Block'), 1);
  });

  testWidgets('and at 360, where they always fit', (tester) async {
    tester.view.physicalSize = const Size(360, 800) * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(pair());
    await tester.pump();
    expect(linesOf(tester, 'Attack'), 1);
    expect(linesOf(tester, 'Block'), 1);
  });
}
