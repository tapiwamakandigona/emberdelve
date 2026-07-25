// ui/level_select_screen.dart — World 1 map: card-styled level nodes over
// the forest backdrop, per-level medal icons (finish / all chests / low
// damage) from saved results, wallet display, shop shortcut, and the boss
// node locked until w1_l1..w1_l5 are all finished (progress_state rules).
import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../meta/economy.dart';
import '../meta/progress_state.dart';
import 'app_state.dart';
import 'game_screen.dart';
import 'shop_screen.dart';

const _gold = Color(0xFFE8A33D);

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  @override
  Widget build(BuildContext context) {
    final save = AppState.save;
    return Scaffold(
      backgroundColor: const Color(0xFF141420),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('DELVE',
            style: TextStyle(
                fontFamily: 'Cinzel',
                color: _gold,
                fontWeight: FontWeight.bold,
                letterSpacing: 3)),
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront, color: _gold),
            tooltip: 'Shop',
            onPressed: () {
              AudioService.instance?.playSfx('ui_tap');
              Navigator.of(context)
                  .push(
                      MaterialPageRoute(builder: (_) => const ShopScreen()))
                  .then((_) => setState(() {}));
            },
          ),
          WalletChip(
              wallet: Wallet(coins: save.coins, feathers: save.feathers)),
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/bg/forest_back.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            color: const Color(0xAA141420),
            colorBlendMode: BlendMode.srcATop),
        ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            _worldHeader('WORLD 1 — EMBERWOOD'),
            ..._worldCards(kWorld1),
            const SizedBox(height: 16),
            _worldHeader(isWorld2Unlocked(save)
                ? 'WORLD 2 — CINDER DEPTHS'
                : 'WORLD 2 — CINDER DEPTHS  (defeat the Grove Golem)'),
            ..._worldCards(kWorld2),
          ],
        ),
      ]),
    );
  }

  Widget _worldHeader(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(label,
            style: const TextStyle(
                fontFamily: 'Cinzel',
                color: _gold,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 2)),
      );

  List<Widget> _worldCards(List<LevelEntry> world) {
    final save = AppState.save;
    return [
      for (var i = 0; i < world.length; i++) ...[
        Builder(builder: (context) {
          final entry = world[i];
          final unlocked = isLevelUnlocked(save, i, world: world);
          return _LevelCard(
            index: i + 1,
            entry: entry,
            unlocked: unlocked,
            onTap: unlocked
                ? () {
                    AudioService.instance?.playSfx('ui_tap');
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => GameScreen(levelId: entry.id)))
                        .then((_) => setState(() {}));
                  }
                : null,
          );
        }),
        if (i != world.length - 1) const SizedBox(height: 8),
      ],
    ];
  }
}

class _LevelCard extends StatelessWidget {
  final int index;
  final LevelEntry entry;
  final bool unlocked;
  final VoidCallback? onTap;
  const _LevelCard({
    required this.index,
    required this.entry,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rec = AppState.save.levels[entry.id];
    final boss = entry.isBoss;
    return Material(
      color: unlocked
          ? (boss ? const Color(0xEE2E1E24) : const Color(0xEE1E1E2E))
          : const Color(0x991E1E2E),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: boss && unlocked
                    ? const Color(0x88E8631A)
                    : Colors.white12),
          ),
          child: Row(children: [
            // Node badge.
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked
                    ? (boss ? const Color(0xFFE8631A) : const Color(0xFF3E8948))
                    : Colors.white10,
              ),
              child: unlocked
                  ? (boss
                      ? const Icon(Icons.whatshot,
                          color: Colors.white, size: 22)
                      : Text('$index',
                          style: const TextStyle(
                              fontFamily: 'Cinzel',
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 18)))
                  : const Icon(Icons.lock, color: Colors.white24, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title,
                        style: TextStyle(
                            fontFamily: 'Cinzel',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color:
                                unlocked ? Colors.white : Colors.white38)),
                    Text(
                      !unlocked
                          ? (boss
                              ? 'Finish all five levels to face the Golem'
                              : 'Locked')
                          : rec == null
                              ? 'Not cleared'
                              : rec.bestTimeMs > 0
                                  ? 'Best ${_fmtMs(rec.bestTimeMs)}'
                                  : 'Cleared',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ]),
            ),
            // Three medal icons: finished / all chests / low damage.
            _Medal(
                earned: rec?.finished ?? false,
                icon: Icons.flag,
                tip: 'Finished'),
            _Medal(
                earned: rec?.allChests ?? false,
                icon: Icons.inventory_2,
                tip: 'All chests'),
            _Medal(
                earned: rec?.lowDamage ?? false,
                icon: Icons.favorite,
                tip: 'Low damage'),
          ]),
        ),
      ),
    );
  }

  static String _fmtMs(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

class _Medal extends StatelessWidget {
  final bool earned;
  final IconData icon;
  final String tip;
  const _Medal({required this.earned, required this.icon, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Icon(icon,
            size: 18, color: earned ? _gold : Colors.white12),
      ),
    );
  }
}
