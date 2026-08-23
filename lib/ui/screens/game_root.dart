// lib/ui/screens/game_root.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class GameRoot extends StatefulWidget {
  final GameController c;
  const GameRoot(this.c, {super.key});

  @override
  State<GameRoot> createState() => _GameRootState();
}

class _GameRootState extends State<GameRoot> {
  GameController get c => widget.c;

  // TalkBack (v0.19.0): speak phase changes ("Map", "Combat: Ash Thrall")
  // so a screen-reader player always knows where the delve took them.
  // Announced at most once per phase transition; silent for sighted play.
  String? _spokenPhase;

  void _speakPhase(BuildContext context, String? phase) {
    if (phase == _spokenPhase) return;
    _spokenPhase = phase;
    final enemy = c.state?['enemy'] as Map?;
    final spoken = switch (phase) {
      'boon' => 'Choose a boon',
      'map' => 'The delve map',
      'player_turn' =>
        'Combat: ${(enemy?['name'] as String?) ?? 'an enemy'} '
            'with ${enemy?['hp'] ?? '?'} HP',
      'keystone' => 'Choose a keystone',
      'reward' => 'Choose a reward',
      'rest' => 'A rest site',
      'shop' => 'A shop',
      'event' => 'An event',
      'run_won' => 'Victory. The run is won',
      'run_lost' => 'The run is lost',
      _ => null,
    };
    if (spoken != null) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        spoken,
        TextDirection.ltr,
      );
    }
  }

  // Screens that scope their own rebuilds (combat) keep ONE widget instance
  // across controller notifications. Handing the framework the identical child
  // widget makes Element.updateChild short-circuit, so a sim command no longer
  // re-runs that screen's build() top to bottom — the screen's own per-field
  // listeners rebuild only the sections whose data moved.
  //
  // Every other screen is still wrapped in AnimatedBuilder(animation: c), i.e.
  // exactly the old whole-screen rebuild. Opt in per screen, after measuring.
  Widget? _scopedScreen;
  String? _scopedKey;

  Widget _scoped(String key, Widget Function() create) {
    if (_scopedKey != key || _scopedScreen == null) {
      _scopedKey = key;
      _scopedScreen = create();
    }
    return _scopedScreen!;
  }

  Widget _whole(Widget Function() create) =>
      AnimatedBuilder(animation: c, builder: (context, _) => create());

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
        _speakPhase(context, phase);
        Widget screen;
        switch (phase) {
          case 'boon':
            screen = _whole(() => BoonScreen(c));
            break;
          case 'map':
            screen = _whole(() => MapScreen(c));
            break;
          case 'player_turn':
            // Scoped screen: rebuilt by its own per-field listeners, not by
            // this builder (see [_scoped]).
            screen = _scoped('player_turn', () => CombatScreen(c));
            break;
          case 'keystone':
            screen = _whole(() => KeystoneScreen(c));
            break;
          case 'reward':
            screen = _whole(() => RewardScreen(c));
            break;
          case 'rest':
            screen = _whole(() => RestScreen(c));
            break;
          case 'shop':
            screen = _whole(() => ShopScreen(c));
            break;
          case 'event':
            screen = _whole(() => EventScreen(c));
            break;
          case 'run_won':
          case 'run_lost':
            screen = _whole(() => SummaryScreen(c));
            break;
          default:
            screen = _whole(() => TitleScreen(c));
        }
        if (phase != 'player_turn' && _scopedKey != null) {
          // Leaving a scoped screen drops the cached instance so the next
          // encounter starts from a fresh State.
          _scopedKey = null;
          _scopedScreen = null;
        }
        final enemy = c.state?['enemy'] as Map?;
        final bossFight =
            enemy != null && (enemy['boss'] == true || enemy['elite'] == true);
        // Flame-wipe smash-cut into combat; fade-through-black elsewhere
        // (visuals.md #12 — the stock cross-fade dies here).
        return Scaffold(
          body: PhaseSwitcher(
            phaseKey: phase ?? 'title',
            flameWipe: phase == 'player_turn',
            child: ScreenBackground(
              asset: Art.backgroundForPhase(phase, bossFight: bossFight),
              // v0.28.0 The Shifting Strata: the rock changes as you
              // descend (depth 0 = identity, so the title never grades).
              grade: Art.strataFilter(c.mapDepth),
              wash: Art.strataWash(c.mapDepth),
              child: SafeArea(
                child: KeyedSubtree(
                  key: ValueKey(phase ?? 'title'),
                  child: screen,
                ),
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
