// Audio asset consistency: every id the AudioService can play maps to a real
// bundled file, and no orphan .ogg ships in the APK (dead dice-era sounds
// were removed in the platformer audio pass — keep it that way).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/audio/audio_service.dart';

void main() {
  test('every sfx/music id points to an existing asset file', () {
    final missing = <String>[];
    for (final entry in {...AudioService.sfxPaths, ...AudioService.musicPaths}
        .entries) {
      if (!File('assets/${entry.value}').existsSync()) {
        missing.add('${entry.key} -> assets/${entry.value}');
      }
    }
    expect(missing, isEmpty,
        reason: 'AudioService ids without a bundled file: $missing');
  });

  test('no orphan audio files ship in the bundle', () {
    final referenced = {
      ...AudioService.sfxPaths.values,
      ...AudioService.musicPaths.values,
    }.map((p) => 'assets/$p').toSet();
    final orphans = Directory('assets/audio')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll('\\', '/'))
        .where((p) => p.endsWith('.ogg') && !referenced.contains(p))
        .toList();
    expect(orphans, isEmpty,
        reason: 'audio files bundled but unreachable by AudioService: '
            '$orphans');
  });
}
