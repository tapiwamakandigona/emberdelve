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
    return // Dice tray (its call-outs are drawn by _trayCallouts, outside the
    // inert dim; in reroll mode taps pick the unassigned dice to risk —
    // assigned dice never join the selection).
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
        ],
      ),
    );
  }

  /// C0-03 + C1-02: the tray lane. Its call-outs rest in the strip between
  /// the HP bar and the dice, beside the "YOUR HP" caption — never on the HP
  /// numerals, the bar, the dice or a sprite — at >= 12 sp. The layer sits
  /// OUTSIDE the tray's inert dim (see build), so a reward read on the
  /// killing blow never fades with the dice, and it ignores pointers.
  Widget _trayCallouts(BuildContext context, _Hud h) => IgnorePointer(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.l),
      child: LayoutBuilder(
        builder: (context, box) {
          final scaler = MediaQuery.textScalerOf(context);
          _noteScaler = scaler;
          final caption = TextPainter(
            text: const TextSpan(
              text: _CombatScreenState._playerHpLabel,
              style: EmberText.micro,
            ),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final lane = TrayLane.measure(
            trayWidth: box.maxWidth,
            gapAbove: h.compact ? Space.s : Space.m,
            caption: caption.size,
            barGap: Space.xs,
            minNoteScale:
                ReadoutLanes.minNoteSp / _CombatScreenState._trayNoteSize,
          );
          caption.dispose();
          _trayLane = lane;
          // Scoped to _fxTick (see the stage layers).
          return RepaintBoundary(
            child: ValueListenableBuilder<int>(
              valueListenable: _fxTick,
              builder: (context, _, _) => Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final n in _notes.where((n) => n.lane == _NoteLane.tray))
                    if (lane.place(
                          _noteSize(
                            n.text,
                            icon: n.icon != null,
                            fontSize: _CombatScreenState._trayNoteSize,
                          ),
                          squeeze: n.squeezed,
                        )
                        case final at?)
                      Positioned(
                        // The lane's one slot, held for the note's whole life:
                        // it never jumps, and nothing else shares it.
                        key: ValueKey('tray-note-slot-${n.id}'),
                        left: at.box.left,
                        top: at.box.top,
                        width: at.box.width,
                        height: at.box.height,
                        // C4-01: on the victory banner's first frame the
                        // lane fades out (it is never under the banner).
                        child: _victoryClear(
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: TextPop(
                              key: ValueKey('note-${n.id}'),
                              text: n.text,
                              color: n.color,
                              icon: n.icon,
                              fontSize: _CombatScreenState._trayNoteSize,
                              duration: n.life,
                              rise: at.rise,
                              overshoot: at.overshoot,
                              onDone: () => _fxUpdate(() => _retire(n)),
                            ),
                          ),
                          fade: VictoryBeat.clear,
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

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
