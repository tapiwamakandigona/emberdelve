import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all 22 stable delver IDs have native, original animated models',
    () async {
      final raw =
          jsonDecode(File('assets/images/sprite_meta.json').readAsStringSync())
              as Map<String, dynamic>;
      final meta = SpriteMeta.parse(jsonEncode(raw));
      expect(meta.characters.keys.toSet(), charactersOrder.toSet());
      expect(meta.characters.length, 22);
      var pngBytes = 0;
      var decodedBytes = 0;
      final masks = <String>{};
      for (final id in charactersOrder) {
        final def = meta.characters[id]!;
        expect(def.frameW, 32);
        expect(def.frameH, 40);
        expect(def.rows['idle']!.frames, 2);
        expect(def.rows['run']!.frames, 2);
        expect(def.rows['hit']!.frames, 1);
        final file = File(def.assetPath);
        pngBytes += file.lengthSync();
        final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
        final frame = await codec.getNextFrame();
        codec.dispose();
        final image = frame.image;
        expect(image.width, 64);
        expect(image.height, 120);
        decodedBytes += image.width * image.height * 4;
        final rgba = (await image.toByteData())!;
        final mask = <int>[];
        for (var y = 0; y < 40; y++) {
          for (var x = 0; x < 32; x++) {
            final alpha = rgba.getUint8((y * image.width + x) * 4 + 3);
            expect(alpha, anyOf(0, 255));
            mask.add(alpha);
            if (x < 2 || x >= 30 || y < 2 || y >= 38) {
              expect(alpha, 0, reason: '$id clips its frame margin');
            }
          }
        }
        expect(
          masks.add(base64Encode(mask)),
          isTrue,
          reason: '$id is a recolour',
        );
        image.dispose();
      }
      expect(pngBytes, lessThanOrEqualTo(100 * 1024));
      expect(decodedBytes, lessThanOrEqualTo(1.5 * 1024 * 1024));
    },
  );
}
