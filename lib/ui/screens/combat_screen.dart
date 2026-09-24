// lib/ui/screens/combat_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';
// Band builders, the _Hud view-model, fx records and badges live in
// lib/ui/screens/combat/ (split 2026-07-26, remaining-work §7).

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
  //   _uiTick     — pure input state: die selection, the busy input lock,
  //                 reroll mode + its multi-select, and the verb-button
  //                 arrival pulses. Consumers: the dice tray, the action
  //                 zone, the assignment preview, the help button. A die tap
  //                 changes nothing the top bar, HP bars, enemy panel or
  //                 sprite stage can see, so they no longer rebuild for it.
  final ValueNotifier<int> _choreoTick = ValueNotifier(0);
  final ValueNotifier<int> _fxTick = ValueNotifier(0);
  final ValueNotifier<int> _uiTick = ValueNotifier(0);
  // Displayed vitals/intent move only at their presentation event, not at
  // synchronous sim.apply(). Separate from per-motion ticks to keep HP bands
  // off the animation clock.
  final ValueNotifier<int> _contactTick = ValueNotifier(0);
  CombatPresentation? _presentation;

  void _beginPresentation() {
    final st = widget.c.state;
    final player = st?['player'] as Map?;
    final enemy = st?['enemy'] as Map?;
    if (player == null || enemy == null) return;
    _presentation = CombatPresentation(
      player: player,
      enemy: enemy,
      turn: st?['turn'] as int? ?? 0,
    );
  }

  Map _shownPlayer(Map live) => _presentation?.playerView(live) ?? live;
  Map? get _shownEnemy => _presentation?.enemy ?? _enemy;

  void _present(Iterable<Map<String, Object?>> events) {
    if (!mounted) return;
    final presentation = _presentation;
    if (presentation == null) return;
    for (final event in events) {
      presentation.apply(event);
    }
    // Preserve the event's corpse HP even after the sim removes the enemy.
    _enemy = Map<String, Object?>.from(presentation.enemy);
    _contactTick.value++;
  }

  void _finishPresentation() {
    if (!mounted) return;
    _presentation = null;
    _contactTick.value++;
  }

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

  /// Mutate pure input state and rebuild only the tray + action zone.
  /// (Anything that also changes sim state goes through the controller, which
  /// rebuilds the screen anyway — use [setState] there.)
  void _ui(VoidCallback f) {
    if (!mounted) return;
    f();
    _uiTick.value++;
  }

  // ---------------------------------------------------------------------
  // Section bands (perf, v0.3.15)
  //
  // Sim state used to reach this screen the blunt way: any notifyListeners()
  // rebuilt GameRoot, which rebuilt CombatScreen top to bottom. The scoped
  // ticks above could not help with that — a roll re-ran the whole build().
  //
  // The controller now publishes per-field ticks, GameRoot hands this screen
  // back as the same widget instance (so the framework skips the subtree), and
  // each section listens to the band it actually reads. A band bundles the
  // controller's field ticks with this screen's own input tick.
  late final Listenable _runBand;
  late final Listenable _enemyBand;
  late final Listenable _stageBand;
  late final Listenable _vitalsBand;
  late final Listenable _diceBand;
  // v0.183.0: the two bodies' own bands (lazily merged in stage.dart).
  Listenable? _heroBandCache;
  Listenable? _foeBandCache;

  void _wireBands() {
    final c = widget.c;
    // Top bar: gold, embers, relic count, daily badge.
    _runBand = c.runTick;
    // Enemy panel: name, HP, block, turn counter. The help button reads the
    // input lock through its own inner listener, so a die tap must not drag
    // the panel along (measured: it did, +48 Text rebuilds on the die storm).
    _enemyBand = Listenable.merge([c.enemyTick, c.turnTick, _contactTick]);
    // Stage: enemy sprite/intent, delver sprite (character comes from `run`).
    // Choreography and the assign preview keep their own inner listeners.
    _stageBand = Listenable.merge([c.enemyTick, c.runTick, _contactTick]);
    // Player HP bar: hp / max_hp / block only — not the dice.
    _vitalsBand = Listenable.merge([c.playerVitalsTick, _contactTick]);
    // Tray and action zone: the pool, this turn's roll, and input state.
    _diceBand = Listenable.merge([c.diceTick, _uiTick]);
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

  // v0.183.0 Bodies in the Fight: the authored strike behind the flags
  // above. Frozen per swing so the body, weapon and contact FX all read the
  // same plan; the enemy's plan comes from its body type.
  StrikePlan _playerPlan = StrikePlan.fallback;
  EnemyStrikePlan _enemyPlan = planEnemyStrike(EnemyStrikeStyle.swipe);

  // Blood/ichor on the stage floor, kept for the whole encounter; the hit
  // seed keeps each burst's spray deterministic yet different.
  final List<FloorStain> _stains = [];
  int _hitSeed = 0;
  static const int _maxStains = 24;

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

  /// The stage's current readout plan (lib/ui/readout_lanes.dart), kept so
  /// spawns can pick a slot the stage actually has.
  ReadoutPlan? _readoutPlan;

  /// Largest intent badge laid out so far (see _planReadout).
  Size _badgeSeen = Size.zero;
  int _popId = 0;

  // Contact FX on the stage: weapon smear on the enemy when the delver's
  // swing lands, claw rake on the player when the enemy's does (the sheets
  // have no attack frames — the overlay IS the strike), and the guard-flash
  // shield arc whenever block happens or a hit is fully absorbed.
  final List<_Fx> _fx = [];
  int _fxId = 0;

  // Boss kill moment: a warm bloom from the boss, scoped to the stage
  // (C1-01: it used to be a full-screen opaque white-out that hid the kill).
  bool _bossKillFlash = false;

  // C1-01: set the frame a blow/turn ends the encounter — the tray and the
  // action zone dim and stop taking taps until the screen moves on.
  bool _encounterOver = false;

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

  /// ONE KNOB for the whole swing anatomy (remaining-work §3).
  ///
  /// Every beat below is derived from this percentage, so pacing is a one-line
  /// change instead of eight edits that can drift out of sync: 100 is the
  /// timing v0.3.15 shipped, 80 is a 20% snappier swing, 120 a heavier one.
  /// Only the RELATIVE anatomy is fixed (anticipation < contact, hit-stop is
  /// the shortest beat, death is the longest) — that ratio is what reads as
  /// "a hit", and scaling keeps it intact.
  ///
  /// Measured, so the knob is not a guess: dropping to 70 shortens the swing
  /// by ~200 ms but does NOT reduce paints/frame (see
  /// docs/improvements/choreo-knob-2026-07-26.md) — fewer frames of the same
  /// animation is the same cost per frame. It is a pacing control, not a perf
  /// control, and 100 stays the default because the profile trace shows the
  /// UI thread has ~9 ms of headroom per frame at the current pacing.
  static const int choreoPercent = 100;

  /// Scales a beat by [choreoPercent], never below one frame at 60 Hz.
  static Duration _pace(int ms) =>
      Duration(milliseconds: math.max(16, ms * choreoPercent ~/ 100));

  // SYNC_POINTS.md: whoosh starts ~2 frames (8 fps => 250 ms) before
  // contact. Since v0.183.0 the wind-up + travel envelope is authored per
  // strike (lib/ui/combat_pose.dart) — always 340 ms in total, the same as
  // the old 90 ms squash + 250 ms contact lead it replaces.
  // Enemy anticipation runs longer than the player's: their wind-up is the
  // player's last cue to read the incoming hit (EnemyStrikePlan.windupMs,
  // never below the legacy 190 ms telegraph; it also times the wind-up heat).
  static final _hitStop = _pace(80);
  static final _knockTime = _pace(140);
  static final _flashTail = _pace(120);
  static final _deathTime = _pace(700);
  // Call-out lifetime (v0.3.10): was TextPop's 1s default — testers couldn't
  // read PAIR/FREE-REROLL/BLOCKED before it faded. 2s holds the text ~1.3s.
  static const _noteLife = Duration(milliseconds: 2000);

  @override
  void initState() {
    super.initState();
    _wireBands();
    BloodEffects.enabled.addListener(_onBloodEffectsChanged);
    // v0.10.0 The First Delve: the up-front tutorial wall is gone. The
    // fight-start moment fires the ROLL-THEN-SPEND tip on the first-ever
    // fight only; every other rule is taught at its own first contact
    // (lib/game/tips.dart). The manual help button still replays the full
    // overlay deck any time.
    widget.c.tipDirector.onFightStart();
    final enemy = widget.c.state?['enemy'] as Map?;
    if (enemy != null && (enemy['boss'] == true || enemy['elite'] == true)) {
      _splash = true;
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _splash = false);
      });
    }
    // v0.180.0 The Spoken Badge: the opening intent is on the badge before
    // the first roll — speak it once the name plate (if any) has cleared.
    Future.delayed(Duration(milliseconds: _splash ? 1900 : 450), () {
      _maybeSpeakBadge(_declaredIntent);
    });
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
    BloodEffects.enabled.removeListener(_onBloodEffectsChanged);
    _choreoTick.dispose();
    _fxTick.dispose();
    _uiTick.dispose();
    _contactTick.dispose();
    super.dispose();
  }

  /// Remove ongoing and historical gore immediately, even when Settings
  /// covers this route. Enabling again affects future hits only; old stains
  /// and cancelled bursts must not return. Body bands observe the same
  /// preference independently, preserving their normal narrow rebuilds.
  void _onBloodEffectsChanged() {
    if (BloodEffects.enabled.value) return;
    _fxUpdate(() {
      _fx.removeWhere((fx) => fx.kind == _FxKind.blood);
      _stains.clear();
    });
  }

  void _spawnPop(int amount, {required bool onPlayer, bool blocked = false}) {
    _fxUpdate(() {
      // Lowest lane free on this side (C0-03): numbers alive together sit
      // side by side instead of printing over each other.
      final used = {
        for (final p in _pops)
          if (p.onPlayer == onPlayer) p.lane,
      };
      var lane = 0;
      while (used.contains(lane)) {
        lane++;
      }
      _pops.add(
        _Pop(
          _popId++,
          amount,
          onPlayer: onPlayer,
          blocked: blocked,
          lane: lane,
        ),
      );
    });
  }

  void _spawnFx(
    _FxKind kind, {
    required bool onPlayer,
    Color color = EmberColors.gold,
    ContactShape? shape,
  }) {
    _fxUpdate(
      () => _fx.add(
        _Fx(_fxId++, kind, onPlayer: onPlayer, color: color, shape: shape),
      ),
    );
  }

  /// Bodies in the Fight: a landed hit bleeds. [severity] is damage over the
  /// victim's max HP; the burst flies away from the attacker and leaves
  /// stains on the floor for the rest of the encounter.
  void _spawnBlood(double severity, {required bool onPlayer}) {
    if (!BloodEffects.enabled.value) return;
    final ichor = onPlayer
        ? Ichor.blood
        : ichorFor((_enemy?['id'] as String?) ?? '', player: false);
    _fxUpdate(
      () => _fx.add(
        _Fx(
          _fxId++,
          _FxKind.blood,
          onPlayer: onPlayer,
          color: EmberColors.danger,
          severity: severity.clamp(0.0, 1.0),
          ichor: ichor,
          seed: _hitSeed++,
        ),
      ),
    );
  }

  /// Keep the floor stains a burst reports, translating from the burst box
  /// (victim-anchored) into stage fractions. Capped so a long fight never
  /// paints without bound.
  void _keepStains(List<FloorStain> landed, {required bool onPlayer}) {
    if (!BloodEffects.enabled.value || landed.isEmpty || !mounted) return;
    _fxUpdate(() {
      for (final s in landed) {
        // Burst boxes sit at the stage's left (player) or right (enemy)
        // edge and span ~35% of its width; map into 0..1 of the stage.
        final x = onPlayer ? s.x * 0.36 : 0.64 + s.x * 0.36;
        _stains.add(FloorStain(x.clamp(0.0, 1.0), s.r, s.ichor));
      }
      while (_stains.length > _maxStains) {
        _stains.removeAt(0);
      }
    });
  }

  /// LFP-2a: what assigning [selected] to [action] will resolve for (or -1
  /// when the action is invalid for that die). Thin wrapper over the public
  /// [assignPreview] so the drift guard in test/feel_pregate_test.dart can
  /// pin the shared function against the sim's own die_assigned values.
  int _assignPreview(Map player, Map enemy, int die, String action) =>
      assignPreview(player, enemy, widget.c.state?['run'] as Map?, die, action);

  /// Weapon choreography rides the existing squash/lunge flags: pull back in
  /// anticipation, whip through the smear arc during the lunge.
  WeaponPhase get _weaponPhase => _playerSquash
      ? WeaponPhase.raise
      : _playerLunge
      ? WeaponPhase.swing
      : _playerBraced
      ? WeaponPhase.guard
      : WeaponPhase.idle;

  /// Bodies in the Fight: the delver holds a guard stance for as long as
  /// block is actually up — data-derived, so the pose and the number never
  /// disagree. Never during their own swing.
  bool get _playerBraced {
    final player = _shownPlayer(widget.c.state?['player'] as Map? ?? const {});
    return ((player['block'] as int?) ?? 0) > 0;
  }

  bool get _enemyBraced => ((_shownEnemy?['block'] as int?) ?? 0) > 0;

  /// The selected die's face and size (null when nothing usable is selected).
  (int, int)? get _selectedFace {
    final st = widget.c.state;
    final player = st?['player'] as Map?;
    final rolled = (player?['rolled'] as List?)?.cast<int>();
    final ids = (player?['dice'] as List?)?.cast<String>();
    final sel = selected;
    if (rolled == null || sel == null || sel > rolled.length) return null;
    final id = ids != null && sel <= ids.length ? ids[sel - 1] : 'd6';
    // Tempered custom_N IDs have no numeric size in their name. Resolve the
    // same catalog base the sim/tray use; a marked d12 is not a fallback d6.
    final size = resolveRunDie(st?['run'] as Map?, id).def.size;
    return (rolled[sel - 1], size);
  }

  /// Selected die pips -> weapon heat (0..1). Keeps glowing through the
  /// swing (selection is cleared after apply, but the lunge should stay hot).
  double get _weaponCharge {
    if (_playerSquash || _playerLunge) return _lastSwingCharge;
    final face = _selectedFace;
    if (face == null) return 0.0;
    // Heat is read against the die's OWN size (a max d4 is white-hot), not
    // the old fixed /12 that left small dice permanently cold.
    return heatFor(face.$1, face.$2);
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
    _fxUpdate(() {
      var slot = 0;
      if (onEnemy) {
        // Experimental loop C0-03: enemy call-outs own a fixed stage slot
        // for life. With every slot busy the oldest yields its slot now —
        // two call-outs never share one.
        final slots = _readoutPlan?.slots.length ?? 1;
        final live = _notes.where((n) => n.onEnemy).toList();
        final used = {for (final n in live) n.slot};
        slot = List.generate(slots, (i) => i).firstWhere(
          (i) => !used.contains(i),
          orElse: () {
            final oldest = live.first;
            _notes.remove(oldest);
            return oldest.slot.clamp(0, slots - 1);
          },
        );
      }
      _notes.add(
        _Note(
          _noteId++,
          text,
          color,
          icon,
          onEnemy: onEnemy,
          life: life,
          slot: slot,
        ),
      );
    });
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

  /// v0.10.0: forward a processed event batch — and the freshly telegraphed
  /// enemy intent — to the tip director. Each contextual tip fires at its
  /// first-contact moment, once ever (lib/game/tips.dart). One tip at a
  /// time; a suppressed trigger simply recurs at the next natural moment.
  void _maybeTip(List<Map<String, Object?>> events) {
    final d = widget.c.tipDirector;
    var tip = d.onEvents(events);
    final rawIntent = (widget.c.state?['enemy'] as Map?)?['intent'];
    final intent = rawIntent is Map
        ? rawIntent.map((k, v) => MapEntry('$k', v as Object?))
        : null;
    if (tip == null && intent != null) tip = d.onIntent(intent);
    if (tip != null) {
      _ui(() {});
      return;
    }
    _maybeSpeakBadge(intent);
  }

  /// v0.180.0 The Spoken Badge: a response-puzzle intent (charge, counter,
  /// stagger, attack+block) speaks its own explain call-out the first time
  /// it is ever declared — the same words the long-press gives, unasked.
  /// Quiet while a tip card, a tour beat or the how-to-play deck is on
  /// screen; the kind recurs, so it speaks at its next declaration instead.
  /// Called after every processed batch and once after the stage settles on
  /// fight start (the opening intent is declared before the first roll).
  void _maybeSpeakBadge(Map<String, Object?>? intent) {
    if (!mounted || intent == null) return;
    if (widget.c.tour.active != null || _tutStep >= 0) return;
    if (widget.c.tipDirector.onIntentDeclared(intent) != null) {
      widget.c.spokenBadgeFired();
      _explainIntent(intent);
    }
  }

  Map<String, Object?>? get _declaredIntent {
    final raw = (widget.c.state?['enemy'] as Map?)?['intent'];
    return raw is Map ? raw.map((k, v) => MapEntry('$k', v as Object?)) : null;
  }

  /// LFP-3b: long-press tooltips — name what a badge means in one 2s
  /// call-out (reuses the existing note primitive; zero new systems).
  void _explainIntent(Map intent) {
    final text = switch (intent['kind']) {
      'attack' => 'NEXT MOVE: ATTACK ${intent['amount']} — AS SHOWN',
      'block' => 'NEXT MOVE: BLOCK ${intent['amount']} — AS SHOWN',
      'attack_block' =>
        'NEXT MOVE: ATTACK ${intent['amount']} + BLOCK ${intent['block']}',
      'charge' =>
        'CHARGING ${intent['amount']} — DEAL ${intent['threshold']} TO BREAK',
      'counter' => 'COUNTERING — EACH STRIKE COSTS ${intent['amount']}',
      'stagger' => 'STAGGERED — IT DOES NOTHING',
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
    _maybeTip(events);
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
    _ui(() => _ffwd = _ffwd + 1);
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
    // Bodies in the Fight: author THIS swing from the weapon family and the
    // die's tier against its own size. Frozen here so body, weapon and
    // contact shape agree even though `selected` clears on apply.
    final face = _selectedFace;
    _playerPlan = planStrike(
      familyForWeapon(weaponFor(_characterId).id),
      face == null ? DieTier.mid : tierFor(face.$1, face.$2),
    );
    final plan = _playerPlan;
    // LFP-2a: capture the chip's slot geometry before the apply dims it.
    final assignedDie = selected!;
    final ghostFrom = _chipKeys[assignedDie] != null
        ? _centerOf(_chipKeys[assignedDie]!)
        : null;
    // Boss deaths get a longer hold: the kill moment below needs the stage.
    final isBoss = _enemy?['boss'] == true;
    _beginPresentation();
    final events = widget.c.apply({
      'type': 'assign',
      'die': selected,
      'action': 'attack',
    }, terminalHold: Duration(milliseconds: isBoss ? 1900 : 1300));
    selected = null;
    if (encounterEnds(events)) _ui(() => _encounterOver = true);
    // LFP-2c: remember what the die actually contributed (incl. modifiers).
    final da = _find(events, 'die_assigned');
    if (da != null) {
      widget.c.tourMoment(TourMoment.actionSpent);
      _assignedValue[da['die'] as int] = da['value'] as int;
      // LFP-2a: the die visibly travels to the verb it was spent on.
      _spawnGhost(assignedDie, 'attack', da['value'] as int, ghostFrom);
    }
    final dmg = _find(events, 'damage_dealt');
    if (dmg == null) {
      // invalid command (e.g. block-only die): no swing
      _busy = false;
      _finishPresentation();
      _ui(() {});
      return;
    }
    // Anticipation before the lunge (visuals.md #9): a heavy blow coils
    // longer, a light one flicks — the wind-up + travel envelope stays the
    // legacy 340 ms so every terminal hold still fits.
    _choreo(() => _playerSquash = true);
    await _sleep(_pace(plan.windupMs));
    if (!mounted) return;
    _audio?.playSfx('whoosh');
    _choreo(() {
      _playerSquash = false;
      _playerLunge = true;
    });
    await _sleep(_pace(plan.travelMs));
    if (!mounted) return;
    _present([
      dmg,
      ...events.where((e) => e['type'] == 'charge_broken'),
      if (_find(events, 'counter_struck') == null)
        ...events.where((e) => e['type'] == 'player_healed'),
    ]);
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
    final enemyMax = (_enemy?['max_hp'] as int?) ?? 1;
    if (landed > 0) {
      _spawnFx(
        _FxKind.slash,
        onPlayer: false,
        color: weaponFor(_characterId).accent,
        shape: plan.contact,
      );
      // It bleeds what it is made of; a shield that ate part of the blow
      // leaves a smaller wound.
      _spawnBlood(landed / enemyMax, onPlayer: false);
    } else {
      _spawnFx(_FxKind.guard, onPlayer: false);
    }
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
      // v0.184.0 Clean Cut: the signature exact kill (a die spent for exactly
      // lethal damage) earns a distinct contact read — a crisp ember-white
      // ring + precise glint over the foe — so mastery is visible, not just a
      // number. Presentation-only and non-blocking: the death choreography's
      // timing is unchanged; overkills and ordinary kills are untouched.
      _spawnFx(_FxKind.cleanCut, onPlayer: false, color: EmberColors.gold);
      _note(
        '+${exact['embers']} EMBERS — EXACT!',
        icon: Icons.local_fire_department,
        onEnemy: true,
      );
    }
    // C0-12: the surplus splashes into the NEXT foe — a run-ending kill
    // has none, so it gets no promise.
    final overText = overkillCallout(events, bossKill: isBoss);
    if (overText != null) {
      _note(
        overText,
        color: EmberColors.ember,
        icon: Icons.double_arrow,
        onEnemy: true,
      );
    }
    // v0.47.0 response puzzles: the break pays off loudly, the riposte
    // stings visibly (both fire during the PLAYER's strike, so they join
    // this choreography rather than the end-turn one).
    if (_find(events, 'charge_broken') != null) {
      _audio?.playSfx('block', volume: 0.7);
      Haptics.medium();
      _note(
        'CHARGE BROKEN!',
        color: EmberColors.ember,
        icon: Icons.flash_off,
        onEnemy: true,
      );
      // v0.180.0 The Spoken Badge: the break is the only moment a stagger
      // is ever declared (no foe patterns one), so its first-contact words
      // ride the break call-out — once, then never.
      _maybeSpeakBadge(_declaredIntent);
    }
    final counter = _find(events, 'counter_struck');
    if (counter != null) {
      _present([counter]);
      final cDmg = counter['damage'] as int? ?? 0;
      _audio?.playSfx(cDmg <= 0 ? 'block' : 'player_hit', volume: 0.8);
      Haptics.light();
      _spawnPop(cDmg, onPlayer: true, blocked: cDmg <= 0);
      if (cDmg > 0) {
        _spawnFx(_FxKind.claws, onPlayer: true, color: EmberColors.danger);
        final playerMax =
            ((widget.c.state?['player'] as Map?)?['max_hp'] as int?) ?? 1;
        _spawnBlood(cDmg / playerMax, onPlayer: true);
      } else {
        _spawnFx(_FxKind.guard, onPlayer: true);
      }
      _note(
        cDmg <= 0 ? 'RIPOSTE BLOCKED' : 'RIPOSTE $cDmg',
        color: cDmg <= 0 ? EmberColors.block : EmberColors.danger,
        icon: Icons.sync_alt,
      );
      _present(events.where((e) => e['type'] == 'player_healed'));
      if (_find(events, 'encounter_lost') != null) {
        _audio?.playSfx('defeat');
        Haptics.heavy();
        _choreo(() {
          _playerFlash = false;
          _playerDying = true;
        });
        // Run-ending moment keeps its weight (mirrors the end-turn path).
        await _sleep(const Duration(milliseconds: 800));
        if (!mounted) return;
      }
    }
    if (_find(events, 'encounter_won') != null) {
      await _enemyDeath(events);
    } else {
      await _sleep(_flashTail);
      _choreo(() => _enemyFlash = false);
    }
    _busy = false;
    _finishPresentation();
    _ui(() {});
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
    _ui(() => selected = null);
    // LFP-2c: remember what the die actually contributed (incl. modifiers).
    final da = _find(events, 'die_assigned');
    if (da != null) {
      widget.c.tourMoment(TourMoment.actionSpent);
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
    _ui(() {
      selected = null;
      _rerollMode = false;
      _rerollSel.clear();
    });
    _beginPresentation();
    final events = widget.c.apply({
      'type': 'end_turn',
    }, terminalHold: const Duration(milliseconds: 1450));
    if (encounterEnds(events)) _ui(() => _encounterOver = true);
    final atk = _find(events, 'enemy_attacked');
    if (atk != null) {
      // Bodies in the Fight: the body type chooses the attack — a rat coils
      // and springs, a boss drops its mass, a wisp darts.
      _enemyPlan = planEnemyStrike(
        enemyStyleFor(
          (_enemy?['id'] as String?) ?? '',
          boss: _enemy?['boss'] == true,
          elite: _enemy?['elite'] == true,
        ),
      );
      final plan = _enemyPlan;
      // Physical wind-up: the enemy leans back and darkens for a beat before
      // the lunge — the strike telegraphs in the body, not just the badge.
      _choreo(() => _enemySquash = true);
      await _beat(_pace(plan.windupMs));
      if (!mounted) return;
      _audio?.playSfx('whoosh');
      _choreo(() {
        _enemySquash = false;
        _enemyLunge = true;
      });
      await _beat(_pace(plan.travelMs));
      if (!mounted) return;
      _present([atk, ...events.where((e) => e['type'] == 'thorns_dealt')]);
      final damage = atk['damage'] as int? ?? 0;
      final absorbed = atk['blocked'] as int? ?? 0;
      _audio?.playSfx(damage <= 0 ? 'block' : 'player_hit');
      Haptics.medium();
      _spawnPop(damage, onPlayer: true, blocked: damage <= 0);
      final playerMaxHp =
          ((widget.c.state?['player'] as Map?)?['max_hp'] as int?) ?? 1;
      // Contact frame: claws rake the delver (and the delver bleeds) — or
      // the blow breaks on the guard when block eats the whole hit.
      if (damage > 0) {
        _spawnFx(
          _FxKind.claws,
          onPlayer: true,
          color: EmberColors.danger,
          shape: plan.contact,
        );
        _spawnBlood(damage / playerMaxHp, onPlayer: true);
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
      _present(events.where((e) => e['type'] == 'enemy_blocked'));
      _audio?.playSfx('block', volume: 0.5);
      _spawnFx(_FxKind.guard, onPlayer: false); // its shield visibly comes up
    } else if (_find(events, 'enemy_staggered') != null) {
      // v0.47.0: the broken charge fizzles — the payoff beat for the break.
      _note(
        'STAGGERED',
        color: EmberColors.textDim,
        icon: Icons.hourglass_empty,
        onEnemy: true,
      );
      await _beat(const Duration(milliseconds: 350));
    }
    // Burn ticks after the enemy acts: flame call-out + damage pop reusing
    // the existing pop primitive (m4 contract §3).
    final burnTick = _find(events, 'burn_tick');
    if (burnTick != null && mounted) {
      _present([burnTick]);
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
    _maybeTip(events);
    // Thorns relics and burn can kill the enemy during its own turn.
    // (Death choreography keeps its full length — the kill is the payoff.)
    if (mounted) await _enemyDeath(events);
    _busy = false;
    _resolving = false;
    _finishPresentation();
    _ui(() {});
    _drainQueue();
  }

  /// Room for the fade/fold strip below the last visible tray row.
  static const _trayPeek = 26.0;

  /// Everything the HUD reads, derived from LIVE sim state plus this frame's
  /// media metrics. Every scoped section calls this when it rebuilds, so no
  /// section can render from another section's snapshot; null means there is
  /// nothing to draw (no sim, or no enemy has ever been seen).
  _Hud? _hud(BuildContext context) {
    final st = widget.c.state;
    if (st == null) return null;
    final liveEnemy = st['enemy'] as Map?;
    if (liveEnemy != null) {
      if (_enemy != null && liveEnemy['id'] != _enemy!['id']) {
        _stains.clear(); // a new foe fights on clean ground
      }
      // Do not overwrite contact-derived corpse/guard state with a
      // post-resolution snapshot while a presentation is still playing.
      if (_presentation == null) _enemy = Map<String, Object?>.from(liveEnemy);
    }
    final run = st['run'] as Map?;
    if (run != null && run['character'] is String) {
      _characterId = run['character'] as String;
    }
    final enemy = _shownEnemy;
    final livePlayer = st['player'] as Map?;
    final player = livePlayer == null ? null : _shownPlayer(livePlayer);
    if (enemy == null || player == null) return null;
    final dice0 = (player['dice'] as List).cast<String>();

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
    // fold pill signals the overflow when it truly must scroll.
    final trayWidth = MediaQuery.sizeOf(context).width - 2 * Space.l;
    final chipScale = dice0.length > (compact ? 4 : 8) ? 0.75 : 1.0;
    final chipW = 64 * chipScale + Space.s;
    final chipH = 80 * chipScale;
    final perRow = math.max(1, ((trayWidth + Space.s) / chipW).floor());
    final rowsNeeded = math.max(1, (dice0.length / perRow).ceil());
    // Whole rows only, inside the same height budget the tray always had
    // (112/256) so the stage never loses more space than before; the fold
    // strip borrows from the budget when the tray truly scrolls.
    final trayBudget = compact ? 112.0 : 256.0;
    final rowH = chipH + Space.s;
    int fitRows(double budget) =>
        math.max(1, ((budget + Space.s) / rowH).floor());
    var visRows = math.min(rowsNeeded, fitRows(trayBudget));
    var trayScrolls = rowsNeeded > visRows;
    if (trayScrolls) {
      visRows = math.min(rowsNeeded, fitRows(trayBudget - _trayPeek));
      trayScrolls = rowsNeeded > visRows;
    }
    // Viewport height is EXACTLY whole rows — the scroll view clips at a row
    // boundary, so no half-cut dice ever bleed through (screenshot review
    // 2026-07-24: the old fade-over-peek let row 2 show as clipped grey dice).
    final trayViewH = visRows * chipH + (visRows - 1) * Space.s;

    return _Hud(
      st: st,
      enemy: enemy,
      player: player,
      intent:
          (enemy['intent'] as Map?) ?? const {'kind': 'attack', 'amount': 0},
      turn: _presentation?.turn ?? st['turn'] as int? ?? 0,
      rolled: (player['rolled'] as List?)?.cast<int>(),
      assigned: (player['assigned'] as Map?) ?? const {},
      maxed: (player['rolled_max'] as List?)?.cast<bool>(),
      dice0: dice0,
      rerolls: player['rerolls_left'] as int? ?? 0,
      riskyUsed: player['risky_used'] == true,
      freeReroll: player['free_reroll'] == true,
      enemyHp: (enemy['hp'] as int).clamp(0, enemy['max_hp'] as int),
      compact: compact,
      maxHudScale: maxHudScale,
      chipScale: chipScale,
      trayViewH: trayViewH,
      trayScrolls: trayScrolls,
      hiddenDice: math.max(0, dice0.length - visRows * perRow),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = _hud(context);
    if (h == null) return const SizedBox.shrink();
    final st = h.st;
    final enemy = h.enemy;
    final compact = h.compact;
    final maxHudScale = h.maxHudScale;

    // Scoped sections (perf, v0.3.15). Each band listens to the controller
    // ticks its own content reads and recomputes [_hud] from live state when
    // it rebuilds — rolling dice no longer repaints the top bar, the enemy
    // panel or the sprite stage, which read none of it.
    final combat = Column(
      children: [
        _band(_runBand, (context, h) => _TopBar(widget.c)),
        _band(_enemyBand, _enemyPanel),
        Expanded(child: _band(_stageBand, _stageSection)),
        _band(_vitalsBand, _playerVitals),
        SizedBox(height: compact ? Space.s : Space.m),
        _band(_diceBand, (c, h) => _inertIfOver(_traySection(c, h))),
        SizedBox(height: compact ? Space.s : Space.m),
        _band(_diceBand, (c, h) => _inertIfOver(_actionZone(c, h))),
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
                              _fxUpdate(() => _ghosts.remove(g));
                              // Arrival pulse on the verb button.
                              _ui(() {
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
                      ],
                    ),
                  ),
                ),
              ),
              if (_splash) _NamePlate(enemy: enemy, layer: _currentLayer(st)),
              // Rebuilds with the dice band: tour moments fire inside _ui
              // scopes, which never reach this outer Stack on their own.
              AnimatedBuilder(
                animation: _diceBand,
                builder: (context, _) => _consumeTourReplay()
                    ? _TourOverlay(
                        beat: widget.c.tour.active!,
                        isInfo: widget.c.tour.activeIsInfo,
                        step: widget.c.tour.step,
                        total: widget.c.tour.total,
                        onAdvanceInfo: () => setState(widget.c.tourAdvanceInfo),
                        onSkip: () => setState(widget.c.tourSkip),
                      )
                    : const SizedBox.shrink(),
              ),
              // Tips stay quiet while the tour is on screen (tour.dart rule).
              if (!widget.c.tour.running &&
                  _tutStep < 0 &&
                  widget.c.tipDirector.active != null)
                _ContextTip(
                  id: widget.c.tipDirector.active!,
                  onDismiss: () => setState(widget.c.dismissTip),
                ),
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

  /// One scoped HUD section: rebuilt only when [band] fires, always from a
  /// freshly derived [_Hud] so a section can never render another section's
  /// snapshot. The RepaintBoundary keeps a section's repaint inside its band.
  Widget _band(Listenable band, Widget Function(BuildContext, _Hud) build) =>
      RepaintBoundary(
        child: ListenableBuilder(
          listenable: band,
          builder: (context, _) {
            final h = _hud(context);
            return h == null ? const SizedBox.shrink() : build(context, h);
          },
        ),
      );

  /// C1-01: once the encounter is decided the controls stop inviting input
  /// — dimmed and inert from the same frame, so the kill reads as the end.
  Widget _inertIfOver(Widget child) => IgnorePointer(
    ignoring: _encounterOver,
    child: Opacity(opacity: _encounterOver ? 0.35 : 1.0, child: child),
  );

  /// Layer of the node the delver stands on (for the boss name-plate).
  int _currentLayer(Map st) {
    final map = st['map'] as Map?;
    if (map == null) return 1;
    final nodes = (map['nodes'] as Map?)?.cast<String, Map>();
    final pos = map['position'];
    return (nodes?['$pos']?['layer'] as int?) ?? 1;
  }

  /// Restart the combat tutorial (band extensions cannot call the
  /// protected [setState] directly).
  void _restartTutorial() => setState(() => _tutStep = 0);

  /// Settings-requested replay: swap in a replay director the first combat
  /// frame after the request, then fall through to the normal running check.
  bool _consumeTourReplay() {
    if (TourDirector.replayRequested) {
      TourDirector.replayRequested = false;
      widget.c.requestTourReplay();
    }
    return widget.c.tour.running;
  }
}
