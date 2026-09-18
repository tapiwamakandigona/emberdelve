// Whole-roster source contracts. Art quality is reviewed in actual renders;
// these checks reject missing/recoloured/ungrippable/placeholder production art.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/ui/combat_articulation.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('twenty new sources plus the retained pair exactly cover the roster', () {
    final all = <String>['kindler', 'warden'];
    for (var i = 1; i <= 5; i++) {
      final directory = 'tool/art/roster-redesign-2026-09-18/group-$i';
      final source = jsonDecode(File('$directory/source.json').readAsStringSync())
          as Map;
      expect(source['generated_source'], isTrue);
      expect(source['columns'], 4);
      expect(source['rows'], 4);
      expect((source['source_prompt'] as String).length, greaterThan(500));
      expect((source['source_sha256'] as String).length, 64);
      expect(File('$directory/source.png').existsSync(), isTrue);
      all.addAll((source['characters'] as List).cast<String>());
    }
    expect(all, orderedEquals(charactersOrder));
    expect(all.toSet().length, 22);
    final authored = jsonDecode(
      File('tool/art/roster_rigs.json').readAsStringSync(),
    ) as Map;
    expect(
      authored.keys.where((k) => !k.toString().startsWith('_')).toSet(),
      charactersOrder.skip(2).toSet(),
    );
  });

  for (final id in charactersOrder) {
    test('$id has a painted matching wrist and real anatomical cutouts', () async {
      final meta = await SpriteMeta.load();
      final def = meta.characters[id]!;
      final rig = CombatRig.forId(id)!;
      final codec = await ui.instantiateImageCodec(
        File(def.assetPath).readAsBytesSync(),
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      final bytes = (await image.toByteData())!;
      int alpha(int x, int y) => bytes.getUint8((y * image.width + x) * 4 + 3);
      final x = rig.wrist.dx.floor(), y = rig.wrist.dy.floor();
      expect(alpha(x, y), 255, reason: '$id primary grip is a source pixel');
      expect(rig.partAt(x, y), RigPart.hand);
      expect(def.hand!.dx, closeTo(rig.wrist.dx / 32, 1e-9));
      expect(def.hand!.dy, closeTo(rig.wrist.dy / 40, 1e-9));
      final counts = <RigPart, int>{};
      for (var y = 0; y < 40; y++) {
        for (var x = 0; x < 32; x++) {
          if (alpha(x, y) != 255) continue;
          counts.update(rig.partAt(x, y), (n) => n + 1, ifAbsent: () => 1);
          expect(
            RigPart.values.any((p) => rig.includesPixel(p, x, y)),
            isTrue,
            reason: '$id source pixel $x,$y must not disappear',
          );
        }
      }
      for (final part in [
        RigPart.head, RigPart.torso, RigPart.upperArm, RigPart.forearm,
        RigPart.hand, RigPart.rearLeg, RigPart.frontLeg,
        RigPart.rearFoot, RigPart.frontFoot,
      ]) {
        expect(counts[part] ?? 0, greaterThanOrEqualTo(3), reason: '$id $part');
      }
      image.dispose();
    });
  }
}
