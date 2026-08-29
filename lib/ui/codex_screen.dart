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
import '../data/relics.dart';
import '../game/controller.dart';
import 'theme.dart';
import 'widgets.dart';

class CodexScreen extends StatelessWidget {
  final GameController c;
  const CodexScreen(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('The Codex', style: EmberText.h2),
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
              return ListView(
                padding: const EdgeInsets.all(Space.l),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${m.ownedCodex.length} of ${codexEntries.length} '
                          'UNSEALED',
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
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                  const SizedBox(height: Space.xl),
                  Text('THE WORLD', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  for (final e in placeEntries) ...[
                    _entryCard(context, e),
                    const SizedBox(height: Space.m),
                  ],
                  const SizedBox(height: Space.l),
                  Text('THE COMPANY', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  for (final e in delverEntries) ...[
                    _entryCard(context, e),
                    const SizedBox(height: Space.m),
                  ],
                  const SizedBox(height: Space.l),
                  Text('ENEMIES', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  for (final e in enemyEntries) ...[
                    _entryCard(context, e),
                    const SizedBox(height: Space.m),
                  ],
                  const SizedBox(height: Space.l),
                  Text('RELICS', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  for (final e in relicEntries) ...[
                    _entryCard(context, e),
                    const SizedBox(height: Space.m),
                  ],
                  const SizedBox(height: Space.l),
                  Text('THE DICE', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  for (final e in dieEntries) ...[
                    _entryCard(context, e),
                    const SizedBox(height: Space.m),
                  ],
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
    'relic' => relics[e.refId]?.name ?? e.refId,
    _ => placeNames[e.refId] ?? e.refId,
  };

  String _entryTag(CodexEntryDef e) {
    if (e.kind == 'place') return 'place';
    if (e.kind == 'delver') return 'delver';
    if (e.kind == 'die') return 'die';
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
    final owned = m.ownedCodex.contains(e.id);
    final affordable = m.embers >= e.costEmbers;
    return GestureDetector(
      key: ValueKey('codex-${e.id}'),
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
