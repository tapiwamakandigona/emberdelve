import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/ui/combat_articulation.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'redesigned idle grips are painted hand pixels, not transparent sockets',
    () async {
      final meta = await SpriteMeta.load();
      for (final id in ['kindler', 'warden']) {
        final def = meta.characters[id]!;
        final rig = CombatRig.forId(id)!;
        final codec = await ui.instantiateImageCodec(
          File(def.assetPath).readAsBytesSync(),
        );
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        final bytes = (await image.toByteData())!;
        final x = rig.wrist.dx.floor(), y = rig.wrist.dy.floor();
        expect(bytes.getUint8((y * image.width + x) * 4 + 3), 255, reason: id);
        expect(rig.partAt(x, y), RigPart.hand, reason: id);
        expect(def.hand!.dx, closeTo(rig.wrist.dx / 32, 1e-9));
        expect(def.hand!.dy, closeTo(rig.wrist.dy / 40, 1e-9));
        // There must be actual source pixels in every anatomical layer, not
        // a nominal rig whose whole body lives in a single catch-all part.
        final populated = <RigPart, int>{};
        for (var y = 0; y < 40; y++) {
          for (var x = 0; x < 32; x++) {
            if (bytes.getUint8((y * image.width + x) * 4 + 3) == 255) {
              populated.update(
                rig.partAt(x, y),
                (n) => n + 1,
                ifAbsent: () => 1,
              );
            }
          }
        }
        for (final part in [
          RigPart.torso,
          RigPart.head,
          RigPart.upperArm,
          RigPart.forearm,
          RigPart.hand,
          RigPart.rearLeg,
          RigPart.frontLeg,
          RigPart.rearFoot,
          RigPart.frontFoot,
          if (id == 'warden') RigPart.shield else RigPart.cape,
        ]) {
          expect(populated[part], greaterThanOrEqualTo(3), reason: '$id $part');
        }
        image.dispose();
      }
    },
  );

  test(
    'source redesign and hand metadata cover stable existing character IDs',
    () {
      final source =
          jsonDecode(
                File(
                  'tool/art/delvers-redesign-2026-09-18/source.json',
                ).readAsStringSync(),
              )
              as Map;
      final hands =
          jsonDecode(File('tool/art/hand_anchors.json').readAsStringSync())
              as Map;
      expect(source['characters'], ['kindler', 'warden']);
      expect(source['generated_source'], isTrue);
      expect(source['rows'], 2);
      expect(source['columns'], 4);
      expect(
        hands.keys.where((k) => !k.toString().startsWith('_')).toSet(),
        charactersOrder.toSet(),
      );
      expect(charactersOrder.length, 22);
      expect(characters['kindler']!.maxHp, 30);
      expect(characters['kindler']!.startDice, ['d6', 'd6', 'd6']);
      expect(characters['warden']!.maxHp, 32);
      expect(characters['warden']!.startRelic, 'iron_scale');
      expect(characters['warden']!.unlockEmbers, 120);
    },
  );
}
