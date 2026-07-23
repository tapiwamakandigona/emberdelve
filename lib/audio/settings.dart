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
  AudioSettings({
    this.musicVolume = 0.7,
    this.sfxVolume = 0.9,
    this.musicMuted = false,
    this.sfxMuted = false,
  });

  double get effectiveMusic => musicMuted ? 0.0 : musicVolume;
  double get effectiveSfx => sfxMuted ? 0.0 : sfxVolume;

  Map<String, Object?> toJson() => {
        'musicVolume': musicVolume,
        'sfxVolume': sfxVolume,
        'musicMuted': musicMuted,
        'sfxMuted': sfxMuted,
      };

  factory AudioSettings.fromJson(Map<String, dynamic> j) => AudioSettings(
        musicVolume: (j['musicVolume'] as num?)?.toDouble() ?? 0.7,
        sfxVolume: (j['sfxVolume'] as num?)?.toDouble() ?? 0.9,
        musicMuted: j['musicMuted'] as bool? ?? false,
        sfxMuted: j['sfxMuted'] as bool? ?? false,
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

  static Future<void> save(AudioSettings s) async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(s.toJson()));
    } catch (_) {/* best-effort; never crash the game on save failure */}
  }
}
