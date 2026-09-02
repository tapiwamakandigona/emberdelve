// test/kept_line_test.dart — v0.180.0 The Kept Line.
//
// On 320 px phones a full-width EmberButton with a leading glyph and a long
// label wrapped to two lines: the hollow's 'Rest — heal 13 HP (10 to 23)'
// and the Forge's 'Kindle the Forge — US$4.99' (Play formats the price
// per locale; 'US$4.99' and '4,99 US$' are real). Past twenty characters on
// a narrow screen the glyph steps aside so the words keep one line; short
// labels keep their glyph everywhere. Measured with the shipped Cinzel.
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

int linesOf(WidgetTester tester, String label) {
  final p = tester.renderObject<RenderParagraph>(find.text(label));
  final one = TextPainter(
    text: p.text,
    textDirection: TextDirection.ltr,
    textScaler: p.textScaler,
  )..layout();
  return (p.size.height / one.height).round();
}

Widget button(String label) => MaterialApp(
  theme: buildEmberTheme(),
  home: Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        child: SizedBox(
          width: double.infinity,
          child: EmberButton(
            label,
            icon: Icons.local_fire_department,
            onTap: () {},
          ),
        ),
      ),
    ),
  ),
);

Future<void> at(WidgetTester tester, Size size, String label) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(button(label));
  await tester.pump();
}

const long = [
  'Rest \u2014 heal 13 HP (10\u00A0to\u00A023)',
  'Kindle the Forge \u2014 US\$4.99',
  'Kindle the Forge \u2014 4,99\u00A0US\$',
];

void main() {
  setUpAll(loadRealFonts);

  for (final label in long) {
    testWidgets('"$label" keeps one line at 320, glyph aside', (tester) async {
      await at(tester, const Size(320, 568), label);
      expect(linesOf(tester, label), 1);
      expect(find.byIcon(Icons.local_fire_department), findsNothing);
    });

    testWidgets('"$label" keeps one line at 360', (tester) async {
      await at(tester, const Size(360, 640), label);
      expect(linesOf(tester, label), 1);
    });
  }

  testWidgets('the hollow keeps its glyph at 360', (tester) async {
    await at(tester, const Size(360, 640), long.first);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
  });

  testWidgets('short labels keep their glyph at 320', (tester) async {
    await at(tester, const Size(320, 568), 'Skip \u2014 delve unaided');
    expect(linesOf(tester, 'Skip \u2014 delve unaided'), 1);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
  });
}
