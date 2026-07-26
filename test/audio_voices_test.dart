// test/audio_voices_test.dart — SFX voice-pool selection (v0.3.15).
//
// The pool exists so a fast dice cascade or a multi-hit turn LAYERS instead of
// cutting the previous sound off. No platform player is involved here: the
// choice is a pure function over "which voices are still sounding", which is
// the part that can regress silently.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/audio/audio_service.dart';

void main() {
  group('AudioService.pickVoice', () {
    test('takes an idle voice over a sounding one', () {
      // voice 0 busy, round-robin points at 0 -> must pick 1.
      expect(AudioService.pickVoice([true, false], 0), 1);
      expect(AudioService.pickVoice([true, true, false], 0), 2);
    });

    test('all voices busy falls back to the round-robin pick', () {
      expect(AudioService.pickVoice([true, true], 0), 0);
      expect(AudioService.pickVoice([true, true], 1), 1);
      expect(AudioService.pickVoice([true, true, true], 2), 2);
    });

    test('round-robin start is respected when several are idle', () {
      // Spreads triggers across voices instead of hammering voice 0, so a
      // sound retriggered three times in a row uses three different voices.
      expect(AudioService.pickVoice([false, false, false], 1), 1);
      expect(AudioService.pickVoice([false, false, false], 2), 2);
    });

    test('wraps past the end of the pool', () {
      expect(AudioService.pickVoice([false, true], 1), 0);
      expect(AudioService.pickVoice([true, false], 1), 1);
    });

    test('single-voice ids always restart the one voice', () {
      expect(AudioService.pickVoice([true], 0), 0);
      expect(AudioService.pickVoice([false], 0), 0);
    });

    test('empty pool is a no-op index, never a crash', () {
      expect(AudioService.pickVoice([], 0), 0);
    });
  });

  group('voice table', () {
    test('every multi-voice id is a real SFX id', () {
      for (final id in AudioService.sfxVoices.keys) {
        expect(
          AudioService.sfxPaths.containsKey(id),
          isTrue,
          reason: '$id has a voice count but no asset',
        );
      }
    });

    test('UI clicks and stings stay single-voice', () {
      for (final id in const [
        'ui_tap',
        'ui_back',
        'victory',
        'defeat',
        'enemy_death',
        'boss_death',
        'ember_ambience_loop',
        'danger_loop',
      ]) {
        expect(AudioService.voicesFor(id), 1, reason: '$id must not layer');
      }
    });

    test('voice counts stay small (SoundPool budget)', () {
      for (final entry in AudioService.sfxVoices.entries) {
        expect(entry.value, greaterThan(1));
        expect(entry.value, lessThanOrEqualTo(3), reason: entry.key);
      }
    });
  });

  // -- Mix-bus invariants (v0.3.17) -------------------------------------------
  //
  // `tool/sfx_headroom.py` renders the worst-case cascades from the shipped
  // .ogg assets and measures true peak. Its verdict "every reachable cascade
  // clears 0 dBTP" rests on two facts about this file. If either changes, the
  // measurement is stale — these tests fail so the tool gets re-run.
  group('SFX mix-bus invariants', () {
    test('a batch of events never fires the same id twice', () {
      // gold_gained + gold_spent + bought all map to 'coin'. Three coin voices
      // started on the same frame sum coherently to +5.9 dBTP (measured); the
      // de-dupe is what keeps that scenario unreachable.
      final ids = AudioService.sfxIdsForEvents(const [
        {'type': 'gold_gained'},
        {'type': 'bought'},
        {'type': 'gold_spent'},
        {'type': 'die_assigned'},
        {'type': 'die_assigned'},
      ]);
      expect(ids, ['coin', 'die_assign']);
    });

    test('unmapped and unknown event types are ignored, order is kept', () {
      final ids = AudioService.sfxIdsForEvents(const [
        {'type': 'combat_started'},
        {'type': 'dice_rolled'},
        {'type': 'not_a_real_event'},
        {'type': 'embers_gained'},
      ]);
      expect(ids, ['dice_roll', 'ember_gain']);
    });

    test('audited voice caps — bump one and re-run tool/sfx_headroom.py', () {
      // Golden copy of the table the headroom measurement was taken against.
      expect(AudioService.sfxVoices, {
        'dice_roll': 2,
        'die_assign': 3,
        'reroll': 2,
        'enemy_hit': 3,
        'player_hit': 2,
        'block': 2,
        'coin': 3,
        'ember_gain': 2,
        'whoosh': 2,
      });
    });
  });
}
