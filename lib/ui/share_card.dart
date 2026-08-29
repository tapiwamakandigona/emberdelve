// lib/ui/share_card.dart — The Delver's Card (v0.34.0): a shareable IMAGE
// summary of one finished run. Design doc: docs/improvements/
// v0.34.0-delvers-card-design.md.
//
// The Wordle lesson, upgraded: v0.8.0 made the share artifact plain text; our
// players live on WhatsApp, where an image travels — it renders inline,
// carries the brand, and survives forwarding. The preview sheet shows EXACTLY
// the pixels that leave the device (the card sits in one RepaintBoundary).
//
// Ethics (spec §5): sharing is player-initiated, never prompted, never
// rewarded. Every line on the card is a banked fact — loss cards are fully
// supported, because honesty is the brand. The seed line INVITES ("delve it
// yourself"); it never challenges. Copy is sweep-pinned in
// test/share_card_test.dart.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/attire.dart' show defaultDye;
import '../data/vistas.dart' show defaultVista;
import '../data/characters.dart';
import '../data/enemies.dart';
import '../data/epithets.dart';
import '../game/controller.dart';
import '../game/delve_code.dart';
import '../game/obituary.dart' show epitaphLine;
import '../game/run_trace.dart';
import '../sim/run_layer.dart' show bossForSeed;
import '../meta/meta.dart' show MetaState;
import 'art.dart';
import 'sprites.dart';
import 'theme.dart';
import 'widgets.dart';

/// The facts one card states. Built once from the controller so the widget
/// (and its tests) depend on plain values, not live game state.
class DelverCardFacts {
  final bool won;
  final String delverName;

  /// v0.70.0 The Pictured Card: the delver's sprite id and worn dye — the
  /// card stays a pure function of facts, so tests can pin the portrait.
  final String charId;
  final String dyeId;

  /// The worn epithet's title ('' when none) — v0.36.0 The Epithets.
  final String epithetTitle;
  final String difficulty; // 'easy' | 'normal' | 'hard'
  final int ascension;
  final String traceGridText; // '' when the trace is empty
  final int embers;
  final int fightsWon;
  final int seed;

  /// The full-challenge Delve Code ('' when unavailable) — v0.37.0. When
  /// present it replaces the bare seed line: the code carries delver,
  /// difficulty and ascension too, so a friend plays THIS run.
  final String delveCode;

  /// The run's one-or-two-sentence story (v0.54.0 The Epitaph) — the
  /// card-sized cut of the Obituary. '' when no story is available (facts
  /// built off a live controller always have one).
  final String epitaph;

  /// v0.56.0 Card from the Ledger: run records don't bank a fights count,
  /// so a remembered card OMITS the figure rather than invent a zero. Facts
  /// built off a live controller always know it.
  final bool fightsKnown;

  /// v0.99.0 The Colored Card: the vista the player has the delve wearing —
  /// the card keeps the delve's light. Portraiture, not history, exactly
  /// like [dyeId]: vistas were never banked per run.
  final String vistaId;
  const DelverCardFacts({
    required this.won,
    required this.delverName,
    this.charId = defaultCharacter,
    this.dyeId = defaultDye,
    this.epithetTitle = '',
    required this.difficulty,
    required this.ascension,
    required this.traceGridText,
    required this.embers,
    required this.fightsWon,
    required this.seed,
    this.delveCode = '',
    this.epitaph = '',
    this.fightsKnown = true,
    this.vistaId = defaultVista,
  });

  /// v0.56.0 Card from the Ledger: facts from a REMEMBERED run record
  /// (meta.runHistory) — so any of the last 30 delves can become a card,
  /// not just the run that ended a second ago. Honesty budget per field:
  /// everything stated comes straight off the record; what the record
  /// never banked (fights won, floor trace, worn epithet) is OMITTED, not
  /// invented. Only 'won'/'lost' records qualify — a walked-away run has
  /// no ember and no grave, so callers skip 'abandoned'.
  static DelverCardFacts fromRecord(Map<String, Object?> r, {MetaState? meta}) {
    final won = (r['result'] as String? ?? 'lost') == 'won';
    final charId = r['character'] as String? ?? defaultCharacter;
    final delverName =
        meta?.nameFor(charId) ?? characters[charId]?.name ?? charId;
    final difficulty = r['difficulty'] as String? ?? 'normal';
    final ascension = int.tryParse('${r['ascension'] ?? 0}') ?? 0;
    final seed = int.tryParse('${r['seed'] ?? 0}') ?? 0;
    // The boss is a pure function of the seed (The Rumor, v0.53.0) — but a
    // seed-0 record (pre-v0.3.4 save) never banked one, so it stays quiet
    // rather than name a boss the run may not have met.
    final bossName = won && seed != 0
        ? (enemies[bossForSeed(seed)]?.name ?? '')
        : '';
    // Losses since v0.51.0 bank their killer; older records simply lack the
    // key and the epitaph degrades to its opener — floor included, honest.
    final killerName = enemies[r['killed_by']]?.name ?? '';
    // v0.57.0 The Fuller Record: records bank fights, the compact floor
    // trace, and the worn epithet — so a card from a NEW record states all
    // three again. Absent keys degrade by omission, exactly as v0.56.0
    // shipped for the 30 remembered runs that predate the banking.
    final fights = r['fights'];
    final compact = r['trace'] as String? ?? '';
    final epithetTitle = epithets[r['epithet']]?.title ?? '';
    return DelverCardFacts(
      won: won,
      delverName: delverName,
      charId: charId,
      // Portraiture, not history: the delver's CURRENT coat, exactly as
      // the picker paints them (dyes were never banked per run).
      dyeId: meta?.dyeFor(charId) ?? defaultDye,
      vistaId: meta?.selectedVista ?? defaultVista,
      epithetTitle: epithetTitle,
      difficulty: difficulty,
      ascension: ascension,
      traceGridText: compact.isEmpty
          ? ''
          : traceGrid(
              RunTrace.fromCompact(compact, outcome: won ? 'won' : 'lost'),
            ),
      embers: int.tryParse('${r['embers'] ?? 0}') ?? 0,
      fightsWon: fights is num ? fights.toInt() : 0,
      fightsKnown: fights is num,
      seed: seed,
      delveCode:
          encodeDelveCode(
            seed: seed,
            character: charId,
            difficulty: difficulty,
            ascension: ascension,
            shortRoad: r['short'] == true,
          ) ??
          '',
      epitaph: epitaphLine(
        won: won,
        delverName: delverName,
        // Worn-at-the-time is knowable since v0.57.0 records bank it;
        // older records keep the bare name — stated facts only.
        epithetTitle: epithetTitle,
        floor: int.tryParse('${r['floor'] ?? 0}') ?? 0,
        killerName: killerName,
        bossName: bossName,
        seed: seed,
      ),
    );
  }

  static DelverCardFacts fromController(GameController c) {
    final st = c.state!;
    final run = st['run'] as Map;
    final charId = run['character'] as String? ?? defaultCharacter;
    return DelverCardFacts(
      won: st['phase'] == 'run_won',
      delverName: c.meta.nameFor(charId),
      charId: charId,
      dyeId: c.meta.dyeFor(charId),
      vistaId: c.meta.selectedVista,
      epithetTitle: epithets[c.meta.epithetFor(charId)]?.title ?? '',
      difficulty: run['difficulty'] as String? ?? 'normal',
      ascension: int.tryParse('${run['ascension'] ?? 0}') ?? 0,
      traceGridText: c.runTrace.marks.isEmpty ? '' : traceGrid(c.runTrace),
      embers: (run['embers'] as num?)?.toInt() ?? 0,
      fightsWon: (run['fights_won'] as num?)?.toInt() ?? 0,
      seed: c.sim?.runSeed ?? 0,
      delveCode:
          encodeDelveCode(
            seed: c.sim?.runSeed ?? 0,
            character: charId,
            difficulty: run['difficulty'] as String? ?? 'normal',
            ascension: int.tryParse('${run['ascension'] ?? 0}') ?? 0,
            shortRoad: c.sim?.hasMutator('short_road') ?? false,
          ) ??
          '',
      epitaph: c.delveEpitaphLine ?? '',
    );
  }

  /// 'DELVE-… — delve it yourself.' or the bare-seed line when no code.
  String get challengeLine => delveCode.isEmpty
      ? 'Seed $seed — delve it yourself.'
      : '$delveCode — delve it yourself.';

  /// 'The Kindler' or 'The Kindler, the Unburnt' when an epithet is worn.
  String get nameLine =>
      epithetTitle.isEmpty ? delverName : '$delverName, $epithetTitle';

  /// 'Easy' / 'Normal' / 'Hard', plus the rung when one was climbed.
  String get modeLine {
    final d = difficulty.isEmpty
        ? 'Normal'
        : difficulty[0].toUpperCase() + difficulty.substring(1);
    return ascension > 0 ? '$d · Ascension $ascension' : d;
  }
}

/// The card itself: fixed 340×480 logical canvas (420 before v0.54.0 — the
/// epitaph bought 60px), hearth palette, bundled fonts only — a pure
/// function of [facts] so tests can pin every line.
/// v0.102.0: the emoji trace grid ('🟩🟨…\n…') parsed back to cell codes —
/// 'c' clean, 'h' hurt, 'f' fell, 'w' Ember claimed. Records bank the emoji
/// string (v0.57.0), so the card parses rather than re-deriving; unknown
/// runes are dropped, never guessed (fromCompact precedent).
List<List<String>> traceCells(String gridText) => [
  for (final row in gridText.split('\n'))
    if (row.isNotEmpty)
      [
        for (final r in row.runes)
          if (r == 0x1F7E9)
            'c'
          else if (r == 0x1F7E8)
            'h'
          else if (r == 0x1F7E5)
            'f'
          else if (r == 0x1F525)
            'w',
      ],
];

/// The floor trace, painted: one rounded cell per floor, five per row —
/// clean in green, hurt in gold, the fall in red, the claimed Ember in
/// ember with a gold ring. Deterministic on every platform, unlike emoji.
class PaintedTrace extends StatelessWidget {
  final String gridText;
  const PaintedTrace(this.gridText, {super.key});

  static const _fill = {
    'c': EmberColors.success,
    'h': EmberColors.gold,
    'f': EmberColors.danger,
    'w': EmberColors.ember,
  };

  @override
  Widget build(BuildContext context) {
    final rows = traceCells(gridText);
    final cells = [for (final r in rows) ...r];
    // The outcome cell REPLACED its floor's clean/hurt mark (traceGrid),
    // so per-floor counts cannot be recovered here — the label states
    // only what the grid truly knows: length and outcome.
    final outcome = cells.contains('w')
        ? ', the Ember claimed'
        : cells.contains('f')
        ? ', the delver fell'
        : '';
    return Semantics(
      label: 'Floor trace: ${cells.length} floors$outcome.',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, row) in rows.indexed)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (j, cell) in row.indexed)
                      Padding(
                        padding: EdgeInsets.only(left: j == 0 ? 0 : 4),
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: _fill[cell],
                            borderRadius: BorderRadius.circular(3.5),
                            border: cell == 'w'
                                ? Border.all(
                                    color: EmberColors.gold,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DelverCard extends StatelessWidget {
  final DelverCardFacts facts;
  const DelverCard(this.facts, {super.key});

  @override
  Widget build(BuildContext context) {
    final accent = facts.won ? EmberColors.gold : EmberColors.ember;
    // The card is an exported IMAGE on a fixed canvas — device text scale
    // must not reflow it (pre-v0.54.0 it did, and big-text devices exported
    // an overflowed card). Like any picture, it renders at 1.0 and ships at
    // 3x; the sheet AROUND it honors the device setting.
    return MediaQuery.withNoTextScaling(
      child: Container(
        width: 340,
        height: 480,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B1410), Color(0xFF0E0A08)],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.55), width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            // v0.99.0 The Colored Card: the same translucent breath the
            // delve wears (Art.backgroundWash at depth 0 = the pure vista
            // wash) under the facts — Emberlight stays byte-identical.
            Positioned.fill(
              child: ColoredBox(
                key: const ValueKey('card-vista-wash'),
                color: Art.backgroundWash(0, facts.vistaId),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.xl,
                vertical: Space.l,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EMBERDELVE',
                    style: EmberText.h2.copyWith(
                      color: EmberColors.textDim,
                      letterSpacing: 4,
                      fontSize: 15,
                    ),
                  ),
                  // v0.70.0 The Pictured Card: the delver stands on their own
                  // card, in their worn dye — the shared artifact is SOMEONE'S
                  // run, not a template. Full opacity on losses too: the export
                  // is a poster, and a dimmed sprite reads as a rendering bug.
                  SpriteView(
                    facts.charId,
                    key: const ValueKey('card-delver'),
                    height: 44,
                    animate: false,
                    dye: Art.dyeFilter(facts.dyeId),
                  ),
                  Text(
                    facts.won ? 'The Ember is yours' : 'The dark claims you',
                    textAlign: TextAlign.center,
                    style: EmberText.h1.copyWith(
                      fontSize: 21,
                      color: facts.won
                          ? EmberColors.gold
                          : EmberColors.textPrimary,
                      shadows: [
                        Shadow(
                          color: accent.withValues(alpha: 0.5),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${facts.nameLine} · ${facts.modeLine}',
                    textAlign: TextAlign.center,
                    style: EmberText.body.copyWith(color: EmberColors.textDim),
                  ),
                  // v0.54.0 The Epitaph: the story under the name — italic, dim,
                  // the narrative voice the numbers below can't carry.
                  if (facts.epitaph.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.s),
                      child: Text(
                        facts.epitaph,
                        key: const ValueKey('card-epitaph'),
                        textAlign: TextAlign.center,
                        style: EmberText.label.copyWith(
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                          color: EmberColors.textDim,
                          height: 1.35,
                        ),
                      ),
                    ),
                  // v0.102.0 The Painted Trace: the card paints its own
                  // floor grid. Emoji squares render with whatever emoji
                  // font the device vendor ships — the one artifact built
                  // to leave the game must not change face per platform.
                  // The share TEXT keeps the emoji grid: text has no
                  // painter, and emoji is honest there.
                  if (facts.traceGridText.isNotEmpty)
                    PaintedTrace(
                      facts.traceGridText,
                      key: const ValueKey('card-trace-grid'),
                    ),
                  Text(
                    facts.fightsKnown
                        ? '${facts.embers} embers banked · '
                              '${facts.fightsWon} fights won'
                        : '${facts.embers} embers banked',
                    textAlign: TextAlign.center,
                    style: EmberText.micro.copyWith(
                      color: EmberColors.textPrimary,
                    ),
                  ),
                  Text(
                    facts.challengeLine,
                    textAlign: TextAlign.center,
                    style: EmberText.micro.copyWith(color: EmberColors.textDim),
                  ),
                  Text(
                    'tsorostudios.itch.io/emberdelve',
                    style: EmberText.micro.copyWith(
                      color: accent.withValues(alpha: 0.85),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the preview sheet. What the sheet shows is exactly what ships: the
/// card sits in one RepaintBoundary and the Share button exports THAT
/// boundary at 3x. From the summary screen [facts] is omitted and built off
/// the live controller; the Ledger (v0.56.0) passes record-built facts.
Future<void> showDelverCardSheet(
  BuildContext context,
  GameController c, {
  DelverCardFacts? facts,
}) {
  final f = facts ?? DelverCardFacts.fromController(c);
  final boundaryKey = GlobalKey();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: EmberColors.surface,
    isScrollControlled: true,
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'THE DELVER\'S CARD',
              style: EmberText.micro.copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: Space.m),
            // Short screens: let the preview scale down instead of
            // overflowing; the export still renders at full card size.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: RepaintBoundary(key: boundaryKey, child: DelverCard(f)),
              ),
            ),
            const SizedBox(height: Space.l),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EmberButton(
                  'Close',
                  dense: true,
                  key: const ValueKey('card-close'),
                  onTap: () => Navigator.of(sheetCtx).pop(),
                ),
                const SizedBox(width: Space.m),
                EmberButton(
                  'Share',
                  dense: true,
                  key: const ValueKey('card-share'),
                  onTap: () => _shareCard(boundaryKey, f, c),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Exports the boundary as PNG and hands it to the OS share sheet. On ANY
/// failure (headless tests, denied share, missing plugin) it degrades to the
/// v0.8.0 behavior — the plain-text summary lands on the clipboard — and
/// says so. Never a crash.
Future<void> _shareCard(
  GlobalKey boundaryKey,
  DelverCardFacts facts,
  GameController c,
) async {
  try {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = data!.buffer.asUint8List();
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'emberdelve-delve-${facts.seed}.png',
          ),
        ],
        fileNameOverrides: ['emberdelve-delve-${facts.seed}.png'],
      ),
    );
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: _fallbackText(facts)));
    c.announce('Sharing is unavailable here — summary copied instead');
  }
}

/// The degraded artifact: same facts, plain text, pastes anywhere.
String _fallbackText(DelverCardFacts facts) => [
  'Emberdelve — ${facts.won ? 'the Ember is mine' : 'the dark claimed me'}',
  '${facts.nameLine} · ${facts.modeLine}',
  if (facts.epitaph.isNotEmpty) facts.epitaph,
  if (facts.traceGridText.isNotEmpty) facts.traceGridText,
  facts.fightsKnown
      ? '${facts.embers} embers banked · ${facts.fightsWon} fights won'
      : '${facts.embers} embers banked',
  facts.challengeLine,
  'tsorostudios.itch.io/emberdelve',
].join('\n');
