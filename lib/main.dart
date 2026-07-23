// Emberdelve — Flutter app entry point.
//
// Routing is a pure function of the sim phase (docs/m1-contract.md §9):
//   no run            -> Title
//   map               -> Map
//   player_turn       -> Combat
//   reward            -> Combat (with reward overlay)
//   rest              -> Rest
//   run_won/run_lost  -> Summary
// On boot a non-terminal autosave resumes straight into its phase's screen.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/session.dart';
import 'ui/screens/combat_screen.dart';
import 'ui/screens/map_screen.dart';
import 'ui/screens/rest_screen.dart';
import 'ui/screens/summary_screen.dart';
import 'ui/screens/title_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final session = GameSession();
  await session.loadSaved(); // resume-on-boot (no-op without a live save)
  runApp(EmberdelveApp(session: session));
}

class EmberdelveApp extends StatelessWidget {
  const EmberdelveApp({super.key, required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emberdelve',
      debugShowCheckedModeBanner: false,
      theme: emberTheme(),
      home: GameShell(session: session),
    );
  }
}

/// Listens to the session and swaps screens as the phase changes.
class GameShell extends StatelessWidget {
  const GameShell({super.key, required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final Widget screen;
        if (!session.hasRun) {
          screen = TitleScreen(key: const ValueKey('title'), session: session);
        } else {
          screen = switch (session.phase) {
            'map' => MapScreen(key: const ValueKey('map'), session: session),
            'player_turn' ||
            'reward' =>
              CombatScreen(key: const ValueKey('combat'), session: session),
            'rest' => RestScreen(key: const ValueKey('rest'), session: session),
            'run_won' ||
            'run_lost' =>
              SummaryScreen(key: const ValueKey('summary'), session: session),
            _ => TitleScreen(key: const ValueKey('title'), session: session),
          };
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          child: screen,
        );
      },
    );
  }
}
