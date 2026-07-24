// lib/audio/settings.dart — user audio settings, persisted with the same
// best-effort JSON-file pattern as MetaStore (lib/meta/meta.dart).
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AudioSettings {
  double musicVolume;
  double sfxVolume;
  bool musicMuted;
  bool sfxMuted;
  bool haptics; // v0.3.1 F12: vibration on key beats (roll/assign/hit/death)
  AudioSettings({
    this.musicVolume = 0.7,
    this.sfxVolume = 0.9,
    this.musicMuted = false,
    this.sfxMuted = false,
    this.haptics = true,
  });

  double get effectiveMusic => musicMuted ? 0.0 : musicVolume;
  double get effectiveSfx => sfxMuted ? 0.0 : sfxVolume;

  Map<String, Object?> toJson() => {
        'musicVolume': musicVolume,
        'sfxVolume': sfxVolume,
        'musicMuted': musicMuted,
        'sfxMuted': sfxMuted,
        'haptics': haptics,
      };

  // Volumes clamped on load: an out-of-range value in a hand-edited or
  // corrupt settings file would otherwise crash the Settings sliders
  // (Slider asserts value ∈ [min, max]).
  factory AudioSettings.fromJson(Map<String, dynamic> j) => AudioSettings(
        musicVolume:
            ((j['musicVolume'] as num?)?.toDouble() ?? 0.7).clamp(0.0, 1.0),
        sfxVolume:
            ((j['sfxVolume'] as num?)?.toDouble() ?? 0.9).clamp(0.0, 1.0),
        musicMuted: j['musicMuted'] as bool? ?? false,
        sfxMuted: j['sfxMuted'] as bool? ?? false,
        haptics: j['haptics'] as bool? ?? true,
      );
}

class SettingsStore {
  static const _fileName = 'emberdelve_settings.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<AudioSettings> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return AudioSettings();
      return AudioSettings.fromJson(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return AudioSettings();
    }
  }

  /// Same durability contract as MetaStore.save / the run autosave: the JSON
  /// snapshot is captured synchronously, writes are chained on a queue (a
  /// slider release + a mute tap fire back-to-back saves that must not
  /// interleave bytes in one file), and each write goes to a temp file that
  /// is renamed into place so a crash mid-write can never leave truncated
  /// JSON (which would silently reset the player's audio settings on load).
  static Future<void> _writeQueue = Future.value();
  static Future<void> save(AudioSettings s) {
    final snap = jsonEncode(s.toJson());
    _writeQueue = _writeQueue.then((_) async {
      try {
        final f = await _file();
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(snap, flush: true);
        await tmp.rename(f.path);
      } catch (_) {/* best-effort; never crash the game on save failure */}
    });
    return _writeQueue;
  }
}
