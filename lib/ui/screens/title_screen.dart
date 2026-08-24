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
    return Stack(
      fit: StackFit.expand,
      children: [
        const Vignette(strength: 0.55),
        EmberDrift(count: 30, warm: warm, bright: bright),
        // Scroll-safe shell: on tall phones the Spacers breathe as before; on
        // short screens (<=320x568) the column scrolls instead of overflowing.
        //
        // PERF (2026-07-26, remaining-work §5): any setState below a
        // LayoutBuilder marks the LayoutBuilder needs-layout, and its relayout
        // marks needs-paint UP to the nearest ancestor boundary — which was the
        // ROUTE's boundary, so every 80ms button-press animation repainted the
        // entire screen (probe: title storm 38.8 paints/frame). The boundary
        // ABOVE the LayoutBuilder stops that bubble; the one BELOW it makes the
        // contained repaint a recomposite instead of a subtree repaint.
        RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, box) {
              return RepaintBoundary(
                child: SingleChildScrollView(
                  // Tablet clamp (v0.26.0): Center + maxWidth keep the menu
                  // column from stretching edge to edge on 800dp tablets.
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: box.maxHeight,
                        maxWidth: kMaxContentWidth,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.all(Space.xl),
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.topRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // The Ledger (v0.3.3): lifetime stats + hearth colors.
                                    IconButton(
                                      key: const ValueKey('ledger-button'),
                                      icon: const Icon(
                                        Icons.menu_book,
                                        color: EmberColors.textDim,
                                        size: 26,
                                      ),
                                      tooltip: 'The Ledger',
                                      onPressed: () {
                                        AudioService.instance?.playSfx(
                                          'ui_tap',
                                        );
                                        Navigator.of(context).push(
                                          emberRoute((_) => LedgerScreen(c)),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.settings,
                                        color: EmberColors.textDim,
                                        size: 26,
                                      ),
                                      tooltip: 'Settings',
                                      onPressed: () {
                                        AudioService.instance?.playSfx(
                                          'ui_tap',
                                        );
                                        Navigator.of(context).push(
                                          emberRoute(
                                            (_) => const SettingsScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              // Drawn logotype: glow bloom + charred-top/molten-bottom fill +
                              // spark pinpricks (visuals.md #1 — never a plain Text).
                              const EmberLogotype('EMBERDELVE', fontSize: 42),
                              const SizedBox(height: Space.s),
                              Text(
                                'A dice-builder delve into the dark',
                                style: EmberText.bodyDim,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: Space.xl),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ResourcePip(
                                    Icons.local_fire_department,
                                    EmberColors.ember,
                                    m.embers,
                                    'EMBERS',
                                    imageAsset: Art.currencyEmber,
                                  ),
                                  const SizedBox(width: Space.xl),
                                  _statText(
                                    '${m.runsWon}/${m.runsPlayed}',
                                    'WINS',
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // The delver, idling by a fire while the dark waits below.
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  SpriteView(
                                    defaultCharacter,
                                    height: 72,
                                    dye: Art.dyeFilter(m.activeDye),
                                  ),
                                  const SizedBox(width: Space.l),
                                  CampFire(
                                    size: 40,
                                    warm: warm,
                                    bright: bright,
                                  ),
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
                                child: EmberButton(
                                  'Delve',
                                  primary: true,
                                  icon: Icons.bolt,
                                  onTap: () => c.startRun(
                                    character: defaultCharacter,
                                    boons: true,
                                  ),
                                ),
                              ),
                              const SizedBox(height: Space.m),
                              // Daily Delve: one shared seed per local calendar date — everyone
                              // gets the same delve. No streaks, no expiry pressure (§Ethics).
                              SizedBox(
                                width: double.infinity,
                                child: EmberButton(
                                  'Daily Delve — ${_dailyLabel()}',
                                  icon: Icons.today,
                                  onTap: () => c.startDailyRun(
                                    character: defaultCharacter,
                                  ),
                                ),
                              ),
                              const SizedBox(height: Space.xs),
                              // Today's Trial (v0.9.0): the ONE declared rule
                              // this date carries, spelled out before you
                              // commit — same charter as the weekly modifier
                              // line. A goal day states its bonus as a fact.
                              Text(
                                _dailyTrialLine(),
                                key: const ValueKey('daily-trial-line'),
                                style: EmberText.micro.copyWith(
                                  color: EmberColors.textDim,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              // Daily recap (v0.3.4): a small honest checkmark on the day it was
                              // played. Replaying stays allowed — no lockout, no streaks.
                              if (m.lastDailyDate ==
                                  dailyKey(DateTime.now())) ...[
                                const SizedBox(height: Space.s),
                                Text(
                                  dailyRecapLine(
                                    won: m.lastDailyWon,
                                    floor: m.lastDailyFloor,
                                    floors: m.lastDailyFloors,
                                  ),
                                  key: const ValueKey('daily-recap'),
                                  style: EmberText.micro,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: Space.m),
                              // Weekly Delve (P3): one shared seed AND one declared
                              // modifier per Monday-aligned week — the same challenge
                              // for everyone. No streaks, no expiry (§Ethics).
                              SizedBox(
                                width: double.infinity,
                                child: EmberButton(
                                  'Weekly Delve — ${_weeklyModifierName()}',
                                  key: const ValueKey('weekly-delve'),
                                  icon: Icons.event_repeat,
                                  onTap: () => c.startWeeklyRun(
                                    character: defaultCharacter,
                                  ),
                                ),
                              ),
                              const SizedBox(height: Space.xs),
                              // The rule, spelled out before you commit — the modifier
                              // IS the difficulty, so it must never be a surprise.
                              Text(
                                _weeklyModifierBlurb(),
                                key: const ValueKey('weekly-modifier'),
                                style: EmberText.micro.copyWith(
                                  color: EmberColors.textDim,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              // Weekly recap: a small honest checkmark for the week it
                              // was played. Replaying stays allowed — no lockout.
                              if (m.lastWeeklyKey ==
                                  weeklyKey(_thisWeek())) ...[
                                const SizedBox(height: Space.s),
                                Text(
                                  weeklyRecapLine(
                                    won: m.lastWeeklyWon,
                                    floor: m.lastWeeklyFloor,
                                    floors: m.lastWeeklyFloors,
                                  ),
                                  key: const ValueKey('weekly-recap'),
                                  style: EmberText.micro,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: Space.m),
                              SizedBox(
                                width: double.infinity,
                                child: EmberButton(
                                  'Choose a delver',
                                  ghost: true,
                                  onTap: () => Navigator.of(
                                    context,
                                  ).push(emberRoute((_) => CharacterScreen(c))),
                                ),
                              ),
                              const SizedBox(height: Space.s),
                              // Seeded delve (v0.3.4): the sim is fully seed-deterministic, so a
                              // shared seed IS a shared delve. Small, out of the main flow.
                              TextButton(
                                key: const ValueKey('seeded-delve'),
                                onPressed: () => _promptSeed(context),
                                child: Text(
                                  'Delve a seed',
                                  style: EmberText.micro.copyWith(
                                    color: EmberColors.textDim,
                                  ),
                                ),
                              ),
                              // The Hearthside Post (v0.15.0): shown ONCE per
                              // release after an update, dismissed forever with
                              // one tap, re-readable from Settings. Fresh
                              // installs never see it (stamped at boot).
                              if (m.lastSeenNewsVersion != currentAppVersion &&
                                  newsFor(currentAppVersion) != null) ...[
                                const SizedBox(height: Space.m),
                                _HearthsidePost(c),
                              ],
                              // The Watchtower (v0.21.0): the opt-in launch
                              // check found a newer release. ONE quiet line,
                              // never a modal or badge; tap opens Settings
                              // and the dismissal sticks per-version.
                              AnimatedBuilder(
                                animation: UpdateService.instance.tick,
                                builder: (context, _) {
                                  final tag = UpdateService.instance.noticeTag;
                                  if (tag == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return TextButton(
                                    key: const ValueKey('update-notice'),
                                    onPressed: () {
                                      UpdateService.instance.dismissNotice();
                                      Navigator.of(context).push(
                                        emberRoute(
                                          (_) => const SettingsScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'v$tag is available — see Settings',
                                      style: EmberText.micro.copyWith(
                                        color: EmberColors.textDim,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A seed decides the whole delve — map, offers, rolls. '
              'Paste a Delve Code or a number from a run summary, or '
              'type any word.',
              style: EmberText.bodyDim,
            ),
            const SizedBox(height: Space.m),
            TextField(
              key: const ValueKey('seed-field'),
              controller: input,
              autofocus: true,
              style: EmberText.body,
              decoration: const InputDecoration(hintText: 'seed or word'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Cancel', style: EmberText.bodyDim),
          ),
          TextButton(
            key: const ValueKey('seed-start'),
            onPressed: () {
              // v0.37.0: a Delve Code carries the WHOLE challenge — seed,
              // delver, difficulty, ascension. Locked tiers still clamp
              // down via startRun's clampRunParams guarantee.
              final code = decodeDelveCode(input.text);
              if (code != null) {
                Navigator.of(dialogCtx).pop();
                c.startRun(
                  character: code.character,
                  boons: true,
                  seed: code.seed,
                  difficulty: code.difficulty,
                  ascension: code.ascension,
                );
                return;
              }
              final seed = parseSeedInput(input.text);
              if (seed == null) return; // blank: nothing to delve
              Navigator.of(dialogCtx).pop();
              c.startRun(character: defaultCharacter, boons: true, seed: seed);
            },
            child: Text(
              'Delve',
              style: EmberText.body.copyWith(color: EmberColors.ember),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statText(String v, String l) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(v, style: EmberText.value.copyWith(fontSize: 18)),
      Text(l, style: EmberText.micro),
    ],
  );

  /// Local calendar date the daily seed is drawn from, e.g. "Jul 24".
  static String _dailyLabel() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.day}';
  }

  /// The current Monday-aligned week index (local clock). One place so the
  /// button, blurb, and recap can never disagree about which week it is.
  static int _thisWeek() => weekIndexForDate(DateTime.now());

  /// Display name of this week's declared modifier, e.g. "Flint Week".
  static String _weeklyModifierName() =>
      mutatorDef(weeklyMutatorFor(_thisWeek())).name;

  /// One-line description of this week's modifier, shown under the button.
  static String _weeklyModifierBlurb() =>
      mutatorDef(weeklyMutatorFor(_thisWeek())).blurb;

  /// Today's Trial line under the Daily Delve button (v0.9.0): the trial
  /// name, its rule, and — on a goal day — the ember bonus, stated as a
  /// fact. No countdowns, no pressure (§Ethics).
  static String _dailyTrialLine() {
    final now = DateTime.now();
    final t = trialForDate(now.year, now.month, now.day);
    final bonus = t.emberBonus > 0
        ? ' Met, it pays +${t.emberBonus} embers.'
        : '';
    return '${t.name} — ${t.blurb}$bonus';
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
        : _options.firstWhere(
            (o) => o.$1 == current,
            orElse: () => _options[1],
          );
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: EmberColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EmberColors.line),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              for (final (id, label, _) in _options)
                Expanded(
                  child: GestureDetector(
                    key: ValueKey('difficulty-$id'),
                    onTap: () {
                      // Ember Forge (v0.4.0): HARD is part of the Forge. A
                      // tap on the locked segment opens the sheet instead of
                      // silently failing — the lock icon says why.
                      if (!canSelectDifficulty(c.meta, id)) {
                        showForgeSheet(context, c);
                        return;
                      }
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
                              : Colors.transparent,
                        ),
                      ),
                      // FittedBox: the lock+label pair must never overflow
                      // the segment on 320px screens at 1.3x text (overflow
                      // probe) — scale down instead.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!canSelectDifficulty(c.meta, id)) ...[
                              const Icon(
                                Icons.lock,
                                size: 11,
                                color: EmberColors.textDim,
                              ),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: EmberText.micro.copyWith(
                                color: id == current
                                    ? EmberColors.textPrimary
                                    : EmberColors.textDim,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          hint.$3,
          style: EmberText.micro.copyWith(color: EmberColors.textDim),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Boon pick — 1-of-3 starting blessing, always skippable (spec §Ethics: no
// timer, no decay; the offer is exactly what the sim telegraphed).
// ---------------------------------------------------------------------------

/// The Hearthside Post (v0.15.0): a small thank-you note after an update —
/// the release's name and 2–4 lines, with a single "Noted" button. Never a
/// badge, never a nag, never a link to spend money (§Ethics). Content lives
/// in data/news.dart; dismissal persists via GameController.dismissNews.
class _HearthsidePost extends StatelessWidget {
  final GameController c;
  const _HearthsidePost(this.c);
  @override
  Widget build(BuildContext context) {
    final entry = newsFor(currentAppVersion);
    if (entry == null) return const SizedBox.shrink();
    return Panel(
      key: const ValueKey('news-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THE HEARTHSIDE POST — v${entry.version}',
            style: EmberText.micro,
          ),
          const SizedBox(height: Space.xs),
          // This release's note is named after the panel itself — skip the
          // duplicate line rather than print the same words twice.
          if (entry.title.toLowerCase() != 'the hearthside post') ...[
            Text(entry.title, style: EmberText.body),
            const SizedBox(height: Space.s),
          ],
          for (final line in entry.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Text(line, style: EmberText.bodyDim),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('news-dismiss'),
              onPressed: c.dismissNews,
              child: Text(
                'Noted',
                style: EmberText.body.copyWith(color: EmberColors.ember),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
