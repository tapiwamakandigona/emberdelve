// lib/ui/screens/combat/tray.dart — part of screens.dart (see library header there).
// HUD band: the dice tray and its scale-to-fit chips.
// Extracted from combat_screen.dart 2026-07-26 (remaining-work §7);
// mechanical, behaviour-preserving. Same library: private access is
// unchanged and no public API moved.
part of '../../screens.dart';

extension _CombatTrayBand on _CombatScreenState {
  Widget _traySection(BuildContext context, _Hud h) {
    final dice0 = h.dice0;
    final rolled = h.rolled;
    final assigned = h.assigned;
    final maxed = h.maxed;
    final chipScale = h.chipScale;
    final trayViewH = h.trayViewH;
    final trayScrolls = h.trayScrolls;
    final hiddenDice = h.hiddenDice;
    return // Dice tray (combo call-outs pop over it; in reroll mode taps pick the
    // unassigned dice to risk — assigned dice never join the selection).
    // Bounded + scrollable: a fat late-run pool can wrap to many rows, so
    // past ~2 rows the tray scrolls instead of squeezing the stage out and
    // overflowing the column on short screens.
    Padding(
      key: TourAnchors.of(TourBeats.pick),
      padding: const EdgeInsets.symmetric(horizontal: Space.l),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: trayViewH),
                child: SingleChildScrollView(
                  // LFP-1: flying dice must be able to draw outside the
                  // tray while inbound; only clip when the tray truly
                  // scrolls (then folded rows must stay hidden).
                  clipBehavior: trayScrolls ? Clip.hardEdge : Clip.none,
                  // Selection rides the dice band (see [_wireBands]), so
                  // tapping a die repaints the tray alone.
                  child: Wrap(
                    spacing: Space.s,
                    runSpacing: Space.s,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 1; i <= dice0.length; i++)
                        KeyedSubtree(
                          // LFP-2a: slot geometry for the assign ghost.
                          key: _chipKeys.putIfAbsent(i, GlobalKey.new),
                          child: _trayChip(
                            chipScale,
                            DieChip(
                              dice0[i - 1],
                              skin: widget.c.activeRunSkin,
                              run: widget.c.state?['run'] as Map?,
                              value: rolled != null ? rolled[i - 1] : null,
                              assigned: assigned['$i'] != null,
                              selected: _rerollMode
                                  ? _rerollSel.contains(i)
                                  : selected == i,
                              maxed: maxed != null && maxed[i - 1],
                              contribution: _assignedValue[i],
                              flight: true, // LFP-1: thrown, not refreshed
                              onSettle: Haptics.light, // LFP-1b rattle
                              rollToken: _rollGen * 4096 + (_reflyGen[i] ?? 0),
                              // 50 ms cascade so the tumble reads left-to-right.
                              tumbleDelayMs: (i - 1) * 50,
                              // v0.3.1 F1/F2: selection is pure UI state, so dice
                              // stay tappable during choreography; a spent die
                              // answers with an explicit call-out instead of
                              // silently eating the tap.
                              onTap: rolled == null
                                  ? null
                                  : assigned['$i'] != null
                                  ? () => _note(
                                      'ALREADY ASSIGNED',
                                      color: EmberColors.textDim,
                                      icon: Icons.do_not_disturb_alt,
                                    )
                                  : _rerollMode
                                  ? () => _ui(
                                      () => _rerollSel.contains(i)
                                          ? _rerollSel.remove(i)
                                          : _rerollSel.add(i),
                                    )
                                  : () {
                                      Haptics.light();
                                      _ui(
                                        () =>
                                            selected = selected == i ? null : i,
                                      );
                                      if (selected != null) {
                                        widget.c.tourMoment(
                                          TourMoment.diePicked,
                                        );
                                      }
                                    },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Fold indicator: an explicit "+N" pill under the last whole
              // row — replaces the fade+chevron that read as a glitch over
              // half-cut dice (owner feedback 2026-07-24).
              if (trayScrolls)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Semantics(
                    label: '$hiddenDice more dice below, scroll the tray',
                    child: Container(
                      height: _CombatScreenState._trayPeek - Space.xs,
                      padding: const EdgeInsets.symmetric(horizontal: Space.m),
                      decoration: BoxDecoration(
                        color: EmberColors.raised,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: EmberColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+$hiddenDice',
                            style: EmberText.label.copyWith(
                              color: EmberColors.textPrimary,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 14,
                            color: EmberColors.textDim,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Tray call-outs, scoped to _fxTick (see the stage layers).
          Positioned.fill(
            child: RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: _fxTick,
                builder: (context, _, _) => Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    for (final (idx, n)
                        in _notes.where((n) => !n.onEnemy).toList().indexed)
                      Positioned(
                        top: -30.0 - idx * 24,
                        child: TextPop(
                          key: ValueKey('note-${n.id}'),
                          text: n.text,
                          color: n.color,
                          icon: n.icon,
                          fontSize: 16,
                          duration: n.life,
                          onDone: () {
                            _fxUpdate(() => _notes.remove(n));
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Chips shrink together once the pool outgrows the tray's row budget so
  /// more dice stay visible per row (FittedBox keeps taps + semantics).
  Widget _trayChip(double scale, DieChip chip) => scale == 1.0
      ? chip
      : SizedBox(
          width: 64 * scale,
          height: 80 * scale,
          child: FittedBox(fit: BoxFit.contain, child: chip),
        );
}
