// lib/ui/screens.dart — every screen, routed by sim.phase. Screens render only
// from controller.state() and never poke sim internals. Layout is portrait,
// one-thumb: the primary action lives in the bottom zone on every screen.
import 'dart:async';
import 'package:flutter/material.dart';
import '../audio/audio_service.dart';
import '../data/characters.dart';
import '../data/dice.dart';
import '../data/events.dart';
import '../data/relics.dart';
import '../game/controller.dart';
import 'art.dart';
import 'settings_screen.dart';
import 'sprites.dart';
import 'theme.dart';
import 'widgets.dart';

class GameRoot extends StatelessWidget {
  final GameController c;
  const GameRoot(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        // surface flash toasts after the frame
        final f = c.flash;
        if (f != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) showFlash(context, f);
            c.flash = null;
          });
        }
        final phase = c.phase;
        Widget screen;
        switch (phase) {
          case 'map':
            screen = MapScreen(c);
            break;
          case 'player_turn':
            screen = CombatScreen(c);
            break;
          case 'reward':
            screen = RewardScreen(c);
            break;
          case 'rest':
            screen = RestScreen(c);
            break;
          case 'shop':
            screen = ShopScreen(c);
            break;
          case 'event':
            screen = EventScreen(c);
            break;
          case 'run_won':
          case 'run_lost':
            screen = SummaryScreen(c);
            break;
          default:
            screen = TitleScreen(c);
        }
        final enemy = c.state?['enemy'] as Map?;
        final bossFight = enemy != null &&
            (enemy['boss'] == true || enemy['elite'] == true);
        return Scaffold(
          body: ScreenBackground(
            asset: Art.backgroundForPhase(phase, bossFight: bossFight),
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                    key: ValueKey(phase ?? 'title'), child: screen),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Title
// ---------------------------------------------------------------------------
class TitleScreen extends StatelessWidget {
  final GameController c;
  const TitleScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final m = c.meta;
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(children: [
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            icon: const Icon(Icons.settings,
                color: EmberColors.textDim, size: 26),
            tooltip: 'Settings',
            onPressed: () {
              AudioService.instance?.playSfx('ui_tap');
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SettingsScreen()));
            },
          ),
        ),
        const Spacer(),
        Text('EMBERDELVE', style: EmberText.display, textAlign: TextAlign.center),
        const SizedBox(height: Space.s),
        Text('A dice-builder delve into the dark',
            style: EmberText.bodyDim, textAlign: TextAlign.center),
        const SizedBox(height: Space.xxl),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ResourcePip(Icons.local_fire_department, EmberColors.ember,
              m.embers, 'EMBERS',
              imageAsset: Art.currencyEmber),
          const SizedBox(width: Space.xl),
          _statText('${m.runsWon}/${m.runsPlayed}', 'WINS'),
        ]),
        const Spacer(),
        // Primary CTA in the thumb zone.
        SizedBox(
          width: double.infinity,
          child: EmberButton('Delve',
              primary: true,
              icon: Icons.bolt,
              onTap: () => c.startRun(character: defaultCharacter)),
        ),
        const SizedBox(height: Space.m),
        SizedBox(
          width: double.infinity,
          child: EmberButton('Choose a delver',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CharacterScreen(c)))),
        ),
      ]),
    );
  }

  Widget _statText(String v, String l) => Column(mainAxisSize: MainAxisSize.min,
          children: [
            Text(v, style: EmberText.value.copyWith(fontSize: 18)),
            Text(l, style: EmberText.micro),
          ]);
}

// ---------------------------------------------------------------------------
// Character select + unlocks (endowed-progress toward the cheapest lock)
// ---------------------------------------------------------------------------
class CharacterScreen extends StatefulWidget {
  final GameController c;
  const CharacterScreen(this.c, {super.key});
  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  int ascension = 0;
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final m = c.meta;
    final maxAsc = m.bestAscension.clamp(0, 20);
    return Scaffold(
      appBar: AppBar(
          title: Text('Choose a delver', style: EmberText.h2),
          backgroundColor: EmberColors.bg,
          leading: BackButton(onPressed: () {
            AudioService.instance?.playSfx('ui_back');
            Navigator.of(context).pop();
          })),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Space.l), children: [
          _nextUnlockBar(m),
          const SizedBox(height: Space.l),
          for (final id in charactersOrder) _charCard(context, id),
          const SizedBox(height: Space.l),
          Text('ASCENSION', style: EmberText.micro),
          const SizedBox(height: Space.s),
          Text('Higher rungs make every enemy hit harder. Unlock the next by '
              'winning at the current one.', style: EmberText.bodyDim),
          const SizedBox(height: Space.s),
          Row(children: [
            IconButton(
                onPressed: ascension > 0
                    ? () => setState(() => ascension--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline)),
            Text('$ascension', style: EmberText.value),
            IconButton(
                onPressed: ascension < maxAsc
                    ? () => setState(() => ascension++)
                    : null,
                icon: const Icon(Icons.add_circle_outline)),
            const SizedBox(width: Space.s),
            Text('max unlocked: $maxAsc', style: EmberText.bodyDim),
          ]),
        ]),
      ),
    );
  }

  Widget _nextUnlockBar(m) {
    final target = m.nextUnlockTarget;
    if (target == null) {
      return Panel(child: Text('All delvers unlocked.', style: EmberText.body));
    }
    final frac = (m.embers / target.unlockEmbers).clamp(0.0, 1.0);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NEXT UNLOCK — ${target.name.toUpperCase()}',
            style: EmberText.micro),
        const SizedBox(height: Space.s),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(children: [
            Container(height: 12, color: EmberColors.raised),
            FractionallySizedBox(
                widthFactor: frac,
                child: Container(height: 12, color: EmberColors.ember)),
          ]),
        ),
        const SizedBox(height: Space.s),
        Text('${m.embers} / ${target.unlockEmbers} embers',
            style: EmberText.bodyDim),
      ]),
    );
  }

  Widget _charCard(BuildContext context, String id) {
    final c = widget.c;
    final def = characters[id]!;
    final unlocked = c.meta.isUnlocked(id);
    final canAfford = c.meta.embers >= def.unlockEmbers;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Static portrait frame from the character sheet (idle frame 0);
            // animation stays reserved for the combat stage.
            Opacity(
              opacity: unlocked ? 1 : 0.45,
              child: SpriteView(id, height: 56, animate: false),
            ),
            const SizedBox(width: Space.m),
            Expanded(child: Text(def.name, style: EmberText.h2)),
            if (!unlocked)
              Row(children: [
                const Icon(Icons.lock, size: 14, color: EmberColors.textDim),
                const SizedBox(width: 4),
                Text('${def.unlockEmbers}', style: EmberText.label),
              ]),
          ]),
          const SizedBox(height: Space.xs),
          Text(def.text, style: EmberText.bodyDim),
          const SizedBox(height: Space.s),
          Text('${def.maxHp} HP · ${def.startDice.map((d) => dieDef(d).name).join(", ")}',
              style: EmberText.micro),
          const SizedBox(height: Space.m),
          SizedBox(
            width: double.infinity,
            child: unlocked
                ? EmberButton('Delve as ${def.name}',
                    primary: id == defaultCharacter,
                    onTap: () {
                      Navigator.of(context).pop();
                      c.startRun(character: id, ascension: ascension);
                    })
                : EmberButton(
                    canAfford ? 'Unlock (${def.unlockEmbers} embers)' : 'Locked',
                    onTap: canAfford
                        ? () {
                            c.unlock(id);
                            setState(() {});
                          }
                        : null),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map
// ---------------------------------------------------------------------------
class MapScreen extends StatelessWidget {
  final GameController c;
  const MapScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = c.state!;
    final map = st['map'] as Map;
    final nodes = (map['nodes'] as Map).cast<String, Map>();
    final edges = (map['edges'] as Map).cast<String, List>();
    final layers = map['layers'] as int;
    final position = map['position'] as int;
    final reachable =
        (edges['$position'] as List).cast<int>().toSet();
    final run = st['run'] as Map;

    return Column(children: [
      _TopBar(c),
      Expanded(
        child: LayoutBuilder(builder: (context, cns) {
          return SingleChildScrollView(
            reverse: true,
            child: SizedBox(
              height: layers * 96.0 + 40,
              width: cns.maxWidth,
              child: CustomPaint(
                painter: _EdgePainter(nodes, edges, cns.maxWidth, layers),
                child: Stack(
                  children: [
                    for (final e in nodes.entries)
                      _nodeWidget(context, e.value, cns.maxWidth, layers,
                          position, reachable),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
      Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Text('Tap a glowing node to advance · Pool: ${(st['player'] as Map)['dice'].length} dice · ${(run['relics'] as List).length} relics',
            style: EmberText.micro, textAlign: TextAlign.center),
      ),
    ]);
  }

  Widget _nodeWidget(BuildContext context, Map node, double w, int layers,
      int position, Set<int> reachable) {
    final id = node['id'] as int;
    final layer = node['layer'] as int;
    final x = (node['x'] as num).toDouble();
    final kind = node['kind'] as String;
    final left = 28 + x * (w - 56 - 44);
    final bottom = (layer - 1) * 96.0 + 20;
    final isReachable = reachable.contains(id);
    final isHere = id == position;
    return Positioned(
      left: left,
      bottom: bottom,
      child: Opacity(
        opacity: isReachable || isHere ? 1 : 0.45,
        child: GestureDetector(
          onTap: isReachable
              ? () => c.apply({'type': 'choose_node', 'node': id})
              : null,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: EmberColors.kind(kind),
              shape: BoxShape.circle,
              border: Border.all(
                  color: isHere
                      ? EmberColors.textPrimary
                      : isReachable
                          ? EmberColors.ember
                          : EmberColors.line,
                  width: isHere || isReachable ? 2.5 : 1),
              boxShadow: isReachable
                  ? [
                      BoxShadow(
                          color: EmberColors.ember.withValues(alpha: 0.5),
                          blurRadius: 12)
                    ]
                  : null,
            ),
            child: Center(child: _nodeIcon(kind)),
          ),
        ),
      ),
    );
  }
}

/// Painted node icon when we have one; material glyph fallback (start node).
Widget _nodeIcon(String kind) {
  final asset = Art.nodeIcons[kind];
  if (asset == null) {
    return Icon(_kindIcon(kind), size: 20, color: Colors.white);
  }
  return Image.asset(asset,
      width: 26, height: 26, filterQuality: FilterQuality.medium);
}

IconData _kindIcon(String kind) {
  switch (kind) {
    case 'start':
      return Icons.play_arrow;
    case 'fight':
      return Icons.sports_martial_arts;
    case 'elite':
      return Icons.whatshot;
    case 'rest':
      return Icons.local_fire_department;
    case 'shop':
      return Icons.storefront;
    case 'event':
      return Icons.help_outline;
    case 'boss':
      return Icons.dangerous;
  }
  return Icons.circle;
}

class _EdgePainter extends CustomPainter {
  final Map<String, Map> nodes;
  final Map<String, List> edges;
  final double w;
  final int layers;
  _EdgePainter(this.nodes, this.edges, this.w, this.layers);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = EmberColors.line
      ..strokeWidth = 2;
    Offset pos(Map n) {
      final x = (n['x'] as num).toDouble();
      final layer = n['layer'] as int;
      return Offset(28 + x * (w - 56 - 44) + 22,
          size.height - ((layer - 1) * 96.0 + 20 + 22));
    }

    edges.forEach((k, v) {
      final from = nodes[k]!;
      for (final t in v.cast<int>()) {
        canvas.drawLine(pos(from), pos(nodes['$t']!), paint);
      }
    });
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => false;
}

// ---------------------------------------------------------------------------
// Combat
// ---------------------------------------------------------------------------
class CombatScreen extends StatefulWidget {
  final GameController c;
  const CombatScreen(this.c, {super.key});
  @override
  State<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends State<CombatScreen> {
  int? selected; // 1-based die index
  bool _busy = false; // input lock while a choreography sequence plays

  // Choreography flags (attack = lunge tween + hit-flash + knockback;
  // death = flash + fade/collapse — the sheets have no attack/death frames).
  bool _playerLunge = false, _enemyLunge = false;
  bool _playerFlash = false, _enemyFlash = false;
  bool _playerKnock = false, _enemyKnock = false;
  bool _playerDying = false, _enemyDying = false;

  // Cached combat view-model: during the end-of-encounter notify hold the sim
  // has already left combat (enemy == null), but we keep rendering the stage.
  Map? _enemy;
  String _characterId = defaultCharacter;

  // SYNC_POINTS.md: whoosh starts ~2 frames (8 fps => 250 ms) before contact.
  static const _contact = Duration(milliseconds: 250);
  static const _knockTime = Duration(milliseconds: 140);
  static const _flashTail = Duration(milliseconds: 120);
  static const _deathTime = Duration(milliseconds: 700);

  AudioService? get _audio => widget.c.audio;

  Map<String, Object?>? _find(List<Map<String, Object?>> events, String type) {
    for (final e in events) {
      if (e['type'] == type) return e;
    }
    return null;
  }

  Future<void> _sleep(Duration d) => Future.delayed(d);

  Future<void> _enemyDeath(List<Map<String, Object?>> events) async {
    if (_find(events, 'encounter_won') == null) return;
    _audio?.playSfx(_enemy?['boss'] == true ? 'boss_death' : 'enemy_death');
    if (!mounted) return;
    setState(() {
      _enemyFlash = false;
      _enemyDying = true;
    });
    await _sleep(_deathTime);
  }

  /// Player attack: lunge toward the enemy, whoosh leading contact by ~2
  /// frames, then enemy_hit/block + hit-flash + knockback on the contact
  /// frame; enemy_death/boss_death + fade-collapse if the blow kills.
  Future<void> _attack() async {
    if (_busy || selected == null) return;
    _busy = true;
    final events = widget.c.apply(
        {'type': 'assign', 'die': selected, 'action': 'attack'},
        terminalHold: const Duration(milliseconds: 1300));
    selected = null;
    final dmg = _find(events, 'damage_dealt');
    if (dmg == null) {
      // invalid command (e.g. block-only die): no swing
      _busy = false;
      if (mounted) setState(() {});
      return;
    }
    _audio?.playSfx('whoosh');
    setState(() => _playerLunge = true);
    await _sleep(_contact);
    if (!mounted) return;
    final amount = dmg['amount'] as int? ?? 0;
    final absorbed = dmg['blocked'] as int? ?? 0;
    _audio?.playSfx(absorbed >= amount ? 'block' : 'enemy_hit');
    setState(() {
      _enemyFlash = true;
      _enemyKnock = true;
    });
    await _sleep(_knockTime);
    if (!mounted) return;
    setState(() {
      _playerLunge = false;
      _enemyKnock = false;
    });
    if (_find(events, 'encounter_won') != null) {
      await _enemyDeath(events);
    } else {
      await _sleep(_flashTail);
      if (mounted) setState(() => _enemyFlash = false);
    }
    _busy = false;
    if (mounted) setState(() {});
  }

  void _block() {
    if (_busy || selected == null) return;
    widget.c.apply({'type': 'assign', 'die': selected, 'action': 'block'});
    setState(() => selected = null);
  }

  /// Enemy turn: mirrored choreography — enemy lunges, player_hit/block on
  /// contact, defeat sting + player fade-collapse if the run ends here.
  Future<void> _endTurn() async {
    if (_busy) return;
    _busy = true;
    setState(() => selected = null);
    final events = widget.c.apply({'type': 'end_turn'},
        terminalHold: const Duration(milliseconds: 1450));
    final atk = _find(events, 'enemy_attacked');
    if (atk != null) {
      _audio?.playSfx('whoosh');
      setState(() => _enemyLunge = true);
      await _sleep(_contact);
      if (!mounted) return;
      final damage = atk['damage'] as int? ?? 0;
      _audio?.playSfx(damage <= 0 ? 'block' : 'player_hit');
      setState(() {
        _playerFlash = true;
        _playerKnock = true;
      });
      await _sleep(_knockTime);
      if (!mounted) return;
      setState(() {
        _enemyLunge = false;
        _playerKnock = false;
      });
      if (_find(events, 'encounter_lost') != null) {
        _audio?.playSfx('defeat');
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
    }
    // Thorns relics can kill the enemy during its own turn.
    if (mounted) await _enemyDeath(events);
    _busy = false;
    if (mounted) setState(() {});
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
    final intent = (enemy['intent'] as Map?) ?? const {'kind': 'attack', 'amount': 0};
    final rerolls = player['rerolls_left'] as int? ?? 0;
    final enemyHp = (enemy['hp'] as int).clamp(0, enemy['max_hp'] as int);

    return Column(children: [
      _TopBar(c),
      // Enemy header: name + intent + HP
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.s),
        child: Panel(
          padding: const EdgeInsets.all(Space.m),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: Text(enemy['name'] as String,
                      style: EmberText.h2.copyWith(
                          color: enemy['boss'] == true
                              ? EmberColors.kindBoss
                              : enemy['elite'] == true
                                  ? EmberColors.kindElite
                                  : EmberColors.textPrimary))),
              _IntentBadge(intent),
            ]),
            const SizedBox(height: Space.s),
            StatBar(
                value: enemyHp,
                max: enemy['max_hp'] as int,
                block: enemy['block'] as int? ?? 0,
                color: EmberColors.danger,
                label: 'ENEMY HP · TURN ${st['turn']}'),
          ]),
        ),
      ),
      // The stage: hero (left) vs enemy (right), animated sprite loops.
      Expanded(child: _stage(enemy)),
      // Player HP
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        child: StatBar(
            value: (player['hp'] as int).clamp(0, player['max_hp'] as int),
            max: player['max_hp'] as int,
            block: player['block'] as int,
            color: EmberColors.hp,
            label: 'YOUR HP'),
      ),
      const SizedBox(height: Space.m),
      // Dice tray
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        child: Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 1; i <= dice0.length; i++)
              DieChip(dice0[i - 1],
                  value: rolled != null ? rolled[i - 1] : null,
                  assigned: assigned['$i'] != null,
                  selected: selected == i,
                  maxed: maxed != null && maxed[i - 1],
                  onTap: rolled == null || _busy
                      ? null
                      : () => setState(
                          () => selected = selected == i ? null : i))
          ],
        ),
      ),
      const SizedBox(height: Space.m),
      // Action zone (thumb reach)
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.l),
        child: rolled == null
            ? SizedBox(
                width: double.infinity,
                child: EmberButton('Roll',
                    primary: true,
                    icon: Icons.casino,
                    onTap: _busy
                        ? null
                        : () {
                            setState(() => selected = null);
                            c.apply({'type': 'roll'});
                          }))
            : Column(children: [
                Row(children: [
                  Expanded(
                      child: EmberButton('Attack',
                          icon: Icons.gps_fixed,
                          onTap: selected != null && !_busy ? _attack : null)),
                  const SizedBox(width: Space.m),
                  Expanded(
                      child: EmberButton('Block',
                          icon: Icons.shield,
                          onTap: selected != null && !_busy ? _block : null)),
                ]),
                const SizedBox(height: Space.m),
                Row(children: [
                  if (rerolls > 0)
                    Expanded(
                        child: EmberButton('Reroll ($rerolls)',
                            icon: Icons.replay,
                            onTap: selected != null && !_busy
                                ? () {
                                    c.apply({'type': 'reroll', 'die': selected});
                                    setState(() {});
                                  }
                                : null)),
                  if (rerolls > 0) const SizedBox(width: Space.m),
                  Expanded(
                      child: EmberButton('End turn',
                          primary: true,
                          onTap: _busy ? null : _endTurn)),
                ]),
              ]),
      ),
    ]);
  }

  /// Hero vs enemy, bottom-aligned; lunges slide the combatant toward the
  /// other side, knockback nudges away, death fades + sinks the sprite.
  Widget _stage(Map enemy) {
    final enemyId = enemy['id'] as String? ?? '';
    final big = enemy['boss'] == true || enemy['elite'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: _combatant(
              sprite: SpriteView(_characterId,
                  key: ValueKey('hero-$_characterId'), height: 104),
              lungeToward: 1,
              lunge: _playerLunge,
              knock: _playerKnock,
              flash: _playerFlash,
              dying: _playerDying,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: _combatant(
              sprite: SpriteView(enemyId,
                  key: ValueKey('enemy-$enemyId'),
                  height: big ? 128 : 96,
                  flipX: true),
              lungeToward: -1,
              lunge: _enemyLunge,
              knock: _enemyKnock,
              flash: _enemyFlash,
              dying: _enemyDying,
            ),
          ),
        ],
      ),
    );
  }

  Widget _combatant({
    required Widget sprite,
    required int lungeToward, // +1 lunges right, -1 lunges left
    required bool lunge,
    required bool knock,
    required bool flash,
    required bool dying,
  }) {
    Widget w = sprite;
    // Hit-flash: paint the sprite solid white for a beat.
    w = AnimatedSwitcher(
      duration: const Duration(milliseconds: 60),
      child: flash
          ? ColorFiltered(
              key: const ValueKey('flash'),
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcATop),
              child: w)
          : KeyedSubtree(key: const ValueKey('plain'), child: w),
    );
    // Death: fade out while sinking (collapse).
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

class _IntentBadge extends StatelessWidget {
  final Map intent;
  const _IntentBadge(this.intent);
  @override
  Widget build(BuildContext context) {
    final kind = intent['kind'];
    IconData icon;
    String text;
    Color color;
    switch (kind) {
      case 'attack':
        icon = Icons.gps_fixed;
        color = EmberColors.danger;
        text = '${intent['amount']}';
        break;
      case 'block':
        icon = Icons.shield;
        color = EmberColors.block;
        text = '${intent['amount']}';
        break;
      default: // attack_block
        icon = Icons.flash_on;
        color = EmberColors.kindElite;
        text = '${intent['amount']}/${intent['block']}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
      decoration: BoxDecoration(
          color: EmberColors.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: Space.xs),
        Text(text, style: EmberText.value.copyWith(fontSize: 18, color: color)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Reward — smart default (RECOMMENDED on the biggest upgrade)
// ---------------------------------------------------------------------------
class RewardScreen extends StatelessWidget {
  final GameController c;
  const RewardScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final offers = ((c.state!['offers']) as List).cast<String>();
    var recIdx = 0, recSize = -1;
    for (var i = 0; i < offers.length; i++) {
      if (dieDef(offers[i]).size > recSize) {
        recSize = dieDef(offers[i]).size;
        recIdx = i;
      }
    }
    return Column(children: [
      _TopBar(c),
      const SizedBox(height: Space.xl),
      Text('Choose a die', style: EmberText.h1),
      const SizedBox(height: Space.xs),
      Text('It joins your pool for the rest of the run.',
          style: EmberText.bodyDim),
      const Spacer(),
      for (var i = 0; i < offers.length; i++)
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.m),
          child: _dieOffer(offers[i], i + 1, i == recIdx),
        ),
      const SizedBox(height: Space.s),
      Padding(
        padding: const EdgeInsets.all(Space.l),
        child: SizedBox(
          width: double.infinity,
          child: EmberButton('Skip',
              onTap: () => c.apply({'type': 'choose_reward', 'index': 0})),
        ),
      ),
    ]);
  }

  Widget _dieOffer(String id, int index, bool recommended) {
    final def = dieDef(id);
    return GestureDetector(
      onTap: () => c.apply({'type': 'choose_reward', 'index': index}),
      child: Panel(
        color: recommended ? EmberColors.raised : EmberColors.surface,
        child: Row(children: [
          DieChip(id),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(def.name, style: EmberText.h2),
                if (recommended) ...[
                  const SizedBox(width: Space.s),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Space.s, vertical: 2),
                    decoration: BoxDecoration(
                        color: EmberColors.ember,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('RECOMMENDED',
                        style: EmberText.micro
                            .copyWith(color: const Color(0xFF17110A))),
                  ),
                ],
              ]),
              const SizedBox(height: Space.xs),
              Text(_dieDesc(def), style: EmberText.bodyDim),
            ]),
          ),
        ]),
      ),
    );
  }
}

String _dieDesc(DieDef d) {
  final parts = <String>['d${d.size}'];
  final m = d.mods;
  if (m['attack_bonus'] != null) parts.add('+${m['attack_bonus']} attack');
  if (m['block_bonus'] != null) parts.add('+${m['block_bonus']} block');
  if (m['min_value'] != null) parts.add('min ${m['min_value']}');
  if (m['on_max_bonus'] != null) parts.add('+${m['on_max_bonus']} on max');
  if (m['attack_only'] == true) parts.add('attack only');
  if (m['block_only'] == true) parts.add('block only');
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Rest + forge
// ---------------------------------------------------------------------------
class RestScreen extends StatelessWidget {
  final GameController c;
  const RestScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final player = c.state!['player'] as Map;
    final dice0 = (player['dice'] as List).cast<String>();
    final forgeable = <int>[];
    for (var i = 0; i < dice0.length; i++) {
      if (dieDef(dice0[i]).forgeTo.isNotEmpty) forgeable.add(i);
    }
    return Column(children: [
      _TopBar(c),
      const SizedBox(height: Space.xl),
      Text('A warm hollow', style: EmberText.h1),
      const SizedBox(height: Space.xs),
      Text('Rest to heal, or forge a die into something stronger. One only.',
          style: EmberText.bodyDim, textAlign: TextAlign.center),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.all(Space.l),
        child: SizedBox(
          width: double.infinity,
          child: EmberButton('Rest — heal 30%',
              primary: true,
              icon: Icons.local_fire_department,
              onTap: () => c.apply({'type': 'rest'})),
        ),
      ),
      if (forgeable.isNotEmpty)
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.l),
            children: [
              Text('FORGE', style: EmberText.micro),
              const SizedBox(height: Space.s),
              for (final i in forgeable)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: _forgeRow(dice0[i], i + 1),
                ),
            ],
          ),
        )
      else
        const Spacer(),
    ]);
  }

  Widget _forgeRow(String id, int index) {
    final def = dieDef(id);
    final into = def.forgeTo.first;
    return Panel(
      child: Row(children: [
        DieChip(id),
        const Icon(Icons.arrow_forward, color: EmberColors.ember),
        DieChip(into),
        const SizedBox(width: Space.m),
        Expanded(
            child: Text('${def.name} → ${dieDef(into).name}',
                style: EmberText.body)),
        EmberButton('Forge',
            onTap: () => c.apply({'type': 'forge', 'die': index, 'into': into})),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Shop
// ---------------------------------------------------------------------------
class ShopScreen extends StatelessWidget {
  final GameController c;
  const ShopScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final slots = ((c.state!['shop'] as Map)['slots'] as List).cast<Map>();
    final gold = (c.state!['run'] as Map)['gold'] as int;
    return Column(children: [
      _TopBar(c),
      const SizedBox(height: Space.l),
      Text('The Ashmonger', style: EmberText.h1),
      const SizedBox(height: Space.xs),
      Text('Spend your gold before the descent.', style: EmberText.bodyDim),
      const SizedBox(height: Space.l),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          children: [
            for (var i = 0; i < slots.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.m),
                child: _slot(slots[i], i + 1, gold),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(Space.l),
        child: SizedBox(
          width: double.infinity,
          child: EmberButton('Leave shop',
              primary: true, onTap: () => c.apply({'type': 'leave_shop'})),
        ),
      ),
    ]);
  }

  Widget _slot(Map slot, int index, int gold) {
    final kind = slot['kind'] as String;
    final id = slot['id'] as String;
    final price = slot['price'] as int;
    final sold = slot['sold'] == true;
    final afford = gold >= price;
    String title, desc;
    Widget lead;
    if (kind == 'die') {
      title = dieDef(id).name;
      desc = _dieDesc(dieDef(id));
      lead = DieChip(id);
    } else if (kind == 'relic') {
      title = relicDef(id).name;
      desc = relicDef(id).text;
      lead = Image.asset(Art.relicIcon(id),
          width: 44, height: 44, filterQuality: FilterQuality.medium);
    } else {
      title = 'Field Rations';
      desc = 'Heal ${slot['amount']} HP';
      lead = const Icon(Icons.healing, color: EmberColors.success, size: 40);
    }
    return Opacity(
      opacity: sold ? 0.4 : 1,
      child: Panel(
        child: Row(children: [
          SizedBox(width: 64, child: Center(child: lead)),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: EmberText.h2),
              const SizedBox(height: Space.xs),
              Text(desc, style: EmberText.bodyDim),
            ]),
          ),
          const SizedBox(width: Space.s),
          sold
              ? Text('SOLD', style: EmberText.micro)
              : EmberButton('$price',
                  icon: Icons.circle,
                  onTap: afford
                      ? () => c.apply({'type': 'buy', 'slot': index})
                      : null),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event
// ---------------------------------------------------------------------------
class EventScreen extends StatelessWidget {
  final GameController c;
  const EventScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final def = eventDef(c.state!['event'] as String);
    return Column(children: [
      _TopBar(c),
      const SizedBox(height: Space.xl),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        child: Column(children: [
          Image.asset(Art.eventIcon(def.id),
              width: 96, height: 96, filterQuality: FilterQuality.medium),
          const SizedBox(height: Space.l),
          Text(def.name, style: EmberText.h1, textAlign: TextAlign.center),
          const SizedBox(height: Space.m),
          Text(def.text, style: EmberText.body, textAlign: TextAlign.center),
        ]),
      ),
      const Spacer(),
      for (var i = 0; i < def.options.length; i++)
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.m),
          child: SizedBox(
            width: double.infinity,
            child: EmberButton(def.options[i].label,
                primary: i == 0,
                onTap: () =>
                    c.apply({'type': 'event_choose', 'option': i + 1})),
          ),
        ),
      const SizedBox(height: Space.s),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Summary — death/victory ledger leads with GAINS (fair-death pillar)
// ---------------------------------------------------------------------------
class SummaryScreen extends StatelessWidget {
  final GameController c;
  const SummaryScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = c.state!;
    final won = st['phase'] == 'run_won';
    final run = st['run'] as Map;
    final insight = run['insight'] as String?;
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(children: [
        const Spacer(),
        Icon(won ? Icons.emoji_events : Icons.local_fire_department,
            size: 56,
            color: won ? EmberColors.gold : EmberColors.ember),
        const SizedBox(height: Space.m),
        Text(won ? 'The Ember is yours' : 'The dark claims you',
            style: EmberText.h1, textAlign: TextAlign.center),
        const SizedBox(height: Space.xl),
        Panel(
          child: Column(children: [
            _ledgerRow(Icons.local_fire_department, EmberColors.ember,
                'Embers banked', '${run['embers']}'),
            const Divider(color: EmberColors.line, height: Space.xl),
            _ledgerRow(Icons.sports_martial_arts, EmberColors.textPrimary,
                'Fights won', '${run['fights_won']}'),
            const Divider(color: EmberColors.line, height: Space.xl),
            _ledgerRow(Icons.circle, EmberColors.gold, 'Gold at the end',
                '${run['gold']}'),
          ]),
        ),
        if (insight != null) ...[
          const SizedBox(height: Space.l),
          Panel(
            color: EmberColors.raised,
            child: Row(children: [
              const Icon(Icons.lightbulb_outline,
                  color: EmberColors.gold, size: 20),
              const SizedBox(width: Space.m),
              Expanded(child: Text(insight, style: EmberText.body)),
            ]),
          ),
        ],
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: EmberButton('Continue',
              primary: true, onTap: () => c.endToTitle()),
        ),
      ]),
    );
  }

  Widget _ledgerRow(IconData icon, Color color, String label, String value) {
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: Space.m),
      Expanded(child: Text(label, style: EmberText.body)),
      Text(value, style: EmberText.value.copyWith(color: color)),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Top bar — run resources (values bright, labels micro)
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  final GameController c;
  const _TopBar(this.c);
  @override
  Widget build(BuildContext context) {
    final run = c.state?['run'] as Map?;
    if (run == null) return const SizedBox(height: Space.l);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
      decoration: const BoxDecoration(
        color: EmberColors.surface,
        border: Border(bottom: BorderSide(color: EmberColors.line)),
      ),
      child: Row(children: [
        ResourcePip(Icons.circle, EmberColors.gold, run['gold'] as int, 'GOLD',
            imageAsset: Art.currencyCoin),
        const SizedBox(width: Space.xl),
        ResourcePip(Icons.local_fire_department, EmberColors.ember,
            run['embers'] as int, 'EMBERS',
            imageAsset: Art.currencyEmber),
        const Spacer(),
        Icon(Icons.diamond, size: 14, color: EmberColors.textDim),
        const SizedBox(width: 4),
        Text('${(run['relics'] as List).length}', style: EmberText.label),
      ]),
    );
  }
}
