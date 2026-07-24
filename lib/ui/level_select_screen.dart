// ui/level_select_screen.dart — World 1 level list with locks + medals.
// M1: functional placeholder; M4 adds the world-map art treatment.
import 'package:flutter/material.dart';

import '../meta/progress_state.dart';
import 'app_state.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final save = AppState.save;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emberwood — World 1'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: kWorld1.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final entry = kWorld1[i];
          final unlocked = isLevelUnlocked(save, i);
          final record = save.levels[entry.id];
          return ListTile(
            tileColor: const Color(0xFF1E1E2E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            leading: Icon(
              unlocked
                  ? (entry.isBoss ? Icons.whatshot : Icons.forest)
                  : Icons.lock,
              color: unlocked ? const Color(0xFFE8A33D) : Colors.white24,
            ),
            title: Text(entry.title,
                style: TextStyle(
                    color: unlocked ? Colors.white : Colors.white38)),
            subtitle: Text(
              record == null
                  ? (unlocked ? 'Not cleared' : 'Locked')
                  : 'Medals: ${record.medals}/3',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            onTap: unlocked
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Gameplay lands in M2 — engine core.')),
                    )
                : null,
          );
        },
      ),
    );
  }
}
