// lib/ui/ledger_screen.dart — The Ledger (v0.3.3): lifetime stats + hearth
// colors. The macro-loop chase after all delvers unlock (gameplay analysis
// caveat 3): every number is REAL and earned (§Ethics honesty — no faked
// progress, no timers, no FOMO), and hearth colors are a pure-cosmetic ember
// sink with prices shown up front.
//
// v0.5.0 adds the Delver's Ledger achievement list. Same honesty rule: every
// bar is REAL banked progress (see meta/achievements.dart), nothing is a
// teaser, and no achievement grants anything — they are recognition only, so
// the list can never turn into a grind gate.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../audio/audio_service.dart';
import '../data/achievements.dart';
import '../data/characters.dart';
import '../data/codex.dart';
import '../data/enemies.dart';
import '../data/skins.dart';
import '../data/tracks.dart';
import '../data/themes.dart';
import '../game/controller.dart';
import '../game/delve_code.dart';
import '../meta/achievements.dart' as ach;
import '../meta/meta.dart';
import '../meta/rank.dart';
import 'codex_screen.dart';
import 'fx.dart';
import 'theme.dart';
import 'widgets.dart';

class LedgerScreen extends StatelessWidget {
  final GameController c;
  const LedgerScreen(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('The Ledger', style: EmberText.h2),
        backgroundColor: EmberColors.bg,
        leading: BackButton(
          onPressed: () {
            AudioService.instance?.playSfx('ui_back');
            Navigator.of(context).pop();
          },
        ),
      ),
      // Tablet clamp (v0.26.0): content caps at kMaxContentWidth.
      body: ContentClamp(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: c,
            builder: (context, _) {
              final m = c.meta;
              final rank = rankFor(m);
              final next = nextRank(m);
              return ListView(
                padding: const EdgeInsets.all(Space.l),
                children: [
                  // v0.13.0 Delver's Rank: derived from the counters below —
                  // every mark is real banked history (§Ethics honesty), and
                  // the next-tier line shows REAL earned progress, never a
                  // teaser that resets or expires.
                  Panel(
                    key: const ValueKey('rank-line'),
                    color: EmberColors.raised,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium,
                          color: EmberColors.gold,
                          size: 28,
                        ),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You delve as ${rank.withArticle}',
                                style: EmberText.body.copyWith(
                                  color: EmberColors.gold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rank.flavor,
                                style: EmberText.micro.copyWith(
                                  color: EmberColors.textDim,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                next == null
                                    ? '${rankMarks(m)} marks — the ladder '
                                          'ends here'
                                    : '${rankMarks(m)} marks · '
                                          '${next.name} at ${next.marks}',
                                style: EmberText.micro.copyWith(
                                  color: EmberColors.textDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.l),
                  Text('LIFETIME', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  Panel(
                    child: Column(
                      children: [
                        _row(
                          Icons.local_fire_department,
                          EmberColors.ember,
                          'Embers banked, all time',
                          '${m.lifetimeEmbers}',
                        ),
                        const Divider(
                          color: EmberColors.line,
                          height: Space.xl,
                        ),
                        _row(
                          Icons.sports_martial_arts,
                          EmberColors.textPrimary,
                          'Delves won',
                          '${m.runsWon} of ${m.runsPlayed}',
                        ),
                        const Divider(
                          color: EmberColors.line,
                          height: Space.xl,
                        ),
                        _row(
                          Icons.trending_up,
                          EmberColors.gold,
                          'Best ascension',
                          '${m.bestAscension}',
                        ),
                        const Divider(
                          color: EmberColors.line,
                          height: Space.xl,
                        ),
                        _row(
                          Icons.adjust,
                          EmberColors.success,
                          'Exact kills',
                          '${m.exactKills}',
                        ),
                        const Divider(
                          color: EmberColors.line,
                          height: Space.xl,
                        ),
                        _row(
                          Icons.bolt,
                          EmberColors.gold,
                          'Best exact-kill streak',
                          '${m.bestExactStreak}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  Text('DELVERS', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  Panel(
                    child: Column(
                      children: [
                        for (final (i, id) in charactersOrder.indexed) ...[
                          if (i > 0)
                            const Divider(
                              color: EmberColors.line,
                              height: Space.xl,
                            ),
                          _delverRow(m, id),
                        ],
                      ],
                    ),
                  ),
                  // Recent delves (v0.3.4, review note #4): the last runs,
                  // newest first — every entry REAL (§Ethics honesty).
                  if (m.runHistory.isNotEmpty) ...[
                    const SizedBox(height: Space.xl),
                    Text('RECENT DELVES', style: EmberText.micro),
                    const SizedBox(height: Space.s),
                    Panel(
                      key: const ValueKey('recent-delves'),
                      child: Column(
                        children: [
                          for (final (i, r)
                              in m.runHistory.take(10).toList().indexed) ...[
                            if (i > 0)
                              const Divider(
                                color: EmberColors.line,
                                height: Space.xl,
                              ),
                            _historyRow(r),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.xl),
                  // Achievements (v0.5.0). Earned first, then the ones closest
                  // to done, then the rest — so the list opens on what the
                  // player has actually achieved.
                  Row(
                    children: [
                      Expanded(
                        child: Text('ACHIEVEMENTS', style: EmberText.micro),
                      ),
                      Text(
                        '${ach.earnedCount(m)} of ${ach.achievementCount}',
                        style: EmberText.label.copyWith(
                          color: EmberColors.textDim,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.s),
                  Panel(
                    key: const ValueKey('achievements'),
                    child: Column(
                      children: [
                        for (final (i, def) in _ordered(m).indexed) ...[
                          if (i > 0)
                            const Divider(
                              color: EmberColors.line,
                              height: Space.xl,
                            ),
                          _achievementRow(m, def),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.s),
                  Text(
                    'Achievements are recognition only — they never change '
                    'a delve, and none of them expires.',
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                  const SizedBox(height: Space.xl),
                  // Hearth colors: tap an owned color to light it; tap a
                  // locked one to buy it with embers (price always shown).
                  Row(
                    children: [
                      Expanded(
                        child: Text('HEARTH COLORS', style: EmberText.micro),
                      ),
                      const Icon(
                        Icons.local_fire_department,
                        color: EmberColors.ember,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${m.embers}',
                        style: EmberText.label.copyWith(
                          color: EmberColors.ember,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.s),
                  for (final id in hearthThemesOrder) ...[
                    _themeCard(context, id),
                    const SizedBox(height: Space.m),
                  ],
                  const SizedBox(height: Space.s),
                  Text(
                    'Hearth colors retint the fire on the title screen. '
                    'Pure cosmetics — the delve itself never changes.',
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                  const SizedBox(height: Space.xl),
                  // Dice skins: same contract as hearth colors — tap an
                  // owned skin to lit it, tap a locked one to buy it.
                  Row(
                    children: [
                      Expanded(
                        child: Text('DICE SKINS', style: EmberText.micro),
                      ),
                      const Icon(
                        Icons.local_fire_department,
                        color: EmberColors.ember,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${m.embers}',
                        style: EmberText.label.copyWith(
                          color: EmberColors.ember,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.s),
                  for (final id in dieSkinsOrder) ...[
                    _skinCard(context, id),
                    const SizedBox(height: Space.m),
                  ],
                  const SizedBox(height: Space.s),
                  Text(
                    'Dice skins repaint every die in play. Pure cosmetics '
                    '— faces, rolls and odds never change.',
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                  const SizedBox(height: Space.xl),
                  // The Codex: lore entries bought with embers, on their own
                  // screen so the Ledger stays scannable.
                  Text('THE CODEX', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  Panel(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.menu_book,
                          color: EmberColors.gold,
                          size: 20,
                        ),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('The Codex', style: EmberText.body),
                              const SizedBox(height: 2),
                              Text(
                                '${m.ownedCodex.length} of '
                                '${codexEntries.length} entries unsealed',
                                style: EmberText.micro.copyWith(
                                  color: EmberColors.textDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                        EmberButton(
                          'OPEN',
                          dense: true,
                          onTap: () {
                            AudioService.instance?.playSfx('ui_tap');
                            Navigator.of(
                              context,
                            ).push(emberRoute((_) => CodexScreen(c)));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.s),
                  Text(
                    'Enemy and relic lore, unsealed with embers. Flavor '
                    'only — every rule stays readable in play for free.',
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                  const SizedBox(height: Space.xl),
                  // v0.33.0 The Gramophone: the soundtrack as a collection.
                  // Tracks unlock by simply playing (each names how, plainly);
                  // tap an unlocked track to hear it here. No purchase, no
                  // timer — a record of what the delve has already sung.
                  Text('THE GRAMOPHONE', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  _GramophoneSection(
                    key: const ValueKey('gramophone-section'),
                    heard: m.heardTracks,
                  ),
                  const SizedBox(height: Space.s),
                  Text(
                    'Every tune the delve has played for you, kept by the '
                    'fire. The rest are earned by delving — each row says '
                    'how.',
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _historyRow(Map<String, Object?> r) {
    final result = r['result'] as String? ?? 'lost';
    final won = result == 'won';
    final abandoned = result == 'abandoned';
    final ch = characters[r['character']]?.name ?? '${r['character']}';
    final diff = r['difficulty'] as String? ?? 'normal';
    final daily = r['daily'] == true;
    // v0.51.0 The Obituary: records now remember WHO ended a lost run.
    // Older records lack the key and render exactly as before.
    final killer = enemies[r['killed_by']]?.name;
    final outcome = won
        ? 'Ember claimed'
        : abandoned
        ? 'walked away'
        : 'fell on floor ${r['floor']} of ${r['floors']}'
              '${killer == null ? '' : ' to $killer'}';
    final icon = won
        ? Icons.emoji_events
        : abandoned
        ? Icons.logout
        : Icons.local_fire_department;
    final color = won
        ? EmberColors.gold
        : abandoned
        ? EmberColors.textDisabled
        : EmberColors.ember;
    // The Remembered Delves (v0.43.0): every remembered run carries enough
    // to rebuild its Delve Code — seed, delver, difficulty, ascension — so
    // any row can be shared or replayed, not just the run that ended last.
    // Records that can't encode (seed 0 from a pre-v0.3.4 save) simply stay
    // quiet rather than offer a code that would lie.
    final code = encodeDelveCode(
      seed: int.tryParse('${r['seed'] ?? 0}') ?? 0,
      character: r['character'] as String? ?? defaultCharacter,
      difficulty: diff,
      ascension: int.tryParse('${r['ascension'] ?? 0}') ?? 0,
      // v0.49.0: a remembered short run rebuilds a SHORT code — the code
      // must reproduce the same six-layer map, never one like it.
      shortRoad: r['short'] == true,
    );
    final row = Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$ch — $outcome', style: EmberText.body),
              const SizedBox(height: 2),
              Text(
                '${daily ? 'daily · ' : ''}$diff · ${r['date']}'
                '${code == null ? '' : ' · tap to copy its Delve Code'}',
                style: EmberText.micro.copyWith(color: EmberColors.textDim),
              ),
            ],
          ),
        ),
        if (code != null)
          const Icon(Icons.copy, size: 14, color: EmberColors.textDim),
      ],
    );
    if (code == null) return row;
    return GestureDetector(
      key: ValueKey('history-code-$code'),
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        AudioService.instance?.playSfx('ui_confirm');
        c.announce('Delve Code copied');
      },
      child: row,
    );
  }

  /// Earned (authoring order), then unearned by descending real progress,
  /// then untouched ones. Deterministic: ties keep authoring order.
  List<AchievementDef> _ordered(MetaState meta) {
    final earned = <AchievementDef>[];
    final started = <AchievementDef>[];
    final untouched = <AchievementDef>[];
    for (final id in achievementsOrder) {
      final def = achievements[id];
      if (def == null) continue;
      if (ach.isEarned(meta, def)) {
        earned.add(def);
      } else if (ach.progress(meta, def) > 0) {
        started.add(def);
      } else {
        untouched.add(def);
      }
    }
    started.sort((a, b) {
      final c = ach.progress(meta, b).compareTo(ach.progress(meta, a));
      if (c != 0) return c;
      return achievementsOrder
          .indexOf(a.id)
          .compareTo(achievementsOrder.indexOf(b.id));
    });
    return [...earned, ...started, ...untouched];
  }

  Widget _achievementRow(MetaState meta, AchievementDef def) {
    final earned = ach.isEarned(meta, def);
    final value = ach.statValue(meta, def.stat, def.param);
    final p = ach.progress(meta, def);
    final titleColor = earned
        ? EmberColors.textPrimary
        : EmberColors.textDisabled;
    return Row(
      children: [
        Icon(
          earned ? Icons.military_tech : Icons.radio_button_unchecked,
          color: earned ? EmberColors.gold : EmberColors.textDisabled,
          size: 20,
        ),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(def.name, style: EmberText.body.copyWith(color: titleColor)),
              const SizedBox(height: 2),
              Text(
                def.text,
                style: EmberText.micro.copyWith(color: EmberColors.textDim),
              ),
              // Only draw a bar for goals actually under way: an empty bar on an
              // untouched goal reads as failure rather than as an invitation.
              if (!earned && p > 0) ...[
                const SizedBox(height: Space.s),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: p,
                    minHeight: 3,
                    backgroundColor: EmberColors.line,
                    valueColor: const AlwaysStoppedAnimation(EmberColors.ember),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: Space.s),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              earned ? 'EARNED' : '$value / ${def.target}',
              style: EmberText.label.copyWith(
                color: earned ? EmberColors.gold : EmberColors.textDisabled,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: Space.m),
        Expanded(child: Text(label, style: EmberText.body)),
        const SizedBox(width: Space.s),
        // Flexible + scale-down: six-digit lifetime values shrink on narrow
        // phones instead of overflowing the panel (same trick as _TopBar).
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: EmberText.value.copyWith(color: color)),
          ),
        ),
      ],
    );
  }

  Widget _delverRow(dynamic m, String id) {
    final ch = characters[id]!;
    final unlocked = m.isUnlocked(id) as bool;
    final runs = (m.charRuns[id] as int?) ?? 0;
    final wins = (m.charWins[id] as int?) ?? 0;
    return Row(
      children: [
        Icon(
          unlocked ? Icons.person : Icons.lock,
          color: unlocked ? EmberColors.textPrimary : EmberColors.textDisabled,
          size: 20,
        ),
        const SizedBox(width: Space.m),
        Expanded(
          child: Text(
            ch.name,
            style: EmberText.body.copyWith(
              color: unlocked
                  ? EmberColors.textPrimary
                  : EmberColors.textDisabled,
            ),
          ),
        ),
        const SizedBox(width: Space.s),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              unlocked
                  ? '$wins ${wins == 1 ? 'win' : 'wins'} · '
                        '$runs ${runs == 1 ? 'delve' : 'delves'}'
                  : 'locked',
              style: EmberText.label.copyWith(
                color: unlocked
                    ? EmberColors.textDim
                    : EmberColors.textDisabled,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Same contract as [_themeCard]: tap owned to lit, tap locked to buy
  /// (price always visible). The swatch is a live skinned d6 chip, so what
  /// you see is exactly what the tray will paint.
  Widget _skinCard(BuildContext context, String id) {
    final s = dieSkins[id]!;
    final m = c.meta;
    final owned = m.ownedDieSkins.contains(id);
    final active = m.activeDieSkin == id;
    final affordable = m.embers >= s.costEmbers;
    return GestureDetector(
      key: ValueKey('skin-$id'),
      onTap: () {
        if (active) return;
        if (owned) {
          AudioService.instance?.playSfx('ui_tap');
          c.setActiveDieSkin(id);
        } else if (c.buyDieSkin(id)) {
          c.setActiveDieSkin(id);
        } else {
          AudioService.instance?.playSfx('ui_back');
        }
      },
      child: Panel(
        color: active ? EmberColors.raised : EmberColors.surface,
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 42,
              child: FittedBox(
                fit: BoxFit.contain,
                child: DieChip('d6', skin: id),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: EmberText.body),
                  const SizedBox(height: 2),
                  Text(
                    s.text,
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            if (active)
              Text(
                'LIT',
                style: EmberText.micro.copyWith(
                  color: EmberColors.ember,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (owned)
              Text(
                'OWNED',
                style: EmberText.micro.copyWith(color: EmberColors.textDim),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 14,
                    color: affordable
                        ? EmberColors.ember
                        : EmberColors.textDisabled,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${s.costEmbers}',
                    style: EmberText.label.copyWith(
                      color: affordable
                          ? EmberColors.ember
                          : EmberColors.textDisabled,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _themeCard(BuildContext context, String id) {
    final t = hearthThemes[id]!;
    final m = c.meta;
    final owned = m.ownedThemes.contains(id);
    final active = m.activeTheme == id;
    final affordable = m.embers >= t.costEmbers;
    return GestureDetector(
      key: ValueKey('theme-$id'),
      onTap: () {
        if (active) return;
        if (owned) {
          AudioService.instance?.playSfx('ui_tap');
          c.setActiveTheme(id);
        } else if (c.buyTheme(id)) {
          c.setActiveTheme(id);
        } else {
          AudioService.instance?.playSfx('ui_back');
        }
      },
      child: Panel(
        color: active ? EmberColors.raised : EmberColors.surface,
        child: Row(
          children: [
            // Swatch: the theme's warm->bright gradient.
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [Color(t.warmArgb), Color(t.brightArgb)],
                ),
                border: Border.all(
                  color: active ? EmberColors.ember : EmberColors.line,
                ),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: EmberText.body),
                  const SizedBox(height: 2),
                  Text(
                    t.text,
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            if (active)
              Text(
                'LIT',
                style: EmberText.micro.copyWith(
                  color: EmberColors.ember,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (owned)
              Text(
                'OWNED',
                style: EmberText.micro.copyWith(color: EmberColors.textDim),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 14,
                    color: affordable
                        ? EmberColors.ember
                        : EmberColors.textDisabled,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${t.costEmbers}',
                    style: EmberText.label.copyWith(
                      color: affordable
                          ? EmberColors.ember
                          : EmberColors.textDisabled,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// v0.33.0 The Gramophone — soundtrack rows inside the Ledger.
///
/// Stateful because playback preview is screen-local: tap an unlocked track
/// to play it (looped), tap it again to stop; leaving the Ledger restores
/// the hearth theme. The unlock record itself lives in MetaState.heardTracks
/// (written by GameController, merged by union in the cloud) — this widget
/// only reads it.
class _GramophoneSection extends StatefulWidget {
  final Set<String> heard;
  const _GramophoneSection({super.key, required this.heard});

  @override
  State<_GramophoneSection> createState() => _GramophoneSectionState();
}

class _GramophoneSectionState extends State<_GramophoneSection> {
  String? _playing;

  @override
  void dispose() {
    // Hand the speakers back to the hearth. playMusic dedupes on key, so
    // this is a no-op when nothing was previewed.
    if (_playing != null) {
      AudioService.instance?.playMusic('title_menu');
    }
    super.dispose();
  }

  void _toggle(String key) {
    final audio = AudioService.instance;
    setState(() {
      if (_playing == key) {
        _playing = null;
        audio?.playMusic('title_menu');
      } else {
        _playing = key;
        audio?.playSfx('ui_tap');
        audio?.playMusic(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final t in gramophoneTracks) ...[
          _trackRow(t),
          const SizedBox(height: Space.m),
        ],
      ],
    );
  }

  Widget _trackRow(TrackDef t) {
    final heard = widget.heard.contains(t.key);
    final playing = _playing == t.key;
    return Panel(
      child: InkWell(
        onTap: heard ? () => _toggle(t.key) : null,
        child: Row(
          children: [
            Icon(
              heard
                  ? (playing ? Icons.graphic_eq : Icons.music_note)
                  : Icons.lock_outline,
              color: heard ? EmberColors.gold : EmberColors.textDim,
              size: 20,
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heard ? t.name : '— — —',
                    style: EmberText.body.copyWith(
                      color: heard ? EmberColors.textPrimary : EmberColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    heard ? (playing ? 'Playing — tap to stop' : 'Tap to play') : t.hint,
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                ],
              ),
            ),
            if (heard)
              Icon(
                playing ? Icons.stop : Icons.play_arrow,
                color: EmberColors.textDim,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
