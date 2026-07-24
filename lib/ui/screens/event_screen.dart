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
                // Options the sim would reject render DISABLED instead of
                // inviting a tap that only spawns a "Not enough gold" toast
                // (2026-07-24: a 0-gold peddler showed a glowing primary
                // "Buy (35 gold)" CTA). Mirrors runEventChoose's validation.
                primary: i == 0 && _legal(def.options[i].effects),
                // Icon telegraphs the option's payoff/risk at a glance
                // (wordiness pass 2026-07-24).
                icon: _optionIcon(def.options[i].effects),
                onTap: _legal(def.options[i].effects)
                    ? () =>
                        c.apply({'type': 'event_choose', 'option': i + 1})
                    : null),
          ),
        ),
      const SizedBox(height: Space.s),
    ]);
  }

  /// Same legality rules as the sim's runEventChoose: gold cost must be
  /// coverable, and lose_random_die needs a pool above the floor of 3.
  bool _legal(Map<String, Object> e) {
    final goldDelta = (e['gold'] as int?) ?? 0;
    final gold = ((c.state!['run'] as Map)['gold'] as int?) ?? 0;
    if (goldDelta < 0 && gold + goldDelta < 0) return false;
    if (e['lose_random_die'] == 1 &&
        ((c.state!['player'] as Map)['dice'] as List).length <= 3) {
      return false;
    }
    return true;
  }

  /// The dominant effect of an option, as an icon: cost (HP) beats reward so
  /// risky picks read as risky.
  IconData? _optionIcon(Map<String, Object> e) {
    if ((e['hp'] as int? ?? 0) < 0) return Icons.heart_broken;
    if (e.containsKey('lose_random_die')) return Icons.do_not_disturb_on;
    if (e.containsKey('gain_die') || e.containsKey('gain_random_die')) {
      return Icons.casino;
    }
    if (e.containsKey('gain_random_relic')) return Icons.auto_awesome;
    if (e.containsKey('heal_pct')) return Icons.healing;
    if (e.containsKey('max_hp')) return Icons.favorite;
    if (e.containsKey('gold') || e.containsKey('gold_after')) return Icons.paid;
    if (e.containsKey('embers')) return Icons.local_fire_department;
    return null; // walk away / no effect: keep the button quiet
  }
}

// ---------------------------------------------------------------------------
// Summary — death/victory ledger leads with GAINS (fair-death pillar)
// ---------------------------------------------------------------------------
