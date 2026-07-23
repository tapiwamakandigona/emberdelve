// Summary screen: run_won / run_lost ledger — the "fair death" pillar means
// the player always sees what they earned and how far they got.
import 'package:flutter/material.dart';

import '../../services/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final won = session.phase == 'run_won';
    final st = session.state;
    final run = (st['run'] as Map?) ?? const {};
    final map = st['map'] as Map<String, dynamic>?;
    int? layerReached;
    if (map != null) {
      final pos = map['position'];
      final node = (map['nodes'] as Map)[pos];
      if (node is Map) layerReached = node['layer'] as int?;
    }
    final accent = won ? Ember.eliteGold : Ember.danger;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const Spacer(flex: 2),
            Icon(
              won ? Icons.emoji_events_rounded : Icons.whatshot_rounded,
              size: 72,
              color: accent,
            ),
            const SizedBox(height: 14),
            Text(
              won ? 'THE EMBER ENDURES' : 'THE EMBER FADES',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium!
                  .copyWith(fontSize: 26, letterSpacing: 2, color: accent),
            ),
            const SizedBox(height: 6),
            Text(
              won
                  ? 'You conquered the delve.'
                  : 'The depths claim another delver.',
              style: const TextStyle(color: Ember.textDim),
            ),
            const SizedBox(height: 28),
            EmberPanel(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                _StatRow(
                  icon: Icons.local_fire_department_rounded,
                  color: Ember.primaryBright,
                  label: 'Embers earned',
                  value: '${run['embers'] ?? 0}',
                ),
                const Divider(color: Ember.line, height: 22),
                _StatRow(
                  icon: Icons.military_tech_rounded,
                  color: Ember.eliteGold,
                  label: 'Fights won',
                  value: '${run['fights_won'] ?? 0}',
                ),
                if (layerReached != null) ...[
                  const Divider(color: Ember.line, height: 22),
                  _StatRow(
                    icon: Icons.stairs_rounded,
                    color: Ember.block,
                    label: 'Layer reached',
                    value: '$layerReached${won ? ' (boss)' : ''}',
                  ),
                ],
              ]),
            ),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => session.newRun(),
                child: const Text('NEW RUN'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => session.toTitle(),
                child: const Text('TITLE'),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(color: Ember.textDim))),
      Text(value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    ]);
  }
}
