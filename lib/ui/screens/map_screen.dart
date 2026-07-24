// lib/ui/screens/map_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

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
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  // Where the delver marker last stood, kept across map visits so the marker
  // visibly walks node-to-node after each encounter. Keyed by run seed:
  // node ids restart at 1 every run, so without the key a NEW run's marker
  // would "walk" from wherever the previous run ended (a cross-run ghost).
  static int? _walkFrom;
  static int? _walkRunSeed;

  // Auto-follow: the map used to reopen scrolled to the BOTTOM every visit,
  // so late-run reachable nodes sat clipped off the top edge (found via a
  // stuck autoplay session 2026-07-24). Scroll to the delver on each arrival.
  final ScrollController _scroll = ScrollController();
  int? _scrolledForPos;

  @override
  void dispose() {
    _pulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Node geometry (shared by nodes, trails, and the marker).
  static const double _nodeSize = 52;
  static const double _rowH = 96;
  static Offset _center(Map n, double w) {
    final x = (n['x'] as num).toDouble();
    final layer = n['layer'] as int;
    return Offset(
      28 + x * (w - 56 - _nodeSize) + _nodeSize / 2,
      (layer - 1) * _rowH + 20 + _nodeSize / 2,
    ); // in bottom-up coords
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
    final runSeed = c.runSeed;
    if (_walkRunSeed != runSeed ||
        _walkFrom == null ||
        !nodes.containsKey('$_walkFrom')) {
      _walkRunSeed = runSeed;
      _walkFrom = position;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            _TopBar(c),
            Expanded(
              child: LayoutBuilder(
                builder: (context, cns) {
                  final h = layers * _rowH + 40;
                  // Follow the delver: keep the marker ~45% up the viewport so
                  // the reachable row above is always on screen (reverse list:
                  // offset 0 == bottom of the delve).
                  if (_scrolledForPos != position) {
                    _scrolledForPos = position;
                    final target = ((curLayer - 1) * _rowH +
                            20 +
                            _nodeSize / 2 -
                            cns.maxHeight * 0.45)
                        .clamp(0.0, math.max(0.0, h - cns.maxHeight))
                        .toDouble();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || !_scroll.hasClients) return;
                      _scroll.animateTo(
                        target,
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                      );
                    });
                  }
                  return SingleChildScrollView(
                    reverse: true,
                    controller: _scroll,
                    child: SizedBox(
                      height: h,
                      width: cns.maxWidth,
                      child: Stack(
                        children: [
                          // Trails + fog-of-war + descent tint, painted once.
                          RepaintBoundary(
                            child: CustomPaint(
                              size: Size(cns.maxWidth, h),
                              painter: _MapScenePainter(
                                nodes,
                                edges,
                                cns.maxWidth,
                                layers,
                                position,
                                reachable,
                                curLayer,
                              ),
                            ),
                          ),
                          for (final e in nodes.entries)
                            _nodeWidget(
                              context,
                              e.value,
                              cns.maxWidth,
                              position,
                              reachable,
                            ),
                          // Honest reward telegraphs: the sim pre-resolves each
                          // fight/elite node's offers at start_run; the badge shows
                          // its `reward_preview` verbatim (never invented here).
                          for (final e in nodes.entries)
                            if (e.value['reward_preview'] is String)
                              _telegraphBadge(e.value, cns.maxWidth, reachable),
                          _delverMarker(
                            nodes,
                            cns.maxWidth,
                            h,
                            position,
                            characterId,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.l),
              child: Text(
                'Tap a glowing node to descend · Pool: ${(st['player'] as Map)['dice'].length} dice · ${(run['relics'] as List).length} relics',
                style: EmberText.micro,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        // Ambient embers rising off the delve.
        const EmberDrift(count: 18, opacity: 0.7),
      ],
    );
  }

  /// The "you are here" delver, walking from the previous node to this one.
  Widget _delverMarker(
    Map<String, Map> nodes,
    double w,
    double h,
    int position,
    String characterId,
  ) {
    final from = _center(nodes['$_walkFrom'] ?? nodes['$position']!, w);
    final to = _center(nodes['$position']!, w);
    final walkKey = '$_walkFrom>$position';
    return TweenAnimationBuilder<double>(
      key: ValueKey(walkKey),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: _walkFrom == position ? 1 : 650),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpriteView(characterId, height: 30, animate: false),
            Container(
              width: 14,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
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
          // FittedBox: the badge is pinned to a 48px-wide slot under the
          // node; at large system font sizes it scales down instead of
          // overflowing the slot.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.casino, size: 9, color: tierColor),
                const SizedBox(width: 2),
                Text(
                  'd${def.size}',
                  style: EmberText.micro.copyWith(
                    color: tierColor,
                    fontSize: 9,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nodeWidget(
    BuildContext context,
    Map node,
    double w,
    int position,
    Set<int> reachable,
  ) {
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
  return Image.asset(
    asset,
    width: 26,
    height: 26,
    filterQuality: FilterQuality.medium,
  );
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
  _MedallionPainter({
    required this.kind,
    required this.here,
    required this.reachable,
    required this.pulse,
  });

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
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    // Soft grounding shadow.
    canvas.drawCircle(
      c + const Offset(0, 3),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
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
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
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
            : kindColor,
    );
    canvas.drawCircle(
      c,
      r - 3.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.5),
    );
    if (reachable) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = EmberColors.ember.withValues(alpha: 0.5 + pulse * 0.5),
      );
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
  _MapScenePainter(
    this.nodes,
    this.edges,
    this.w,
    this.layers,
    this.position,
    this.reachable,
    this.curLayer,
  );

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
        ).createShader(Offset.zero & size),
    );

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
        _trail(
          canvas,
          _pos(from, size),
          _pos(nodes['$t']!, size),
          active ? hot : dim,
        );
      }
    });

    // Fog of war: rows beyond the next one sink into darkness.
    for (var layer = curLayer + 2; layer <= layers; layer++) {
      final depth = layer - curLayer - 1; // 1, 2, 3...
      final alpha = (0.14 * depth).clamp(0.0, 0.5);
      final top = size.height - (layer - 1) * _MapScreenState._rowH - 68;
      canvas.drawRect(
        Rect.fromLTWH(0, top, size.width, _MapScreenState._rowH),
        Paint()..color = Colors.black.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapScenePainter old) =>
      old.position != position || old.curLayer != curLayer;
}

// ---------------------------------------------------------------------------
// Combat
// ---------------------------------------------------------------------------
