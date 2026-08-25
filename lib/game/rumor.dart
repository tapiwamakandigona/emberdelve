// lib/game/rumor.dart — The Rumor (v0.53.0): pre-delve boss telegraph.
//
// The run's boss is a PURE function of the run seed (sim/run_layer.dart
// `bossForSeed`) — decided the moment the seed exists, before a single die
// is rolled. Telling the player is therefore honest information, not a
// mechanic: no RNG stream is consumed, no odds are hidden, and nothing about
// the run changes based on whether the rumor is read (spec §Ethics test:
// "would the player endorse it if we explained exactly how it works?" —
// this line IS the explanation).
//
// Surfaces (v0.53.0): the boon pick (the run-start panel every delve opens
// on) and a live preview in the "Delve a seed" dialog — a shared Delve Code
// becomes "seed X, <boss> at the bottom", which is the whole point of
// sharing one.
import '../data/enemies.dart';
import '../sim/run_layer.dart';

/// One campfire line naming the boss the seed has already chosen.
String rumorForSeed(int seed) =>
    'Rumor has it the ${enemies[bossForSeed(seed)]!.name} waits at the '
    'bottom.';
