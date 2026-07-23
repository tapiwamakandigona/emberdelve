// lib/audio/audio_service.dart — music loops + SFX one-shots (audioplayers).
//
// Music: one looping track per screen family (title/map/combat/boss_combat)
// with a short crossfade on change; victory/defeat play as non-looping stings.
// A quiet ember-ambience bed runs under the title and rest screens.
//
// SFX: 20 one-shot ids (see [sfxPaths]) played through a small player pool.
// Immediate, event-mapped SFX go through [handleEvents]; combat impact sounds
// (whoosh/hits/deaths) are timed by the combat screen's choreography per
// staging SYNC_POINTS.md, so they land on the animation contact frame.
//
// Everything is best-effort: every platform call is caught so audio can never
// crash gameplay, and nothing here is constructed in widget tests.
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'settings.dart';

class AudioService {
  /// Set by main(); null in tests (all call sites are null-safe).
  static AudioService? instance;

  static const Map<String, String> musicPaths = {
    'title_menu': 'audio/music/title_menu.ogg',
    'map': 'audio/music/map.ogg',
    'combat': 'audio/music/combat.ogg',
    'boss_combat': 'audio/music/boss_combat.ogg',
    'victory': 'audio/music/victory.ogg',
    'defeat': 'audio/music/defeat.ogg',
  };

  static const Map<String, String> sfxPaths = {
    'dice_roll': 'audio/sfx/dice_roll.ogg',
    'die_assign': 'audio/sfx/die_assign.ogg',
    'reroll': 'audio/sfx/reroll.ogg',
    'player_hit': 'audio/sfx/player_hit.ogg',
    'enemy_hit': 'audio/sfx/enemy_hit.ogg',
    'block': 'audio/sfx/block.ogg',
    'enemy_death': 'audio/sfx/enemy_death.ogg',
    'boss_death': 'audio/sfx/boss_death.ogg',
    'victory': 'audio/sfx/victory.ogg',
    'defeat': 'audio/sfx/defeat.ogg',
    'coin': 'audio/sfx/coin.ogg',
    'forge': 'audio/sfx/forge.ogg',
    'heal': 'audio/sfx/heal.ogg',
    'event_page': 'audio/sfx/event_page.ogg',
    'ui_tap': 'audio/sfx/ui_tap.ogg',
    'ui_back': 'audio/sfx/ui_back.ogg',
    'unlock': 'audio/sfx/unlock.ogg',
    'ember_gain': 'audio/sfx/ember_gain.ogg',
    'whoosh': 'audio/sfx/whoosh.ogg',
    'ember_ambience_loop': 'audio/sfx/ember_ambience_loop.ogg',
  };

  /// Immediate SFX per sim event type. Combat impacts (whoosh, hits, deaths,
  /// stings) are deliberately absent — the combat screen times those to the
  /// animation frames instead.
  static const Map<String, String> eventSfx = {
    'dice_rolled': 'dice_roll',
    'die_assigned': 'die_assign',
    'reroll_used': 'reroll',
    'gold_gained': 'coin',
    'gold_spent': 'coin',
    'bought': 'coin',
    'forged': 'forge',
    'healed': 'heal',
    'rested': 'heal',
    'event_shown': 'event_page',
    'embers_gained': 'ember_gain',
    'relic_gained': 'unlock',
  };

  AudioSettings settings;
  AudioService(this.settings);

  static const _ambienceLevel = 0.35; // relative to music volume

  AudioPlayer? _music;
  String? _musicKey;
  AudioPlayer? _ambience;

  final List<AudioPlayer> _sfxPool = [];
  int _sfxNext = 0;
  static const _sfxPoolSize = 6;

  // -- Music ----------------------------------------------------------------

  /// Music key for a sim phase. `null`/idle = title.
  static String? musicKeyForPhase(String? phase, {bool bossFight = false}) {
    switch (phase) {
      case 'player_turn':
        return bossFight ? 'boss_combat' : 'combat';
      case 'map':
      case 'reward':
      case 'shop':
      case 'event':
      case 'rest':
        return 'map';
      case 'run_won':
        return 'victory';
      case 'run_lost':
        return 'defeat';
      default:
        return 'title_menu';
    }
  }

  static bool _ambientPhase(String? phase) =>
      phase == null || phase == 'idle' || phase == 'rest';

  /// Crossfade to the track for [phase]; manage the ambience bed too.
  Future<void> syncPhase(String? phase, {bool bossFight = false}) async {
    final key = musicKeyForPhase(phase, bossFight: bossFight);
    setAmbience(_ambientPhase(phase));
    if (key == _musicKey) return;
    final sting = key == 'victory' || key == 'defeat';
    await playMusic(key!, loop: !sting);
  }

  Future<void> playMusic(String key, {bool loop = true}) async {
    final path = musicPaths[key];
    if (path == null) return;
    _musicKey = key;
    final old = _music;
    _music = null;
    if (old != null) _fadeOutAndDispose(old);
    try {
      final p = AudioPlayer();
      _music = p;
      await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
      await p.play(AssetSource(path), volume: settings.effectiveMusic);
    } catch (_) {}
  }

  void _fadeOutAndDispose(AudioPlayer p) {
    var v = settings.effectiveMusic;
    // One timer per faded player: rapid consecutive music switches each get
    // their own fade, so an earlier fading player can never be orphaned
    // mid-fade (which would leave it looping at partial volume).
    Timer.periodic(const Duration(milliseconds: 50), (t) async {
      v -= 0.12;
      if (v <= 0) {
        t.cancel();
        try {
          await p.stop();
          await p.dispose();
        } catch (_) {}
      } else {
        try {
          await p.setVolume(v.clamp(0.0, 1.0));
        } catch (_) {}
      }
    });
  }

  /// Quiet ember-crackle bed under title/rest.
  void setAmbience(bool on) {
    if (on) {
      if (_ambience != null) return;
      try {
        final p = AudioPlayer();
        _ambience = p;
        p.setReleaseMode(ReleaseMode.loop);
        p.play(AssetSource(sfxPaths['ember_ambience_loop']!),
            volume: settings.effectiveMusic * _ambienceLevel);
      } catch (_) {}
    } else {
      final p = _ambience;
      _ambience = null;
      if (p != null) {
        try {
          p.stop();
          p.dispose();
        } catch (_) {}
      }
    }
  }

  // -- SFX --------------------------------------------------------------------

  Future<void> playSfx(String id, {double volume = 1.0}) async {
    final path = sfxPaths[id];
    if (path == null) return;
    final v = settings.effectiveSfx * volume;
    if (v <= 0) return;
    try {
      if (_sfxPool.length < _sfxPoolSize) {
        _sfxPool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      }
      final p = _sfxPool[_sfxNext % _sfxPool.length];
      _sfxNext++;
      await p.stop();
      await p.play(AssetSource(path), volume: v.clamp(0.0, 1.0));
    } catch (_) {}
  }

  /// Immediate, non-choreographed SFX for a batch of sim events.
  void handleEvents(List<Map<String, Object?>> events) {
    final played = <String>{};
    for (final e in events) {
      final id = eventSfx[e['type']];
      if (id != null && played.add(id)) playSfx(id);
    }
  }

  // -- Settings ---------------------------------------------------------------

  /// Push current settings onto live players (sliders move audio instantly).
  void applySettings() {
    try {
      _music?.setVolume(settings.effectiveMusic);
      _ambience?.setVolume(settings.effectiveMusic * _ambienceLevel);
    } catch (_) {}
  }
}
