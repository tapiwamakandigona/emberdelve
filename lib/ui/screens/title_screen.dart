// Title screen: logo treatment + New Run / Continue.
import 'package:flutter/material.dart';

import '../../services/session.dart';
import '../theme.dart';

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key, required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const Spacer(flex: 3),
            // Logo treatment: ember glyph over the wordmark.
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Ember.glow, Colors.transparent],
                  stops: [0.4, 1],
                ),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                size: 64,
                color: Ember.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'EMBERDELVE',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .displayLarge!
                  .copyWith(fontSize: 40, letterSpacing: 6),
            ),
            const SizedBox(height: 8),
            const Text(
              'Delve deep. Roll true. Keep the ember lit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Ember.textDim, fontSize: 15),
            ),
            const Spacer(flex: 3),
            FutureBuilder<bool>(
              future: GameSession.hasResumableSave(),
              builder: (context, snap) {
                final canContinue = snap.data == true;
                return Column(children: [
                  if (canContinue) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => session.loadSaved(),
                        child: const Text('CONTINUE'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: canContinue
                        ? OutlinedButton(
                            onPressed: () => session.newRun(),
                            child: const Text('NEW RUN'),
                          )
                        : FilledButton(
                            onPressed: () => session.newRun(),
                            child: const Text('NEW RUN'),
                          ),
                  ),
                ]);
              },
            ),
            const Spacer(),
            const Text(
              'Tsoro Studios',
              style: TextStyle(color: Ember.textDim, fontSize: 12),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }
}
