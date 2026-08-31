// lib/ui/screens/relic_inventory.dart — part of screens.dart (see library
// header there).
//
// v0.27.0 (#97): in-run relic inventory. Player request (itch, 0.26.0
// devlog): owned relics and the starting relic's effect were invisible
// mid-run — effects only surfaced through events. This panel lists every
// owned relic with its full effect text, in pickup order, with the
// character's starting relic tagged. Effect text stays free (the codex
// sells lore only, per docs/store policy).
part of '../screens.dart';

/// In-run relic inventory dialog. Opened from the top bar's relic pip and
/// the pause menu. Read-only: shows name + effect for every owned relic.
void showRelicInventory(BuildContext context, GameController c) {
  final run = c.state?['run'] as Map?;
  if (run == null) return;
  final owned = (run['relics'] as List).cast<String>();
  final charId = run['character'] as String?;
  final startRelic = charId != null ? characters[charId]?.startRelic : null;
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Panel(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.diamond, size: 16, color: EmberColors.gold),
                const SizedBox(width: Space.s),
                Text('RELICS · ${owned.length}', style: EmberText.h2),
              ],
            ),
            const SizedBox(height: Space.l),
            if (owned.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: Space.l),
                child: Text(
                  'No relics yet. Elites, events, and the shop carry them.',
                  style: EmberText.bodyDim,
                  textAlign: TextAlign.center,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: owned.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: EmberColors.line, height: Space.l),
                  itemBuilder: (_, i) {
                    final def = relics[owned[i]];
                    if (def == null) return const SizedBox.shrink();
                    // v0.93.0 The Pictured Satchel: rows lead with the
                    // relic's icon — recognition built at the shop carries
                    // into the one place the player reviews what they own.
                    return Row(
                      children: [
                        Image.asset(
                          Art.relicIcon(owned[i]),
                          width: 36,
                          height: 36,
                          filterQuality: FilterQuality.medium,
                        ),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      def.name,
                                      style: EmberText.label,
                                    ),
                                  ),
                                  if (owned[i] == startRelic)
                                    Text(
                                      'STARTING',
                                      style: EmberText.micro.copyWith(
                                        color: EmberColors.gold,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(def.text, style: EmberText.bodyDim),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: Space.m),
            SizedBox(
              width: double.infinity,
              child: EmberButton(
                'Close',
                primary: true,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
