// lib/ui/screens.dart — every screen, routed by sim.phase. Screens render only
// from controller.state() and never poke sim internals. Layout is portrait,
// one-thumb: the primary action lives in the bottom zone on every screen.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/audio_service.dart';
import '../data/boons.dart';
import '../data/characters.dart';
import '../data/dice.dart';
import '../data/events.dart';
import '../data/relics.dart';
import '../game/controller.dart';
import 'art.dart';
import 'fx.dart';
import 'haptics.dart';
import 'logo.dart';
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
          case 'boon':
            screen = BoonScreen(c);
            break;
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
        // Flame-wipe smash-cut into combat; fade-through-black elsewhere
        // (visuals.md #12 — the stock cross-fade dies here).
        return Scaffold(
          body: PhaseSwitcher(
            phaseKey: phase ?? 'title',
            flameWipe: phase == 'player_turn',
            child: ScreenBackground(
              asset: Art.backgroundForPhase(phase, bossFight: bossFight),
              child: SafeArea(
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
    return Stack(fit: StackFit.expand, children: [
      const Vignette(strength: 0.55),
      const EmberDrift(count: 30),
      Padding(
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
                Navigator.of(context)
                    .push(emberRoute((_) => const SettingsScreen()));
              },
            ),
          ),
          const Spacer(),
          // Drawn logotype: glow bloom + charred-top/molten-bottom fill +
          // spark pinpricks (visuals.md #1 — never a plain Text).
          const EmberLogotype('EMBERDELVE', fontSize: 42),
          const SizedBox(height: Space.s),
          Text('A dice-builder delve into the dark',
              style: EmberText.bodyDim, textAlign: TextAlign.center),
          const SizedBox(height: Space.xl),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ResourcePip(Icons.local_fire_department, EmberColors.ember,
                m.embers, 'EMBERS',
                imageAsset: Art.currencyEmber),
            const SizedBox(width: Space.xl),
            _statText('${m.runsWon}/${m.runsPlayed}', 'WINS'),
          ]),
          const Spacer(),
          // The delver, idling by a fire while the dark waits below.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              SpriteView(defaultCharacter, height: 72),
              SizedBox(width: Space.l),
              CampFire(size: 40),
            ],
          ),
          const SizedBox(height: Space.xxl),
          // Primary CTA in the thumb zone.
          SizedBox(
            width: double.infinity,
            child: EmberButton('Delve',
                primary: true,
                icon: Icons.bolt,
                onTap: () =>
                    c.startRun(character: defaultCharacter, boons: true)),
          ),
          const SizedBox(height: Space.m),
          // Daily Delve: one shared seed per local calendar date — everyone
          // gets the same delve. No streaks, no expiry pressure (§Ethics).
          SizedBox(
            width: double.infinity,
            child: EmberButton('Daily Delve — ${_dailyLabel()}',
                icon: Icons.today,
                onTap: () => c.startDailyRun(character: defaultCharacter)),
          ),
          const SizedBox(height: Space.m),
          SizedBox(
            width: double.infinity,
            child: EmberButton('Choose a delver',
                ghost: true,
                onTap: () => Navigator.of(context)
                    .push(emberRoute((_) => CharacterScreen(c)))),
          ),
        ]),
      ),
    ]);
  }

  Widget _statText(String v, String l) => Column(mainAxisSize: MainAxisSize.min,
          children: [
            Text(v, style: EmberText.value.copyWith(fontSize: 18)),
            Text(l, style: EmberText.micro),
          ]);

  /// Local calendar date the daily seed is drawn from, e.g. "Jul 24".
  static String _dailyLabel() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.day}';
  }
}

// ---------------------------------------------------------------------------
// Boon pick — 1-of-3 starting blessing, always skippable (spec §Ethics: no
// timer, no decay; the offer is exactly what the sim telegraphed).
// ---------------------------------------------------------------------------
class BoonScreen extends StatelessWidget {
  final GameController c;
  const BoonScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final boonIds = ((c.state!['boons']) as List?)?.cast<String>() ?? const [];
    return Stack(fit: StackFit.expand, children: [
      const Vignette(strength: 0.5),
      const EmberDrift(count: 16, opacity: 0.6),
      Column(children: [
        _TopBar(c),
        const SizedBox(height: Space.xl),
        Text('Choose a boon', style: EmberText.h1),
        const SizedBox(height: Space.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: Text('A blessing for this delve — or walk in unaided.',
              style: EmberText.bodyDim, textAlign: TextAlign.center),
        ),
        const SizedBox(height: Space.l),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.l),
            children: [
              for (var i = 0; i < boonIds.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.m),
                  child: _boonCard(context, boonIds[i], i + 1),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.l),
          child: SizedBox(
            width: double.infinity,
            child: EmberButton('Skip — delve unaided',
                key: const ValueKey('boon-skip'),
                onTap: () => c.apply({'type': 'choose_boon', 'index': 0})),
          ),
        ),
      ]),
    ]);
  }

  Widget _boonCard(BuildContext context, String id, int index) {
    final def = boonDef(id);
    return GestureDetector(
      key: ValueKey('boon-$index'),
      onTap: () => c.apply({'type': 'choose_boon', 'index': index}),
      child: Panel(
        child: Row(children: [
          const Icon(Icons.auto_awesome, color: EmberColors.gold, size: 28),
          const SizedBox(width: Space.l),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(def.name, style: EmberText.h2),
              const SizedBox(height: Space.xs),
              Text(def.text, style: EmberText.bodyDim),
            ]),
          ),
        ]),
      ),
    );
  }
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
                      c.startRun(
                          character: id, ascension: ascension, boons: true);
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
class MapScreen extends StatefulWidget {
  final GameController c;
  const MapScreen(this.c, {super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  // Pulse for reachable-node glow (one controller for the whole scene).
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  // Where the delver marker last stood, kept across map visits so the marker
  // visibly walks node-to-node after each encounter.
  static int? _walkFrom;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // Node geometry (shared by nodes, trails, and the marker).
  static const double _nodeSize = 52;
  static const double _rowH = 96;
  static Offset _center(Map n, double w) {
    final x = (n['x'] as num).toDouble();
    final layer = n['layer'] as int;
    return Offset(28 + x * (w - 56 - _nodeSize) + _nodeSize / 2,
        (layer - 1) * _rowH + 20 + _nodeSize / 2); // in bottom-up coords
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final st = c.state!;
    final map = st['map'] as Map;
    final nodes = (map['nodes'] as Map).cast<String, Map>();
    final edges = (map['edges'] as Map).cast<String, List>();
    final layers = map['layers'] as int;
    final position = map['position'] as int;
    final reachable = (edges['$position'] as List).cast<int>().toSet();
    final run = st['run'] as Map;
    final characterId = run['character'] as String? ?? defaultCharacter;
    final curLayer = (nodes['$position']?['layer'] as int?) ?? 1;
    if (_walkFrom == null || !nodes.containsKey('$_walkFrom')) {
      _walkFrom = position;
    }

    return Stack(fit: StackFit.expand, children: [
      Column(children: [
        _TopBar(c),
        Expanded(
          child: LayoutBuilder(builder: (context, cns) {
            final h = layers * _rowH + 40;
            return SingleChildScrollView(
              reverse: true,
              child: SizedBox(
                height: h,
                width: cns.maxWidth,
                child: Stack(children: [
                  // Trails + fog-of-war + descent tint, painted once.
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size(cns.maxWidth, h),
                      painter: _MapScenePainter(nodes, edges, cns.maxWidth,
                          layers, position, reachable, curLayer),
                    ),
                  ),
                  for (final e in nodes.entries)
                    _nodeWidget(context, e.value, cns.maxWidth, position,
                        reachable),
                  // Honest reward telegraphs: the sim pre-resolves each
                  // fight/elite node's offers at start_run; the badge shows
                  // its `reward_preview` verbatim (never invented here).
                  for (final e in nodes.entries)
                    if (e.value['reward_preview'] is String)
                      _telegraphBadge(e.value, cns.maxWidth, reachable),
                  _delverMarker(nodes, cns.maxWidth, h, position, characterId),
                ]),
              ),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Text(
              'Tap a glowing node to descend · Pool: ${(st['player'] as Map)['dice'].length} dice · ${(run['relics'] as List).length} relics',
              style: EmberText.micro, textAlign: TextAlign.center),
        ),
      ]),
      // Ambient embers rising off the delve.
      const EmberDrift(count: 18, opacity: 0.7),
    ]);
  }

  /// The "you are here" delver, walking from the previous node to this one.
  Widget _delverMarker(Map<String, Map> nodes, double w, double h,
      int position, String characterId) {
    final from = _center(nodes['$_walkFrom'] ?? nodes['$position']!, w);
    final to = _center(nodes['$position']!, w);
    final walkKey = '$_walkFrom>$position';
    return TweenAnimationBuilder<double>(
      key: ValueKey(walkKey),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
          milliseconds: _walkFrom == position ? 1 : 650),
      curve: Curves.easeInOut,
      onEnd: () => _walkFrom = position,
      builder: (context, f, child) {
        final p = Offset.lerp(from, to, f)!;
        // Little hop while walking.
        final hop = _walkFrom == position
            ? 0.0
            : (math.sin(f * math.pi * 4).abs() * 4);
        return Positioned(
          left: p.dx - 14,
          bottom: p.dy + _nodeSize / 2 - 6 + hop,
          child: child!,
        );
      },
      child: IgnorePointer(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SpriteView(characterId, height: 30, animate: false),
          Container(
            width: 14,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ]),
      ),
    );
  }

  /// Compact reward telegraph under a fight/elite medallion: die size tinted
  /// by tier (tier 3 gold — the elite's guaranteed rare reads at a glance).
  Widget _telegraphBadge(Map node, double w, Set<int> reachable) {
    final id = node['id'] as int;
    final center = _center(node, w);
    final preview = node['reward_preview'] as String;
    final def = dieDef(preview);
    final tierColor = switch (def.tier) {
      3 => EmberColors.gold,
      2 => EmberColors.ember,
      _ => EmberColors.textDim,
    };
    final lit = reachable.contains(id);
    return Positioned(
      left: center.dx - 24,
      bottom: center.dy - _nodeSize / 2 - 15,
      width: 48,
      child: IgnorePointer(
        child: Opacity(
          opacity: lit ? 1.0 : 0.55,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.casino, size: 9, color: tierColor),
            const SizedBox(width: 2),
            Text('d${def.size}',
                style: EmberText.micro.copyWith(
                    color: tierColor,
                    fontSize: 9,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 3),
                    ])),
          ]),
        ),
      ),
    );
  }

  Widget _nodeWidget(BuildContext context, Map node, double w, int position,
      Set<int> reachable) {
    final id = node['id'] as int;
    final kind = node['kind'] as String;
    final center = _center(node, w);
    final isReachable = reachable.contains(id);
    final isHere = id == position;
    return Positioned(
      left: center.dx - _nodeSize / 2,
      bottom: center.dy - _nodeSize / 2,
      child: GestureDetector(
        onTap: isReachable
            ? () => widget.c.apply({'type': 'choose_node', 'node': id})
            : null,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => CustomPaint(
            size: const Size(_nodeSize, _nodeSize),
            painter: _MedallionPainter(
              kind: kind,
              here: isHere,
              reachable: isReachable,
              pulse: isReachable ? _pulse.value : 0,
            ),
            child: SizedBox(
              width: _nodeSize,
              height: _nodeSize,
              child: Center(
                child: Opacity(
                  opacity: isReachable || isHere ? 1.0 : 0.55,
                  child: _nodeIcon(kind),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Painted node icon when we have one; drawn glyph fallback (start node).
Widget _nodeIcon(String kind) {
  final asset = Art.nodeIcons[kind];
  if (asset == null) {
    return Icon(_kindIcon(kind), size: 20, color: EmberColors.textPrimary);
  }
  return Image.asset(asset,
      width: 26, height: 26, filterQuality: FilterQuality.medium);
}

IconData _kindIcon(String kind) {
  switch (kind) {
    case 'start':
      return Icons.flag;
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

/// Framed medallion: soft drop shadow, dark disc, kind-tinted ring, and a
/// pulsing ember halo when the node is reachable.
class _MedallionPainter extends CustomPainter {
  final String kind;
  final bool here;
  final bool reachable;
  final double pulse;
  _MedallionPainter(
      {required this.kind,
      required this.here,
      required this.reachable,
      required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    final kindColor = EmberColors.kind(kind);
    final dimmed = !reachable && !here;

    // Pulsing halo on reachable nodes only.
    if (reachable) {
      canvas.drawCircle(
          c,
          r + 3 + pulse * 4,
          Paint()
            ..color = EmberColors.ember.withValues(alpha: 0.22 + pulse * 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    }
    // Soft grounding shadow.
    canvas.drawCircle(
        c + const Offset(0, 3),
        r,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    // Medallion disc, lit warm-from-below.
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dimmed
                ? const [Color(0xFF16101E), Color(0xFF241B30)]
                : [
                    const Color(0xFF1B1424),
                    Color.lerp(const Color(0xFF2A2136), kindColor, 0.22)!,
                  ],
          ).createShader(Rect.fromCircle(center: c, radius: r)));
    // Kind-tinted ring + inner hairline frame.
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = here ? 3.0 : 2.2
          ..color = here
              ? EmberColors.textPrimary
              : dimmed
                  ? Color.lerp(kindColor, Colors.black, 0.5)!
                  : kindColor);
    canvas.drawCircle(
        c,
        r - 3.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black.withValues(alpha: 0.5));
    if (reachable) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color =
                EmberColors.ember.withValues(alpha: 0.5 + pulse * 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _MedallionPainter old) =>
      old.pulse != pulse ||
      old.here != here ||
      old.reachable != reachable ||
      old.kind != kind;
}

/// The map scene beneath the nodes: dashed trails between medallions, fog on
/// rows the delver can't reach yet, and the descent tint (hotter down low,
/// darker up top).
class _MapScenePainter extends CustomPainter {
  final Map<String, Map> nodes;
  final Map<String, List> edges;
  final double w;
  final int layers;
  final int position;
  final Set<int> reachable;
  final int curLayer;
  _MapScenePainter(this.nodes, this.edges, this.w, this.layers, this.position,
      this.reachable, this.curLayer);

  Offset _pos(Map n, Size size) {
    final c = _MapScreenState._center(n, w);
    return Offset(c.dx, size.height - c.dy);
  }

  void _trail(Canvas canvas, Offset a, Offset b, Paint p, {double gap = 9}) {
    // Hand-laid dashes: slight perpendicular jitter so the trail reads as
    // stones/embers, not a ruler line.
    final d = b - a;
    final len = d.distance;
    final dir = d / len;
    final normal = Offset(-dir.dy, dir.dx);
    var t = 12.0; // start clear of the node
    var i = 0;
    while (t < len - 12) {
      final jitter = math.sin(t * 0.7 + a.dx) * 1.6;
      final p0 = a + dir * t + normal * jitter;
      final p1 = a + dir * (t + 4.5) + normal * jitter;
      canvas.drawLine(p0, p1, p);
      t += gap + (i.isEven ? 0 : 2);
      i++;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Descent tint: hotter (warm) toward the bottom layer, colder/darker up.
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              EmberColors.ember.withValues(alpha: 0.10),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.30),
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(Offset.zero & size));

    // Trails.
    final dim = Paint()
      ..color = const Color(0xFF4A4058)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final hot = Paint()
      ..color = EmberColors.ember.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    edges.forEach((k, v) {
      final from = nodes[k]!;
      final fromHere = k == '$position';
      for (final t in v.cast<int>()) {
        final active = fromHere && reachable.contains(t);
        _trail(canvas, _pos(from, size), _pos(nodes['$t']!, size),
            active ? hot : dim);
      }
    });

    // Fog of war: rows beyond the next one sink into darkness.
    for (var layer = curLayer + 2; layer <= layers; layer++) {
      final depth = layer - curLayer - 1; // 1, 2, 3...
      final alpha = (0.14 * depth).clamp(0.0, 0.5);
      final top = size.height - (layer - 1) * _MapScreenState._rowH - 68;
      canvas.drawRect(
          Rect.fromLTWH(0, top, size.width, _MapScreenState._rowH),
          Paint()..color = Colors.black.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(covariant _MapScenePainter old) =>
      old.position != position || old.curLayer != curLayer;
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

  // Boss/elite name-plate splash, shown once when the encounter opens.
  bool _splash = false;

  // Cached combat view-model: during the end-of-encounter notify hold the sim
  // has already left combat (enemy == null), but we keep rendering the stage.
  Map? _enemy;
  String _characterId = defaultCharacter;

  // SYNC_POINTS.md: whoosh starts ~2 frames (8 fps => 250 ms) before contact.
  static const _contact = Duration(milliseconds: 250);
  static const _squashTime = Duration(milliseconds: 90);
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
    setState(() =>
        _pops.add(_Pop(_popId++, amount, onPlayer: onPlayer, blocked: blocked)));
  }

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

  void _note(String text,
      {Color color = EmberColors.gold, IconData? icon, bool onEnemy = false}) {
    if (!mounted) return;
    setState(() =>
        _notes.add(_Note(_noteId++, text, color, icon, onEnemy: onEnemy)));
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
          _note('TRIPLE!',
              color: EmberColors.danger, icon: Icons.casino);
          break;
        case 'burn_applied':
          _note('IGNITE +${e['stacks']} BURN',
              color: EmberColors.ember,
              icon: Icons.local_fire_department,
              onEnemy: true);
          break;
        case 'combo_straight':
          _note('STRAIGHT!', color: EmberColors.kindElite,
              icon: Icons.trending_up);
          break;
        case 'free_reroll_earned':
          _note('FREE REROLL NEXT TURN',
              color: EmberColors.success, icon: Icons.replay);
          break;
        case 'free_reroll_granted':
          _note('FREE REROLL READY',
              color: EmberColors.success, icon: Icons.replay);
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
    _audio?.playSfx(_enemy?['boss'] == true ? 'boss_death' : 'enemy_death');
    Haptics.heavy();
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
    if (selected == null) return;
    if (_busy) {
      _queued = ('attack', selected); // F2: remember, don't drop
      return;
    }
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
    _spawnPop(landed > 0 ? landed : amount,
        onPlayer: false, blocked: landed <= 0);
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
      _note('+${exact['embers']} EMBERS — EXACT!',
          icon: Icons.local_fire_department, onEnemy: true);
    }
    final over = _find(events, 'overkill');
    if (over != null) {
      _note('OVERKILL +${over['surplus']} → NEXT FOE',
          color: EmberColors.ember, icon: Icons.double_arrow, onEnemy: true);
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
    widget.c.apply({'type': 'assign', 'die': selected, 'action': 'block'});
    Haptics.light();
    setState(() => selected = null);
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
    final events = widget.c.apply({'type': 'end_turn'},
        terminalHold: const Duration(milliseconds: 1450));
    final atk = _find(events, 'enemy_attacked');
    if (atk != null) {
      setState(() => _enemySquash = true);
      await _sleep(_squashTime);
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
    }
    // Burn ticks after the enemy acts: flame call-out + damage pop reusing
    // the existing pop primitive (m4 contract §3).
    final burnTick = _find(events, 'burn_tick');
    if (burnTick != null && mounted) {
      _audio?.playSfx('enemy_hit', volume: 0.5);
      _spawnPop(burnTick['amount'] as int? ?? 0, onPlayer: false);
      _note('BURN',
          color: EmberColors.ember,
          icon: Icons.local_fire_department,
          onEnemy: true);
      await _sleep(const Duration(milliseconds: 350));
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
    final intent = (enemy['intent'] as Map?) ?? const {'kind': 'attack', 'amount': 0};
    final rerolls = player['rerolls_left'] as int? ?? 0;
    final riskyUsed = player['risky_used'] == true;
    final freeReroll = player['free_reroll'] == true;
    final enemyHp = (enemy['hp'] as int).clamp(0, enemy['max_hp'] as int);

    final combat = Column(children: [
      _TopBar(c),
      // Enemy header: name + HP (intent lives on the stage, over the enemy).
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
      Expanded(child: _stage(enemy, intent)),
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
      // Dice tray (combo call-outs pop over it; in reroll mode taps pick the
      // unassigned dice to risk — assigned dice never join the selection).
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 1; i <= dice0.length; i++)
                  DieChip(dice0[i - 1],
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
                              ? () => _note('ALREADY ASSIGNED',
                                  color: EmberColors.textDim,
                                  icon: Icons.do_not_disturb_alt)
                              : _rerollMode
                                  ? () => setState(() =>
                                      _rerollSel.contains(i)
                                          ? _rerollSel.remove(i)
                                          : _rerollSel.add(i))
                                  : () {
                                      Haptics.light();
                                      setState(() => selected =
                                          selected == i ? null : i);
                                    })
              ],
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
                            Haptics.light();
                            setState(() {
                              selected = null;
                              _rollGen++; // trigger the dice tumble cascade
                            });
                            final events = c.apply({'type': 'roll'});
                            // Combo call-outs land after the tumble reads.
                            Future.delayed(
                                const Duration(milliseconds: 550), () {
                              if (mounted) _announceCombos(events);
                            });
                          }))
            : _rerollMode
                // Risky-reroll confirm: pick unassigned dice, then commit.
                ? Column(children: [
                    Text(
                        freeReroll
                            ? 'Pick dice to reroll — FREE this turn'
                            : 'Pick dice to reroll — each lands −1 pip',
                        style: EmberText.micro.copyWith(
                            color: freeReroll
                                ? EmberColors.success
                                : EmberColors.textDim)),
                    const SizedBox(height: Space.s),
                    Row(children: [
                      Expanded(
                          child: EmberButton('Cancel',
                              ghost: true,
                              onTap: () => setState(() {
                                    _rerollMode = false;
                                    _rerollSel.clear();
                                  }))),
                      const SizedBox(width: Space.m),
                      Expanded(
                          child: EmberButton(
                              'Reroll (${_rerollSel.length})',
                              primary: true,
                              icon: Icons.casino,
                              onTap: _rerollSel.isNotEmpty && !_busy
                                  ? _doRiskyReroll
                                  : null)),
                    ]),
                  ])
                : Column(children: [
                    Row(children: [
                      // Enabled during choreography too: taps land in the
                      // one-slot queue instead of being dropped (F2).
                      Expanded(
                          child: EmberButton('Attack',
                              icon: Icons.gps_fixed,
                              onTap: selected != null ? _attack : null)),
                      const SizedBox(width: Space.m),
                      Expanded(
                          child: EmberButton('Block',
                              icon: Icons.shield,
                              onTap: selected != null ? _block : null)),
                    ]),
                    const SizedBox(height: Space.m),
                    Row(children: [
                      if (rerolls > 0)
                        Expanded(
                            child: EmberButton('Reroll ($rerolls)',
                                icon: Icons.replay,
                                onTap: selected != null && !_busy
                                    ? () {
                                        c.apply(
                                            {'type': 'reroll', 'die': selected});
                                        setState(() {});
                                      }
                                    : null)),
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
                              icon: Icons.casino,
                              onTap: riskyUsed || _busy
                                  ? null
                                  : () => setState(() {
                                        _rerollMode = true;
                                        _rerollSel.clear();
                                        selected = null;
                                      }))),
                    ]),
                    const SizedBox(height: Space.m),
                    SizedBox(
                        width: double.infinity,
                        child: EmberButton('End turn',
                            primary: true, onTap: _endTurn)),
                  ]),
      ),
    ]);

    return ShakeBox(
      key: _shakeKey,
      child: Stack(fit: StackFit.expand, children: [
        combat,
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
      ]),
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
  Widget _stage(Map enemy, Map intent) {
    final enemyId = enemy['id'] as String? ?? '';
    final big = enemy['boss'] == true || enemy['elite'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      child: Stack(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: _combatant(
                sprite: SpriteView(_characterId,
                    key: ValueKey('hero-$_characterId'), height: 104),
                spriteHeight: 104,
                lungeToward: 1,
                lunge: _playerLunge,
                knock: _playerKnock,
                flash: _playerFlash,
                dying: _playerDying,
                squash: _playerSquash,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  _combatant(
                    sprite: SpriteView(enemyId,
                        key: ValueKey('enemy-$enemyId'),
                        height: big ? 128 : 96,
                        flipX: true),
                    spriteHeight: big ? 128 : 96,
                    // Slight depth scale: the enemy stands a step closer.
                    depthScale: big ? 1.02 : 1.06,
                    lungeToward: -1,
                    lunge: _enemyLunge,
                    knock: _enemyKnock,
                    flash: _enemyFlash,
                    dying: _enemyDying,
                    squash: _enemySquash,
                  ),
                  // Intent as an icon badge floating above the enemy
                  // (overlaid, so it never adds layout height). Burn stacks
                  // sit beside it while the enemy is alight.
                  Positioned(
                    top: -44,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _IntentBadge(intent),
                      if ((enemy['burn'] as int? ?? 0) > 0) ...[
                        const SizedBox(width: Space.xs),
                        _BurnBadge(enemy['burn'] as int),
                      ],
                    ]),
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
      ]),
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
    double depthScale = 1.0,
  }) {
    Widget w = sprite;
    // Grounding: soft shadow ellipse under the feet (+ ember dissolve cloud
    // while dying).
    w = Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter,
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
              borderRadius:
                  BorderRadius.all(Radius.elliptical(spriteHeight, 20)),
              color: Colors.black.withValues(alpha: 0.38),
            ),
          ),
        ),
      ),
      w,
      if (dying)
        Positioned.fill(
            child: EmberBurst(duration: _deathTime, count: 30)),
    ]);
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
    // Anticipation squash (bottom-anchored) right before the lunge, and the
    // slight depth scale that grounds the enemy a step closer to the camera.
    w = Transform.scale(
      alignment: Alignment.bottomCenter,
      scale: depthScale,
      child: AnimatedContainer(
        duration: _squashTime,
        curve: Curves.easeOut,
        transformAlignment: Alignment.bottomCenter,
        transform: squash
            ? (Matrix4.identity()..scale(1.08, 0.86))
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
            final scale = 1.15 - 0.15 * Curves.easeOut.transform(
                (f / 0.2).clamp(0.0, 1.0));
            return Opacity(
                opacity: a.clamp(0.0, 1.0),
                child: Transform.scale(scale: scale, child: child));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: Space.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.85),
                Colors.transparent,
              ], stops: const [0.0, 0.18, 0.82, 1.0]),
              border: const Border(
                top: BorderSide(color: EmberColors.ember, width: 1),
                bottom: BorderSide(color: EmberColors.ember, width: 1),
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text((enemy['name'] as String? ?? '').toUpperCase(),
                  textAlign: TextAlign.center,
                  style: EmberText.h1.copyWith(
                      color:
                          boss ? EmberColors.kindBoss : EmberColors.kindElite,
                      letterSpacing: 3)),
              const SizedBox(height: Space.xs),
              Text(boss ? 'LAYER $layer · BOSS' : 'LAYER $layer · ELITE',
                  style: EmberText.micro.copyWith(letterSpacing: 3)),
            ]),
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
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.s),
      decoration: BoxDecoration(
          color: EmberColors.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EmberColors.ember)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_fire_department,
            size: 16, color: EmberColors.ember),
        const SizedBox(width: 2),
        Text('$stacks',
            style: EmberText.value
                .copyWith(fontSize: 15, color: EmberColors.ember)),
      ]),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
      decoration: BoxDecoration(
          color: EmberColors.raised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (i, part) in parts.indexed) ...[
          if (i > 0) const SizedBox(width: Space.m),
          Icon(part.$1, size: 18, color: part.$2),
          const SizedBox(width: Space.xs),
          Text(part.$3,
              style: EmberText.value.copyWith(fontSize: 18, color: part.$2)),
        ],
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
    // v0.3.1 F9: never offer a heal that heals nothing.
    final fullHp = (player['hp'] as int) >= (player['max_hp'] as int);
    return Stack(fit: StackFit.expand, children: [
      const EmberDrift(count: 16, opacity: 0.6),
      Column(children: [
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
          child: EmberButton(
              fullHp ? 'Fully rested — forge or move on' : 'Rest — heal 30%',
              primary: !fullHp,
              icon: Icons.local_fire_department,
              onTap: fullHp ? null : () => c.apply({'type': 'rest'})),
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
      ]),
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
    // After leave_shop the PhaseSwitcher cross-fade keeps this screen mounted
    // briefly while state['shop'] is already null — render nothing then.
    final shop = c.state?['shop'] as Map?;
    if (shop == null) return const SizedBox.shrink();
    final slots = (shop['slots'] as List).cast<Map>();
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
    // Same stale-frame guard as ShopScreen: event is null right after
    // event_choose while the cross-fade is still showing this screen.
    final eventId = c.state?['event'] as String?;
    if (eventId == null) return const SizedBox.shrink();
    final def = eventDef(eventId);
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
    return Stack(fit: StackFit.expand, children: [
      // The designed moment: embers rise in triumph, or sink and die.
      Vignette(strength: won ? 0.45 : 0.7),
      EmberDrift(count: won ? 44 : 12, falling: !won, opacity: won ? 1 : 0.7),
      Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(children: [
        const Spacer(),
        Icon(won ? Icons.emoji_events : Icons.local_fire_department,
            size: 56,
            color: won ? EmberColors.gold : EmberColors.ember),
        const SizedBox(height: Space.m),
        Text(won ? 'The Ember is yours' : 'The dark claims you',
            textAlign: TextAlign.center,
            style: EmberText.h1.copyWith(
              color: won ? EmberColors.gold : EmberColors.textPrimary,
              shadows: [
                Shadow(
                    color: (won ? EmberColors.gold : EmberColors.ember)
                        .withValues(alpha: 0.55),
                    blurRadius: 18),
              ],
            )),
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
        // Fast restart (backlog #8): straight into a new run — boon pick
        // included — without a detour through the title.
        SizedBox(
          width: double.infinity,
          child: EmberButton('Delve again',
              primary: true, icon: Icons.bolt, onTap: () => c.delveAgain()),
        ),
        const SizedBox(height: Space.m),
        SizedBox(
          width: double.infinity,
          child: EmberButton('Back to the fire',
              ghost: true, onTap: () => c.endToTitle()),
        ),
      ]),
      ),
    ]);
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
        if (c.dailyDate != null) ...[
          Text('DAILY ${c.dailyDate}',
              style: EmberText.micro.copyWith(color: EmberColors.gold)),
          const SizedBox(width: Space.m),
        ],
        Icon(Icons.diamond, size: 14, color: EmberColors.textDim),
        const SizedBox(width: 4),
        Text('${(run['relics'] as List).length}', style: EmberText.label),
        const SizedBox(width: Space.m),
        // v0.3.1 F10: in-run pause menu — settings (volume!) and a way out
        // of a delve were unreachable before the run ended.
        GestureDetector(
          onTap: () {
            AudioService.instance?.playSfx('ui_tap');
            showPauseMenu(context, c);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.xs),
            child: Icon(Icons.settings, size: 18, color: EmberColors.textDim),
          ),
        ),
      ]),
    );
  }
}

/// In-run pause menu (v0.3.1 F10): Resume / Settings / Abandon run.
/// Abandoning is voluntary (unlike death) — it discards the run without
/// banking embers, behind an explicit confirm.
void showPauseMenu(BuildContext context, GameController c) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Panel(
        padding: const EdgeInsets.all(Space.l),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('PAUSED', style: EmberText.h2),
          const SizedBox(height: Space.l),
          SizedBox(
            width: double.infinity,
            child: EmberButton('Resume', primary: true, icon: Icons.play_arrow,
                onTap: () => Navigator.of(ctx).pop()),
          ),
          const SizedBox(height: Space.m),
          SizedBox(
            width: double.infinity,
            child: EmberButton('Settings', icon: Icons.settings, onTap: () {
              Navigator.of(ctx).pop();
              Navigator.of(context)
                  .push(emberRoute((_) => const SettingsScreen()));
            }),
          ),
          const SizedBox(height: Space.m),
          SizedBox(
            width: double.infinity,
            child: EmberButton('Abandon run', danger: true, icon: Icons.close,
                onTap: () {
              Navigator.of(ctx).pop();
              _confirmAbandon(context, c);
            }),
          ),
        ]),
      ),
    ),
  );
}

void _confirmAbandon(BuildContext context, GameController c) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Panel(
        padding: const EdgeInsets.all(Space.l),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Abandon this delve?', style: EmberText.h2,
              textAlign: TextAlign.center),
          const SizedBox(height: Space.s),
          Text(
              'The run ends here — embers gathered this run are lost. '
              'Dying keeps half; walking away keeps nothing.',
              style: EmberText.bodyDim, textAlign: TextAlign.center),
          const SizedBox(height: Space.l),
          Row(children: [
            Expanded(
                child: EmberButton('Keep delving', primary: true,
                    onTap: () => Navigator.of(ctx).pop())),
            const SizedBox(width: Space.m),
            Expanded(
                child: EmberButton('Abandon', danger: true, onTap: () {
              Navigator.of(ctx).pop();
              c.abandonRun();
            })),
          ]),
        ]),
      ),
    ),
  );
}


// ---------------------------------------------------------------------------
// First-fight tutorial (v0.3.1 F11) — three dismissible cards, shown once
// ever (MetaState.tutorialSeen). No forced taps, always skippable (§Ethics).
// ---------------------------------------------------------------------------
class _TutorialOverlay extends StatelessWidget {
  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const _TutorialOverlay(
      {required this.step, required this.onNext, required this.onSkip});

  static const _cards = [
    (
      Icons.visibility,
      'THE DARK FIGHTS FAIR',
      'The badge above the enemy is its next move — attack damage, shield '
          'block, or both. It always resolves exactly as shown.'
    ),
    (
      Icons.casino,
      'ROLL, THEN SPEND',
      'Roll your dice, tap one, then ATTACK or BLOCK with its value. Each '
          'die is spent once per turn; a reroll can save a bad face.'
    ),
    (
      Icons.local_fire_department,
      'MATCHING FACES PAY',
      'A PAIR adds +2, a TRIPLE ignites the enemy with burn, and a straight '
          'earns a FREE risky reroll. Forge dice bigger at rest fires.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = _cards[step];
    // Dim everything; the card sits near what it explains (intent up top,
    // dice tray at the bottom, combos mid-stage).
    final align = switch (step) {
      0 => Alignment.topCenter,
      1 => Alignment.bottomCenter,
      _ => Alignment.center,
    };
    return Positioned.fill(
      child: GestureDetector(
        onTap: onNext, // tapping anywhere advances — never traps the player
        child: Container(
          color: Colors.black.withValues(alpha: 0.62),
          padding: EdgeInsets.only(
              left: Space.l,
              right: Space.l,
              top: step == 0 ? 120 : Space.l,
              bottom: step == 1 ? 210 : Space.l),
          child: Align(
            alignment: align,
            child: Panel(
              padding: const EdgeInsets.all(Space.l),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: EmberColors.ember, size: 28),
                const SizedBox(height: Space.s),
                Text(title, style: EmberText.h2, textAlign: TextAlign.center),
                const SizedBox(height: Space.s),
                Text(body,
                    style: EmberText.bodyDim, textAlign: TextAlign.center),
                const SizedBox(height: Space.l),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  EmberButton('Skip', ghost: true, onTap: onSkip),
                  const SizedBox(width: Space.m),
                  EmberButton(step >= 2 ? 'Got it' : 'Next',
                      primary: true, onTap: onNext),
                ]),
                const SizedBox(height: Space.s),
                Text('${step + 1} / 3', style: EmberText.micro),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
