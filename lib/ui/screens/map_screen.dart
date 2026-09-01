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
  void initState() {
    super.initState();
    // v0.30.0 The Delver's Primer: the map IS the delve, so first contact
    // with it defines the word. Fires once ever; a no-op on every later
    // visit (lib/game/tips.dart owns the once-and-suppression rules).
    widget.c.tipDirector.onMapArrival();
  }

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
                    // First follow of a visit JUMPS (the screen mounts behind
                    // the phase fade at its darkest, so the cut is invisible);
                    // animating from offset 0 swept the camera up from the
                    // delve floor on EVERY arrival mid-run — half of the
                    // "progression glitches back and forth" owner report
                    // (2026-08-11). Later moves within the same visit animate.
                    final firstFollow = _scrolledForPos == null;
                    _scrolledForPos = position;
                    final target =
                        ((curLayer - 1) * _rowH +
                                20 +
                                _nodeSize / 2 -
                                cns.maxHeight * 0.45)
                            .clamp(0.0, math.max(0.0, h - cns.maxHeight))
                            .toDouble();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || !_scroll.hasClients) return;
                      if (firstFollow) {
                        _scroll.jumpTo(target);
                      } else {
                        _scroll.animateTo(
                          target,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    });
                  }
                  // PERF (2026-07-26, remaining-work §5): the viewport paints
                  // its child at the scroll offset, so without a boundary HERE
                  // every drag frame repainted every non-boundaried child in
                  // the Stack below (badges, delver marker, node chrome:
                  // probe map_drag 54.5 paints/frame). With it, a drag is a
                  // layer translation; only the pulsing medallions keep
                  // painting inside their own boundaries.
                  return SingleChildScrollView(
                    reverse: true,
                    controller: _scroll,
                    child: RepaintBoundary(
                      child: SizedBox(
                        height: h,
                        width: cns.maxWidth,
                        child: Stack(
                          children: [
                            // THE DEEP WALL: far plane, parallax on scroll.
                            IgnorePointer(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  key: const ValueKey('deep-wall'),
                                  size: Size(cns.maxWidth, h),
                                  painter: _FarWallPainter(
                                    _scroll,
                                    Motion.instance.reduced,
                                  ),
                                ),
                              ),
                            ),
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
                            // v0.82.0 The Farthest Lantern: the lifetime
                            // deepest floor, drawn where it matters — a thin
                            // gold rule between charted ground and new depth.
                            // Pure meta read; banks only at run end, so the
                            // line holds still all run. A record beyond this
                            // map's floors (short road after a long career)
                            // has no line to draw.
                            if (c.meta.bestFloor > 0 &&
                                c.meta.bestFloor < layers)
                              IgnorePointer(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    key: const ValueKey('plumb-mark'),
                                    size: Size(cns.maxWidth, h),
                                    painter: _FarthestLanternPainter(
                                      c.meta.bestFloor,
                                    ),
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
                                _telegraphBadge(
                                  e.value,
                                  cns.maxWidth,
                                  reachable,
                                ),
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
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.l),
              child: Text(
                // v0.83.0 The Depth Gauge: the live depth, stated where the
                // descent is chosen — same layer numbers the run record and
                // the lantern (v0.82.0) already use.
                'Floor $curLayer of $layers · Tap a glowing node to descend · Pool: ${(st['player'] as Map)['dice'].length} dice · ${(run['relics'] as List).length} relics',
                style: EmberText.micro,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        // Ambient embers rising off the delve.
        const EmberDrift(count: 18, opacity: 0.7),
        // v0.30.0: the whats_a_delve tip fires on first arrival (initState);
        // the shared card renders here so the word is defined where the
        // player is standing. Same widget, same tap-anywhere dismiss as the
        // combat tips (tutorial_overlay.dart).
        if (c.tipDirector.active != null)
          _ContextTip(
            id: c.tipDirector.active!,
            onDismiss: () => setState(c.dismissTip),
          ),
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
        // THE WALKED PATH (2026-09-01): the hop respects reduce motion
        // (the glide alone still shows where you went), the sprite faces
        // the way it walks, and the shadow thins at the hop's apex —
        // three small tells that turn a lerp into a walk.
        final walking = _walkFrom != position;
        final reduced = Motion.instance.reduced;
        final hopWave = (walking && !reduced)
            ? math.sin(f * math.pi * 4).abs()
            : 0.0;
        final hop = hopWave * 4;
        // Face the travel direction while walking; at rest face forward.
        final faceLeft = walking && f < 1 && to.dx < from.dx - 1;
        return Positioned(
          left: p.dx - 14,
          bottom: p.dy + _nodeSize / 2 - 6 + hop,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.flip(flipX: faceLeft, child: child!),
                // Grounded shadow: it stays on the path (does not ride the
                // hop) — width and weight ease off as the delver lifts.
                Transform.translate(
                  offset: Offset(0, hop),
                  child: Container(
                    key: const ValueKey('delver-shadow'),
                    width: 14 - hopWave * 5,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: 0.4 - hopWave * 0.18,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: RepaintBoundary(
        child: SpriteView(
          characterId,
          height: 30,
          animate: false,
          dye: Art.dyeFilter(widget.c.meta.dyeFor(characterId)),
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
    final layer = node['layer'] as int;
    return Positioned(
      left: center.dx - _nodeSize / 2,
      bottom: center.dy - _nodeSize / 2,
      // TalkBack (v0.19.0): the medallion is pure CustomPaint + icon, so
      // without a label a screen-reader user hears nothing but "double tap
      // to activate" on the game's main navigation. Speak what the eye sees:
      // kind, floor, and whether you can go there.
      child: Semantics(
        label:
            '${_kindName(kind)}, floor ${layer + 1}'
            '${isHere
                ? ', you are here'
                : isReachable
                ? ', reachable'
                : ', out of reach'}',
        button: isReachable,
        container: true,
        child: GestureDetector(
          // Stable hook for tests/tools (same pattern as the reward screen's
          // ValueKey('reward-...')): the play harness taps nodes by id. The
          // old structural finder (GestureDetector wrapping AnimatedBuilder)
          // silently broke when the 2026-07-25 perf pass removed the
          // AnimatedBuilder — a key can't rot like that.
          key: ValueKey('map-node-$id'),
          onTap: isReachable
              ? () => widget.c.apply({'type': 'choose_node', 'node': id})
              : null,
          // Perf (2026-07-25): this used to be an AnimatedBuilder around the
          // whole medallion, so every glow frame rebuilt the CustomPaint, the
          // icon Image and their boxes for EVERY node — 20 nodes x 60fps of
          // widget churn inside a scroll view, which then repainted the entire
          // delve. The pulse now drives the painter directly (repaint:) and
          // each medallion is its own repaint layer, so an idle map paints
          // only the halos that are actually animating.
          child: RepaintBoundary(
            child: CustomPaint(
              size: const Size(_nodeSize, _nodeSize),
              painter: _MedallionPainter(
                kind: kind,
                here: isHere,
                reachable: isReachable,
                // Unreachable nodes have no halo, so they don't listen at all.
                pulse: isReachable ? _pulse : null,
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
      ),
    );
  }
}

/// Spoken name for a node kind (TalkBack label; mirrors _kindIcon).
String _kindName(String kind) {
  switch (kind) {
    case 'start':
      return 'Start';
    case 'fight':
      return 'Fight';
    case 'elite':
      return 'Elite fight';
    case 'rest':
      return 'Rest site';
    case 'shop':
      return 'Shop';
    case 'event':
      return 'Event';
    case 'boss':
      return 'Boss';
  }
  return kind;
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

  /// The shared glow controller, passed straight to `repaint:` so the halo
  /// animates without rebuilding a single widget. Null on nodes with no halo.
  final Animation<double>? pulse;
  _MedallionPainter({
    required this.kind,
    required this.here,
    required this.reachable,
    required this.pulse,
  }) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = this.pulse?.value ?? 0.0;
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
      // `pulse` is now the animation itself; its ticks come through
      // `repaint:`, so only the static inputs are compared here.
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

  /// One chasm wall: a jagged silhouette hugging the screen edge, plus a
  /// dim inner echo line for depth. Deterministic in y so it never shifts.
  void _wall(Canvas canvas, Size size, {required bool left}) {
    double edgeAt(double y, double base) {
      // Two sine octaves + a phase offset per side read as hewn rock.
      final phase = left ? 0.0 : 2.1;
      return base +
          math.sin(y * 0.021 + phase) * 5.0 +
          math.sin(y * 0.0047 + phase * 1.7) * 7.0;
    }

    Path silhouette(double base) {
      final p = Path()..moveTo(left ? 0 : size.width, 0);
      for (var y = 0.0; y <= size.height + 14; y += 14) {
        final yy = math.min(y, size.height);
        final e = edgeAt(yy, base);
        p.lineTo(left ? e : size.width - e, yy);
      }
      p.lineTo(left ? 0 : size.width, size.height);
      p.close();
      return p;
    }

    canvas.drawPath(
      silhouette(11),
      Paint()..color = const Color(0xFF0E0B13).withValues(alpha: 0.85),
    );
    // A faint warm rim where torchlight from the paths grazes the rock.
    final rim = Path();
    var first = true;
    for (var y = 0.0; y <= size.height; y += 14) {
      final e = edgeAt(y, 11);
      final x = left ? e : size.width - e;
      if (first) {
        rim.moveTo(x, y);
        first = false;
      } else {
        rim.lineTo(x, y);
      }
    }
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = EmberColors.ember.withValues(alpha: 0.10),
    );
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

    // THE CARVED CHASM: jagged rock walls frame the descent so the chart
    // reads as the inside of a delve, not nodes on a void. Pure function
    // of y (sin-noise, no RNG state) — the same map always shows the same
    // walls, and the painter stays static: zero per-frame cost. Nodes
    // never enter the outer 22px (min center x = 54, node edge = 28).
    // THE DEEP WALL: the far plane lives in _FarWallPainter (parallax,
    // scroll-driven, its own boundary); only near plane + rim live here.
    _wall(canvas, size, left: true);
    _wall(canvas, size, left: false);

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

/// v0.82.0 The Farthest Lantern: one dashed gold rule at the boundary
/// between the lifetime deepest floor and the floor beyond, captioned with
/// the record. Repaint-isolated from the scene painter — the scene repaints
/// on every move; this repaints only if the record itself changes.
// THE DEEP WALL: the far rock plane, one step behind the near wall.
// Parallax — it tracks the scroll at 0.94x, so during a drag or the
// camera follow the far plane lags ~6% and the chasm gains true depth.
// Cost discipline: repaint is the ScrollController itself, so this
// painter (behind its own RepaintBoundary) redraws ONLY on scrolled
// frames — idle stays zero like everything else on this screen
// [entrance_probe map_idle_60f, 2026-09-01]. Reduced motion pins the
// offset to 0: the plane still exists, it just holds still.
class _FarWallPainter extends CustomPainter {
  final ScrollController scroll;
  final bool reduced;
  _FarWallPainter(this.scroll, this.reduced) : super(repaint: scroll);

  double _edgeAt(double y, bool left) {
    final phase = left ? 0.0 : 2.1;
    return 19.0 +
        math.sin(y * 0.021 + phase) * 5.0 +
        math.sin(y * 0.0047 + phase * 1.7) * 7.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final off = (reduced || !scroll.hasClients) ? 0.0 : scroll.offset * 0.06;
    final paintFill = Paint()
      ..color = const Color(0xFF1A1522).withValues(alpha: 0.55);
    for (final left in [true, false]) {
      final p = Path()..moveTo(left ? 0 : size.width, 0);
      for (var y = 0.0; y <= size.height + 14; y += 14) {
        final yy = math.min(y, size.height);
        final e = _edgeAt(yy + off, left);
        p.lineTo(left ? e : size.width - e, yy);
      }
      p.lineTo(left ? 0 : size.width, size.height);
      p.close();
      canvas.drawPath(p, paintFill);
    }
  }

  @override
  bool shouldRepaint(covariant _FarWallPainter old) =>
      old.scroll != scroll || old.reduced != reduced;
}

class _FarthestLanternPainter extends CustomPainter {
  final int bestFloor;
  _FarthestLanternPainter(this.bestFloor);

  @override
  void paint(Canvas canvas, Size size) {
    // Top edge of the record floor's band == bottom edge of the band beyond
    // (same row math as the fog-of-war rects above).
    final y = size.height - (bestFloor - 1) * _MapScreenState._rowH - 68;
    final line = Paint()
      ..color = EmberColors.gold.withValues(alpha: 0.40)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    var x = 8.0;
    while (x < size.width - 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 6, y), line);
      x += 12;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: 'YOUR DEEPEST · FLOOR $bestFloor',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 9,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: Color(0xB3E8C24A), // gold at ~0.7
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width - 12, y - tp.height - 3));
  }

  @override
  bool shouldRepaint(covariant _FarthestLanternPainter old) =>
      old.bestFloor != bestFloor;
}

// ---------------------------------------------------------------------------
// Combat
// ---------------------------------------------------------------------------
