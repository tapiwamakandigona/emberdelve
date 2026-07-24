// lib/ui/screens/event_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class EventScreen extends StatelessWidget {
  final GameController c;
  const EventScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    // Same stale-frame guard as ShopScreen: event is null right after
    // event_choose while the cross-fade is still showing this screen.
    final eventId = c.state?['event'] as String?;
    if (eventId == null) return const SizedBox.shrink();
    final def = eventDef(eventId);
    return Column(children: [
      _TopBar(c),
      const SizedBox(height: Space.xl),
      // Long event prose scrolls on short screens; the choice buttons stay
      // pinned in the thumb zone below.
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          child: Column(children: [
            Image.asset(Art.eventIcon(def.id),
                width: 96, height: 96, filterQuality: FilterQuality.medium),
            const SizedBox(height: Space.l),
            Text(def.name, style: EmberText.h1, textAlign: TextAlign.center),
            const SizedBox(height: Space.m),
            Text(def.text, style: EmberText.body, textAlign: TextAlign.center),
          ]),
        ),
      ),
      const SizedBox(height: Space.m),
      for (var i = 0; i < def.options.length; i++)
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.m),
          child: SizedBox(
            width: double.infinity,
            child: EmberButton(def.options[i].label,
                primary: i == 0,
                onTap: () =>
                    c.apply({'type': 'event_choose', 'option': i + 1})),
          ),
        ),
      const SizedBox(height: Space.s),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Summary — death/victory ledger leads with GAINS (fair-death pillar)
// ---------------------------------------------------------------------------
