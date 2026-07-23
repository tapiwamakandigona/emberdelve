import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all bundled PNGs decode with the engine codec', () async {
    final files = Directory('assets/images')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList();
    final failures = <String>[];
    for (final f in files) {
      try {
        final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
        await codec.getNextFrame();
      } catch (e) {
        failures.add('${f.path}: $e');
      }
    }
    if (failures.isNotEmpty) {
      fail('${failures.length}/${files.length} failed:\n${failures.take(10).join('\n')}');
    }
  });
}
