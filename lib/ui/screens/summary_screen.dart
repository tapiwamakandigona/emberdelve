// lib/ui/screens/summary_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class SummaryScreen extends StatelessWidget {
  final GameController c;
  const SummaryScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = c.state!;
    final won = st['phase'] == 'run_won';
    final run = st['run'] as Map;
    final player = st['player'] as Map?;
    final pool =
        (player?['dice'] as List?)?.whereType<String>().toList() ?? const [];
    final identity = buildIdentity(pool, run: run);
    final insight = run['insight'] as String?;
    return Stack(
      fit: StackFit.expand,
      children: [
        // The designed moment: embers rise in triumph, or sink and die.
        Vignette(strength: won ? 0.45 : 0.7),
        EmberDrift(count: won ? 44 : 12, falling: !won, opacity: won ? 1 : 0.7),
        // Scroll-safe shell (same as TitleScreen): the ledger + insight panel
        // can outgrow short screens, so scroll instead of overflowing.
        LayoutBuilder(
          builder: (context, box) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.xl),
                    child: Column(
                      children: [
                        const Spacer(),
                        Icon(
                          won
                              ? Icons.emoji_events
                              : Icons.local_fire_department,
                          size: 56,
                          color: won ? EmberColors.gold : EmberColors.ember,
                        ),
                        const SizedBox(height: Space.m),
                        Text(
                          won ? 'The Ember is yours' : 'The dark claims you',
                          textAlign: TextAlign.center,
                          style: EmberText.h1.copyWith(
                            color: won
                                ? EmberColors.gold
                                : EmberColors.textPrimary,
                            shadows: [
                              Shadow(
                                color:
                                    (won ? EmberColors.gold : EmberColors.ember)
                                        .withValues(alpha: 0.55),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.xl),
                        Panel(
                          child: Column(
                            children: [
                              _ledgerRow(
                                Icons.local_fire_department,
                                EmberColors.ember,
                                'Embers banked',
                                '${run['embers']}',
                              ),
                              const Divider(
                                color: EmberColors.line,
                                height: Space.xl,
                              ),
                              _ledgerRow(
                                Icons.sports_martial_arts,
                                EmberColors.textPrimary,
                                'Fights won',
                                '${run['fights_won']}',
                              ),
                              const Divider(
                                color: EmberColors.line,
                                height: Space.xl,
                              ),
                              _ledgerRow(
                                Icons.circle,
                                EmberColors.gold,
                                'Gold at the end',
                                '${run['gold']}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.l),
                        _poolRecap(identity),
                        // Delver's Ledger (v0.5.0): achievements this run earned, announced
                        // in the same breath as the result. _bankRun collects them and
                        // startRun clears them, so this list is exactly this run's harvest.
                        // Recognition only — no reward talk, no next-goal teaser (§Ethics).
                        if (c.pendingAchievements.isNotEmpty) ...[
                          const SizedBox(height: Space.l),
                          Panel(
                            key: const ValueKey('achievements-earned'),
                            color: EmberColors.raised,
                            child: Column(
                              children: [
                                for (final (i, id)
                                    in c.pendingAchievements.indexed) ...[
                                  if (i > 0)
                                    const Divider(
                                      color: EmberColors.line,
                                      height: Space.xl,
                                    ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.military_tech,
                                        color: EmberColors.gold,
                                        size: 20,
                                      ),
                                      const SizedBox(width: Space.m),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              achievements[id]?.name ?? id,
                                              style: EmberText.body.copyWith(
                                                color: EmberColors.gold,
                                              ),
                                            ),
                                            Text(
                                              achievements[id]?.text ?? '',
                                              style: EmberText.micro.copyWith(
                                                color: EmberColors.textDim,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (insight != null) ...[
                          const SizedBox(height: Space.l),
                          Panel(
                            color: EmberColors.raised,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline,
                                  color: EmberColors.gold,
                                  size: 20,
                                ),
                                const SizedBox(width: Space.m),
                                Expanded(
                                  child: Text(insight, style: EmberText.body),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: Space.m),
                        // v0.8.0: the floor trace, shown exactly as it will
                        // paste — the share artifact IS the display (Wordle
                        // lesson, studio-priorities doc §7). One combined
                        // screen-reader label; the emoji stay decorative.
                        if (c.runTrace.marks.isNotEmpty) ...[
                          Semantics(
                            label: traceSemanticLabel(c.runTrace),
                            child: ExcludeSemantics(
                              child: Text(
                                traceGrid(c.runTrace),
                                key: const ValueKey('trace-grid'),
                                textAlign: TextAlign.center,
                                style: EmberText.body.copyWith(
                                  height: 1.25,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.s),
                        ],
                        // Run seed (v0.3.4): shown on every summary, tap to copy. Paste it
                        // into 'Delve a seed' on the title to replay this exact delve.
                        GestureDetector(
                          key: const ValueKey('run-seed'),
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: '${c.sim?.runSeed ?? ''}'),
                            );
                            c.announce('Seed copied');
                          },
                          child: Text(
                            'Seed ${c.sim?.runSeed} — tap to copy',
                            textAlign: TextAlign.center,
                            style: EmberText.micro.copyWith(
                              color: EmberColors.textDim,
                            ),
                          ),
                        ),
                        // Ember Forge (v0.4.0): ONE quiet panel, only on a WON run, only
                        // while locked — the peak-joy moment is the only honest time to ask.
                        // Never a popup, never blocks the buttons below (§Ethics).
                        if (won && !c.meta.forgeUnlocked) ...[
                          const SizedBox(height: Space.l),
                          Panel(
                            color: EmberColors.raised,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  color: EmberColors.ember,
                                  size: 20,
                                ),
                                const SizedBox(width: Space.m),
                                Expanded(
                                  child: Text(
                                    'The dark goes deeper. The Ascension ladder '
                                    'waits in the Ember Forge.',
                                    style: EmberText.body,
                                  ),
                                ),
                                EmberButton(
                                  'Open',
                                  dense: true,
                                  key: const ValueKey('forge-victory-cta'),
                                  onTap: () => showForgeSheet(context, c),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Fast restart (backlog #8): straight into a new run — boon pick
                        // included — without a detour through the title.
                        SizedBox(
                          width: double.infinity,
                          child: EmberButton(
                            'Delve again',
                            primary: true,
                            icon: Icons.bolt,
                            onTap: () => c.delveAgain(),
                          ),
                        ),
                        const SizedBox(height: Space.m),
                        // Daily result share (v0.3.4): plain-text copy, pastes anywhere.
                        // Only offered when this run WAS the daily — normal runs stay quiet.
                        if (c.dailyResultShareText != null) ...[
                          SizedBox(
                            width: double.infinity,
                            child: EmberButton(
                              'Copy daily result',
                              key: const ValueKey('copy-daily-result'),
                              ghost: true,
                              icon: Icons.copy,
                              onTap: () async {
                                final text = c.dailyResultShareText;
                                if (text == null) return;
                                await Clipboard.setData(
                                  ClipboardData(text: text),
                                );
                                c.announce('Result copied');
                              },
                            ),
                          ),
                          const SizedBox(height: Space.m),
                        ],
                        // Weekly result share (P3): same plain-text copy, only when this run
                        // WAS the weekly. States the seed + modifier fact and stops.
                        if (c.weeklyResultShareText != null) ...[
                          SizedBox(
                            width: double.infinity,
                            child: EmberButton(
                              'Copy weekly result',
                              key: const ValueKey('copy-weekly-result'),
                              ghost: true,
                              icon: Icons.copy,
                              onTap: () async {
                                final text = c.weeklyResultShareText;
                                if (text == null) return;
                                await Clipboard.setData(
                                  ClipboardData(text: text),
                                );
                                c.announce('Result copied');
                              },
                            ),
                          ),
                          const SizedBox(height: Space.m),
                        ],
                        // v0.8.0: seed challenge for every OTHER finished
                        // run — the daily/weekly keep their own text above.
                        // A seed plus a claim is a complete invitation
                        // (Balatro lesson); the copy states facts and stops.
                        if (c.seedChallengeShareText != null) ...[
                          SizedBox(
                            width: double.infinity,
                            child: EmberButton(
                              'Copy seed challenge',
                              key: const ValueKey('copy-seed-challenge'),
                              ghost: true,
                              icon: Icons.copy,
                              onTap: () async {
                                final text = c.seedChallengeShareText;
                                if (text == null) return;
                                await Clipboard.setData(
                                  ClipboardData(text: text),
                                );
                                c.announce('Challenge copied');
                              },
                            ),
                          ),
                          const SizedBox(height: Space.m),
                        ],
                        // P5 (v0.5.0): straight to the board this run just landed on. Only
                        // for a finished Daily/Weekly AND only while Play Games is connected
                        // — normal runs and unconnected players see nothing.
                        if (PlayGamesService.instance.connected &&
                            (c.dailyResultShareText != null ||
                                c.weeklyResultShareText != null)) ...[
                          SizedBox(
                            width: double.infinity,
                            child: EmberButton(
                              'Leaderboard',
                              key: const ValueKey('summary-leaderboard'),
                              ghost: true,
                              icon: Icons.leaderboard,
                              onTap: () {
                                AudioService.instance?.playSfx('ui_tap');
                                PlayGamesService.instance.showLeaderboards(
                                  leaderboardId: c.dailyResultShareText != null
                                      ? PlayGamesService.dailyLeaderboardId
                                      : PlayGamesService.weeklyLeaderboardId,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: Space.m),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: EmberButton(
                            'Back to the fire',
                            ghost: true,
                            onTap: () => c.endToTitle(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _ledgerRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: Space.m),
        Expanded(child: Text(label, style: EmberText.body)),
        Text(value, style: EmberText.value.copyWith(color: color)),
      ],
    );
  }

  Widget _poolRecap(RunBuildIdentity identity) {
    final counts = [
      for (final sides in const [4, 6, 8, 10, 12])
        if (identity.countFor(sides) > 0)
          (sides: sides, count: identity.countFor(sides)),
    ];
    return Semantics(
      key: const ValueKey('pool-forged-recap'),
      container: true,
      label:
          'Pool forged this run. ${identity.name}. '
          '${counts.map((e) => 'd${e.sides}: ${e.count}').join(', ')}. '
          '${identity.specialDice} special dice.',
      child: Panel(
        color: EmberColors.raised,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'POOL FORGED THIS RUN',
              style: EmberText.micro.copyWith(
                color: EmberColors.textDim,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: Space.m),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: identity.color.withValues(alpha: 0.13),
                    border: Border.all(
                      color: identity.color.withValues(alpha: 0.52),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(identity.icon, color: identity.color, size: 21),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        identity.name.toUpperCase(),
                        key: const ValueKey('pool-identity-name'),
                        style: EmberText.body.copyWith(color: identity.color),
                      ),
                      Text(
                        identity.description,
                        style: EmberText.micro.copyWith(
                          color: EmberColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final entry in counts)
                  _poolChip(
                    'd${entry.sides} ×${entry.count}',
                    ValueKey('pool-d${entry.sides}'),
                  ),
                if (identity.specialDice > 0)
                  _poolChip(
                    '${identity.specialDice} SPECIAL',
                    const ValueKey('pool-special'),
                    color: identity.color,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _poolChip(String label, Key key, {Color? color}) {
    final tint = color ?? EmberColors.textDim;
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        border: Border.all(color: tint.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: EmberText.micro.copyWith(
          color: color ?? EmberColors.textPrimary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar — run resources (values bright, labels micro)
// ---------------------------------------------------------------------------
