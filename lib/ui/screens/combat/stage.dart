// lib/ui/screens/combat/stage.dart — part of screens.dart (see library header there).
// HUD band: the sprite stage — hero vs enemy, lunges, fx overlays.
// Extracted from combat_screen.dart 2026-07-26 (remaining-work §7);
// mechanical, behaviour-preserving. Same library: private access is
// unchanged and no public API moved.
part of '../../screens.dart';

extension _CombatStageBand on _CombatScreenState {
  Widget _stageSection(BuildContext context, _Hud h) {
    final enemy = h.enemy;
    final intent = h.intent;
    final compact = h.compact;
    return // The stage: hero (left) vs enemy (right), animated sprite loops.
    // LFP-2a: while a die is selected, the stage shows what assigning it
    // will actually resolve for — modifiers, combos and relics included —
    // so the number is on screen BEFORE the tap, not discovered on the
    // HP bar afterwards.
    RepaintBoundary(
      child: _stage(
        enemy,
        intent,
        compact: compact,
        identity: buildIdentity(h.dice0),
        // Evaluated inside the preview's own ValueListenableBuilder so
        // selecting a die repaints the badge, not the whole stage.
        preview: () {
          // Read LIVE state, not this section's snapshot: the stage does
          // not listen to the dice tick, so a captured `rolled` would go
          // stale the moment the pool is rerolled.
          final live = _hud(context);
          if (live == null ||
              selected == null ||
              live.rolled == null ||
              _rerollMode) {
            return null;
          }
          final a = _assignPreview(
            live.player,
            live.enemy,
            selected!,
            'attack',
          );
          final b = _assignPreview(live.player, live.enemy, selected!, 'block');
          return [
            if (a >= 0) 'ATTACK +$a',
            if (b >= 0) 'BLOCK +$b',
          ].join('  ·  ');
        },
      ),
    );
  }

  /// Hero vs enemy, bottom-aligned on a grounded floor plane (shadow
  /// ellipses); lunges slide the combatant toward the other side, knockback
  /// nudges away, deaths dissolve into embers. Damage numbers pop over the
  /// stage; the enemy's next intent floats above it as an icon badge.
  Widget _stage(
    Map enemy,
    Map intent, {
    bool compact = false,
    required RunBuildIdentity identity,
    required String? Function() preview,
  }) {
    final enemyId = enemy['id'] as String? ?? '';
    final big = enemy['boss'] == true || enemy['elite'] == true;
    final heroH = compact ? 72.0 : 104.0;
    final enemyH = compact ? (big ? 96.0 : 72.0) : (big ? 128.0 : 96.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      // Clip.none so sprites/badges can animate past their own boxes, but the
      // intent badge's lift is clamped to the stage's real headroom below —
      // on a squeezed stage the old fixed -44 pushed it clear out of the
      // stage and over the enemy HP bar (owner screenshot 2026-07-24).
      child: LayoutBuilder(
        builder: (context, box) {
          // Space above the enemy sprite's top edge inside the stage (the
          // combatants row is pinned to the stage floor below). A negative
          // lift pushes the badge DOWN onto the sprite when the stage is
          // shorter than the sprite itself — never up over the HP panel.
          final headroom = box.maxHeight - Space.s - enemyH;
          final badgeLift = headroom.isFinite ? math.min(44.0, headroom) : 44.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Dimensional stage v1: one static painter turns the empty
              // middle band into a shallow cavern diorama — far arch,
              // floor plane, fissures and foreground rock. No ticker, blur,
              // saveLayer or binary asset: idle combat keeps its two tiny
              // sprite-painter repaints/frame.
              Positioned.fill(
                child: RepaintBoundary(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CombatDioramaPainter(
                        boss: enemy['boss'] == true,
                        elite: enemy['elite'] == true,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s),
                      // Scoped to _choreoTick: the swing rebuilds the delver,
                      // not the screen. RepaintBoundary keeps the lunge's
                      // transform from dirtying the rest of the stage.
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _choreoTick,
                          builder: (context, _, _) => _combatant(
                            sprite: SpriteView(
                              _characterId,
                              key: ValueKey('hero-$_characterId'),
                              height: heroH,
                              bob: true, // LFP-4a: the stage always breathes
                              // v0.27.0: the delver wears their dye into
                              // the fight; enemies are never tinted.
                              dye: Art.dyeFilter(widget.c.meta.activeDye),
                            ),
                            spriteHeight: heroH,
                            lungeToward: 1,
                            lunge: _playerLunge,
                            knock: _playerKnock,
                            flash: _playerFlash,
                            dying: _playerDying,
                            squash: _playerSquash,
                            // The delver's signature weapon, finally visible:
                            // idles in hand, pulls back on the squash, swings
                            // with the lunge.
                            weapon: WeaponView(
                              _characterId,
                              // Keep state across pool evolution; changing the
                              // build should morph the existing weapon, not
                              // restart its choreography controller.
                              key: const ValueKey('combat-weapon'),
                              height: heroH,
                              phase: _weaponPhase,
                              // Die -> weapon causality made visible: the
                              // selected die's pips heat the blade before the
                              // swing.
                              charge: _weaponCharge,
                              // The weapon's edge/profile now reflects the
                              // pool forged so far (presentation only).
                              identity: identity,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          // Scoped to _choreoTick (see the delver above).
                          RepaintBoundary(
                            child: ValueListenableBuilder<int>(
                              valueListenable: _choreoTick,
                              builder: (context, _, _) => _combatant(
                                sprite: SpriteView(
                                  enemyId,
                                  key: ValueKey('enemy-$enemyId'),
                                  height: enemyH,
                                  flipX: true,
                                  bob: true, // LFP-4a
                                  // LFP-4b: slow lean while an attack is
                                  // telegraphed — the badge gets body language.
                                  sway:
                                      intent['kind'] == 'attack' ||
                                      intent['kind'] == 'attack_block' ||
                                      // v0.47.0: a wind-up has body language.
                                      intent['kind'] == 'charge',
                                ),
                                spriteHeight: enemyH,
                                // Slight depth scale: the enemy stands a step
                                // closer.
                                depthScale: big ? 1.02 : 1.06,
                                lungeToward: -1,
                                lunge: _enemyLunge,
                                knock: _enemyKnock,
                                flash: _enemyFlash,
                                dying: _enemyDying,
                                squash: _enemySquash,
                                windup: true,
                              ),
                            ),
                          ),
                          // Intent as an icon badge floating above the enemy
                          // (overlaid, so it never adds layout height). The lift
                          // is clamped so the badge never escapes the stage upward.
                          //
                          // LFP-3a: the badge owns this slot ALONE. Burn stacks
                          // used to share its row — "🛡13 🔥3" read as one intent
                          // ("it will shield 13 and burn me for 3"), misread live
                          // in the plan playtest. Status now renders on the body
                          // below, in a visibly different chip style.
                          Positioned(
                            top: -badgeLift,
                            // v0.47.0 plate critique: the badge used to center
                            // on the enemy box (sprite width), so any 2-chip
                            // badge (attack_block, charge) escaped the screen's
                            // right edge on 320px @1.3x text. Anchoring its
                            // RIGHT edge Space.s inside the screen (the stack
                            // sits Space.xl from it) keeps every width legible;
                            // at 360px this lands within a few px of the old
                            // centered position.
                            right: -(Space.xl - Space.s),
                            child: KeyedSubtree(
                              key: TourAnchors.of(TourBeats.intent),
                              child: _IntentBadge(
                                intent,
                                onLongPress: () => _explainIntent(intent),
                              ),
                            ),
                          ),
                          // LFP-3a: status stacks live ON the enemy sprite —
                          // what it is suffering, not what it will do. Small
                          // sprite-hugging pill, deliberately unlike the
                          // squared intent badge.
                          if ((enemy['burn'] as int? ?? 0) > 0)
                            Positioned(
                              bottom: -4,
                              right: -14,
                              child: _StatusChip(
                                icon: Icons.local_fire_department,
                                color: EmberColors.ember,
                                value: enemy['burn'] as int,
                                semantics:
                                    'Burning, ${enemy['burn']} stacks. Long press to explain.',
                                onLongPress: () =>
                                    _explainBurn(enemy['burn'] as int),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // LFP-2a: assignment preview — floats at the stage floor
              // between the combatants (no layout height, no button-label
              // change, so the play harness and height budgets are safe).
              Positioned(
                left: 0,
                right: 0,
                bottom: Space.s,
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _uiTick,
                      builder: (context, _, _) {
                        final text = preview();
                        if (text == null || text.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.m,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: EmberColors.raised.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: EmberColors.line),
                            ),
                            child: Text(
                              text,
                              style: EmberText.micro.copyWith(
                                color: EmberColors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Transient overlay layers, scoped to _fxTick: a damage pop
              // or a call-out spawning/expiring rebuilds THIS stack only —
              // it used to setState the whole 1000-line screen build.
              Positioned.fill(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _fxTick,
                    builder: (context, _, _) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Enemy-anchored call-outs: burn ticks, exact-kill, overkill.
                        for (final (idx, n)
                            in _notes.where((n) => n.onEnemy).toList().indexed)
                          Positioned(
                            right: 12,
                            bottom: 150.0 + idx * 24,
                            child: TextPop(
                              key: ValueKey('note-${n.id}'),
                              text: n.text,
                              color: n.color,
                              icon: n.icon,
                              fontSize: 15,
                              duration: n.life,
                              onDone: () {
                                _fxUpdate(() => _notes.remove(n));
                              },
                            ),
                          ),
                        // Contact FX: weapon smear / claw rake / guard arc over the victim.
                        for (final fx in _fx)
                          Positioned(
                            left: fx.onPlayer ? 0 : null,
                            right: fx.onPlayer ? null : 0,
                            bottom: Space.s,
                            width: (fx.onPlayer ? heroH : enemyH) * 1.35,
                            height: (fx.onPlayer ? heroH : enemyH) * 1.35,
                            child: fx.kind == _FxKind.guard
                                ? GuardFlash(
                                    key: ValueKey('fx-${fx.id}'),
                                    facing: fx.onPlayer ? 1 : -1,
                                    onDone: () {
                                      _fxUpdate(() => _fx.remove(fx));
                                    },
                                  )
                                : ImpactSlash(
                                    key: ValueKey('fx-${fx.id}'),
                                    claws: fx.kind == _FxKind.claws,
                                    color: fx.color,
                                    onDone: () {
                                      _fxUpdate(() => _fx.remove(fx));
                                    },
                                  ),
                          ),
                        // Floating damage numbers (player pops left, enemy pops right).
                        for (final p in _pops)
                          Positioned(
                            left: p.onPlayer ? 24 : null,
                            right: p.onPlayer ? null : 24,
                            bottom: 120,
                            child: DamagePop(
                              key: ValueKey('pop-${p.id}'),
                              amount: p.amount,
                              blocked: p.blocked,
                              onPlayer: p.onPlayer,
                              onDone: () {
                                _fxUpdate(() => _pops.remove(p));
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _combatant({
    required Widget sprite,
    required double spriteHeight,
    required int lungeToward, // +1 lunges right, -1 lunges left
    required bool lunge,
    required bool knock,
    required bool flash,
    required bool dying,
    required bool squash,
    // Wind-up telegraph (enemy only): lean away + darken during the squash
    // so the incoming strike reads in the body, not just the intent badge.
    bool windup = false,
    double depthScale = 1.0,
    Widget? weapon,
  }) {
    Widget w = sprite;
    // Grounding: soft shadow ellipse under the feet (+ ember dissolve cloud
    // while dying). The weapon sits inside this stack so it inherits every
    // transform — squash, lunge, hit-flash, death fade — with its grip
    // riding at the sprite's hand.
    w = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          bottom: -4,
          child: AnimatedOpacity(
            duration: _CombatScreenState._deathTime,
            opacity: dying ? 0.0 : 1.0,
            child: Container(
              width: spriteHeight * 0.82,
              height: spriteHeight * 0.16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.elliptical(spriteHeight, 20),
                ),
                // Crisp concentric ellipses fake a soft
                // contact shadow without MaskFilter.blur.
                border: Border.all(
                  color: const Color(0xFFEF7B23).withValues(alpha: 0.12),
                  width: 1.0,
                ),
                color: Colors.black.withValues(alpha: 0.46),
              ),
            ),
          ),
        ),
        w,
        if (weapon != null)
          Positioned(
            bottom: spriteHeight * 0.02,
            child: Transform.translate(
              offset: Offset(spriteHeight * 0.30, 0),
              child: weapon,
            ),
          ),
        if (dying)
          Positioned.fill(
            child: EmberBurst(
              duration: _CombatScreenState._deathTime,
              count: 30,
            ),
          ),
      ],
    );
    // Hit-flash: paint the sprite solid white for a beat.
    w = AnimatedSwitcher(
      duration: const Duration(milliseconds: 60),
      child: flash
          ? ColorFiltered(
              key: const ValueKey('flash'),
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcATop,
              ),
              child: w,
            )
          : KeyedSubtree(key: const ValueKey('plain'), child: w),
    );
    // Death: fade out while sinking (collapse) into the ember cloud.
    w = AnimatedOpacity(
      opacity: dying ? 0.0 : 1.0,
      duration: _CombatScreenState._deathTime,
      curve: Curves.easeIn,
      child: AnimatedSlide(
        offset: dying ? const Offset(0, 0.35) : Offset.zero,
        duration: _CombatScreenState._deathTime,
        curve: Curves.easeIn,
        child: w,
      ),
    );
    // Wind-up tint: threat reads as a heat shift on the body.
    if (windup) {
      w = AnimatedContainer(
        duration: _CombatScreenState._enemyWindupTime,
        foregroundDecoration: BoxDecoration(
          backgroundBlendMode: BlendMode.srcATop,
          color: squash ? const Color(0x55C24040) : const Color(0x00C24040),
        ),
        child: w,
      );
    }
    // Anticipation squash (bottom-anchored) right before the lunge, and the
    // slight depth scale that grounds the enemy a step closer to the camera.
    // A wind-up leans back away from the target while it squashes.
    w = Transform.scale(
      alignment: Alignment.bottomCenter,
      scale: depthScale,
      child: AnimatedContainer(
        duration: windup && squash
            ? _CombatScreenState._enemyWindupTime
            : _CombatScreenState._squashTime,
        curve: Curves.easeOut,
        transformAlignment: Alignment.bottomCenter,
        transform: squash
            ? (windup
                  ? (Matrix4.identity()
                      // vector_math deprecated the polymorphic translate/scale
                      // in favour of the typed variants. These are the exact
                      // desugarings of the old calls: translate(d) was
                      // translateByDouble(d, 0, 0, 1) and scale(x, y) was
                      // scaleByDouble(x, y, x, 1) — the z factor mirrored x.
                      ..translateByDouble(lungeToward * -8.0, 0.0, 0.0, 1.0)
                      ..rotateZ(
                        lungeToward * -0.07,
                      ) // top tips away from target
                      ..scaleByDouble(1.06, 0.90, 1.06, 1.0))
                  : (Matrix4.identity()..scaleByDouble(1.08, 0.86, 1.08, 1.0)))
            : Matrix4.identity(),
        child: w,
      ),
    );
    // Lunge toward the opponent / knockback away from them.
    final dx = lunge
        ? 1.15 * lungeToward
        : knock
        ? -0.22 * lungeToward
        : 0.0;
    return AnimatedSlide(
      offset: Offset(dx, 0),
      duration: lunge
          ? _CombatScreenState._contact
          : _CombatScreenState._knockTime,
      curve: lunge ? Curves.easeInCubic : Curves.easeOutCubic,
      child: w,
    );
  }
}

/// Static, allocation-light combat depth. The background PNG supplies distant
/// texture; this painter adds a readable horizon and floor so combatants no
/// longer float in a flat void. All geometry is normalized and cached by the
/// retained CustomPaint display list behind a RepaintBoundary.
class _CombatDioramaPainter extends CustomPainter {
  final bool boss;
  final bool elite;
  const _CombatDioramaPainter({required this.boss, required this.elite});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.58;
    final floor = Path()
      ..moveTo(0, horizon)
      ..lineTo(w, horizon)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      floor,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF211727).withValues(alpha: 0.10),
            const Color(0xFF0B0710).withValues(alpha: 0.66),
          ],
        ).createShader(Rect.fromLTWH(0, horizon, w, h - horizon)),
    );

    // Receding floor seams converge on the central vanishing point.
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFB95B25).withValues(alpha: 0.13);
    for (final x in [0.08, 0.27, 0.73, 0.92]) {
      canvas.drawLine(Offset(w * 0.50, horizon), Offset(w * x, h), seam);
    }
    for (final y in [0.66, 0.78, 0.90]) {
      final t = (y - 0.58) / 0.42;
      final inset = (1 - t) * w * 0.28;
      canvas.drawLine(Offset(inset, h * y), Offset(w - inset, h * y), seam);
    }

    // A low ember pool anchors the duel. RadialGradient is direct paint (no
    // offscreen layer); alpha is deliberately restrained for text contrast.
    final emberPool = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.91),
      width: w * (boss ? 0.82 : 0.68),
      height: h * 0.18,
    );
    canvas.drawOval(
      emberPool,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color(
              boss
                  ? 0xFFDA3D24
                  : elite
                  ? 0xFFC95B28
                  : 0xFFF08A2C,
            ).withValues(alpha: boss ? 0.19 : 0.13),
            const Color(0x00F08A2C),
          ],
        ).createShader(emberPool),
    );

    // Foreground silhouettes create a camera plane without consuming sprite
    // or texture memory.
    final rock = Paint()
      ..color = const Color(0xFF09070C).withValues(alpha: 0.82);
    final left = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.83)
      ..lineTo(w * 0.05, h * 0.78)
      ..lineTo(w * 0.11, h * 0.88)
      ..lineTo(w * 0.18, h)
      ..close();
    final right = Path()
      ..moveTo(w, h)
      ..lineTo(w, h * 0.80)
      ..lineTo(w * 0.95, h * 0.77)
      ..lineTo(w * 0.88, h * 0.89)
      ..lineTo(w * 0.82, h)
      ..close();
    canvas.drawPath(left, rock);
    canvas.drawPath(right, rock);
  }

  @override
  bool shouldRepaint(covariant _CombatDioramaPainter old) =>
      old.boss != boss || old.elite != elite;
}

@visibleForTesting
CustomPainter debugCombatDioramaPainter({
  bool boss = false,
  bool elite = false,
}) => _CombatDioramaPainter(boss: boss, elite: elite);
