// lib/ui/forge_sheet.dart — the Ember Forge purchase sheet (spec R8, v0.4.0).
//
// The single place the game ever asks for money. Shown only when the player
// taps a locked thing (HARD or the Ascension ladder, v0.6.1) or the one quiet victory
// panel — never as a popup, never on a timer (§Ethics).
//
// Copy rules: say exactly what is paid and what is free, price comes from
// Play (localized), the close button is as big as the buy button's dignity
// allows, and a failed purchase reads as "nothing was charged".
import 'package:flutter/material.dart';
import '../audio/audio_service.dart';
import '../game/controller.dart';
import '../meta/store_service.dart';
import 'theme.dart';
import 'widgets.dart';

/// Open the Forge sheet. Safe to call anywhere; if the entitlement is already
/// owned the sheet celebrates instead of selling.
Future<void> showForgeSheet(BuildContext context, GameController c) {
  AudioService.instance?.playSfx('ui_tap');
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: EmberColors.bg,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ForgeSheet(c),
  );
}

class ForgeSheet extends StatelessWidget {
  final GameController c;
  const ForgeSheet(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreService.instance;
    // Rebuild on store state changes (price load, pending, owned).
    return AnimatedBuilder(
      animation: Listenable.merge([if (store != null) store.tick, c]),
      builder: (context, _) {
        final owned = c.meta.forgeUnlocked;
        final state =
            store?.state ??
            (owned ? ForgeStoreState.owned : ForgeStoreState.unavailable);
        return SafeArea(
          // The offer must remain readable on short phones and at enlarged
          // text sizes. Scroll the content, never shrink the words or hide
          // the price, restore link or way back to the free game.
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: Space.xl,
              right: Space.xl,
              top: Space.xl,
              bottom: Space.xl + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: EmberColors.ember,
                      size: 28,
                    ),
                    const SizedBox(width: Space.m),
                    const Expanded(
                      child: Text('THE EMBER FORGE', style: EmberText.h2),
                    ),
                    IconButton(
                      key: const ValueKey('forge-close'),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: EmberColors.textDim),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: Space.m),
                if (owned) ...[
                  const Panel(
                    child: Text(
                      'The Forge burns for you. HARD and the Ascension '
                      'ladder are open — thank you for keeping a solo '
                      'delve alive.',
                      style: EmberText.body,
                    ),
                  ),
                ] else ...[
                  const Text('FREE TO PLAY', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  const Text(
                    'Emberdelve is free, forever: full runs, every delver, '
                    'the Daily and Weekly Delves. No ads, no timers, no tricks.',
                    style: EmberText.bodyDim,
                  ),
                  const SizedBox(height: Space.l),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ONE PURCHASE OPENS THE ENDGAME',
                          style: EmberText.micro,
                        ),
                        const SizedBox(height: Space.m),
                        _perk(
                          Icons.whatshot,
                          'HARD difficulty — brutal foes, embers ×1.25',
                        ),
                        _perk(
                          Icons.stairs,
                          'The Ascension ladder — 20 rungs of stacked '
                          'challenge, earned one win at a time',
                        ),
                        _perk(
                          Icons.update,
                          'Every future act and delver, included',
                        ),
                        _perk(
                          Icons.favorite,
                          'And a solo developer\'s honest gratitude',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.l),
                  const Text(
                    'Pay once. Keep it. No subscription.',
                    style: EmberText.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.m),
                  ..._actionZone(context, state, store),
                  const SizedBox(height: Space.s),
                  Center(
                    child: TextButton(
                      key: const ValueKey('forge-restore'),
                      onPressed: state == ForgeStoreState.pending
                          ? null
                          : () => store?.restore(),
                      child: Text(
                        'Already bought it? Restore purchase',
                        style: EmberText.micro.copyWith(
                          color: EmberColors.textDim,
                        ),
                      ),
                    ),
                  ),
                  if (store?.lastError != null) ...[
                    const SizedBox(height: Space.s),
                    Text(
                      store!.lastError!,
                      key: const ValueKey('forge-error'),
                      style: EmberText.micro.copyWith(
                        color: EmberColors.textDim,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
                const SizedBox(height: Space.m),
                EmberButton(
                  owned ? 'Back to the game' : 'Not now — keep playing',
                  key: const ValueKey('forge-not-now'),
                  ghost: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _actionZone(
    BuildContext context,
    ForgeStoreState state,
    StoreService? store,
  ) {
    switch (state) {
      case ForgeStoreState.owned:
        return const []; // handled by the owned panel above
      case ForgeStoreState.pending:
        return [
          const Center(
            child: Padding(
              padding: EdgeInsets.all(Space.m),
              child: CircularProgressIndicator(color: EmberColors.ember),
            ),
          ),
          const Text(
            'Waiting on Google Play…',
            style: EmberText.micro,
            textAlign: TextAlign.center,
          ),
        ];
      case ForgeStoreState.ready:
        return [
          EmberButton(
            'Kindle the Forge — ${store?.price ?? ''}',
            key: const ValueKey('forge-buy'),
            primary: true,
            icon: Icons.local_fire_department,
            onTap: () => store?.buy(),
          ),
        ];
      case ForgeStoreState.unknown:
      case ForgeStoreState.unavailable:
        return [
          Panel(
            child: Text(
              state == ForgeStoreState.unknown
                  ? 'Reaching Google Play…'
                  : 'Google Play isn\'t reachable right now — nothing is '
                        'lost. Have an unlock code? Redeem it in Settings.',
              style: EmberText.bodyDim,
              textAlign: TextAlign.center,
            ),
          ),
        ];
    }
  }

  Widget _perk(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: EmberColors.ember, size: 18),
        const SizedBox(width: Space.m),
        Expanded(child: Text(text, style: EmberText.body)),
      ],
    ),
  );
}
