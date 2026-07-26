// lib/ui/screens/combat/enemy_panel.dart — part of screens.dart (see library header there).
// HUD band: enemy panel (plate, HP, statuses, tutorial help).
// Extracted from combat_screen.dart 2026-07-26 (remaining-work §7);
// mechanical, behaviour-preserving. Same library: private access is
// unchanged and no public API moved.
part of '../../screens.dart';

extension _CombatEnemyPanelBand on _CombatScreenState {
  Widget _enemyPanel(BuildContext context, _Hud h) {
    final enemy = h.enemy;
    final enemyHp = h.enemyHp;
    final compact = h.compact;
    return // Enemy header: name + HP (intent lives on the stage, over the enemy).
    RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.l,
          compact ? Space.s : Space.l,
          Space.l,
          compact ? Space.xs : Space.s,
        ),
        child: Panel(
          padding: EdgeInsets.all(compact ? Space.s : Space.m),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      enemy['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EmberText.h2.copyWith(
                        color: enemy['boss'] == true
                            ? EmberColors.kindBoss
                            : enemy['elite'] == true
                            ? EmberColors.kindElite
                            : EmberColors.textPrimary,
                      ),
                    ),
                  ),
                  // Replayable how-to-play (v0.3.10): the tutorial used to
                  // show once, ever — a tester considered REINSTALLING to
                  // see it again. This reopens the same overlay any time.
                  // Reads the input lock, so it listens to _uiTick like
                  // the rest of the input surfaces.
                  ValueListenableBuilder<int>(
                    valueListenable: _uiTick,
                    builder: (context, _, _) => Semantics(
                      label: 'How to play',
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _busy || _tutStep >= 0
                            ? null
                            : _restartTutorial,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Space.s,
                            vertical: Space.xs,
                          ),
                          child: Icon(
                            Icons.help_outline,
                            size: 20,
                            color: EmberColors.textDim,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.s),
              StatBar(
                value: enemyHp,
                max: enemy['max_hp'] as int,
                block: enemy['block'] as int? ?? 0,
                color: EmberColors.danger,
                label: 'ENEMY HP · TURN ${h.turn}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
