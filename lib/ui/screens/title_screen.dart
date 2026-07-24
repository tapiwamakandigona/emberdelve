// lib/ui/screens/title_screen.dart — part of screens.dart (see library header there).
part of '../screens.dart';

class TitleScreen extends StatelessWidget {
  final GameController c;
  const TitleScreen(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final m = c.meta;
    // Hearth colors (v0.3.3): the active theme retints the title hearth.
    // The default theme passes null tints => byte-identical classic render.
    final theme = hearthThemeDef(m.activeTheme);
    final themed = theme.id != defaultTheme;
    final warm = themed ? Color(theme.warmArgb) : null;
    final bright = themed ? Color(theme.brightArgb) : null;
    return Stack(fit: StackFit.expand, children: [
      const Vignette(strength: 0.55),
      EmberDrift(count: 30, warm: warm, bright: bright),
      // Scroll-safe shell: on tall phones the Spacers breathe as before; on
      // short screens (<=320x568) the column scrolls instead of overflowing.
      LayoutBuilder(builder: (context, box) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Column(children: [
          Align(
            alignment: Alignment.topRight,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // The Ledger (v0.3.3): lifetime stats + hearth colors.
              IconButton(
                key: const ValueKey('ledger-button'),
                icon: const Icon(Icons.menu_book,
                    color: EmberColors.textDim, size: 26),
                tooltip: 'The Ledger',
                onPressed: () {
                  AudioService.instance?.playSfx('ui_tap');
                  Navigator.of(context)
                      .push(emberRoute((_) => LedgerScreen(c)));
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings,
                    color: EmberColors.textDim, size: 26),
                tooltip: 'Settings',
                onPressed: () {
                  AudioService.instance?.playSfx('ui_tap');
                  Navigator.of(context)
                      .push(emberRoute((_) => const SettingsScreen()));
                },
              ),
            ]),
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
            children: [
              const SpriteView(defaultCharacter, height: 72),
              const SizedBox(width: Space.l),
              CampFire(size: 40, warm: warm, bright: bright),
            ],
          ),
          const SizedBox(height: Space.xxl),
          // Difficulty selector (v0.3.2): sticky, honest about the trade —
          // easier fights pay fewer embers, harder fights pay more. The
          // Daily Delve ignores it (shared seed, level field for everyone).
          _DifficultySelector(c),
          const SizedBox(height: Space.m),
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
          // Daily recap (v0.3.4): a small honest checkmark on the day it was
          // played. Replaying stays allowed — no lockout, no streaks.
          if (m.lastDailyDate == dailyKey(DateTime.now())) ...[
            const SizedBox(height: Space.s),
            Text(
              dailyRecapLine(
                  won: m.lastDailyWon,
                  floor: m.lastDailyFloor,
                  floors: m.lastDailyFloors),
              key: const ValueKey('daily-recap'),
              style: EmberText.micro,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: Space.m),
          SizedBox(
            width: double.infinity,
            child: EmberButton('Choose a delver',
                ghost: true,
                onTap: () => Navigator.of(context)
                    .push(emberRoute((_) => CharacterScreen(c)))),
          ),
          const SizedBox(height: Space.s),
          // Seeded delve (v0.3.4): the sim is fully seed-deterministic, so a
          // shared seed IS a shared delve. Small, out of the main flow.
          TextButton(
            key: const ValueKey('seeded-delve'),
            onPressed: () => _promptSeed(context),
            child: Text('Delve a seed',
                style: EmberText.micro.copyWith(color: EmberColors.textDim)),
          ),
                ]),
              ),
            ),
          ),
        );
      }),
    ]);
  }

  /// Custom-seed dialog: paste a number from a summary screen (exact replay)
  /// or type any word (hashed deterministically — same word, same delve).
  void _promptSeed(BuildContext context) {
    final input = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: EmberColors.surface,
        title: Text('Delve a seed', style: EmberText.h2),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              'A seed decides the whole delve — map, offers, rolls. '
              'Paste a number from a run summary, or type any word.',
              style: EmberText.bodyDim),
          const SizedBox(height: Space.m),
          TextField(
            key: const ValueKey('seed-field'),
            controller: input,
            autofocus: true,
            style: EmberText.body,
            decoration: const InputDecoration(hintText: 'seed or word'),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Cancel', style: EmberText.bodyDim),
          ),
          TextButton(
            key: const ValueKey('seed-start'),
            onPressed: () {
              final seed = parseSeedInput(input.text);
              if (seed == null) return; // blank: nothing to delve
              Navigator.of(dialogCtx).pop();
              c.startRun(
                  character: defaultCharacter, boons: true, seed: seed);
            },
            child: Text('Delve',
                style: EmberText.body.copyWith(color: EmberColors.ember)),
          ),
        ],
      ),
    );
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

/// Three-segment easy/normal/hard switch (v0.3.2). Sticky via MetaState and
/// honest about the trade (easier foes pay fewer embers, harder pay more) so
/// the choice is informed, never a trap. Daily Delve always runs on normal.
class _DifficultySelector extends StatelessWidget {
  final GameController c;
  const _DifficultySelector(this.c);

  static const _options = [
    ('easy', 'EASY', 'gentler foes · embers ×0.75'),
    ('normal', 'NORMAL', 'the delve as intended'),
    ('hard', 'HARD', 'brutal foes · embers ×1.25'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = c.meta.preferredDifficulty;
    // First-run on-ramp (v0.3.3, analysis caveat 1): a brand-new profile is
    // steered to easy on the VISIBLE selector with an honest caption — 58%
    // of bot deaths on normal happen before a single fight is won, so new
    // players get an on-ramp, never a silent switch. One tap ends it.
    final hint = c.meta.steerToEasy && current == 'easy'
        ? ('easy', 'EASY', 'recommended for your first delve')
        : _options.firstWhere((o) => o.$1 == current,
            orElse: () => _options[1]);
    return Column(children: [
      Container(
        decoration: BoxDecoration(
          color: EmberColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EmberColors.line),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(children: [
          for (final (id, label, _) in _options)
            Expanded(
              child: GestureDetector(
                key: ValueKey('difficulty-$id'),
                onTap: () {
                  AudioService.instance?.playSfx('ui_tap');
                  c.setPreferredDifficulty(id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: Space.s),
                  decoration: BoxDecoration(
                    color: id == current
                        ? EmberColors.raised
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: id == current
                            ? EmberColors.ember
                            : Colors.transparent),
                  ),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: EmberText.micro.copyWith(
                          color: id == current
                              ? EmberColors.textPrimary
                              : EmberColors.textDim,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: Space.xs),
      Text(hint.$3,
          style: EmberText.micro.copyWith(color: EmberColors.textDim)),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Boon pick — 1-of-3 starting blessing, always skippable (spec §Ethics: no
// timer, no decay; the offer is exactly what the sim telegraphed).
// ---------------------------------------------------------------------------
