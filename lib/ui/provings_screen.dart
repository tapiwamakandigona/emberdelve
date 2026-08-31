// lib/ui/provings_screen.dart — The Provings (v0.38.0): eight named,
// curated challenge delves on machine-proven winnable seeds. Same charter
// as the Ledger (§Ethics): the clear mark is the whole prize — no rewards,
// no order, no rotation, nothing expires. A proving the player can't start
// yet states its requirement as a quiet fact; it never prompts a purchase.
import 'package:flutter/material.dart';
import '../audio/audio_service.dart';
import '../data/characters.dart';
import '../data/mutators.dart';
import '../data/provings.dart';
import '../game/controller.dart';
import '../game/delve_code.dart';
import '../meta/forge.dart';
import 'theme.dart';
import 'widgets.dart';

class ProvingsScreen extends StatelessWidget {
  final GameController c;
  const ProvingsScreen(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Provings', style: EmberText.h2),
        backgroundColor: EmberColors.bg,
        leading: BackButton(
          onPressed: () {
            AudioService.instance?.playSfx('ui_back');
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ContentClamp(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: c,
            builder: (context, _) {
              final m = c.meta;
              return ListView(
                padding: const EdgeInsets.all(Space.l),
                children: [
                  Text(
                    '${m.provingsCleared.length} of ${provings.length} '
                    'CLEARED',
                    style: EmberText.micro,
                  ),
                  const SizedBox(height: Space.s),
                  const Text(
                    // Count-free on purpose (v0.41.0 lesson: "eight" went
                    // stale the moment a ninth was added — the header's
                    // "N of M" states the count, so the prose never should).
                    'Named delves, each one exact — same floors, same '
                    'offers, same rolls for every delver who takes it. '
                    'Every one is proven winnable. Take them in any order; '
                    'clearing one marks it here, and the mark is the prize.',
                    style: EmberText.bodyDim,
                  ),
                  const SizedBox(height: Space.l),
                  for (final p in provings) ...[
                    _ProvingCard(c, p, key: ValueKey('proving-${p.id}')),
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
}

class _ProvingCard extends StatelessWidget {
  final GameController c;
  final ProvingDef p;
  const _ProvingCard(this.c, this.p, {super.key});

  /// The one thing still standing between the player and this exact run,
  /// stated as a fact — or null when it can start right now.
  String? _requirement() {
    final m = c.meta;
    if (!m.unlockedCharacters.contains(p.character)) {
      return 'Needs ${characterDef(p.character).name} at the fire.';
    }
    if (!canSelectDifficulty(m, p.difficulty)) {
      return 'Needs hard mode (the Ember Forge).';
    }
    if (p.ascension > maxAscensionFor(m)) {
      // Free profiles delve at rung 0 (forge.dart): without the Forge the
      // honest blocker is the Forge itself, not the ladder.
      return m.forgeUnlocked
          ? 'Needs Ascension ${p.ascension} — the ladder is climbed one '
                'win at a time.'
          : 'Needs Ascension ${p.ascension} (the Ember Forge, then the '
                'climb).';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cleared = c.meta.provingsCleared.contains(p.id);
    final req = _requirement();
    // A modded proving shows no Delve Code: a code cannot carry rules,
    // and one that replayed the run without them would be a lie
    // (v0.103.0 refusal precedent).
    final code = p.mutators.isEmpty
        ? encodeDelveCode(
            seed: p.seed,
            character: p.character,
            difficulty: p.difficulty,
            ascension: p.ascension,
          )
        : null;
    final diffLabel = p.difficulty[0].toUpperCase() + p.difficulty.substring(1);
    final metaLine = [
      characterDef(p.character).name,
      diffLabel,
      if (p.ascension > 0) 'Ascension ${p.ascension}',
      // The rule is part of the delve; the card states it plainly.
      for (final m in p.mutators) mutatorDef(m).name,
    ].join(' · ');
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(p.title, style: EmberText.h2)),
              if (cleared)
                Padding(
                  padding: const EdgeInsets.only(left: Space.s),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check,
                        size: 14,
                        color: EmberColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CLEARED',
                        style: EmberText.micro.copyWith(
                          color: EmberColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(metaLine, style: EmberText.micro),
          const SizedBox(height: Space.s),
          Text(p.blurb, style: EmberText.bodyDim),
          if (code != null) ...[
            const SizedBox(height: Space.s),
            Text(
              code,
              style: EmberText.micro.copyWith(color: EmberColors.textDim),
            ),
          ],
          const SizedBox(height: Space.m),
          if (req == null)
            SizedBox(
              width: double.infinity,
              child: EmberButton(
                cleared ? 'Delve it again' : 'Take this delve',
                ghost: cleared,
                key: ValueKey('proving-start-${p.id}'),
                onTap: () {
                  AudioService.instance?.playSfx('ui_confirm');
                  Navigator.of(context).pop();
                  c.startRun(
                    character: p.character,
                    seed: p.seed,
                    difficulty: p.difficulty,
                    ascension: p.ascension,
                    boons: true,
                    mutators: p.mutators,
                  );
                },
              ),
            )
          else
            Text(
              req,
              key: ValueKey('proving-req-${p.id}'),
              style: EmberText.micro.copyWith(color: EmberColors.textDim),
            ),
        ],
      ),
    );
  }
}
