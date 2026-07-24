// lib/ui/screens/top_bar.dart — part of screens.dart (see library header there).
part of '../screens.dart';

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
        // Flexible + FittedBox: on narrow screens (320dp) with fat purses the
        // pips scale down instead of overflowing the bar on the right.
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ResourcePip(
                  Icons.circle, EmberColors.gold, run['gold'] as int, 'GOLD',
                  imageAsset: Art.currencyCoin),
              const SizedBox(width: Space.xl),
              ResourcePip(Icons.local_fire_department, EmberColors.ember,
                  run['embers'] as int, 'EMBERS',
                  imageAsset: Art.currencyEmber),
            ]),
          ),
        ),
        const SizedBox(width: Space.s),
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
