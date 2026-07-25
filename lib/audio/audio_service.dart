// lib/audio/audio_service.dart — music loops + SFX one-shots (audioplayers).
//
// Music: one looping track per screen family (title/map/combat/boss_combat)
// with a short crossfade on change; victory/defeat play as non-looping stings.
// A quiet ember-ambience bed runs under the title and rest screens.
//
// SFX: one-shot ids (see [sfxPaths]) played through a small player pool.
// The platformer maps them per event in EmberGame._handlePlayerEvents /
// _handleSessionEvents (jump/land/swing combo/chest/feather/secret/...).
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
    // -- movement / combat (platformer v2 pass, tool/build_platformer_sfx.py)
    'jump': 'audio/sfx/jump.ogg',
    'double_jump': 'audio/sfx/double_jump.ogg',
    'land': 'audio/sfx/land.ogg',
    'swing1': 'audio/sfx/swing1.ogg',
    'swing2': 'audio/sfx/swing2.ogg',
    'swing3': 'audio/sfx/swing3.ogg',
    // -- loot / discovery
    'chest_open': 'audio/sfx/chest_open.ogg',
    'feather': 'audio/sfx/feather.ogg',
    'secret': 'audio/sfx/secret.ogg',
    'medal': 'audio/sfx/medal.ogg',
    // -- shared
    'player_hit': 'audio/sfx/player_hit.ogg',
    'enemy_hit': 'audio/sfx/enemy_hit.ogg',
    'block': 'audio/sfx/block.ogg',
    'enemy_death': 'audio/sfx/enemy_death.ogg',
    'boss_death': 'audio/sfx/boss_death.ogg',
    'victory': 'audio/sfx/victory.ogg',
    'defeat': 'audio/sfx/defeat.ogg',
    'coin': 'audio/sfx/coin.ogg',
    'heal': 'audio/sfx/heal.ogg',
    'ui_tap': 'audio/sfx/ui_tap.ogg',
    'ui_back': 'audio/sfx/ui_back.ogg',
    'unlock': 'audio/sfx/unlock.ogg',
    'ember_gain': 'audio/sfx/ember_gain.ogg',
    'whoosh': 'audio/sfx/whoosh.ogg',
    'ember_ambience_loop': 'audio/sfx/ember_ambience_loop.ogg',
    'danger_loop': 'audio/sfx/danger_loop.ogg',
  };

  AudioSettings settings;
  AudioService(this.settings);

  /// One-time platform audio session setup — call from main() before any
  /// player is created. Android's default AudioContext makes EVERY player
  /// request exclusive audio focus (AUDIOFOCUS_GAIN) on play(), so each SFX
  /// one-shot (ui_tap on the settings gear, the difficulty selector, every
  /// EmberButton...) delivered a permanent AUDIOFOCUS_LOSS to the music
  /// player, which audioplayers answers with a pause() that is never
  /// resumed — "tapping settings kills the music". mixWithOthers drops all
  /// in-app focus fighting (Android: AUDIOFOCUS_NONE, iOS: playback +
  /// mixWithOthers); backgrounding is handled by the app-lifecycle observer
  /// (pauseAll/resumeAll), not by audio focus.
  static Future<void> initPlatformAudio() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
    } catch (_) {}
  }

  static const _ambienceLevel = 0.35; // relative to music volume
  static const _dangerLevel = 0.5; // relative to music volume

  AudioPlayer? _music;
  String? _musicKey;
  AudioPlayer? _ambience;
  AudioPlayer? _danger;

  final List<AudioPlayer> _sfxPool = [];
  int _sfxNext = 0;
  static const _sfxPoolSize = 6;

  // -- Music ----------------------------------------------------------------

  Future<void> playMusic(String key, {bool loop = true}) async {
    final path = musicPaths[key];
    if (path == null) return;
    // Dedupe looping tracks: navigating title -> shop/settings -> title must
    // not restart the theme mid-phrase. Stings (victory/defeat) always play.
    if (loop && key == _musicKey && _music != null) return;
    _musicKey = key;
    final old = _music;
    _music = null;
    if (old != null) _fadeOutAndDispose(old);
    AudioPlayer? p;
    try {
      p = AudioPlayer();
      _music = p;
      await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
      await p.play(AssetSource(path), volume: settings.effectiveMusic);
    } catch (_) {
      // A failed start must not poison the dedupe key: playMusic would keep
      // early-returning on `key == _musicKey` and the whole screen family
      // (title/map/combat) would stay silent. Reset so the next call retries
      // — but only if a newer playMusic hasn't already taken over.
      if (_music == p) {
        _music = null;
        _musicKey = null;
      }
      try {
        await p?.dispose();
      } catch (_) {}
    }
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
      AudioPlayer? p;
      try {
        p = AudioPlayer();
        _ambience = p;
        p.setReleaseMode(ReleaseMode.loop);
        p.play(AssetSource(sfxPaths['ember_ambience_loop']!),
            volume: settings.effectiveMusic * _ambienceLevel);
      } catch (_) {
        // Same retry rule as playMusic: a failed start must not occupy the
        // slot, or ambience stays silent until the next off/on phase swing.
        if (_ambience == p) _ambience = null;
      }
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

  /// Low-HP danger bed (v0.4, flagged "before 1.0" since v0.2): a quiet
  /// heartbeat loop under the combat music while the player is in lethal
  /// range. Same lifecycle rules as the ambience bed: a failed start must
  /// not occupy the slot, and off always stops+disposes.
  void setDanger(bool on) {
    if (on) {
      if (_danger != null) return;
      AudioPlayer? p;
      try {
        p = AudioPlayer();
        _danger = p;
        p.setReleaseMode(ReleaseMode.loop);
        p.play(AssetSource(sfxPaths['danger_loop']!),
            volume: settings.effectiveMusic * _dangerLevel);
      } catch (_) {
        if (_danger == p) _danger = null;
      }
    } else {
      final p = _danger;
      _danger = null;
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

  // -- App lifecycle (v0.3.1 F3) ----------------------------------------------

  /// Pause everything when the app leaves the foreground (Home/lock/call) —
  /// Android keeps audioplayers running otherwise, which is a Play-review
  /// killer. Best-effort like everything else here.
  void pauseAll() {
    try {
      _music?.pause();
      _ambience?.pause();
      for (final p in _sfxPool) {
        p.stop();
      }
    } catch (_) {}
  }

  /// Resume the music + ambience beds on return to the foreground.
  void resumeAll() {
    try {
      _music?.resume();
      _ambience?.resume();
    } catch (_) {}
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
