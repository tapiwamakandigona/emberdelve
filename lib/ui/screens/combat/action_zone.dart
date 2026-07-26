// lib/ui/screens/combat/action_zone.dart — part of screens.dart (see library header there).
// HUD band: the action zone — verb buttons, reroll controls, end turn.
// Extracted from combat_screen.dart 2026-07-26 (remaining-work §7);
// mechanical, behaviour-preserving. Same library: private access is
// unchanged and no public API moved.
part of '../../screens.dart';

extension _CombatActionZoneBand on _CombatScreenState {
  Widget _actionZone(BuildContext context, _Hud h) {
    final c = widget.c;
    final compact = h.compact;
    final rolled = h.rolled;
    final rerolls = h.rerolls;
    final riskyUsed = h.riskyUsed;
    final freeReroll = h.freeReroll;
    return // Action zone (thumb reach)
    Padding(
      padding: EdgeInsets.fromLTRB(
        Space.l,
        0,
        Space.l,
        compact ? Space.s : Space.l,
      ),
      // The action zone reads this turn's roll plus pure input state
      // (selection, the busy lock, reroll mode, the verb pulses) — the dice
      // band — so it never drags the stage or the HUD along.
      child: RepaintBoundary(
        child: rolled == null
            ? SizedBox(
                width: double.infinity,
                child: EmberButton(
                  'Roll',
                  primary: true,
                  dense: compact,
                  icon: Icons.casino,
                  onTap: _busy
                      ? null
                      : () {
                          Haptics.light();
                          _ui(() {
                            selected = null;
                            _assignedValue.clear(); // fresh turn (LFP-2c)
                            _reflyGen.clear(); // fresh throw set (LFP-1c)
                            _rollGen++; // trigger the dice throw cascade
                          });
                          final events = c.apply({'type': 'roll'});
                          // Combo call-outs land after the tumble reads.
                          Future.delayed(const Duration(milliseconds: 550), () {
                            if (mounted) _announceCombos(events);
                          });
                        },
                ),
              )
            : _rerollMode
            // Risky-reroll confirm: pick unassigned dice, then commit.
            ? Column(
                children: [
                  Text(
                    freeReroll
                        ? 'Pick dice to reroll — FREE this turn'
                        // LFP-6b: "each lands −1 pip" read as "−1 from the
                        // CURRENT face"; the actual rule is reroll first,
                        // THEN subtract 1 (a rolled 1 can come back higher).
                        : 'Pick dice to reroll — new face −1 pip',
                    style: EmberText.micro.copyWith(
                      color: freeReroll
                          ? EmberColors.success
                          : EmberColors.textDim,
                    ),
                  ),
                  const SizedBox(height: Space.s),
                  Row(
                    children: [
                      Expanded(
                        child: EmberButton(
                          'Cancel',
                          ghost: true,
                          dense: compact,
                          onTap: () => _ui(() {
                            _rerollMode = false;
                            _rerollSel.clear();
                          }),
                        ),
                      ),
                      const SizedBox(width: Space.m),
                      Expanded(
                        child: EmberButton(
                          'Reroll (${_rerollSel.length})',
                          primary: true,
                          dense: compact,
                          icon: Icons.casino,
                          onTap: _rerollSel.isNotEmpty && !_busy
                              ? _doRiskyReroll
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      // Enabled during choreography too: taps land in the
                      // one-slot queue instead of being dropped (F2).
                      Expanded(
                        child: _Pulse(
                          token: _attackPulse,
                          child: EmberButton(
                            'Attack',
                            key: _attackKey,
                            dense: compact,
                            icon: Icons.gps_fixed,
                            onTap: selected != null ? _attack : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.m),
                      Expanded(
                        child: _Pulse(
                          token: _blockPulse,
                          child: EmberButton(
                            'Block',
                            key: _blockKey,
                            dense: compact,
                            icon: Icons.shield,
                            onTap: selected != null ? _block : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? Space.s : Space.m),
                  Row(
                    children: [
                      if (rerolls > 0)
                        Expanded(
                          child: EmberButton(
                            'Reroll ($rerolls)',
                            dense: compact,
                            icon: Icons.replay,
                            onTap: selected != null && !_busy
                                ? () {
                                    final die = selected!;
                                    final events = c.apply({
                                      'type': 'reroll',
                                      'die': die,
                                    });
                                    _ui(() {
                                      // LFP-1c: the rerolled die re-flies
                                      // (charge rerolls used to not even
                                      // retumble).
                                      if (_find(events, 'reroll_used') !=
                                          null) {
                                        _reflyGen[die] =
                                            (_reflyGen[die] ?? 0) + 1;
                                      }
                                    });
                                    // A charge reroll re-detects combos
                                    // (m4 §3) — announce them like the
                                    // roll/risky paths do.
                                    _announceCombos(events);
                                  }
                                : null,
                          ),
                        ),
                      if (rerolls > 0) const SizedBox(width: Space.m),
                      // Risky reroll (m4 contract §1): once per turn, −1 pip
                      // per rerolled die — waived after a straight (FREE).
                      Expanded(
                        child: EmberButton(
                          riskyUsed
                              ? 'Reroll spent'
                              : freeReroll
                              ? 'Risky reroll · FREE'
                              : 'Risky reroll · new face −1',
                          dense: compact,
                          icon: Icons.casino,
                          onTap: riskyUsed || _busy
                              ? null
                              : () => _ui(() {
                                  _rerollMode = true;
                                  _rerollSel.clear();
                                  selected = null;
                                }),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? Space.s : Space.m),
                  SizedBox(
                    width: double.infinity,
                    child: EmberButton(
                      'End turn',
                      primary: true,
                      dense: compact,
                      onTap: _endTurn,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
