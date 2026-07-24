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
    final insight = run['insight'] as String?;
    return Stack(fit: StackFit.expand, children: [
      // The designed moment: embers rise in triumph, or sink and die.
      Vignette(strength: won ? 0.45 : 0.7),
      EmberDrift(count: won ? 44 : 12, falling: !won, opacity: won ? 1 : 0.7),
      // Scroll-safe shell (same as TitleScreen): the ledger + insight panel
      // can outgrow short screens, so scroll instead of overflowing.
      LayoutBuilder(builder: (context, box) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
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
        const SizedBox(height: Space.m),
        // Run seed (v0.3.4): shown on every summary, tap to copy. Paste it
        // into 'Delve a seed' on the title to replay this exact delve.
        GestureDetector(
          key: const ValueKey('run-seed'),
          onTap: () async {
            await Clipboard.setData(
                ClipboardData(text: '${c.sim?.runSeed ?? ''}'));
            c.announce('Seed copied');
          },
          child: Text('Seed ${c.sim?.runSeed} — tap to copy',
              textAlign: TextAlign.center,
              style: EmberText.micro.copyWith(color: EmberColors.textDim)),
        ),
        const Spacer(),
        // Fast restart (backlog #8): straight into a new run — boon pick
        // included — without a detour through the title.
        SizedBox(
          width: double.infinity,
          child: EmberButton('Delve again',
              primary: true, icon: Icons.bolt, onTap: () => c.delveAgain()),
        ),
        const SizedBox(height: Space.m),
        // Daily result share (v0.3.4): plain-text copy, pastes anywhere.
        // Only offered when this run WAS the daily — normal runs stay quiet.
        if (c.dailyResultShareText != null) ...[
          SizedBox(
            width: double.infinity,
            child: EmberButton('Copy daily result',
                key: const ValueKey('copy-daily-result'),
                ghost: true,
                icon: Icons.copy, onTap: () async {
              final text = c.dailyResultShareText;
              if (text == null) return;
              await Clipboard.setData(ClipboardData(text: text));
              c.announce('Result copied');
            }),
          ),
          const SizedBox(height: Space.m),
        ],
        SizedBox(
          width: double.infinity,
          child: EmberButton('Back to the fire',
              ghost: true, onTap: () => c.endToTitle()),
        ),
      ]),
              ),
            ),
          ),
        );
      }),
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
