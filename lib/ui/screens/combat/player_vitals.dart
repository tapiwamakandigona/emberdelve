// lib/ui/screens/combat/player_vitals.dart — part of screens.dart (see library header there).
// HUD band: the player HP/block bar.
// Extracted from combat_screen.dart 2026-07-26 (remaining-work §7);
// mechanical, behaviour-preserving. Same library: private access is
// unchanged and no public API moved.
part of '../../screens.dart';

extension _CombatPlayerVitalsBand on _CombatScreenState {
  Widget _playerVitals(BuildContext context, _Hud h) {
    final player = h.player;
    return // Player HP
    RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        child: StatBar(
          value: (player['hp'] as int).clamp(0, player['max_hp'] as int),
          max: player['max_hp'] as int,
          block: player['block'] as int,
          color: EmberColors.hp,
          label: 'YOUR HP',
        ),
      ),
    );
  }
}
