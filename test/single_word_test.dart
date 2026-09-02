// test/single_word_test.dart — v0.180.0 The Single Word.
//
// The hollow's temper button read 'Temper a face — two per delve' and
// wrapped to two lines at 360 and 320 (hearth_tale plates), repeating the
// count the sentence above it already states ('Two marks a delve.' / 'One
// mark left.'). The button now says only what it does, and this pins that
// it stays one line on the smallest phones while the sentence keeps the
// count in both temper states. Measured with the shipped Cinzel.
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

Widget button() => MaterialApp(
  theme: buildEmberTheme(),
  home: Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        child: SizedBox(
          width: double.infinity,
          child: EmberButton(
            'Temper a face',
            icon: Icons.auto_awesome,
            onTap: () {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(loadRealFonts);

  for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
    testWidgets('the temper button is one line at ${size.width.toInt()}', (
      tester,
    ) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(button());
      await tester.pump();
      expect(linesOf(tester, 'Temper a face'), 1);
    });
  }
}
