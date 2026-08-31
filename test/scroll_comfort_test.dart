// test/scroll_comfort_test.dart — v0.174.0 The Honest Fold.
//
// Every scrolling surface tells the truth about the fold: a bottom fade
// while content waits below, a top fade once content is scrolled past,
// neither when everything fits. Purely visual — physics untouched.
import 'package:emberdelve/ui/theme.dart';
import 'package:emberdelve/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _fade(WidgetTester t, String key) =>
    t.widget<AnimatedOpacity>(find.byKey(ValueKey(key))).opacity;

Widget _host(Widget child) => MaterialApp(
  theme: buildEmberTheme(),
  home: Scaffold(body: Center(child: SizedBox(height: 300, child: child))),
);

void main() {
  testWidgets('long content: bottom fade on, then top fade after scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ScrollComfort(
          child: ListView(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 40, child: Text('row $i')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_fade(tester, 'scroll-fade-bottom'), 1, reason: 'more below');
    expect(_fade(tester, 'scroll-fade-top'), 0, reason: 'nothing above yet');

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(_fade(tester, 'scroll-fade-bottom'), 0, reason: 'at the end');
    expect(_fade(tester, 'scroll-fade-top'), 1, reason: 'content above now');
  });

  testWidgets('short content: no fades — nothing past the fold to signal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ScrollComfort(
          child: ListView(
            children: const [SizedBox(height: 40, child: Text('only row'))],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_fade(tester, 'scroll-fade-bottom'), 0);
    expect(_fade(tester, 'scroll-fade-top'), 0);
  });

  testWidgets('fades never intercept taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        ScrollComfort(
          child: ListView(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(
                  height: 40,
                  child: GestureDetector(
                    onTap: () => taps++,
                    child: Text('row $i'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_fade(tester, 'scroll-fade-bottom'), 1);
    await tester.tap(find.text('row 6')); // sits under the bottom fade zone
    expect(taps, 1, reason: 'IgnorePointer: the fade is visual only');
  });
}
