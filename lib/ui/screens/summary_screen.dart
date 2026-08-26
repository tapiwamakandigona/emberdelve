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
              // Tablet clamp (v0.26.0): Center + maxWidth keep the summary
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
                          const Spacer(),
                          // v0.69.0 The Standing Delver: the run's OWN
                          // delver stands where a generic trophy/flame
                          // stood — in their worn dye, breathing on a win,
                          // still on a loss (stillness is the dignity).
                          // Same 56dp slot as the old icon, so rhythm and
                          // short-screen behavior never shift.
                          Builder(
                            builder: (context) {
                              final charId =
                                  run['character'] as String? ??
                                  defaultCharacter;
                              return Opacity(
                                opacity: won ? 1 : 0.55,
                                child: SpriteView(
                                  charId,
                                  key: const ValueKey('summary-delver'),
                                  height: 56,
                                  animate: false,
                                  bob: won,
                                  dye: Art.dyeFilter(c.meta.dyeFor(charId)),
                                ),
                              );
                            },
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
                                      (won
                                              ? EmberColors.gold
                                              : EmberColors.ember)
                                          .withValues(alpha: 0.55),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Space.s),
                          // The delver's name with their worn title — the
                          // picker's voice, on the screen where the run's
                          // identity pays off.
                          Builder(
                            builder: (context) {
                              final charId =
                                  run['character'] as String? ??
                                  defaultCharacter;
                              final name = c.meta.nameFor(charId);
                              final title =
                                  epithets[c.meta.epithetFor(charId)]?.title;
                              return Text(
                                title == null ? name : '$name, $title',
                                key: const ValueKey('summary-delver-name'),
                                textAlign: TextAlign.center,
                                style: EmberText.body.copyWith(
                                  color: EmberColors.textDim,
                                ),
                              );
                            },
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
                          // v0.13.0 Delver's Rank: one quiet line when this
                          // run's banking crossed a tier. No badge rain, no
                          // reward talk — the Ledger holds the detail.
                          if (c.pendingRankUp != null) ...[
                            const SizedBox(height: Space.l),
                            Text(
                              'You delve as '
                              '${c.pendingRankUp!.withArticle} now.',
                              key: const ValueKey('rank-up-line'),
                              textAlign: TextAlign.center,
                              style: EmberText.body.copyWith(
                                color: EmberColors.gold,
                              ),
                            ),
                          ],
                          // v0.61.0 The Deepest Mark: one quiet line when
                          // THIS run stood deeper than any before it — shown
                          // on wins and losses alike (a lost run can still be
                          // the deepest; the record is the dignity). Pure
                          // fact, no next-goal teaser (§Ethics).
                          // v0.68.0 The Earned Name: one quiet line per
                          // epithet this run's banking earned. A fact about
                          // a name already won — no button, no teaser; the
                          // wardrobe holds the detail (rank-up restraint).
                          for (final id in c.pendingEpithets) ...[
                            const SizedBox(height: Space.l),
                            Text(
                              '\u201c${epithets[id]?.title}\u201d is yours '
                              'to wear.',
                              key: ValueKey('earned-name-$id'),
                              textAlign: TextAlign.center,
                              style: EmberText.body.copyWith(
                                color: EmberColors.gold,
                              ),
                            ),
                          ],
                          if (c.pendingDeepestFloor != null) ...[
                            const SizedBox(height: Space.l),
                            Text(
                              'Floor ${c.pendingDeepestFloor} — the deepest '
                              'you have delved.',
                              key: const ValueKey('deepest-line'),
                              textAlign: TextAlign.center,
                              style: EmberText.body.copyWith(
                                color: EmberColors.gold,
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
                          // v0.11.0 Delver's Ledger: the firsts this run
                          // produced — quiet, factual, absent when there are
                          // none. Names resolve through enemies.dart so a
                          // rename can never leave this line lying.
                          if (_firstsLine(c) != null) ...[
                            Text(
                              _firstsLine(c)!,
                              key: const ValueKey('firsts-line'),
                              textAlign: TextAlign.center,
                              style: EmberText.micro.copyWith(
                                color: EmberColors.textDim,
                              ),
                            ),
                            const SizedBox(height: Space.s),
                          ],
                          // v0.31.0 (retention hook #6): the codex pull. The
                          // moment the record grows is the only honest moment
                          // to name the collection — one factual line, shown
                          // only when this run produced a first, win or loss
                          // (records grow either way). No button, no urgency,
                          // no price talk; the Ledger holds the door (§Ethics).
                          if (_firstsLine(c) != null) ...[
                            Text(
                              'Their tales wait in the Codex — '
                              '${c.meta.ownedCodex.length} of '
                              '${codexEntries.length} unsealed.',
                              key: const ValueKey('codex-pull-line'),
                              textAlign: TextAlign.center,
                              style: EmberText.micro.copyWith(
                                color: EmberColors.textDim,
                              ),
                            ),
                            const SizedBox(height: Space.s),
                          ],
                          // v0.32.0 (retention hook #7): an earned rung.
                          // Shown only when THIS win raised bestAscension
                          // AND the profile owns the Forge — a free
                          // profile's first win moves the ledger number but
                          // cannot climb, and saying so would be a soft
                          // upsell (§Ethics, v0.32.0 design doc). Pure
                          // fact, no button, no price talk.
                          if (c.pendingRungOpened != null &&
                              c.meta.forgeUnlocked) ...[
                            Text(
                              'Rung ${c.pendingRungOpened} of the '
                              'Ascension now stands open.',
                              key: const ValueKey('rung-open-line'),
                              textAlign: TextAlign.center,
                              style: EmberText.micro.copyWith(
                                color: EmberColors.textDim,
                              ),
                            ),
                            const SizedBox(height: Space.s),
                          ],
                          // Today's Trial chip (v0.9.0): shown ONLY when a
                          // goal-day daily met its objective — the bonus is a
                          // banked fact by the time this screen exists. A
                          // missed goal renders nothing at all (§Ethics).
                          if (c.dailyTrialBonus > 0) ...[
                            Text(
                              'Trial met ✦ +${c.dailyTrialBonus} embers',
                              key: const ValueKey('trial-met-chip'),
                              textAlign: TextAlign.center,
                              style: EmberText.micro.copyWith(
                                color: EmberColors.gold,
                              ),
                            ),
                            const SizedBox(height: Space.s),
                          ],
                          // Run seed (v0.3.4) upgraded to a Delve Code
                          // (v0.37.0): the code packs seed + delver +
                          // difficulty + ascension, so a friend plays THIS
                          // run. Tap to copy; falls back to the bare seed
                          // when the run can't be encoded.
                          Builder(
                            builder: (context) {
                              final run = c.state!['run'] as Map;
                              final code = encodeDelveCode(
                                seed: c.sim?.runSeed ?? 0,
                                character:
                                    run['character'] as String? ??
                                    defaultCharacter,
                                difficulty:
                                    run['difficulty'] as String? ?? 'normal',
                                ascension:
                                    int.tryParse('${run['ascension'] ?? 0}') ??
                                    0,
                                shortRoad:
                                    c.sim?.hasMutator('short_road') ?? false,
                              );
                              final label = code ?? 'Seed ${c.sim?.runSeed}';
                              return GestureDetector(
                                key: const ValueKey('run-seed'),
                                onTap: () async {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: code ?? '${c.sim?.runSeed ?? ''}',
                                    ),
                                  );
                                  c.announce(
                                    code == null
                                        ? 'Seed copied'
                                        : 'Delve Code copied',
                                  );
                                },
                                child: Text(
                                  '$label — tap to copy',
                                  textAlign: TextAlign.center,
                                  style: EmberText.micro.copyWith(
                                    color: EmberColors.textDim,
                                  ),
                                ),
                              );
                            },
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
                          // v0.29.0 (retention hook #3): a summary should
                          // always name a next action. After a win on EASY,
                          // one quiet panel says Normal exists — same delve,
                          // sharper teeth, full ember rate (easy banks 0.75x,
                          // see sim/run_layer.dart). Factual invitation only:
                          // never a popup, never blocks the buttons below,
                          // nothing lost by ignoring it (spec §5 endorsement
                          // test). Taking it is an explicit difficulty choice.
                          if (won &&
                              (run['difficulty'] as String? ?? 'normal') ==
                                  'easy') ...[
                            const SizedBox(height: Space.l),
                            Panel(
                              key: const ValueKey('normal-nudge'),
                              color: EmberColors.raised,
                              // Column, not Row: the CTA label is wide, and a
                              // trailing button starves the text on 360dp
                              // phones (plate critique, v0.29.0).
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.terrain,
                                        color: EmberColors.gold,
                                        size: 20,
                                      ),
                                      const SizedBox(width: Space.m),
                                      Expanded(
                                        child: Text(
                                          'The easy delve is tamed. The same '
                                          'halls wait on Normal — sharper '
                                          'teeth, a fuller ember pouch.',
                                          style: EmberText.body,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: Space.m),
                                  EmberButton(
                                    'Delve Normal',
                                    dense: true,
                                    key: const ValueKey('delve-normal-cta'),
                                    onTap: () => c.delveNormal(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // v0.39.0 The Waymarks: the ledger's "so close"
                          // resolver (nearestAchievements — tested since
                          // v0.5.0, surfaced nowhere until now) names up to
                          // two unearned marks the player has ALREADY
                          // started. Bare counts only; zero-progress goals
                          // are excluded, because a goal you have not started
                          // is not a goal you are near. Shows after wins AND
                          // losses — the counters banked either way, so the
                          // fact is equally true (§Ethics: recognition facts,
                          // no urgency, no reward, nothing sold; ignoring it
                          // costs nothing).
                          Builder(
                            builder: (context) {
                              final near = ach.nearestAchievements(
                                c.meta,
                                limit: 2,
                              );
                              if (near.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: Space.l),
                                child: Panel(
                                  key: const ValueKey('waymarks'),
                                  color: EmberColors.raised,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'WITHIN REACH',
                                        style: EmberText.micro,
                                      ),
                                      for (final def in near) ...[
                                        const SizedBox(height: Space.m),
                                        Row(
                                          key: ValueKey('waymark-${def.id}'),
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    def.name,
                                                    style: EmberText.body,
                                                  ),
                                                  Text(
                                                    def.text,
                                                    style: EmberText.bodyDim,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: Space.m),
                                            Text(
                                              '${ach.statValue(c.meta, def.stat, def.param)}'
                                              ' of ${def.target}',
                                              style: EmberText.value.copyWith(
                                                color: EmberColors.gold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
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
                          // v0.44.0 The Retraced Road: a lost delve offers
                          // one more honest door — the SAME seed, so the map,
                          // offers, and rolls repeat and only the choices
                          // change (learning made playable). Quiet ghost
                          // button, no urgency; shared-seed runs never show
                          // it (controller.canRetrace).
                          if (c.canRetrace) ...[
                            const SizedBox(height: Space.m),
                            SizedBox(
                              width: double.infinity,
                              child: EmberButton(
                                'Retrace this delve',
                                key: const ValueKey('retrace-delve'),
                                ghost: true,
                                icon: Icons.replay,
                                onTap: () => c.retraceDelve(),
                              ),
                            ),
                            const SizedBox(height: Space.s),
                            Text(
                              'Same map, same offers, same rolls — '
                              'only your choices change.',
                              key: const ValueKey('retrace-fact'),
                              style: EmberText.micro,
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: Space.m),
                          // v0.51.0 The Obituary: the run's story told back
                          // in two or three sentences — every figure real
                          // (design doc v0.51.0-delve-obituary-design.md).
                          // Losses get a dignified epitaph, wins a proud one;
                          // deterministic per run, so retelling never drifts.
                          if (c.delveStoryText != null) ...[
                            Text(
                              c.delveStoryText!,
                              key: const ValueKey('delve-story'),
                              style: EmberText.micro.copyWith(
                                color: EmberColors.textDim,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: Space.m),
                          ],
                          // v0.34.0 The Delver's Card: an IMAGE of this run,
                          // previewed before it leaves the device (design doc
                          // v0.34.0-delvers-card-design.md). Player-initiated,
                          // never prompted, never rewarded (§Ethics); loss
                          // cards are equally supported — honesty is the
                          // brand.
                          SizedBox(
                            width: double.infinity,
                            child: EmberButton(
                              'Share this delve',
                              key: const ValueKey('share-delve-card'),
                              ghost: true,
                              icon: Icons.ios_share,
                              onTap: () => showDelverCardSheet(context, c),
                            ),
                          ),
                          const SizedBox(height: Space.m),
                          // v0.51.0: the story above, as plain text that
                          // pastes anywhere — same pattern as the daily copy
                          // below. Player-initiated, never rewarded (§Ethics).
                          if (c.delveStoryText != null) ...[
                            SizedBox(
                              width: double.infinity,
                              child: EmberButton(
                                'Copy delve story',
                                key: const ValueKey('copy-delve-story'),
                                ghost: true,
                                icon: Icons.copy,
                                onTap: () async {
                                  final text = c.delveStoryText;
                                  if (text == null) return;
                                  await Clipboard.setData(
                                    ClipboardData(text: text),
                                  );
                                  c.announce('Story copied');
                                },
                              ),
                            ),
                            const SizedBox(height: Space.m),
                          ],
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
                                    leaderboardId:
                                        c.dailyResultShareText != null
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

/// v0.11.0 Delver's Ledger: the firsts THIS run produced, or null when it
/// produced none. First sightings are enemies whose lifetime met-count went
/// 0 -> 1 this run; first fellings the same for wins. Sorted for stable
/// copy; names resolve live from enemies.dart.
String? _firstsLine(GameController c) {
  String names(Set<String> ids) =>
      (ids.toList()..sort()).map((id) => enemies[id]?.name ?? id).join(' · ');
  final parts = <String>[
    if (c.runFirstMet.isNotEmpty) 'First sighting: ${names(c.runFirstMet)}',
    if (c.runFirstFelled.isNotEmpty)
      'First felling: ${names(c.runFirstFelled)}',
  ];
  return parts.isEmpty ? null : parts.join('\n');
}
