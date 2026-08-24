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

import '../data/characters.dart';
import '../data/epithets.dart';
import '../game/controller.dart';
import '../game/run_trace.dart';
import 'theme.dart';
import 'widgets.dart';

/// The facts one card states. Built once from the controller so the widget
/// (and its tests) depend on plain values, not live game state.
class DelverCardFacts {
  final bool won;
  final String delverName;

  /// The worn epithet's title ('' when none) — v0.36.0 The Epithets.
  final String epithetTitle;
  final String difficulty; // 'easy' | 'normal' | 'hard'
  final int ascension;
  final String traceGridText; // '' when the trace is empty
  final int embers;
  final int fightsWon;
  final int seed;
  const DelverCardFacts({
    required this.won,
    required this.delverName,
    this.epithetTitle = '',
    required this.difficulty,
    required this.ascension,
    required this.traceGridText,
    required this.embers,
    required this.fightsWon,
    required this.seed,
  });

  static DelverCardFacts fromController(GameController c) {
    final st = c.state!;
    final run = st['run'] as Map;
    final charId = run['character'] as String? ?? defaultCharacter;
    return DelverCardFacts(
      won: st['phase'] == 'run_won',
      delverName: characters[charId]?.name ?? charId,
      epithetTitle: epithets[c.meta.selectedEpithet]?.title ?? '',
      difficulty: run['difficulty'] as String? ?? 'normal',
      ascension: int.tryParse('${run['ascension'] ?? 0}') ?? 0,
      traceGridText: c.runTrace.marks.isEmpty ? '' : traceGrid(c.runTrace),
      embers: (run['embers'] as num?)?.toInt() ?? 0,
      fightsWon: (run['fights_won'] as num?)?.toInt() ?? 0,
      seed: c.sim?.runSeed ?? 0,
    );
  }

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

/// The card itself: fixed 340×420 logical canvas, hearth palette, bundled
/// fonts only — a pure function of [facts] so tests can pin every line.
class DelverCard extends StatelessWidget {
  final DelverCardFacts facts;
  const DelverCard(this.facts, {super.key});

  @override
  Widget build(BuildContext context) {
    final accent = facts.won ? EmberColors.gold : EmberColors.ember;
    return Container(
      width: 340,
      height: 420,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1410), Color(0xFF0E0A08)],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
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
          Icon(
            facts.won ? Icons.emoji_events : Icons.local_fire_department,
            size: 40,
            color: accent,
          ),
          Text(
            facts.won ? 'The Ember is yours' : 'The dark claims you',
            textAlign: TextAlign.center,
            style: EmberText.h1.copyWith(
              fontSize: 21,
              color: facts.won ? EmberColors.gold : EmberColors.textPrimary,
              shadows: [
                Shadow(color: accent.withValues(alpha: 0.5), blurRadius: 14),
              ],
            ),
          ),
          Text(
            '${facts.nameLine} · ${facts.modeLine}',
            textAlign: TextAlign.center,
            style: EmberText.body.copyWith(color: EmberColors.textDim),
          ),
          if (facts.traceGridText.isNotEmpty)
            Text(
              facts.traceGridText,
              textAlign: TextAlign.center,
              style: EmberText.body.copyWith(height: 1.25, letterSpacing: 2),
            ),
          Text(
            '${facts.embers} embers banked · ${facts.fightsWon} fights won',
            textAlign: TextAlign.center,
            style: EmberText.micro.copyWith(color: EmberColors.textPrimary),
          ),
          Text(
            'Seed ${facts.seed} — delve it yourself.',
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
    );
  }
}

/// Opens the preview sheet from the summary screen. What the sheet shows is
/// exactly what ships: the card sits in one RepaintBoundary and the Share
/// button exports THAT boundary at 3x.
Future<void> showDelverCardSheet(BuildContext context, GameController c) {
  final facts = DelverCardFacts.fromController(c);
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
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: DelverCard(facts),
                ),
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
                  onTap: () => _shareCard(boundaryKey, facts, c),
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
  if (facts.traceGridText.isNotEmpty) facts.traceGridText,
  '${facts.embers} embers banked · ${facts.fightsWon} fights won',
  'Seed ${facts.seed} — delve it yourself.',
  'tsorostudios.itch.io/emberdelve',
].join('\n');
