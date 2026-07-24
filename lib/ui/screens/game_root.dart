// lib/ui/screens/game_root.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class GameRoot extends StatelessWidget {
  final GameController c;
  const GameRoot(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        // surface flash toasts after the frame
        final f = c.flash;
        if (f != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) showFlash(context, f);
            c.flash = null;
          });
        }
        final phase = c.phase;
        Widget screen;
        switch (phase) {
          case 'boon':
            screen = BoonScreen(c);
            break;
          case 'map':
            screen = MapScreen(c);
            break;
          case 'player_turn':
            screen = CombatScreen(c);
            break;
          case 'reward':
            screen = RewardScreen(c);
            break;
          case 'rest':
            screen = RestScreen(c);
            break;
          case 'shop':
            screen = ShopScreen(c);
            break;
          case 'event':
            screen = EventScreen(c);
            break;
          case 'run_won':
          case 'run_lost':
            screen = SummaryScreen(c);
            break;
          default:
            screen = TitleScreen(c);
        }
        final enemy = c.state?['enemy'] as Map?;
        final bossFight = enemy != null &&
            (enemy['boss'] == true || enemy['elite'] == true);
        // Flame-wipe smash-cut into combat; fade-through-black elsewhere
        // (visuals.md #12 — the stock cross-fade dies here).
        return Scaffold(
          body: PhaseSwitcher(
            phaseKey: phase ?? 'title',
            flameWipe: phase == 'player_turn',
            child: ScreenBackground(
              asset: Art.backgroundForPhase(phase, bossFight: bossFight),
              child: SafeArea(
                child: KeyedSubtree(
                    key: ValueKey(phase ?? 'title'), child: screen),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Title
// ---------------------------------------------------------------------------
