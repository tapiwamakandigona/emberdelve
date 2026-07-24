// lib/ui/screens/combat_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class CombatScreen extends StatefulWidget {
  final GameController c;
  const CombatScreen(this.c, {super.key});
  @override
  State<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends State<CombatScreen> {
  int? selected; // 1-based die index
  bool _busy = false; // input lock while a choreography sequence plays

  // One-slot action queue (v0.3.1 F2): actions tapped while a choreography
  // sequence plays are remembered (latest wins) and run when it finishes —
  // fast play stops silently eating taps. Die *selection* is pure UI state
  // and is allowed during choreography outright.
  (String, int?)? _queued; // (action, die) — 'attack' | 'block' | 'end_turn'

  // First-fight tutorial (v0.3.1 F11): -1 = off, 0..2 = current step.
  int _tutStep = -1;

  // Risky-reroll multi-select: while [_rerollMode] is on, taps on UNASSIGNED
  // dice toggle membership in [_rerollSel]; confirm sends `reroll_risky`.
  bool _rerollMode = false;
  final Set<int> _rerollSel = {};

  // Combo / kill call-outs: transient TextPops over the tray or the enemy.
  final List<_Note> _notes = [];
  int _noteId = 0;

  // Choreography flags (attack = squash + lunge tween + hit-flash + knockback;
  // death = flash + ember-dissolve — the sheets have no attack/death frames).
  bool _playerLunge = false, _enemyLunge = false;
  bool _playerFlash = false, _enemyFlash = false;
  bool _playerKnock = false, _enemyKnock = false;
  bool _playerDying = false, _enemyDying = false;
  bool _playerSquash = false, _enemySquash = false;

  // Juice: roll generation triggers the dice tumble; shake key drives screen
  // shake; pops are floating damage numbers over the stage.
  int _rollGen = 0;
  final GlobalKey<ShakeBoxState> _shakeKey = GlobalKey<ShakeBoxState>();
  final List<_Pop> _pops = [];
  int _popId = 0;

  // Contact FX on the stage: weapon smear on the enemy when the delver's
  // swing lands, claw rake on the player when the enemy's does (the sheets
  // have no attack frames — the overlay IS the strike), and the guard-flash
  // shield arc whenever block happens or a hit is fully absorbed.
  final List<_Fx> _fx = [];
  int _fxId = 0;

  // Boss kill moment: a full-screen white-hot flash held over the stage.
  bool _bossKillFlash = false;

  // Boss/elite name-plate splash, shown once when the encounter opens.
  bool _splash = false;

  // Cached combat view-model: during the end-of-encounter notify hold the sim
  // has already left combat (enemy == null), but we keep rendering the stage.
  Map? _enemy;
  String _characterId = defaultCharacter;

  // SYNC_POINTS.md: whoosh starts ~2 frames (8 fps => 250 ms) before contact.
  static const _contact = Duration(milliseconds: 250);
  static const _squashTime = Duration(milliseconds: 90);
  // Enemy anticipation runs longer than the player's: their wind-up is the
  // player's last cue to read the incoming hit.
  static const _enemyWindupTime = Duration(milliseconds: 190);
  static const _hitStop = Duration(milliseconds: 80);
  static const _knockTime = Duration(milliseconds: 140);
  static const _flashTail = Duration(milliseconds: 120);
  static const _deathTime = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    // First-ever fight: run the 3-step onboarding overlay (F11).
    if (!widget.c.meta.tutorialSeen) _tutStep = 0;
    final enemy = widget.c.state?['enemy'] as Map?;
    if (enemy != null && (enemy['boss'] == true || enemy['elite'] == true)) {
      _splash = true;
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _splash = false);
      });
    }
  }

  void _spawnPop(int amount, {required bool onPlayer, bool blocked = false}) {
    setState(
      () => _pops.add(
        _Pop(_popId++, amount, onPlayer: onPlayer, blocked: blocked),
      ),
    );
  }

  void _spawnFx(_FxKind kind,
      {required bool onPlayer, Color color = EmberColors.gold}) {
    setState(() => _fx.add(_Fx(_fxId++, kind, onPlayer: onPlayer, color: color)));
  }

  /// Weapon choreography rides the existing squash/lunge flags: pull back in
  /// anticipation, whip through the smear arc during the lunge.
  WeaponPhase get _weaponPhase => _playerSquash
      ? WeaponPhase.raise
      : _playerLunge
          ? WeaponPhase.swing
          : WeaponPhase.idle;

  /// Selected die pips -> weapon heat (0..1). Keeps glowing through the
  /// swing (selection is cleared after apply, but the lunge should stay hot).
  double get _weaponCharge {
    if (_playerSquash || _playerLunge) return _lastSwingCharge;
    final st = widget.c.state;
    final player = st?['player'] as Map?;
    final rolled = (player?['rolled'] as List?)?.cast<int>();
    final sel = selected;
    if (rolled == null || sel == null || sel > rolled.length) return 0.0;
    return (rolled[sel - 1] / 12.0).clamp(0.15, 1.0);
  }

  double _lastSwingCharge = 0.0;

  /// Shake scaled by damage relative to the victim's max HP; hits at or above
  /// 25% of max HP also earn an ~80 ms hit-stop (design-system §5).
  bool _impact(int amount, int victimMaxHp) {
    final frac = victimMaxHp <= 0 ? 0.0 : amount / victimMaxHp;
    _shakeKey.currentState?.shake((0.25 + frac * 2.2).clamp(0.0, 1.0));
    return frac >= 0.25;
  }

  AudioService? get _audio => widget.c.audio;

  Map<String, Object?>? _find(List<Map<String, Object?>> events, String type) {
    for (final e in events) {
      if (e['type'] == type) return e;
    }
    return null;
  }

  void _note(
    String text, {
    Color color = EmberColors.gold,
    IconData? icon,
    bool onEnemy = false,
  }) {
    if (!mounted) return;
    setState(
      () => _notes.add(_Note(_noteId++, text, color, icon, onEnemy: onEnemy)),
    );
  }

  /// Celebrate the sim's combo/reroll events (docs/m4-sim-contract.md §8):
  /// pair/triple/straight get distinct call-outs over the dice tray; ignite
  /// flames the enemy; straight announces the earned free reroll.
  void _announceCombos(List<Map<String, Object?>> events) {
    for (final e in events) {
      switch (e['type']) {
        case 'combo_pair':
          _note('PAIR +${e['bonus']}', icon: Icons.casino);
          break;
        case 'combo_triple':
          // Ignite is announced by burn_applied (it only fires when the sim
          // actually applies burn) — claiming IGNITE here would exaggerate.
          _note('TRIPLE!', color: EmberColors.danger, icon: Icons.casino);
          break;
        case 'burn_applied':
          _note(
            'IGNITE +${e['stacks']} BURN',
            color: EmberColors.ember,
            icon: Icons.local_fire_department,
            onEnemy: true,
          );
          break;
        case 'combo_straight':
          _note(
            'STRAIGHT!',
            color: EmberColors.kindElite,
            icon: Icons.trending_up,
          );
          break;
        case 'free_reroll_earned':
          _note(
            'FREE REROLL NEXT TURN',
            color: EmberColors.success,
            icon: Icons.replay,
          );
          break;
        case 'free_reroll_granted':
          _note(
            'FREE REROLL READY',
            color: EmberColors.success,
            icon: Icons.replay,
          );
          break;
      }
    }
  }

  void _doRiskyReroll() {
    if (_busy || _rerollSel.isEmpty) return;
    final dice = _rerollSel.toList()..sort();
    final events = widget.c.apply({'type': 'reroll_risky', 'dice': dice});
    setState(() {
      _rerollMode = false;
      _rerollSel.clear();
      if (_find(events, 'risky_reroll') != null) {
        _rollGen++; // retumble the tray on a successful reroll
      }
    });
    _announceCombos(events);
  }

  Future<void> _sleep(Duration d) => Future.delayed(d);

  /// Run the queued action once the current choreography finishes (F2).
  /// Guarded: the encounter must still be running, and a queued assign only
  /// fires if its die is still rolled and unassigned.
  void _drainQueue() {
    final q = _queued;
    _queued = null;
    if (q == null || !mounted || _busy) return;
    final st = widget.c.state;
    if (st == null || st['enemy'] == null || widget.c.phase != 'player_turn') {
      return;
    }
    final (action, die) = q;
    if (action == 'end_turn') {
      _endTurn();
      return;
    }
    final player = st['player'] as Map;
    if (player['rolled'] == null) return;
    final assigned = (player['assigned'] as Map?) ?? const {};
    if (die == null || assigned['$die'] != null) return;
    selected = die;
    if (action == 'attack') {
      _attack();
    } else {
      _block();
    }
  }

  Future<void> _enemyDeath(List<Map<String, Object?>> events) async {
    if (_find(events, 'encounter_won') == null) return;
    final boss = _enemy?['boss'] == true;
    _audio?.playSfx(boss ? 'boss_death' : 'enemy_death');
    Haptics.heavy();
    if (!mounted) return;
    if (boss) {
      // Boss kill moment: the frame holds white-hot for a beat (impact
      // freeze), the screen rocks at full magnitude, then the dissolve.
      _shakeKey.currentState?.shake(1.0);
      setState(() {
        _enemyFlash = true;
        _bossKillFlash = true;
      });
      await _sleep(const Duration(milliseconds: 260));
      if (!mounted) return;
    }
    setState(() {
      _enemyFlash = false;
      _enemyDying = true;
    });
    await _sleep(_deathTime);
    if (boss && mounted) {
      // Let the flash overlay finish fading before the phase switch.
      setState(() => _bossKillFlash = false);
      await _sleep(const Duration(milliseconds: 150));
    }
  }

  /// Player attack: lunge toward the enemy, whoosh leading contact by ~2
  /// frames, then enemy_hit/block + hit-flash + knockback on the contact
  /// frame; enemy_death/boss_death + fade-collapse if the blow kills.
  Future<void> _attack() async {
    if (selected == null) return;
    if (_busy) {
      _queued = ('attack', selected); // F2: remember, don't drop
      return;
    }
    _busy = true;
    _lastSwingCharge = _weaponCharge; // freeze the heat for the swing itself
    // Boss deaths get a longer hold: the kill moment below needs the stage.
    final isBoss = _enemy?['boss'] == true;
    final events = widget.c.apply({
      'type': 'assign',
      'die': selected,
      'action': 'attack',
    }, terminalHold: Duration(milliseconds: isBoss ? 1900 : 1300));
    selected = null;
    final dmg = _find(events, 'damage_dealt');
    if (dmg == null) {
      // invalid command (e.g. block-only die): no swing
      _busy = false;
      if (mounted) setState(() {});
      return;
    }
    // Anticipation squash before the lunge (visuals.md #9).
    setState(() => _playerSquash = true);
    await _sleep(_squashTime);
    if (!mounted) return;
    _audio?.playSfx('whoosh');
    setState(() {
      _playerSquash = false;
      _playerLunge = true;
    });
    await _sleep(_contact);
    if (!mounted) return;
    final amount = dmg['amount'] as int? ?? 0;
    final absorbed = dmg['blocked'] as int? ?? 0;
    final landed = amount - absorbed;
    _audio?.playSfx(absorbed >= amount ? 'block' : 'enemy_hit');
    Haptics.medium();
    _spawnPop(
      landed > 0 ? landed : amount,
      onPlayer: false,
      blocked: landed <= 0,
    );
    // Contact frame: the weapon's smear crosses the enemy — or glances off
    // a shield arc when the hit is fully absorbed.
    if (landed > 0) {
      _spawnFx(_FxKind.slash,
          onPlayer: false, color: weaponFor(_characterId).accent);
    } else {
      _spawnFx(_FxKind.guard, onPlayer: false);
    }
    final enemyMax = (_enemy?['max_hp'] as int?) ?? 1;
    final bigHit = _impact(landed, enemyMax);
    setState(() => _enemyFlash = true);
    // Hit-stop: the frame freezes on contact before the knockback releases.
    if (bigHit) await _sleep(_hitStop);
    if (!mounted) return;
    setState(() => _enemyKnock = true);
    await _sleep(_knockTime);
    if (!mounted) return;
    setState(() {
      _playerLunge = false;
      _enemyKnock = false;
    });
    // Exact-kill / overkill moments (m4 contract §4): arithmetic pays off.
    final exact = _find(events, 'exact_kill');
    if (exact != null) {
      _audio?.playSfx('ember_gain');
      _note(
        '+${exact['embers']} EMBERS — EXACT!',
        icon: Icons.local_fire_department,
        onEnemy: true,
      );
    }
    final over = _find(events, 'overkill');
    if (over != null) {
      _note(
        'OVERKILL +${over['surplus']} → NEXT FOE',
        color: EmberColors.ember,
        icon: Icons.double_arrow,
        onEnemy: true,
      );
    }
    if (_find(events, 'encounter_won') != null) {
      await _enemyDeath(events);
    } else {
      await _sleep(_flashTail);
      if (mounted) setState(() => _enemyFlash = false);
    }
    _busy = false;
    if (mounted) setState(() {});
    _drainQueue();
  }

  void _block() {
    if (selected == null) return;
    if (_busy) {
      _queued = ('block', selected); // F2: remember, don't drop
      return;
    }
    final events =
        widget.c.apply({'type': 'assign', 'die': selected, 'action': 'block'});
    Haptics.light();
    setState(() => selected = null);
    // Block used to be completely silent — now the guard visibly comes up.
    final gained = _find(events, 'block_gained');
    if (gained != null) {
      _audio?.playSfx('block', volume: 0.55);
      _spawnFx(_FxKind.guard, onPlayer: true);
      _note('+${gained['amount']} BLOCK',
          color: EmberColors.block, icon: Icons.shield);
    }
  }

  /// Enemy turn: mirrored choreography — enemy lunges, player_hit/block on
  /// contact, defeat sting + player fade-collapse if the run ends here.
  Future<void> _endTurn() async {
    if (_busy) {
      _queued = ('end_turn', null); // F2: remember, don't drop
      return;
    }
    _busy = true;
    setState(() {
      selected = null;
      _rerollMode = false;
      _rerollSel.clear();
    });
    final events = widget.c.apply({
      'type': 'end_turn',
    }, terminalHold: const Duration(milliseconds: 1450));
    final atk = _find(events, 'enemy_attacked');
    if (atk != null) {
      // Physical wind-up: the enemy leans back and darkens for a beat before
      // the lunge — the strike telegraphs in the body, not just the badge.
      setState(() => _enemySquash = true);
      await _sleep(_enemyWindupTime);
      if (!mounted) return;
      _audio?.playSfx('whoosh');
      setState(() {
        _enemySquash = false;
        _enemyLunge = true;
      });
      await _sleep(_contact);
      if (!mounted) return;
      final damage = atk['damage'] as int? ?? 0;
      _audio?.playSfx(damage <= 0 ? 'block' : 'player_hit');
      Haptics.medium();
      _spawnPop(damage, onPlayer: true, blocked: damage <= 0);
      // Contact frame: claws rake the delver — or break on the guard arc
      // when block eats the whole hit.
      if (damage > 0) {
        _spawnFx(_FxKind.claws, onPlayer: true, color: EmberColors.danger);
      } else {
        _spawnFx(_FxKind.guard, onPlayer: true);
      }
      final playerMax =
          ((widget.c.state?['player'] as Map?)?['max_hp'] as int?) ?? 1;
      final bigHit = _impact(damage, playerMax);
      setState(() => _playerFlash = true);
      if (bigHit) await _sleep(_hitStop);
      if (!mounted) return;
      setState(() => _playerKnock = true);
      await _sleep(_knockTime);
      if (!mounted) return;
      setState(() {
        _enemyLunge = false;
        _playerKnock = false;
      });
      if (_find(events, 'encounter_lost') != null) {
        _audio?.playSfx('defeat');
        Haptics.heavy();
        setState(() {
          _playerFlash = false;
          _playerDying = true;
        });
        await _sleep(const Duration(milliseconds: 800));
      } else {
        await _sleep(_flashTail);
        if (mounted) setState(() => _playerFlash = false);
      }
    } else if (_find(events, 'enemy_blocked') != null) {
      _audio?.playSfx('block', volume: 0.5);
      _spawnFx(_FxKind.guard, onPlayer: false); // its shield visibly comes up
    }
    // Burn ticks after the enemy acts: flame call-out + damage pop reusing
    // the existing pop primitive (m4 contract §3).
    final burnTick = _find(events, 'burn_tick');
    if (burnTick != null && mounted) {
      _audio?.playSfx('enemy_hit', volume: 0.5);
      _spawnPop(burnTick['amount'] as int? ?? 0, onPlayer: false);
      _note(
        'BURN',
        color: EmberColors.ember,
        icon: Icons.local_fire_department,
        onEnemy: true,
      );
      // The 350 ms beat lets a plain tick read on its own — but when the
      // tick KILLS, it pushed the worst end-turn path to ~1730 ms, past the
      // 1450 ms terminal hold: the phase switched to the reward screen while
      // the enemy was still mid-dissolve. The death choreography is the
      // payoff there, so skip the beat and let _enemyDeath play in budget
      // (worst path ≤ ~1380 ms).
      if (_find(events, 'encounter_won') == null) {
        await _sleep(const Duration(milliseconds: 350));
      }
    }
    // A straight last turn grants this turn's free reroll — announce it.
    _announceCombos(events);
    // Thorns relics and burn can kill the enemy during its own turn.
    if (mounted) await _enemyDeath(events);
    _busy = false;
    if (mounted) setState(() {});
    _drainQueue();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final st = c.state!;
    final liveEnemy = st['enemy'] as Map?;
    if (liveEnemy != null) _enemy = liveEnemy;
    final run = st['run'] as Map?;
    if (run != null && run['character'] is String) {
      _characterId = run['character'] as String;
    }
    final enemy = _enemy;
    if (enemy == null) return const SizedBox.shrink();
    final player = st['player'] as Map;
    final rolled = (player['rolled'] as List?)?.cast<int>();
    final assigned = (player['assigned'] as Map?) ?? const {};
    final maxed = (player['rolled_max'] as List?)?.cast<bool>();
    final dice0 = (player['dice'] as List).cast<String>();
    final intent =
        (enemy['intent'] as Map?) ?? const {'kind': 'attack', 'amount': 0};
    final rerolls = player['rerolls_left'] as int? ?? 0;
    final riskyUsed = player['risky_used'] == true;
    final freeReroll = player['free_reroll'] == true;
    final enemyHp = (enemy['hp'] as int).clamp(0, enemy['max_hp'] as int);
    // Compact mode for short phones: tighter chrome and smaller sprites so
    // the fixed sections never overflow the column (measured: the roomy
    // chrome needs ~700px once the tray wraps to two rows).
    //
    // The combat HUD is a fixed-height layout, so large system font sizes
    // are handled in two steps (probed at 1.3x across all supported sizes):
    // 1. text scale is clamped to what the height budget can absorb
    //    (~400px of height buys one full step of text growth, measured);
    // 2. the compact decision uses the *effective* height at that scale.
    // Every label the clamp affects also carries a Semantics description,
    // so screen readers get the full text regardless of visual scale.
    final height = MediaQuery.sizeOf(context).height;
    final systemScale = MediaQuery.textScalerOf(context).scale(100) / 100;
    final maxHudScale = (1.0 + (height - 570) / 400).clamp(1.0, 2.0).toDouble();
    final hudScale = math.min(systemScale, maxHudScale);
    final compact = height / hudScale < 700;

    final combat = Column(
      children: [
        _TopBar(c),
        // Enemy header: name + HP (intent lives on the stage, over the enemy).
        Padding(
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
                  ],
                ),
                const SizedBox(height: Space.s),
                StatBar(
                  value: enemyHp,
                  max: enemy['max_hp'] as int,
                  block: enemy['block'] as int? ?? 0,
                  color: EmberColors.danger,
                  label: 'ENEMY HP · TURN ${st['turn']}',
                ),
              ],
            ),
          ),
        ),
        // The stage: hero (left) vs enemy (right), animated sprite loops.
        Expanded(child: _stage(enemy, intent, compact: compact)),
        // Player HP
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          child: StatBar(
            value: (player['hp'] as int).clamp(0, player['max_hp'] as int),
            max: player['max_hp'] as int,
            block: player['block'] as int,
            color: EmberColors.hp,
            label: 'YOUR HP',
          ),
        ),
        SizedBox(height: compact ? Space.s : Space.m),
        // Dice tray (combo call-outs pop over it; in reroll mode taps pick the
        // unassigned dice to risk — assigned dice never join the selection).
        // Bounded + scrollable: a fat late-run pool can wrap to many rows, so
        // past ~2 rows the tray scrolls instead of squeezing the stage out and
        // overflowing the column on short screens.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: compact ? 112 : 256),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: Space.s,
                    runSpacing: Space.s,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 1; i <= dice0.length; i++)
                        DieChip(
                          dice0[i - 1],
                          value: rolled != null ? rolled[i - 1] : null,
                          assigned: assigned['$i'] != null,
                          selected: _rerollMode
                              ? _rerollSel.contains(i)
                              : selected == i,
                          maxed: maxed != null && maxed[i - 1],
                          rollToken: _rollGen,
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
                              ? () => setState(
                                  () => _rerollSel.contains(i)
                                      ? _rerollSel.remove(i)
                                      : _rerollSel.add(i),
                                )
                              : () {
                                  Haptics.light();
                                  setState(
                                    () => selected = selected == i ? null : i,
                                  );
                                },
                        ),
                    ],
                  ),
                ),
              ),
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
                    onDone: () {
                      if (mounted) setState(() => _notes.remove(n));
                    },
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: compact ? Space.s : Space.m),
        // Action zone (thumb reach)
        Padding(
          padding: EdgeInsets.fromLTRB(
            Space.l,
            0,
            Space.l,
            compact ? Space.s : Space.l,
          ),
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
                            setState(() {
                              selected = null;
                              _rollGen++; // trigger the dice tumble cascade
                            });
                            final events = c.apply({'type': 'roll'});
                            // Combo call-outs land after the tumble reads.
                            Future.delayed(
                              const Duration(milliseconds: 550),
                              () {
                                if (mounted) _announceCombos(events);
                              },
                            );
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
                          : 'Pick dice to reroll — each lands −1 pip',
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
                            onTap: () => setState(() {
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
                          child: EmberButton(
                            'Attack',
                            dense: compact,
                            icon: Icons.gps_fixed,
                            onTap: selected != null ? _attack : null,
                          ),
                        ),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: EmberButton(
                            'Block',
                            dense: compact,
                            icon: Icons.shield,
                            onTap: selected != null ? _block : null,
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
                                      final events = c.apply({
                                        'type': 'reroll',
                                        'die': selected,
                                      });
                                      setState(() {});
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
                                : 'Risky reroll · −1 pip',
                            dense: compact,
                            icon: Icons.casino,
                            onTap: riskyUsed || _busy
                                ? null
                                : () => setState(() {
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
      ],
    );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxHudScale,
      child: ShakeBox(
        key: _shakeKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            combat,
            // Boss kill flash: white-out that decays into the ember dissolve.
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _bossKillFlash ? 1.0 : 0.0,
                duration: Duration(milliseconds: _bossKillFlash ? 60 : 420),
                curve: Curves.easeOut,
                child: const ColoredBox(
                  color: Color(0xFFFFE9C4),
                  child: SizedBox.expand(),
                ),
              ),
            ),
            if (_splash) _NamePlate(enemy: enemy, layer: _currentLayer(st)),
            if (_tutStep >= 0)
              _TutorialOverlay(
                step: _tutStep,
                onNext: () => setState(() {
                  if (_tutStep >= 2) {
                    _tutStep = -1;
                    widget.c.markTutorialSeen();
                  } else {
                    _tutStep++;
                  }
                }),
                onSkip: () => setState(() {
                  _tutStep = -1;
                  widget.c.markTutorialSeen();
                }),
              ),
          ],
        ),
      ),
    );
  }

  /// Layer of the node the delver stands on (for the boss name-plate).
  int _currentLayer(Map st) {
    final map = st['map'] as Map?;
    if (map == null) return 1;
    final nodes = (map['nodes'] as Map?)?.cast<String, Map>();
    final pos = map['position'];
    return (nodes?['$pos']?['layer'] as int?) ?? 1;
  }

  /// Hero vs enemy, bottom-aligned on a grounded floor plane (shadow
  /// ellipses); lunges slide the combatant toward the other side, knockback
  /// nudges away, deaths dissolve into embers. Damage numbers pop over the
  /// stage; the enemy's next intent floats above it as an icon badge.
  Widget _stage(Map enemy, Map intent, {bool compact = false}) {
    final enemyId = enemy['id'] as String? ?? '';
    final big = enemy['boss'] == true || enemy['elite'] == true;
    final heroH = compact ? 72.0 : 104.0;
    final enemyH = compact ? (big ? 96.0 : 72.0) : (big ? 128.0 : 96.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      // Clip.none: on short screens the shrunken stage lets sprites/intent
      // badges overlap the header gracefully instead of being cut off.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: _combatant(
                  sprite: SpriteView(
                    _characterId,
                    key: ValueKey('hero-$_characterId'),
                    height: heroH,
                  ),
                  spriteHeight: heroH,
                  lungeToward: 1,
                  lunge: _playerLunge,
                  knock: _playerKnock,
                  flash: _playerFlash,
                  dying: _playerDying,
                  squash: _playerSquash,
                  // The delver's signature weapon, finally visible: idles in
                  // hand, pulls back on the squash, swings with the lunge.
                  weapon: WeaponView(
                    _characterId,
                    key: ValueKey('weapon-$_characterId'),
                    height: heroH,
                    phase: _weaponPhase,
                    // Die -> weapon causality made visible: the selected
                    // die's pips heat the blade before the swing.
                    charge: _weaponCharge,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    _combatant(
                      sprite: SpriteView(
                        enemyId,
                        key: ValueKey('enemy-$enemyId'),
                        height: enemyH,
                        flipX: true,
                      ),
                      spriteHeight: enemyH,
                      // Slight depth scale: the enemy stands a step closer.
                      depthScale: big ? 1.02 : 1.06,
                      lungeToward: -1,
                      lunge: _enemyLunge,
                      knock: _enemyKnock,
                      flash: _enemyFlash,
                      dying: _enemyDying,
                      squash: _enemySquash,
                      windup: true,
                    ),
                    // Intent as an icon badge floating above the enemy
                    // (overlaid, so it never adds layout height). Burn stacks
                    // sit beside it while the enemy is alight.
                    Positioned(
                      top: -44,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _IntentBadge(intent),
                          if ((enemy['burn'] as int? ?? 0) > 0) ...[
                            const SizedBox(width: Space.xs),
                            _BurnBadge(enemy['burn'] as int),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                onDone: () {
                  if (mounted) setState(() => _notes.remove(n));
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
                      if (mounted) setState(() => _fx.remove(fx));
                    })
                : ImpactSlash(
                    key: ValueKey('fx-${fx.id}'),
                    claws: fx.kind == _FxKind.claws,
                    color: fx.color,
                    onDone: () {
                      if (mounted) setState(() => _fx.remove(fx));
                    }),
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
                  if (mounted) setState(() => _pops.remove(p));
                },
              ),
            ),
        ],
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
            duration: _deathTime,
            opacity: dying ? 0.0 : 1.0,
            child: Container(
              width: spriteHeight * 0.7,
              height: spriteHeight * 0.14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.elliptical(spriteHeight, 20),
                ),
                color: Colors.black.withValues(alpha: 0.38),
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
          Positioned.fill(child: EmberBurst(duration: _deathTime, count: 30)),
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
      duration: _deathTime,
      curve: Curves.easeIn,
      child: AnimatedSlide(
        offset: dying ? const Offset(0, 0.35) : Offset.zero,
        duration: _deathTime,
        curve: Curves.easeIn,
        child: w,
      ),
    );
    // Wind-up tint: threat reads as a heat shift on the body.
    if (windup) {
      w = AnimatedContainer(
        duration: _enemyWindupTime,
        foregroundDecoration: BoxDecoration(
          backgroundBlendMode: BlendMode.srcATop,
          color: squash
              ? const Color(0x55C24040)
              : const Color(0x00C24040),
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
        duration: windup && squash ? _enemyWindupTime : _squashTime,
        curve: Curves.easeOut,
        transformAlignment: Alignment.bottomCenter,
        transform: squash
            ? (windup
                ? (Matrix4.identity()
                  ..translate(lungeToward * -8.0)
                  ..rotateZ(lungeToward * -0.07) // top tips away from target
                  ..scale(1.06, 0.90))
                : (Matrix4.identity()..scale(1.08, 0.86)))
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
      duration: lunge ? _contact : _knockTime,
      curve: lunge ? Curves.easeInCubic : Curves.easeOutCubic,
      child: w,
    );
  }
}

/// One transient combat call-out (combo, burn tick, exact-kill, overkill).
/// One transient stage contact effect (weapon smear, claw rake, guard arc).
enum _FxKind { slash, claws, guard }

class _Fx {
  final int id;
  final _FxKind kind;
  final bool onPlayer;
  final Color color;
  const _Fx(this.id, this.kind, {required this.onPlayer, required this.color});
}

class _Note {
  final int id;
  final String text;
  final Color color;
  final IconData? icon;
  final bool onEnemy; // anchors near the enemy instead of the dice tray
  _Note(this.id, this.text, this.color, this.icon, {required this.onEnemy});
}

/// One floating damage number's spawn record.
class _Pop {
  final int id;
  final int amount;
  final bool onPlayer;
  final bool blocked;
  _Pop(this.id, this.amount, {required this.onPlayer, required this.blocked});
}

/// Boss/elite name-plate splash: "SOOT SHADE — LAYER 1" over a charred band.
class _NamePlate extends StatelessWidget {
  final Map enemy;
  final int layer;
  const _NamePlate({required this.enemy, required this.layer});
  @override
  Widget build(BuildContext context) {
    final boss = enemy['boss'] == true;
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1600),
          builder: (context, f, child) {
            // In 0-15%, hold, out 85-100%.
            final a = f < 0.15
                ? f / 0.15
                : f > 0.85
                ? (1 - f) / 0.15
                : 1.0;
            final scale =
                1.15 -
                0.15 * Curves.easeOut.transform((f / 0.2).clamp(0.0, 1.0));
            return Opacity(
              opacity: a.clamp(0.0, 1.0),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: Space.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.18, 0.82, 1.0],
              ),
              border: const Border(
                top: BorderSide(color: EmberColors.ember, width: 1),
                bottom: BorderSide(color: EmberColors.ember, width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (enemy['name'] as String? ?? '').toUpperCase(),
                  textAlign: TextAlign.center,
                  style: EmberText.h1.copyWith(
                    color: boss ? EmberColors.kindBoss : EmberColors.kindElite,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  boss ? 'LAYER $layer · BOSS' : 'LAYER $layer · ELITE',
                  style: EmberText.micro.copyWith(letterSpacing: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Burn stacks on the enemy: small flame + count, ticking down each turn.
class _BurnBadge extends StatelessWidget {
  final int stacks;
  const _BurnBadge(this.stacks);
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Burning, $stacks ${stacks == 1 ? 'stack' : 'stacks'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s,
          vertical: Space.s,
        ),
        decoration: BoxDecoration(
          color: EmberColors.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EmberColors.ember),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department,
              size: 16,
              color: EmberColors.ember,
            ),
            const SizedBox(width: 2),
            Text(
              '$stacks',
              style: EmberText.value.copyWith(
                fontSize: 15,
                color: EmberColors.ember,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentBadge extends StatelessWidget {
  final Map intent;
  const _IntentBadge(this.intent);
  @override
  Widget build(BuildContext context) {
    final kind = intent['kind'];
    // v0.3.1 F6: attack_block reads as two explicit chips (attack amount +
    // block amount) — one lightning icon over two bare numbers was
    // undecodable without reading the sim.
    final parts = <(IconData, Color, String)>[
      if (kind == 'attack' || kind == 'attack_block')
        (Icons.gps_fixed, EmberColors.danger, '${intent['amount']}'),
      if (kind == 'block')
        (Icons.shield, EmberColors.block, '${intent['amount']}'),
      if (kind == 'attack_block')
        (Icons.shield, EmberColors.block, '${intent['block']}'),
    ];
    final border = kind == 'attack_block'
        ? EmberColors.kindElite
        : kind == 'block'
        ? EmberColors.block
        : EmberColors.danger;
    final spoken = switch (kind) {
      'attack' => 'attack for ${intent['amount']}',
      'block' => 'block ${intent['amount']}',
      'attack_block' =>
        'attack for ${intent['amount']} and block ${intent['block']}',
      _ => '$kind',
    };
    return Semantics(
      label: 'Enemy intent: $spoken',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.m,
          vertical: Space.s,
        ),
        decoration: BoxDecoration(
          color: EmberColors.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, part) in parts.indexed) ...[
              if (i > 0) const SizedBox(width: Space.m),
              Icon(part.$1, size: 18, color: part.$2),
              const SizedBox(width: Space.xs),
              Text(
                part.$3,
                style: EmberText.value.copyWith(fontSize: 18, color: part.$2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reward — smart default (RECOMMENDED on the biggest upgrade)
// ---------------------------------------------------------------------------
