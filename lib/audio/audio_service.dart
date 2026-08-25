// lib/audio/audio_service.dart — music loops + SFX one-shots (audioplayers).
//
// Music: one looping track per screen family (title/map/combat/boss_combat)
// with a short crossfade on change; victory/defeat play as non-looping stings.
// A quiet ember-ambience bed runs under the title and rest screens.
//
// SFX: 20 one-shot ids (see [sfxPaths]), each with one or more resident
// low-latency voices (see [sfxVoices]) so overlapping triggers layer.
// Immediate, event-mapped SFX go through [handleEvents]; combat impact sounds
// (whoosh/hits/deaths) are timed by the combat screen's choreography per
// staging SYNC_POINTS.md, so they land on the animation contact frame.
//
// Everything is best-effort: every platform call is caught so audio can never
// crash gameplay, and nothing here is constructed in widget tests.
import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:audioplayers/audioplayers.dart';
import 'settings.dart';

class AudioService {
  /// Set by main(); null in tests (all call sites are null-safe).
  static AudioService? instance;

  static const Map<String, String> musicPaths = {
    'title_menu': 'audio/music/title_menu.ogg',
    'map': 'audio/music/map.ogg',
    'map_deep': 'audio/music/map_deep.ogg',
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
    'danger_loop': 'audio/sfx/danger_loop.ogg',
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
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
    } catch (_) {}
  }

  static const _ambienceLevel = 0.35; // relative to music volume
  static const _dangerLevel = 0.5; // relative to music volume

  /// v0.23.0 "The Deep Hum": on the delve map the ember bed deepens with
  /// descent. [depth] is 0.0 at the first layer and 1.0 at the boss layer;
  /// shallow floors whisper under the map music, the last approach hums.
  /// Pure so the curve is pinned by tests without a platform player.
  static double mapAmbienceLevel(double depth) {
    final d = depth.clamp(0.0, 1.0);
    return 0.12 + (0.45 - 0.12) * d;
  }

  /// Relative level the ambience bed is currently running at (null when the
  /// bed is off). Kept so applySettings and live depth changes re-apply the
  /// right level instead of snapping map ambience back to the title level.
  double? _ambienceRel;

  AudioPlayer? _music;
  String? _musicKey;
  AudioPlayer? _ambience;
  AudioPlayer? _danger;

  /// Preloaded low-latency voices per SFX id (see [playSfx]). Most ids have a
  /// single voice; the ones a player can genuinely trigger on top of
  /// themselves get [sfxVoices] of them so the second hit LAYERS instead of
  /// cutting the first one off.
  final Map<String, List<AudioPlayer>> _sfxPlayers = {};
  final Map<String, int> _sfxNextVoice = {};
  final Set<String> _sfxLoading = {};

  /// Voice count per SFX id (default 1). Multi-voice ids are the ones that
  /// overlap in real play: the dice cascade assigns/rolls in quick succession,
  /// and multi-hit turns stack impacts. UI clicks stay single-voice — a click
  /// that restarts is correct, a click that layers sounds broken.
  static const Map<String, int> sfxVoices = {
    'dice_roll': 2,
    'die_assign': 3,
    'reroll': 2,
    'enemy_hit': 3,
    'player_hit': 2,
    'block': 2,
    'coin': 3,
    'ember_gain': 2,
    'whoosh': 2,
  };

  static int voicesFor(String id) => sfxVoices[id] ?? 1;

  /// Which voice to trigger next: the first idle one, else the round-robin
  /// pick (the least recently started voice, i.e. the closest to finished).
  /// Pure and static so the choice is testable without a platform player.
  @visibleForTesting
  static int pickVoice(List<bool> busy, int next) {
    if (busy.isEmpty) return 0;
    for (var i = 0; i < busy.length; i++) {
      final idx = (next + i) % busy.length;
      if (!busy[idx]) return idx;
    }
    return next % busy.length;
  }

  /// Ids worth having ready before the first tap ever happens.
  static const _warmSfx = [
    'ui_tap',
    'ui_back',
    'dice_roll',
    'die_assign',
    'reroll',
    'coin',
  ];

  // -- Music ----------------------------------------------------------------

  /// Music key for a sim phase. `null`/idle = title.
  ///
  /// [mapDepth] (0..1, first layer -> boss layer) darkens the map-family
  /// theme past the delve's midpoint (v0.45.0 "The Deeper Song"): the same
  /// depth signal the Deep Hum ambience follows, so sound and music agree
  /// about how far down the delver stands.
  static String? musicKeyForPhase(
    String? phase, {
    bool bossFight = false,
    double mapDepth = 0,
  }) {
    switch (phase) {
      case 'player_turn':
        return bossFight ? 'boss_combat' : 'combat';
      // 'boon' is part of the run (the map background already shows behind
      // it) — without this case it fell through to title music, so "Delve
      // again" after a defeat played: defeat sting -> title theme for the
      // boon pick -> map music seconds later. Two jarring switches.
      case 'boon':
      case 'map':
      case 'reward':
      case 'shop':
      case 'event':
      case 'rest':
        return mapDepth >= 0.5 ? 'map_deep' : 'map';
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
  ///
  /// [mapDepth] (0..1, first layer -> boss layer) only matters on the map
  /// phase, where the ember bed runs at a depth-scaled level instead of the
  /// fixed title level (v0.23.0 "The Deep Hum").
  Future<void> syncPhase(
    String? phase, {
    bool bossFight = false,
    double mapDepth = 0,
  }) async {
    final key = musicKeyForPhase(phase, bossFight: bossFight, mapDepth: mapDepth);
    if (phase == 'map') {
      setAmbience(true, level: mapAmbienceLevel(mapDepth));
    } else {
      setAmbience(_ambientPhase(phase));
    }
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
    AudioPlayer? p;
    try {
      p = AudioPlayer();
      _music = p;
      await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
      await p.play(AssetSource(path), volume: settings.effectiveMusic);
    } catch (_) {
      // A failed start must not poison the dedupe key: syncPhase would keep
      // early-returning on `key == _musicKey` and the whole screen family
      // (title/map/combat) would stay silent. Reset so the next sync retries
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

  /// Quiet ember-crackle bed under title/rest — and, depth-scaled, under the
  /// delve map (v0.23.0). [level] is relative to the music volume and
  /// defaults to the fixed title/rest level. A live level change on a
  /// running bed is a setVolume, never a restart: the loop must not hiccup
  /// as the player steps a node deeper.
  void setAmbience(bool on, {double? level}) {
    final rel = level ?? _ambienceLevel;
    if (on) {
      if (_ambience != null) {
        if (_ambienceRel != rel) {
          _ambienceRel = rel;
          try {
            _ambience?.setVolume(settings.effectiveMusic * rel);
          } catch (_) {}
        }
        return;
      }
      AudioPlayer? p;
      try {
        p = AudioPlayer();
        _ambience = p;
        _ambienceRel = rel;
        p.setReleaseMode(ReleaseMode.loop);
        p.play(
          AssetSource(sfxPaths['ember_ambience_loop']!),
          volume: settings.effectiveMusic * rel,
        );
      } catch (_) {
        // Same retry rule as playMusic: a failed start must not occupy the
        // slot, or ambience stays silent until the next off/on phase swing.
        if (_ambience == p) {
          _ambience = null;
          _ambienceRel = null;
        }
      }
    } else {
      final p = _ambience;
      _ambience = null;
      _ambienceRel = null;
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
        p.play(
          AssetSource(sfxPaths['danger_loop']!),
          volume: settings.effectiveMusic * _dangerLevel,
        );
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

  /// A one-shot SFX.
  ///
  /// PERF (2026-07-25): this used to round-robin a pool of six DEFAULT-mode
  /// players and call `stop()` + `play(AssetSource(...))` on every tap. On
  /// Android that means PlayerMode.mediaPlayer, so each tap tore down and
  /// re-prepared a MediaPlayer — a JNI hop plus an asset read plus a codec
  /// prepare, on the platform thread, *while* the UI was mid-tap. That is
  /// audible as the SFX arriving late or glitching, and it lands right on
  /// top of the frame the tap has to render, which is why hammering a button
  /// felt so much worse than tapping it once.
  ///
  /// Now: one player per sound id, created in [PlayerMode.lowLatency]
  /// (SoundPool on Android — the sample is decoded and resident in memory,
  /// playback is a single non-blocking native call) with the source set once
  /// up front. Re-triggering is stop -> resume, which SoundPool implements as
  /// "start a new stream from the decoded sample". Every SFX asset is <=56KB,
  /// well inside SoundPool's per-sample budget.
  ///
  /// Re-triggering (v0.3.15): ids listed in [sfxVoices] hold several resident
  /// voices and the next trigger takes an IDLE one, so a fast dice cascade or
  /// a multi-hit turn layers instead of chopping the previous sound off
  /// mid-tail. Single-voice ids (UI clicks, stings) still restart, which is
  /// the right behaviour for them.
  Future<void> playSfx(String id, {double volume = 1.0}) async {
    final path = sfxPaths[id];
    if (path == null) return;
    final v = settings.effectiveSfx * volume;
    if (v <= 0) return;
    try {
      final voices = _sfxPlayers[id] ?? await _ensureSfx(id, path);
      if (voices == null || voices.isEmpty) return;
      final idx = pickVoice([
        for (final p in voices) p.state == PlayerState.playing,
      ], _sfxNextVoice[id] ?? 0);
      _sfxNextVoice[id] = (idx + 1) % voices.length;
      final p = voices[idx];
      // Only a voice that is still sounding needs the stop(); skipping it on
      // an idle voice saves a platform hop on the frame of the tap.
      if (p.state == PlayerState.playing) await p.stop();
      await p.setVolume(v.clamp(0.0, 1.0));
      await p.resume();
    } catch (_) {}
  }

  /// Create + preload every voice for [id]. Concurrent callers for the same id
  /// don't stack up duplicate players.
  Future<List<AudioPlayer>?> _ensureSfx(String id, String path) async {
    final existing = _sfxPlayers[id];
    if (existing != null) return existing;
    if (_sfxLoading.contains(id)) return null;
    _sfxLoading.add(id);
    final made = <AudioPlayer>[];
    try {
      for (var i = 0; i < voicesFor(id); i++) {
        final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
        // Resolves once the sample is decoded and resident.
        await p.setSource(AssetSource(path));
        made.add(p);
      }
      _sfxPlayers[id] = made;
      return made;
    } catch (_) {
      // Keep whatever loaded: one working voice beats none.
      if (made.isNotEmpty) {
        _sfxPlayers[id] = made;
        return made;
      }
      return null;
    } finally {
      _sfxLoading.remove(id);
    }
  }

  /// Preload the SFX a player hits in the first seconds. Called from main()
  /// after [initPlatformAudio]; failures are silent and simply mean the first
  /// use of that sound loads on demand.
  Future<void> warmUp() async {
    for (final id in _warmSfx) {
      final path = sfxPaths[id];
      if (path != null) await _ensureSfx(id, path);
    }
  }

  /// Which SFX ids a batch of sim events should fire, in order, each at most
  /// once. The de-duplication is a mix-bus guarantee, not a nicety: two copies
  /// of the same sample started on the same frame sum coherently at +6 dB and
  /// clip (see `tool/sfx_headroom.py`, scenario `coin_3x_simultaneous`), so
  /// identical ids must never start together. Pure and static so the invariant
  /// is testable without a platform player.
  @visibleForTesting
  static List<String> sfxIdsForEvents(List<Map<String, Object?>> events) {
    final ids = <String>[];
    final seen = <String>{};
    for (final e in events) {
      final id = eventSfx[e['type']];
      if (id != null && seen.add(id)) ids.add(id);
    }
    return ids;
  }

  /// Immediate, non-choreographed SFX for a batch of sim events.
  void handleEvents(List<Map<String, Object?>> events) {
    for (final id in sfxIdsForEvents(events)) {
      playSfx(id);
    }
  }

  // -- App lifecycle (v0.3.1 F3) ----------------------------------------------

  /// Pause everything when the app leaves the foreground (Home/lock/call) —
  /// Android keeps audioplayers running otherwise, which is a Play-review
  /// killer. Best-effort like everything else here.
  void pauseAll() {
    try {
      _music?.pause();
      _ambience?.pause();
      _danger?.pause();
      for (final voices in _sfxPlayers.values) {
        for (final p in voices) {
          p.stop();
        }
      }
    } catch (_) {}
  }

  /// Resume the music + ambience beds on return to the foreground.
  void resumeAll() {
    try {
      _music?.resume();
      _ambience?.resume();
      _danger?.resume();
    } catch (_) {}
  }

  // -- Settings ---------------------------------------------------------------

  /// Push current settings onto live players (sliders move audio instantly).
  void applySettings() {
    try {
      _music?.setVolume(settings.effectiveMusic);
      _ambience?.setVolume(
        settings.effectiveMusic * (_ambienceRel ?? _ambienceLevel),
      );
    } catch (_) {}
  }
}
