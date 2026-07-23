// Rest screen: campfire, heal preview (30% max hp, floored, capped), one
// Rest button. The sim computes the real heal; the preview mirrors its rule.
import 'package:flutter/material.dart';

import '../../services/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

class RestScreen extends StatelessWidget {
  const RestScreen({super.key, required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final st = session.state;
    final player = st['player'] as Map<String, dynamic>;
    final run = (st['run'] as Map?) ?? const {};
    final hp = player['hp'] as int;
    final maxHp = player['max_hp'] as int;
    // Same rule the sim applies: 30% of max, floored, capped at max hp.
    final heal = ((maxHp * 3) ~/ 10).clamp(0, maxHp - hp);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          RunHeader(player: player, run: run),
          const Spacer(),
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Ember.glow, Colors.transparent],
                stops: [0.35, 1],
              ),
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                size: 72, color: Ember.primary),
          ),
          const SizedBox(height: 16),
          Text('CAMPFIRE',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium!
                  .copyWith(fontSize: 24, letterSpacing: 3)),
          const SizedBox(height: 10),
          Text(
            heal > 0
                ? 'Rest here to recover $heal hp\n($hp → ${hp + heal} of $maxHp)'
                : 'You are already at full strength.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Ember.textDim, height: 1.5),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => session.apply({'type': 'rest'}),
                icon: const Icon(Icons.nightlight_round),
                label: const Text('REST'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
