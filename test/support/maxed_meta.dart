// Shared fixture: a maxed VETERAN MetaState — every codex entry,
// achievement, tale, tip, track, cosmetic, and per-delver tally filled.
// Used by test/meta_size_test.dart (suite gate) and
// tool/boot_cost_probe_test.dart (explicit timing probe).

import 'package:emberdelve/data/achievements.dart';
import 'package:emberdelve/data/attire.dart';
import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/data/codex.dart';
import 'package:emberdelve/data/skins.dart';
import 'package:emberdelve/data/tales.dart';
import 'package:emberdelve/data/themes.dart';
import 'package:emberdelve/data/tracks.dart';
import 'package:emberdelve/game/tips.dart';
import 'package:emberdelve/meta/meta.dart';

MetaState maxedMeta() {
  final m = MetaState()
    ..tutorialSeen = true
    ..forgeUnlocked = true
    ..embers = 2400
    ..lifetimeEmbers = 99999
    ..runsPlayed = 500
    ..runsWon = 210;
  m.tipsSeen.addAll(ContextTips.all);
  m.hearthTalesHeard = hearthTales.length;
  for (final e in codexEntries) {
    m.ownedCodex.add(e.id);
  }
  m.seenAchievements.addAll(achievements.keys);
  m.ownedDieSkins.addAll(dieSkinsOrder);
  m.ownedDyes.addAll(delverDyesOrder);
  m.ownedThemes.addAll(hearthThemesOrder);
  m.unlockedCharacters.addAll(charactersOrder);
  for (final t in gramophoneTracks) {
    m.heardTracks.add(t.key);
  }
  for (final id in charactersOrder) {
    m.charRuns[id] = 30;
    m.charWins[id] = 12;
    m.charHardWins[id] = 3;
    m.charEpithet[id] = 'sparktender';
    m.charDye[id] = delverDyesOrder.first;
    m.charVista[id] = 'the_first_dark';
    m.charSkin[id] = dieSkinsOrder.first;
    m.charName[id] = 'Delver of the Long Dark $id';
  }
  return m;
}
