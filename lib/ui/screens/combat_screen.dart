// lib/ui/screens/combat_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

/// LFP-2a: what assigning [die] to [action] will resolve for, computed from
/// public sim state + content data (dieDef mods, combo_bonus, relic hooks) —
/// the same inputs sim/combat.dart reads. Returns -1 when the die can't take
/// the action (attack_only/block_only). PRESENTATION-ONLY twin of the sim's
/// assign math: test/feel_pregate_test.dart replays a scripted run and
/// asserts this against every die_assigned event the sim emits, so the two
/// cannot drift silently.
int assignPreview(
  Map player,
  Map enemy,
  List<String> relics,
  int die,
  String action,
) {
  final rolled = (player['rolled'] as List).cast<int>();
  final def = dieDef((player['dice'] as List).cast<String>()[die - 1]);
  final mods = def.mods;
  if (action == 'attack' && mods['block_only'] == true) return -1;
  if (action == 'block' && mods['attack_only'] == true) return -1;
  final maxed = (player['rolled_max'] as List?)?.cast<bool>();
  final onMax = (maxed != null && maxed[die - 1])
      ? (mods['on_max_bonus'] as int? ?? 0)
      : 0;
  final combo = (player['combo_bonus'] as List?)?.cast<int>();
  int hook(String h) {
    var t = 0;
    for (final id in relics) {
      t += relicDef(id).hooks[h] ?? 0;
    }
    return t;
  }

  var v = rolled[die - 1] + onMax + (combo != null ? combo[die - 1] : 0);
  if (action == 'attack') {
    v += (mods['attack_bonus'] as int? ?? 0) + hook('attack_flat');
    if (enemy['boss'] == true || enemy['elite'] == true) {
      v += hook('elite_damage');
    }
  } else {
    v += (mods['block_bonus'] as int? ?? 0) + hook('block_flat');
  }
  return v;
}

class CombatScreen extends StatefulWidget {
  final GameController c;
  const CombatScreen(this.c, {super.key});
  @override
  State<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends State<CombatScreen> {
  // ---------------------------------------------------------------------
  // Scoped rebuild ticks (perf, 2026-07-25). This screen's build() is ~1000
  // lines and every setState re-ran ALL of it: top bar, enemy panel, sprite
  // stage, dice tray, action zone. Choreography alone fires ~20 setStates
  // per attack, so a normal swing rebuilt the whole screen 20 times — and a
  // rapid tapper stacked those sequences.
  //
  // The two highest-churn state groups now live behind ValueNotifier ticks
  // instead. The fields themselves are unchanged (so every read site reads
  // the same way); only the NOTIFICATION is scoped: bump the tick and just
  // the subtree that listens rebuilds.
  //
  //   _choreoTick — combatant flags (lunge/knock/flash/dying/squash) +
  //                 the weapon phase/charge derived from them. Consumers:
  //                 the two _combatant() subtrees on the stage.
  //   _fxTick     — transient overlay layers: pops, contact fx, call-out
  //                 notes, assign ghosts, boss-kill flash. Consumers: the
  //                 overlay layers themselves, nothing else.
  //
  // Anything sim-driven (HP, dice faces, phase) still goes through setState:
  // those genuinely change the whole screen.
  final ValueNotifier<int> _choreoTick = ValueNotifier(0);
  final ValueNotifier<int> _fxTick = ValueNotifier(0);

  /// Mutate choreography flags and rebuild only the combatants.
  void _choreo(VoidCallback f) {
    if (!mounted) return;
    f();
    _choreoTick.value++;
  }

  /// Mutate a transient overlay list/flag and rebuild only the fx layers.
  void _fxUpdate(VoidCallback f) {
    if (!mounted) return;
    f();
    _fxTick.value++;
  }

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

  // LFP-1c: per-die reflight generations — a risky/charge reroll re-flies
  // ONLY the rerolled dice (the old `_rollGen++` on risky rerolls re-tumbled
  // the whole tray, including dice that never moved). A chip's effective
  // roll token is `_rollGen * 4096 + _reflyGen[i]`.
  final Map<int, int> _reflyGen = {};
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

  // LFP-5: resolution pacing control. END TURN choreography is fixed-length
  // (~2.5–3.5s to next input; design-system §5 wants ≤400ms input blocks) —
  // fine at fight 1, heavy by fight 30. Tapping anywhere during enemy
  // resolution arms fast-forward: 1 tap = 2x (call-outs drop to 1s), 2 taps
  // = skip-to-state. Information is never skipped — every pop, call-out and
  // state change still happens — only duration. Reset every END TURN.
  int _ffwd = 0;
  bool _resolving = false;

  // Boss/elite name-plate splash, shown once when the encounter opens.
  bool _splash = false;

  // Cached combat view-model: during the end-of-encounter notify hold the sim
  // has already left combat (enemy == null), but we keep rendering the stage.
  Map? _enemy;
  String _characterId = defaultCharacter;

  // LFP-2c: what each spent die actually contributed (from its die_assigned
  // event, so modifiers/combos/relics are included) — keyed by die index,
  // cleared on every new roll. The chip label shows it ("+7 SPENT"), making
  // the silent arithmetic visible after the fact too.
  final Map<int, int> _assignedValue = {};

  // LFP-2a die flight: on assign, a ghost of the die flies from its tray
  // slot to the verb button (230ms easeIn), which pulses on arrival — the
  // cause→effect link the tray's grey-out never gave. Geometry is captured
  // through GlobalKeys and rendered in root-Stack coordinates.
  final GlobalKey _rootKey = GlobalKey();
  final GlobalKey _attackKey = GlobalKey();
  final GlobalKey _blockKey = GlobalKey();
  final Map<int, GlobalKey> _chipKeys = {};
  final List<_Ghost> _ghosts = [];
  int _ghostId = 0;
  int _attackPulse = 0;
  int _blockPulse = 0;

  /// Root-stack-local center of the widget under [key], or null.
  Offset? _centerOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final root = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || root == null || !box.attached || !box.hasSize) {
      return null;
    }
    return root.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  /// Spawn the assign ghost for [die] flying to the [action] button.
  void _spawnGhost(int die, String action, int value, Offset? from) {
    final to = _centerOf(action == 'attack' ? _attackKey : _blockKey);
    if (from == null || to == null || !mounted) return;
    _fxUpdate(() => _ghosts.add(_Ghost(_ghostId++, from, to, value, action)));
  }

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
  // Call-out lifetime (v0.3.10): was TextPop's 1s default — testers couldn't
  // read PAIR/FREE-REROLL/BLOCKED before it faded. 2s holds the text ~1.3s.
  static const _noteLife = Duration(milliseconds: 2000);

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
    // LFP-6a: overkill splash carried into THIS enemy — call the dent out on
    // the stage (the enemy opens below max HP by design, not by bug). Delayed
    // past the flame wipe so the call-out lands on a readable stage.
    final splashIn = widget.c.takeSplashIn();
    if (splashIn != null && splashIn > 0) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _note(
          'OVERKILL SPLASH −$splashIn',
          color: EmberColors.ember,
          icon: Icons.double_arrow,
          onEnemy: true,
        );
      });
    }
  }

  @override
  void dispose() {
    _choreoTick.dispose();
    _fxTick.dispose();
    super.dispose();
  }

  void _spawnPop(int amount, {required bool onPlayer, bool blocked = false}) {
    _fxUpdate(
      () => _pops.add(
        _Pop(_popId++, amount, onPlayer: onPlayer, blocked: blocked),
      ),
    );
  }

  void _spawnFx(
    _FxKind kind, {
    required bool onPlayer,
    Color color = EmberColors.gold,
  }) {
    _fxUpdate(
      () => _fx.add(_Fx(_fxId++, kind, onPlayer: onPlayer, color: color)),
    );
  }

  /// LFP-2a: what assigning [selected] to [action] will resolve for (or -1
  /// when the action is invalid for that die). Thin wrapper over the public
  /// [assignPreview] so the drift guard in test/feel_pregate_test.dart can
  /// pin the shared function against the sim's own die_assigned values.
  int _assignPreview(Map player, Map enemy, int die, String action) =>
      assignPreview(
        player,
        enemy,
        ((widget.c.state?['run'] as Map?)?['relics'] as List?)
                ?.cast<String>() ??
            const [],
        die,
        action,
      );

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
    // LFP-5: while fast-forwarding, call-outs hold 1s instead of 2s — same
    // information, matched pacing (the plan's "call-outs to 1s").
    final life = _resolving && _ffwd > 0
        ? const Duration(milliseconds: 1000)
        : _noteLife;
    _fxUpdate(
      () => _notes.add(
        _Note(_noteId++, text, color, icon, onEnemy: onEnemy, life: life),
      ),
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

  /// LFP-3b: long-press tooltips — name what a badge means in one 2s
  /// call-out (reuses the existing note primitive; zero new systems).
  void _explainIntent(Map intent) {
    final text = switch (intent['kind']) {
      'attack' => 'NEXT MOVE: ATTACK ${intent['amount']} — AS SHOWN',
      'block' => 'NEXT MOVE: BLOCK ${intent['amount']} — AS SHOWN',
      'attack_block' =>
        'NEXT MOVE: ATTACK ${intent['amount']} + BLOCK ${intent['block']}',
      _ => 'NEXT MOVE — RESOLVES AS SHOWN',
    };
    Haptics.light();
    _note(
      text,
      color: EmberColors.textPrimary,
      icon: Icons.visibility,
      onEnemy: true,
    );
  }

  // Burn semantics VERIFIED against sim/combat.dart: damage = current stacks,
  // ticks at the end of the enemy's action, then stacks decay by 1.
  void _explainBurn(int stacks) {
    Haptics.light();
    _note(
      'BURN $stacks — $stacks DMG AFTER ITS MOVE, THEN −1',
      color: EmberColors.ember,
      icon: Icons.local_fire_department,
      onEnemy: true,
    );
  }

  void _doRiskyReroll() {
    if (_busy || _rerollSel.isEmpty) return;
    final dice = _rerollSel.toList()..sort();
    final events = widget.c.apply({'type': 'reroll_risky', 'dice': dice});
    setState(() {
      _rerollMode = false;
      _rerollSel.clear();
      if (_find(events, 'risky_reroll') != null) {
        // LFP-1c: only the picked dice re-fly.
        for (final d in dice) {
          _reflyGen[d] = (_reflyGen[d] ?? 0) + 1;
        }
      }
    });
    _announceCombos(events);
  }

  Future<void> _sleep(Duration d) => Future.delayed(d);

  /// LFP-5: like [_sleep], but chunked so a fast-forward tap landing
  /// mid-wait shortens the REMAINING wait too — 2x after one tap, ~instant
  /// after two. Only the enemy-resolution path ([_endTurn]) waits through
  /// this; the player's own swing keeps its full anatomy.
  Future<void> _beat(Duration d) async {
    var elapsed = 0;
    while (true) {
      final total = _ffwd >= 2
          ? 0
          : _ffwd == 1
          ? d.inMilliseconds ~/ 2
          : d.inMilliseconds;
      if (elapsed >= total) return;
      final step = math.min(40, total - elapsed);
      await Future.delayed(Duration(milliseconds: step));
      elapsed += step;
    }
  }

  /// Armed only while the enemy resolution plays; taps that no button or die
  /// claims fall through to this (the root gesture arena defers to children).
  void _fastForwardTap() {
    if (!_busy || !_resolving) return;
    if (_ffwd >= 2) return;
    Haptics.light();
    setState(() => _ffwd = _ffwd + 1);
  }

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
      _choreo(() => _enemyFlash = true);
      _fxUpdate(() => _bossKillFlash = true);
      await _sleep(const Duration(milliseconds: 260));
      if (!mounted) return;
    }
    _choreo(() {
      _enemyFlash = false;
      _enemyDying = true;
    });
    await _sleep(_deathTime);
    if (boss && mounted) {
      // Let the flash overlay finish fading before the phase switch.
      _fxUpdate(() => _bossKillFlash = false);
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
    // LFP-2a: capture the chip's slot geometry before the apply dims it.
    final assignedDie = selected!;
    final ghostFrom = _chipKeys[assignedDie] != null
        ? _centerOf(_chipKeys[assignedDie]!)
        : null;
    // Boss deaths get a longer hold: the kill moment below needs the stage.
    final isBoss = _enemy?['boss'] == true;
    final events = widget.c.apply({
      'type': 'assign',
      'die': selected,
      'action': 'attack',
    }, terminalHold: Duration(milliseconds: isBoss ? 1900 : 1300));
    selected = null;
    // LFP-2c: remember what the die actually contributed (incl. modifiers).
    final da = _find(events, 'die_assigned');
    if (da != null) {
      _assignedValue[da['die'] as int] = da['value'] as int;
      // LFP-2a: the die visibly travels to the verb it was spent on.
      _spawnGhost(assignedDie, 'attack', da['value'] as int, ghostFrom);
    }
    final dmg = _find(events, 'damage_dealt');
    if (dmg == null) {
      // invalid command (e.g. block-only die): no swing
      _busy = false;
      if (mounted) setState(() {});
      return;
    }
    // Anticipation squash before the lunge (visuals.md #9).
    _choreo(() => _playerSquash = true);
    await _sleep(_squashTime);
    if (!mounted) return;
    _audio?.playSfx('whoosh');
    _choreo(() {
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
    // Mirror of the player-side rule (v0.3.10): when the enemy's shield eats
    // part of the hit, say so — otherwise "-3" against a shielded foe reads
    // like the attack die itself rolled low.
    if (absorbed > 0 && landed > 0) {
      _note(
        'SHIELD ATE $absorbed',
        color: EmberColors.block,
        icon: Icons.shield,
        onEnemy: true,
      );
    }
    // Contact frame: the weapon's smear crosses the enemy — or glances off
    // a shield arc when the hit is fully absorbed.
    if (landed > 0) {
      _spawnFx(
        _FxKind.slash,
        onPlayer: false,
        color: weaponFor(_characterId).accent,
      );
    } else {
      _spawnFx(_FxKind.guard, onPlayer: false);
    }
    final enemyMax = (_enemy?['max_hp'] as int?) ?? 1;
    final bigHit = _impact(landed, enemyMax);
    _choreo(() => _enemyFlash = true);
    // Hit-stop: the frame freezes on contact before the knockback releases.
    if (bigHit) await _sleep(_hitStop);
    if (!mounted) return;
    _choreo(() => _enemyKnock = true);
    await _sleep(_knockTime);
    if (!mounted) return;
    _choreo(() {
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
      _choreo(() => _enemyFlash = false);
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
    // LFP-2a: capture the chip's slot geometry before the apply dims it.
    final assignedDie = selected!;
    final ghostFrom = _chipKeys[assignedDie] != null
        ? _centerOf(_chipKeys[assignedDie]!)
        : null;
    final events = widget.c.apply({
      'type': 'assign',
      'die': selected,
      'action': 'block',
    });
    Haptics.light();
    setState(() => selected = null);
    // LFP-2c: remember what the die actually contributed (incl. modifiers).
    final da = _find(events, 'die_assigned');
    if (da != null) {
      _assignedValue[da['die'] as int] = da['value'] as int;
      // LFP-2a: the die visibly travels to the verb it was spent on.
      _spawnGhost(assignedDie, 'block', da['value'] as int, ghostFrom);
    }
    // Block used to be completely silent — now the guard visibly comes up.
    final gained = _find(events, 'block_gained');
    if (gained != null) {
      _audio?.playSfx('block', volume: 0.55);
      _spawnFx(_FxKind.guard, onPlayer: true);
      _note(
        '+${gained['amount']} BLOCK',
        color: EmberColors.block,
        icon: Icons.shield,
      );
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
    _ffwd = 0; // LFP-5: each resolution starts at full speed
    _resolving = true;
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
      _choreo(() => _enemySquash = true);
      await _beat(_enemyWindupTime);
      if (!mounted) return;
      _audio?.playSfx('whoosh');
      _choreo(() {
        _enemySquash = false;
        _enemyLunge = true;
      });
      await _beat(_contact);
      if (!mounted) return;
      final damage = atk['damage'] as int? ?? 0;
      final absorbed = atk['blocked'] as int? ?? 0;
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
      // Make block visibly pay (v0.3.10): a partial block used to show only
      // the damage number, so testers read block as doing nothing. Every
      // absorbed point now gets its own shield call-out (and the guard arc
      // joins the claws on partial blocks).
      if (absorbed > 0) {
        if (damage > 0) _spawnFx(_FxKind.guard, onPlayer: true);
        _note(
          damage <= 0 ? 'FULLY BLOCKED' : 'BLOCKED $absorbed',
          color: EmberColors.block,
          icon: Icons.shield,
        );
      }
      final playerMax =
          ((widget.c.state?['player'] as Map?)?['max_hp'] as int?) ?? 1;
      final bigHit = _impact(damage, playerMax);
      _choreo(() => _playerFlash = true);
      if (bigHit) await _beat(_hitStop);
      if (!mounted) return;
      _choreo(() => _playerKnock = true);
      await _beat(_knockTime);
      if (!mounted) return;
      _choreo(() {
        _enemyLunge = false;
        _playerKnock = false;
      });
      if (_find(events, 'encounter_lost') != null) {
        _audio?.playSfx('defeat');
        Haptics.heavy();
        _choreo(() {
          _playerFlash = false;
          _playerDying = true;
        });
        // The run-ending moment keeps its full weight — never fast-forwarded.
        await _sleep(const Duration(milliseconds: 800));
      } else {
        await _beat(_flashTail);
        _choreo(() => _playerFlash = false);
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
        await _beat(const Duration(milliseconds: 350));
      }
    }
    // A straight last turn grants this turn's free reroll — announce it.
    _announceCombos(events);
    // Thorns relics and burn can kill the enemy during its own turn.
    // (Death choreography keeps its full length — the kill is the payoff.)
    if (mounted) await _enemyDeath(events);
    _busy = false;
    _resolving = false;
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

    // Tray metrics (many-dice sweep 2026-07-24): a fat late-run pool used to
    // clip dice 5+ behind a half-row — technically scrollable, visually
    // broken. Now chips shrink once the pool outgrows the roomy row budget,
    // the tray height is quantized to WHOLE rows (no half-cut dice), and a
    // fade + chevron signals the overflow when it truly must scroll.
    final trayWidth = MediaQuery.sizeOf(context).width - 2 * Space.l;
    final chipScale = dice0.length > (compact ? 4 : 8) ? 0.75 : 1.0;
    final chipW = 64 * chipScale + Space.s;
    final chipH = 80 * chipScale;
    final perRow = math.max(1, ((trayWidth + Space.s) / chipW).floor());
    final rowsNeeded = math.max(1, (dice0.length / perRow).ceil());
    const trayPeek = 26.0; // room for the fade strip below the last row
    // Whole rows only, inside the same height budget the tray always had
    // (112/256) so the stage never loses more space than before; the fade
    // strip borrows from the budget when the tray truly scrolls.
    final trayBudget = compact ? 112.0 : 256.0;
    final rowH = chipH + Space.s;
    int fitRows(double budget) =>
        math.max(1, ((budget + Space.s) / rowH).floor());
    var visRows = math.min(rowsNeeded, fitRows(trayBudget));
    var trayScrolls = rowsNeeded > visRows;
    if (trayScrolls) {
      visRows = math.min(rowsNeeded, fitRows(trayBudget - trayPeek));
      trayScrolls = rowsNeeded > visRows;
    }
    // Viewport height is EXACTLY whole rows — the scroll view clips at a row
    // boundary, so no half-cut dice ever bleed through (screenshot review
    // 2026-07-24: the old fade-over-peek let row 2 show as clipped grey dice).
    final trayViewH = visRows * chipH + (visRows - 1) * Space.s;
    final hiddenDice = math.max(0, dice0.length - visRows * perRow);

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
                    // Replayable how-to-play (v0.3.10): the tutorial used to
                    // show once, ever — a tester considered REINSTALLING to
                    // see it again. This reopens the same overlay any time.
                    Semantics(
                      label: 'How to play',
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _busy || _tutStep >= 0
                            ? null
                            : () => setState(() => _tutStep = 0),
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
        // LFP-2a: while a die is selected, the stage shows what assigning it
        // will actually resolve for — modifiers, combos and relics included —
        // so the number is on screen BEFORE the tap, not discovered on the
        // HP bar afterwards.
        Expanded(
          child: _stage(
            enemy,
            intent,
            compact: compact,
            preview: selected != null && rolled != null && !_rerollMode
                ? () {
                    final a = _assignPreview(
                      player,
                      enemy,
                      selected!,
                      'attack',
                    );
                    final b = _assignPreview(player, enemy, selected!, 'block');
                    return [
                      if (a >= 0) 'ATTACK +$a',
                      if (b >= 0) 'BLOCK +$b',
                    ].join('  ·  ');
                  }()
                : null,
          ),
        ),
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
                                  value: rolled != null ? rolled[i - 1] : null,
                                  assigned: assigned['$i'] != null,
                                  selected: _rerollMode
                                      ? _rerollSel.contains(i)
                                      : selected == i,
                                  maxed: maxed != null && maxed[i - 1],
                                  contribution: _assignedValue[i],
                                  flight: true, // LFP-1: thrown, not refreshed
                                  onSettle: Haptics.light, // LFP-1b rattle
                                  rollToken:
                                      _rollGen * 4096 + (_reflyGen[i] ?? 0),
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
                                            () => selected = selected == i
                                                ? null
                                                : i,
                                          );
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
                          height: trayPeek - Space.xs,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.m,
                          ),
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
                              _assignedValue.clear(); // fresh turn (LFP-2c)
                              _reflyGen.clear(); // fresh throw set (LFP-1c)
                              _rollGen++; // trigger the dice throw cascade
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
                                      setState(() {
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
      // LFP-5: taps that no die/button claims fall through to this root
      // detector (children win the gesture arena, so queued actions and die
      // selection behave exactly as before) — during enemy resolution they
      // arm fast-forward instead of dying silently.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _fastForwardTap,
        child: ShakeBox(
          key: _shakeKey,
          child: Stack(
            key: _rootKey,
            fit: StackFit.expand,
            children: [
              combat,
              // Assign ghosts + boss-kill flash, scoped to _fxTick: a die
              // flying to its verb no longer rebuilds the tray, the stage or
              // the action zone underneath it.
              Positioned.fill(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _fxTick,
                    builder: (context, _, _) => Stack(
                      fit: StackFit.expand,
                      children: [
                        // LFP-2a: assign ghosts — the spent die flies to its verb.
                        for (final g in _ghosts)
                          TweenAnimationBuilder<double>(
                            key: ValueKey('ghost-${g.id}'),
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 230),
                            curve: Curves.easeIn,
                            onEnd: () {
                              if (!mounted) return;
                              setState(() {
                                _ghosts.remove(g);
                                // Arrival pulse on the verb button.
                                if (g.action == 'attack') {
                                  _attackPulse++;
                                } else {
                                  _blockPulse++;
                                }
                              });
                            },
                            builder: (context, f, _) {
                              final p = Offset.lerp(g.from, g.to, f)!;
                              final color = g.action == 'attack'
                                  ? EmberColors.danger
                                  : EmberColors.block;
                              return Positioned(
                                left: p.dx - 19,
                                top: p.dy - 19,
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: (1.0 - f * 0.55).clamp(0.0, 1.0),
                                    child: Transform.scale(
                                      scale: 1.0 - f * 0.35,
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: EmberColors.raised,
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                          border: Border.all(
                                            color: color,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Text(
                                          '+${g.value}',
                                          style: EmberText.value.copyWith(
                                            fontSize: 16,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        // Boss kill flash: white-out that decays into the ember dissolve.
                        IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _bossKillFlash ? 1.0 : 0.0,
                            duration: Duration(
                              milliseconds: _bossKillFlash ? 60 : 420,
                            ),
                            curve: Curves.easeOut,
                            child: const ColoredBox(
                              color: Color(0xFFFFE9C4),
                              child: SizedBox.expand(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_splash) _NamePlate(enemy: enemy, layer: _currentLayer(st)),
              if (_tutStep >= 0)
                _TutorialOverlay(
                  step: _tutStep,
                  onNext: () => setState(() {
                    if (_tutStep >= _TutorialOverlay.cardCount - 1) {
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
  /// Chips shrink together once the pool outgrows the tray's row budget so
  /// more dice stay visible per row (FittedBox keeps taps + semantics).
  Widget _trayChip(double scale, DieChip chip) => scale == 1.0
      ? chip
      : SizedBox(
          width: 64 * scale,
          height: 80 * scale,
          child: FittedBox(fit: BoxFit.contain, child: chip),
        );

  /// stage; the enemy's next intent floats above it as an icon badge.
  Widget _stage(
    Map enemy,
    Map intent, {
    bool compact = false,
    String? preview,
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
                              key: ValueKey('weapon-$_characterId'),
                              height: heroH,
                              phase: _weaponPhase,
                              // Die -> weapon causality made visible: the
                              // selected die's pips heat the blade before the
                              // swing.
                              charge: _weaponCharge,
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
                                      intent['kind'] == 'attack_block',
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
                            child: _IntentBadge(
                              intent,
                              onLongPress: () => _explainIntent(intent),
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
              if (preview != null && preview.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: Space.s,
                  child: IgnorePointer(
                    child: Center(
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
                          preview,
                          style: EmberText.micro.copyWith(
                            color: EmberColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
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
        duration: windup && squash ? _enemyWindupTime : _squashTime,
        curve: Curves.easeOut,
        transformAlignment: Alignment.bottomCenter,
        transform: squash
            ? (windup
                  ? (Matrix4.identity()
                      ..translate(lungeToward * -8.0)
                      ..rotateZ(
                        lungeToward * -0.07,
                      ) // top tips away from target
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

/// LFP-2a: one in-flight assign ghost (die → verb button).
class _Ghost {
  final int id;
  final Offset from;
  final Offset to;
  final int value;
  final String action; // 'attack' | 'block'
  const _Ghost(this.id, this.from, this.to, this.value, this.action);
}

/// LFP-2a: pulses its child (1.0 → ~1.07 → 1.0) every time [token] changes —
/// the verb button visibly "receives" the die. token 0 renders statically so
/// nothing pulses on first build.
class _Pulse extends StatelessWidget {
  final int token;
  final Widget child;
  const _Pulse({required this.token, required this.child});
  @override
  Widget build(BuildContext context) {
    if (token == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey('pulse-$token'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, f, c) =>
          Transform.scale(scale: 1.0 + math.sin(f * math.pi) * 0.07, child: c),
      child: child,
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
  final Duration life; // LFP-5: 1s while fast-forwarding, 2s otherwise
  _Note(
    this.id,
    this.text,
    this.color,
    this.icon, {
    required this.onEnemy,
    this.life = const Duration(milliseconds: 2000),
  });
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

/// LFP-3a: a status stack ON the combatant (burn today; the vocabulary can
/// grow). Deliberately unlike the intent badge: tight rounded pill, tinted
/// fill, smaller type — reads as a condition, not a plan. Long-press names
/// it (LFP-3b).
class _StatusChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String semantics;
  final VoidCallback? onLongPress;
  const _StatusChip({
    required this.icon,
    required this.color,
    required this.value,
    required this.semantics,
    this.onLongPress,
  });
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              color.withValues(alpha: 0.22),
              EmberColors.raised,
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 2),
              Text(
                '$value',
                style: EmberText.value.copyWith(fontSize: 12, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntentBadge extends StatelessWidget {
  final Map intent;
  final VoidCallback? onLongPress;
  const _IntentBadge(this.intent, {this.onLongPress});
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
      label: 'Enemy intent: $spoken. Long press to explain.',
      excludeSemantics: true,
      // LFP-3b: long-press names the badge in a 2s call-out.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reward — smart default (RECOMMENDED on the biggest upgrade)
// ---------------------------------------------------------------------------
