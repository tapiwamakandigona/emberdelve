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
                        // Also listens to the input tick (a die selection
                        // heats the weapon BEFORE the swing — the consumer
                        // used to miss it, critique 2026-09-10 §4) and the
                        // vitals tick (the body carries its HP).
                        child: ListenableBuilder(
                          listenable: _heroBand,
                          builder: (context, _) {
                            final player = _shownPlayer(
                              widget.c.state?['player'] as Map? ?? const {},
                            );
                            final condition = Condition.of(
                              (player['hp'] as int?) ?? 1,
                              (player['max_hp'] as int?) ?? 1,
                            );
                            final rig = CombatRig.forId(_characterId);
                            return _combatant(
                              sprite: rig != null
                                  ? CombatFigure(
                                      key: ValueKey('figure-$_characterId'),
                                      rig: rig,
                                      height: heroH,
                                      phase: _weaponPhase,
                                      plan: _playerPlan,
                                      charge: _weaponCharge,
                                      knock: _playerKnock,
                                      condition: condition,
                                      showWounds: BloodEffects.enabled.value,
                                      dye: Art.dyeFilter(
                                        widget.c.meta.dyeFor(_characterId),
                                      ),
                                      identity: identity,
                                    )
                                  : SpriteView(
                                      _characterId,
                                      key: ValueKey('hero-$_characterId'),
                                      height: heroH,
                                      bob:
                                          true, // LFP-4a: the stage always breathes
                                      // v0.27.0: the delver wears their dye into
                                      // the fight; enemies are never tinted.
                                      dye: Art.dyeFilter(
                                        widget.c.meta.dyeFor(_characterId),
                                      ),
                                      condition: condition,
                                      ichor: Ichor.blood,
                                      showWounds: BloodEffects.enabled.value,
                                    ),
                              spriteHeight: heroH,
                              spriteWidth: _spriteWidth(_characterId, heroH),
                              lungeToward: 1,
                              lunge: _playerLunge,
                              knock: _playerKnock,
                              flash: _playerFlash,
                              dying: _playerDying,
                              squash: _playerSquash,
                              braced: _playerBraced,
                              condition: condition,
                              plan: _playerPlan,
                              articulated: rig != null,
                              hand: SpriteMeta.cachedOrNull
                                  ?.sheet(_characterId)
                                  ?.hand,
                              // The delver's signature weapon: idles in the
                              // hand socket, coils on the wind-up, swings
                              // with the lunge, braces across the body on
                              // guard.
                              weapon: rig != null
                                  ? null
                                  : WeaponView(
                                      _characterId,
                                      // Keep state across pool evolution; changing
                                      // the build should morph the existing weapon,
                                      // not restart its choreography controller.
                                      key: const ValueKey('combat-weapon'),
                                      height: heroH,
                                      phase: _weaponPhase,
                                      // Die -> weapon causality made visible: the
                                      // selected die's pips heat the blade before
                                      // the swing.
                                      charge: _weaponCharge,
                                      // The weapon's edge/profile now reflects the
                                      // pool forged so far (presentation only).
                                      identity: identity,
                                      plan: _playerPlan,
                                    ),
                            );
                          },
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
                            child: ListenableBuilder(
                              listenable: _foeBand,
                              builder: (context, _) {
                                final live = _shownEnemy ?? enemy;
                                final condition = Condition.of(
                                  (live['hp'] as int?) ?? 1,
                                  (live['max_hp'] as int?) ?? 1,
                                );
                                return _combatant(
                                  sprite: SpriteView(
                                    enemyId,
                                    key: ValueKey('enemy-$enemyId'),
                                    height: enemyH,
                                    flipX: true,
                                    bob: true, // LFP-4a
                                    // LFP-4b: slow lean while an attack is
                                    // telegraphed — the badge gets body
                                    // language.
                                    sway:
                                        intent['kind'] == 'attack' ||
                                        intent['kind'] == 'attack_block' ||
                                        // v0.47.0: a wind-up has body language.
                                        intent['kind'] == 'charge',
                                    condition: condition,
                                    ichor: ichorFor(enemyId),
                                    showWounds: BloodEffects.enabled.value,
                                  ),
                                  spriteHeight: enemyH,
                                  spriteWidth: _spriteWidth(enemyId, enemyH),
                                  // Slight depth scale: the enemy stands a
                                  // step closer.
                                  depthScale: big ? 1.02 : 1.06,
                                  lungeToward: -1,
                                  lunge: _enemyLunge,
                                  knock: _enemyKnock,
                                  flash: _enemyFlash,
                                  dying: _enemyDying,
                                  squash: _enemySquash,
                                  braced: _enemyBraced,
                                  condition: condition,
                                  enemyPlan: _enemyPlan,
                                  windup: true,
                                );
                              },
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
                        // Bodies in the Fight: what has been spilled so far
                        // this encounter stays on the floor.
                        if (_stains.isNotEmpty)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: FloorStainsPainter(
                                  List.unmodifiable(_stains),
                                ),
                              ),
                            ),
                          ),
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
                            child: switch (fx.kind) {
                              _FxKind.guard => GuardFlash(
                                key: ValueKey('fx-${fx.id}'),
                                facing: fx.onPlayer ? 1 : -1,
                                onDone: () {
                                  _fxUpdate(() => _fx.remove(fx));
                                },
                              ),
                              _FxKind.blood => BloodBurst(
                                key: ValueKey('fx-${fx.id}'),
                                severity: fx.severity,
                                // Droplets fly AWAY from the attacker.
                                facing: fx.onPlayer ? -1 : 1,
                                ichor: fx.ichor,
                                seed: fx.seed,
                                onStains: (landed) =>
                                    _keepStains(landed, onPlayer: fx.onPlayer),
                                onDone: () {
                                  _fxUpdate(() => _fx.remove(fx));
                                },
                              ),
                              _ => ImpactSlash(
                                key: ValueKey('fx-${fx.id}'),
                                claws: fx.kind == _FxKind.claws,
                                shape: fx.shape,
                                facing: fx.onPlayer ? -1 : 1,
                                color: fx.color,
                                onDone: () {
                                  _fxUpdate(() => _fx.remove(fx));
                                },
                              ),
                            },
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

  /// Listenables for the two bodies (cached per state; see _wireBands).
  Listenable get _heroBand => _heroBandCache ??= Listenable.merge([
    _choreoTick,
    _contactTick,
    _uiTick,
    widget.c.playerVitalsTick,
    BloodEffects.enabled,
  ]);
  Listenable get _foeBand => _foeBandCache ??= Listenable.merge([
    _choreoTick,
    _contactTick,
    widget.c.enemyTick,
    BloodEffects.enabled,
  ]);

  /// Sprite width for [id] at [height] from the sheet's frame aspect (the
  /// SpriteView lays itself out the same way). Falls back to square.
  double _spriteWidth(String id, double height) {
    final def = SpriteMeta.cachedOrNull?.sheet(id);
    if (def == null) return height;
    return height * def.frameW / def.frameH;
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
    double? spriteWidth,
    Widget? weapon,
    // v0.183.0 Bodies in the Fight ------------------------------------
    /// Guard stance while block is up.
    bool braced = false,

    /// How hurt: slump, sag, pallor (breathing/wounds live in the sprite).
    Condition condition = Condition.fresh,

    /// The hero's authored strike (timings + body amplitudes).
    StrikePlan? plan,

    /// The enemy's body-type strike.
    EnemyStrikePlan? enemyPlan,

    /// Forward-hand socket on the idle frame (frame fractions), if known.
    Offset? hand,

    /// Joint rig owns anatomy/weight shift; do not also squash the whole
    /// sprite matrix. Stage translation and terminal treatment stay shared.
    bool articulated = false,
  }) {
    Widget w = sprite;
    final dir = lungeToward.toDouble();
    final width = spriteWidth ?? spriteHeight;
    // Pallor: the colour drains as the body is hurt. Only wraps when there
    // is something to show, so a fresh sprite renders pixel-identical.
    if (condition.pallor > 0.01) {
      w = ColorFiltered(
        colorFilter: ColorFilter.matrix(pallorMatrix(condition.pallor)),
        child: w,
      );
    }
    // Weapon grip: pinned to the sheet's forward-hand socket (the widget's
    // grip point is at 0.5 w / 0.66 h of its own square box). Without a
    // socket, the legacy roster offset.
    Widget? heldWeapon;
    if (weapon != null) {
      final gripDx = hand == null
          ? spriteHeight * 0.30
          : (hand.dx - 0.5) * width;
      final gripBottom = hand == null
          ? spriteHeight * 0.02 + spriteHeight * 0.34
          : (1.0 - hand.dy) * spriteHeight;
      heldWeapon = Positioned(
        bottom: gripBottom - spriteHeight * 0.34,
        child: Transform.translate(offset: Offset(gripDx, 0), child: weapon),
      );
    }
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
        if (heldWeapon != null) heldWeapon,
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
        duration: enemyPlan == null
            ? _CombatScreenState._enemyWindupTime
            : _CombatScreenState._pace(enemyPlan.windupMs),
        foregroundDecoration: BoxDecoration(
          backgroundBlendMode: BlendMode.srcATop,
          color: squash ? const Color(0x55C24040) : const Color(0x00C24040),
        ),
        child: w,
      );
    }
    // ------------------------------------------------------------------
    // The body. One matrix about the feet: lean (rotation), crouch or
    // stretch (scale), lift (hop). Which pose applies is decided by the
    // same flags the choreography always used; how FAR it goes comes from
    // the strike plan and the body's condition.
    final pose = _bodyPose(
      dir: dir,
      squash: squash,
      lunge: lunge,
      knock: knock,
      braced: braced,
      condition: condition,
      plan: plan,
      enemyPlan: enemyPlan,
      windup: windup,
    );
    final m = Matrix4.identity();
    if (!articulated) {
      m
        ..translateByDouble(pose.dx, -pose.lift * spriteHeight, 0.0, 1.0)
        ..rotateZ(pose.lean)
        ..scaleByDouble(pose.scaleX, pose.scaleY, pose.scaleX, 1.0);
    }
    w = Transform.scale(
      alignment: Alignment.bottomCenter,
      scale: depthScale,
      child: AnimatedContainer(
        duration: pose.duration,
        curve: pose.curve,
        transformAlignment: Alignment.bottomCenter,
        transform: m,
        child: w,
      ),
    );
    // Lunge toward the opponent / knockback away from them. The stab
    // travels furthest, the maul barely leaves its feet (plan.advance).
    // Jointed bodies keep their weight over the feet: translate less than
    // the old whole-sprite launch, with the distinct cut/maul advances intact.
    final advance = lunge
        ? (plan?.advance ?? enemyPlan?.advance ?? 1.0) *
              (articulated ? 0.72 : 1.0)
        : 0.0;
    final dx = lunge
        ? 1.15 * advance * lungeToward
        : knock
        ? -0.22 * lungeToward
        : braced
        ? -0.03 * lungeToward
        : 0.0;
    return AnimatedSlide(
      offset: Offset(dx, 0),
      duration: lunge
          ? _CombatScreenState._pace(
              plan?.travelMs ?? enemyPlan?.travelMs ?? 250,
            )
          : _CombatScreenState._knockTime,
      curve: lunge ? Curves.easeInCubic : Curves.easeOutCubic,
      child: w,
    );
  }

  /// Resolve the body pose for the current flags. Pure; see [_combatant].
  _BodyPose _bodyPose({
    required double dir,
    required bool squash,
    required bool lunge,
    required bool knock,
    required bool braced,
    required Condition condition,
    StrikePlan? plan,
    EnemyStrikePlan? enemyPlan,
    bool windup = false,
  }) {
    // Baseline: the hurt body slumps toward the ground and sags.
    final slump = condition.slump * dir;
    final sag = condition.sag;
    if (squash) {
      final lean = plan?.windupLean ?? enemyPlan?.windupLean ?? -0.07;
      final crouch = plan?.windupCrouch ?? enemyPlan?.windupCrouch ?? 0.88;
      final ms = plan?.windupMs ?? enemyPlan?.windupMs ?? (windup ? 190 : 90);
      return _BodyPose(
        lean: lean * dir + slump,
        scaleX: 1.0 + (1.0 - crouch) * 0.6, // keeps volume
        scaleY: crouch * sag,
        dx: -6.0 * dir,
        lift: 0.0,
        duration: _CombatScreenState._pace(ms),
        curve: Curves.easeOut,
      );
    }
    if (lunge) {
      final lean = plan?.strikeLean ?? enemyPlan?.strikeLean ?? 0.12;
      final stretch = plan?.strikeStretch ?? enemyPlan?.strikeStretch ?? 1.03;
      final ms = plan?.travelMs ?? enemyPlan?.travelMs ?? 250;
      return _BodyPose(
        lean: lean * dir,
        scaleX: 1.0 / math.sqrt(stretch),
        scaleY: stretch,
        dx: 0.0,
        lift: enemyPlan?.hop ?? 0.0,
        duration: _CombatScreenState._pace(ms),
        curve: Curves.easeInCubic,
      );
    }
    if (knock) {
      // Head snaps back, knees give a little.
      return _BodyPose(
        lean: -0.10 * dir + slump,
        scaleX: 1.02,
        scaleY: 0.95 * sag,
        dx: 0.0,
        lift: 0.0,
        duration: _CombatScreenState._knockTime,
        curve: Curves.easeOutCubic,
      );
    }
    if (braced) {
      // Guard: weight back, knees bent, compact.
      return _BodyPose(
        lean: -0.06 * dir + slump * 0.5,
        scaleX: 1.03,
        scaleY: 0.95 * sag,
        dx: 0.0,
        lift: 0.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    }
    return _BodyPose(
      lean: slump,
      scaleX: 1.0,
      scaleY: sag,
      dx: 0.0,
      lift: 0.0,
      duration: _CombatScreenState._pace(plan?.recoverMs ?? 260),
      curve: Curves.easeOutCubic,
    );
  }
}

/// One resolved body pose (see _combatant). Rotation about the feet.
class _BodyPose {
  final double lean; // rad, + tips toward screen-right
  final double scaleX;
  final double scaleY;
  final double dx; // px, applied before rotation
  final double lift; // fraction of height (hop)
  final Duration duration;
  final Curve curve;
  const _BodyPose({
    required this.lean,
    required this.scaleX,
    required this.scaleY,
    required this.dx,
    required this.lift,
    required this.duration,
    required this.curve,
  });
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
