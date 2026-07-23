// Map screen: the run's node graph, 9 layers climbing to the boss.
// Renders exclusively from session.state['map'] (+ player/run headers).
// Only nodes reachable from the current position are tappable.
import 'package:flutter/material.dart';

import '../../services/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

const double _kLayerHeight = 104;
const double _kNodeSize = 54;

IconData nodeIcon(String kind) => switch (kind) {
      'start' => Icons.flag_rounded,
      'fight' => Icons.whatshot_rounded,
      'elite' => Icons.star_rounded,
      'rest' => Icons.local_fire_department_rounded,
      'boss' => Icons.dangerous_rounded,
      _ => Icons.circle,
    };

Color nodeColor(String kind) => switch (kind) {
      'elite' => Ember.eliteGold,
      'rest' => Ember.good,
      'boss' => Ember.bossPurple,
      _ => Ember.primary,
    };

class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final st = session.state;
    final map = st['map'] as Map<String, dynamic>;
    final player = st['player'] as Map<String, dynamic>;
    final run = (st['run'] as Map?) ?? const {};
    final layers = map['layers'] as int;
    final position = map['position'] as int;
    final reachable = ((map['edges'] as Map)[position] as List? ?? const [])
        .cast<int>()
        .toSet();

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          RunHeader(player: player, run: run),
          const SizedBox(height: 4),
          const Text(
            'CHOOSE YOUR PATH',
            style: TextStyle(
              color: Ember.textDim,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              return SingleChildScrollView(
                reverse: true, // start of the run sits at the bottom
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: box.maxWidth,
                  height: layers * _kLayerHeight,
                  child: _MapGraph(
                    map: map,
                    reachable: reachable,
                    onTapNode: (id) =>
                        session.apply({'type': 'choose_node', 'node': id}),
                  ),
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }
}

class _MapGraph extends StatelessWidget {
  const _MapGraph({
    required this.map,
    required this.reachable,
    required this.onTapNode,
  });

  final Map<String, dynamic> map;
  final Set<int> reachable;
  final void Function(int id) onTapNode;

  @override
  Widget build(BuildContext context) {
    final nodes = map['nodes'] as Map;
    final layers = map['layers'] as int;
    final position = map['position'] as int;
    final visited =
        ((map['visited'] as List?) ?? const []).cast<int>().toSet();

    return LayoutBuilder(builder: (context, box) {
      Offset center(Map node) {
        const pad = _kNodeSize / 2 + 16;
        final x = pad + (node['x'] as num).toDouble() * (box.maxWidth - 2 * pad);
        final layer = node['layer'] as int;
        final y = (layers - layer) * _kLayerHeight + _kLayerHeight / 2;
        return Offset(x, y);
      }

      return Stack(children: [
        // Edges underneath.
        Positioned.fill(
          child: CustomPaint(
            painter: _EdgePainter(
              map: map,
              center: center,
              reachable: reachable,
              position: position,
            ),
          ),
        ),
        // Nodes on top.
        for (final entry in nodes.entries)
          _placeNode(
            id: entry.key as int,
            node: entry.value as Map,
            at: center(entry.value as Map),
            isCurrent: entry.key == position,
            isVisited: visited.contains(entry.key),
            isReachable: reachable.contains(entry.key),
          ),
      ]);
    });
  }

  Widget _placeNode({
    required int id,
    required Map node,
    required Offset at,
    required bool isCurrent,
    required bool isVisited,
    required bool isReachable,
  }) {
    return Positioned(
      left: at.dx - _kNodeSize / 2,
      top: at.dy - _kNodeSize / 2,
      width: _kNodeSize,
      height: _kNodeSize,
      child: _MapNode(
        id: id,
        kind: node['kind'] as String,
        isCurrent: isCurrent,
        isVisited: isVisited,
        isReachable: isReachable,
        onTap: isReachable ? () => onTapNode(id) : null,
      ),
    );
  }
}

class _MapNode extends StatelessWidget {
  const _MapNode({
    required this.id,
    required this.kind,
    required this.isCurrent,
    required this.isVisited,
    required this.isReachable,
    this.onTap,
  });

  final int id;
  final String kind;
  final bool isCurrent;
  final bool isVisited;
  final bool isReachable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = nodeColor(kind);
    final dimmed = !isReachable && !isCurrent;
    return Semantics(
      button: isReachable,
      label: 'map node $id $kind',
      child: AnimatedScale(
        scale: isReachable ? 1.0 : 0.92,
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: isCurrent
              ? color.withValues(alpha: 0.28)
              : dimmed
                  ? Ember.surface
                  : color.withValues(alpha: 0.16),
          shape: CircleBorder(
            side: BorderSide(
              color: isCurrent
                  ? color
                  : isReachable
                      ? color.withValues(alpha: 0.9)
                      : Ember.line,
              width: isCurrent || isReachable ? 2.5 : 1.5,
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(
              nodeIcon(kind),
              size: 26,
              color: dimmed && !isVisited
                  ? Ember.textDim.withValues(alpha: 0.55)
                  : isVisited && !isCurrent
                      ? Ember.textDim
                      : color,
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.map,
    required this.center,
    required this.reachable,
    required this.position,
  });

  final Map<String, dynamic> map;
  final Offset Function(Map node) center;
  final Set<int> reachable;
  final int position;

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = map['nodes'] as Map;
    final edges = map['edges'] as Map;
    final dim = Paint()
      ..color = Ember.line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final hot = Paint()
      ..color = Ember.primary.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    edges.forEach((from, tos) {
      final a = center(nodes[from] as Map);
      for (final to in tos as List) {
        final b = center(nodes[to] as Map);
        final isActive = from == position && reachable.contains(to);
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(a.dx, a.dy - _kLayerHeight * 0.45, b.dx,
              b.dy + _kLayerHeight * 0.45, b.dx, b.dy);
        canvas.drawPath(path, isActive ? hot : dim);
      }
    });
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.position != position || old.reachable != reachable;
}
