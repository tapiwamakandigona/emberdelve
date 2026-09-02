// lib/ui/codex_screen.dart — The Codex (v0.4.3, P1 ember sink): enemy and
// relic lore entries unsealed with embers. Same charter as hearth colors
// (§Ethics): prices up front, no timers, no FOMO, and lore is flavor only —
// nothing mechanical is ever paywalled (intents and relic effects stay
// readable in play for free). Names are always visible; only the story is
// sealed, so a locked entry is a known quantity, never a gacha tease.
import 'package:flutter/material.dart';
import '../audio/audio_service.dart';
import '../data/characters.dart';
import '../data/codex.dart';
import '../data/dice.dart';
import '../data/enemies.dart';
import '../sim/keystones.dart' show keystoneDef;
import '../sim/run_dice.dart' show runeName;
import '../data/relics.dart';
import '../game/controller.dart';
import 'theme.dart';
import 'widgets.dart';

class CodexScreen extends StatefulWidget {
  final GameController c;

  /// THE NAMED FOE: a namespaced entry id ('enemy:ashfall_twins') to glide
  /// to on open — the loss summary sends the reader straight to the foe
  /// that ended the run. Null opens the book at its first page as ever.
  final String? openEntry;
  const CodexScreen(this.c, {super.key, this.openEntry});

  @override
  State<CodexScreen> createState() => _CodexScreenState();
}

class _CodexScreenState extends State<CodexScreen> {
  GameController get c => widget.c;

  // Codex Lanes: the book is 134 entries across eight sections — reaching
  // THE DICE was a marathon of scrolling. One chip per section, pinned
  // under the app bar, walks the lazy list to that section's header
  // (widgets.dart walkToAnchor). Chips navigate; they never filter — the
  // whole book stays on one honest page.
  static const _lanes = <(String, String)>[
    ('world', 'World'),
    ('company', 'Company'),
    ('enemies', 'Enemies'),
    ('relics', 'Relics'),
    ('rules', 'Rules'),
    ('marks', 'Marks'),
    ('stones', 'Keystones'),
    ('dice', 'Dice'),
  ];
  final _scroll = ScrollController();
  final _laneKeys = {for (final (id, _) in _lanes) id: GlobalKey()};
  int _laneIdx = 0; // last lane walked to: hints the walk direction

  /// THE NAMED FOE: anchor on the one entry the caller asked to open.
  final _openEntryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.openEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        walkToAnchor(_scroll, _openEntryKey, alignment: 0.15);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _toLane(int idx) async {
    AudioService.instance?.playSfx('ui_tap');
    final up = idx < _laneIdx;
    setState(() => _laneIdx = idx);
    await walkToAnchor(_scroll, _laneKeys[_lanes[idx].$1]!, preferUp: up);
  }

  Widget _laneChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.l),
      child: Row(
        children: [
          for (final (i, (id, name)) in _lanes.indexed)
            Padding(
              padding: const EdgeInsets.only(right: Space.s),
              child: GestureDetector(
                key: ValueKey('codex-lane-$id'),
                onTap: () => _toLane(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.m,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: EmberColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: EmberColors.line),
                  ),
                  child: Text(
                    name,
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _laneHeader(String id, String title) =>
      Text(title, key: _laneKeys[id], style: EmberText.micro);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Codex', style: EmberText.h2),
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
              // v0.104.0 The Delve Itself: the world's own words, first —
              // 'what is a delve?' is answered at the top of the book.
              final placeEntries = codexEntries
                  .where((e) => e.kind == 'place')
                  .toList();
              // v0.110.0 The Named Company: the delvers' own stories, right
              // after the world — who the company are is the second question.
              final delverEntries = codexEntries
                  .where((e) => e.kind == 'delver')
                  .toList();
              final enemyEntries = codexEntries
                  .where((e) => e.kind == 'enemy')
                  .toList();
              final relicEntries = codexEntries
                  .where((e) => e.kind == 'relic')
                  .toList();
              // v0.116.0 The Spoken Dice: the five base cuts, last — the
              // tools of the trade close the book.
              final dieEntries = codexEntries
                  .where((e) => e.kind == 'die')
                  .toList();
              // v0.131.0 The Written Rules: the weekly calendar's words,
              // between the relics and the dice.
              final ruleEntries = codexEntries
                  .where((e) => e.kind == 'rule')
                  .toList();
              // v0.142.0 The Written Marks: the anvil's words, between the
              // rules and the dice that wear them.
              final runeEntries = codexEntries
                  .where((e) => e.kind == 'rune')
                  .toList();
              // v0.180.0 The Set Stones: the keystones' words, between the
              // marks and the dice — the last tools of the trade.
              final stoneEntries = codexEntries
                  .where((e) => e.kind == 'keystone')
                  .toList();
              return Column(
                children: [
                  const SizedBox(height: Space.s),
                  _laneChips(context),
                  const SizedBox(height: Space.s),
                  Expanded(
                    child: ScrollComfort(
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(Space.l),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${codexEntries.where((e) => m.codexOwned(e.id)).length} '
                                  'of ${codexEntries.length} UNSEALED',
                                  style: EmberText.micro,
                                ),
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
                          Text(
                            'Lore of the delve, unsealed with embers. Flavor only '
                            '— enemy intents and relic effects stay readable in '
                            'play, free, forever.',
                            style: EmberText.micro.copyWith(
                              color: EmberColors.textDim,
                            ),
                          ),
                          const SizedBox(height: Space.xl),
                          _laneHeader('world', 'THE WORLD'),
                          const SizedBox(height: Space.s),
                          for (final e in placeEntries) ...[
                            _entryCard(context, e),
                            const SizedBox(height: Space.m),
                          ],
                          const SizedBox(height: Space.l),
                          _laneHeader('company', 'THE COMPANY'),
                          const SizedBox(height: Space.s),
                          for (final e in delverEntries) ...[
                            _entryCard(context, e),
                            const SizedBox(height: Space.m),
                          ],
                          const SizedBox(height: Space.l),
                          _laneHeader('enemies', 'ENEMIES'),
                          const SizedBox(height: Space.s),
                          for (final e in enemyEntries) ...[
                            _entryCard(context, e),
                            const SizedBox(height: Space.m),
                          ],
                          const SizedBox(height: Space.l),
                          _laneHeader('relics', 'RELICS'),
                          const SizedBox(height: Space.s),
                          for (final e in relicEntries) ...[
                            _entryCard(context, e),
                            const SizedBox(height: Space.m),
                          ],
                          const SizedBox(height: Space.l),
                          _laneHeader('rules', 'THE RULES'),
                          const SizedBox(height: Space.s),
                          for (final e in ruleEntries) ...[
                            _entryCard(context, e),
                            const SizedBox(height: Space.m),
                          ],
                          const SizedBox(height: Space.l),
                          _laneHeader('marks', 'THE MARKS'),
                          const SizedBox(height: Space.s),
                          for (final e in runeEntries) ...[
                            _entryCard(context, e),
                            const SizedBox(height: Space.m),
                          ],
                          const SizedBox(height: Space.l),
                          _laneHeader('stones', 'THE KEYSTONES'),
                          const SizedBox(height: Space.s),
                          for (final e in stoneEntries) ...[
                            _entryCard(context, e),
                            const SizedBox(height: Space.m),
                          ],
                          const SizedBox(height: Space.l),
                          _laneHeader('dice', 'THE DICE'),
                          const SizedBox(height: Space.s),
                          for (final e in dieEntries) ...[
                            _entryCard(context, e),
                            const SizedBox(height: Space.m),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _entryName(CodexEntryDef e) => switch (e.kind) {
    'enemy' => enemies[e.refId]?.name ?? e.refId,
    'delver' => characterDef(e.refId).name,
    'die' => dice[e.refId]?.name ?? e.refId,
    'rule' => ruleNames[e.refId] ?? e.refId,
    'rune' => runeName(e.refId),
    'keystone' => keystoneDef(e.refId).name,
    'relic' => relics[e.refId]?.name ?? e.refId,
    _ => placeNames[e.refId] ?? e.refId,
  };

  String _entryTag(CodexEntryDef e) {
    if (e.kind == 'place') return 'place';
    if (e.kind == 'delver') return 'delver';
    if (e.kind == 'die') return 'die';
    if (e.kind == 'rule') return 'rule';
    if (e.kind == 'rune') return 'rune';
    if (e.kind == 'keystone') return 'keystone';
    if (e.kind == 'relic') return 'relic';
    final def = enemies[e.refId];
    if (def == null) return 'enemy';
    return def.boss
        ? 'boss'
        : def.elite
        ? 'elite'
        : 'enemy';
  }

  /// v0.11.0 Delver's Ledger: the honest per-enemy record, FREE for every
  /// entry (§Ethics: mechanical/record knowledge is never paywalled — only
  /// the lore text is priced). Enemies only; relics have no fight record.
  String? _recordLine(CodexEntryDef e) {
    if (e.kind != 'enemy') return null;
    final m = c.meta;
    final met = m.enemyMet[e.refId] ?? 0;
    if (met == 0) return 'Not yet met.';
    final felled = m.enemyFelled[e.refId] ?? 0;
    final deaths = m.enemyFellTo[e.refId] ?? 0;
    final parts = ['Met $met'];
    if (felled > 0) parts.add('Felled $felled');
    if (deaths > 0) parts.add('Deaths $deaths');
    return parts.join(' · ');
  }

  Widget _entryCard(BuildContext context, CodexEntryDef e) {
    final m = c.meta;
    final owned = m.codexOwned(e.id);
    final affordable = m.embers >= e.costEmbers;
    return GestureDetector(
      key: e.id == widget.openEntry ? _openEntryKey : ValueKey('codex-${e.id}'),
      onTap: () {
        if (owned) return;
        if (!c.buyCodexEntry(e.id)) {
          AudioService.instance?.playSfx('ui_back');
        }
      },
      child: Panel(
        color: owned ? EmberColors.raised : EmberColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(_entryName(e), style: EmberText.body)),
                const SizedBox(width: Space.s),
                if (owned)
                  Text(
                    _entryTag(e).toUpperCase(),
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
                        '${e.costEmbers}',
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
            const SizedBox(height: 4),
            if (_recordLine(e) != null) ...[
              Text(
                _recordLine(e)!,
                key: ValueKey('codex-record-${e.refId}'),
                style: EmberText.micro.copyWith(color: EmberColors.gold),
              ),
              const SizedBox(height: 4),
            ],
            if (owned)
              Text(
                e.text,
                style: EmberText.micro.copyWith(color: EmberColors.textDim),
              )
            else
              Text(
                'Sealed — tap to unseal.',
                style: EmberText.micro.copyWith(
                  color: EmberColors.textDisabled,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
