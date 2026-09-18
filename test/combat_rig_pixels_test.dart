// Raster continuity is separate from coincident mathematical bone ends.
// No reference golden to update: the actual painted anatomy must connect.
import 'dart:typed_data';

import 'package:emberdelve/ui/combat_articulation.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _Raster {
  final int width, height;
  final Uint8List rgba;
  late final Int32List components = _label();
  _Raster(this.width, this.height, this.rgba);

  bool painted(int x, int y) =>
      x >= 0 &&
      y >= 0 &&
      x < width &&
      y < height &&
      rgba[(y * width + x) * 4 + 3] >= 128;

  Int32List _label() {
    final labels = Int32List(width * height);
    var component = 0;
    final queue = <int>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final start = y * width + x;
        if (!painted(x, y) || labels[start] != 0) continue;
        labels[start] = ++component;
        queue
          ..clear()
          ..add(start);
        for (var i = 0; i < queue.length; i++) {
          final px = queue[i] % width, py = queue[i] ~/ width;
          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              final nx = px + dx, ny = py + dy;
              if (!painted(nx, ny)) continue;
              final next = ny * width + nx;
              if (labels[next] == 0) {
                labels[next] = component;
                queue.add(next);
              }
            }
          }
        }
      }
    }
    return labels;
  }

  int componentNear(Offset point, double radius) {
    var nearest = double.infinity, label = 0;
    for (
      var y = (point.dy - radius).floor();
      y <= (point.dy + radius).ceil();
      y++
    ) {
      for (
        var x = (point.dx - radius).floor();
        x <= (point.dx + radius).ceil();
        x++
      ) {
        if (!painted(x, y)) continue;
        final distance = (Offset(x + 0.5, y + 0.5) - point).distance;
        if (distance <= radius && distance < nearest) {
          nearest = distance;
          label = components[y * width + x];
        }
      }
    }
    return label;
  }
}

Future<_Raster> _raster(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData())!;
      final raster = _Raster(
        image.width,
        image.height,
        Uint8List.fromList(bytes.buffer.asUint8List()),
      );
      image.dispose();
      return raster;
    }))!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => Motion.instance.update(setting: 'system', systemFlag: false));

  for (final rig in [CombatRig.kindler, CombatRig.warden]) {
    testWidgets('${rig.id}: rasterized head, arm and boots stay on the body', (
      tester,
    ) async {
      await tester.runAsync(warmSpriteSheets);
      Motion.instance.update(setting: 'on');
      final key = GlobalKey();
      for (final height in [72.0, 96.0, 104.0]) {
        for (final tier in [DieTier.low, DieTier.high]) {
          final plan = planStrike(
            rig.id == 'warden' ? StrikeFamily.crush : StrikeFamily.cut,
            tier,
          );
          for (final vitality in [1.0, 0.2]) {
            for (final beat in RigBeat.values) {
              final sample = CombatRigSample.solve(
                rig: rig,
                pose: RigPose.at(rig, beat, plan),
                condition: Condition(vitality),
                life: 0.3,
                weaponAngle: 0,
              );
              final notifier = ValueNotifier(sample);
              await tester.pumpWidget(
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Center(
                    child: RepaintBoundary(
                      key: key,
                      child: SizedBox(
                        width: 180,
                        height: 180,
                        child: Center(
                          child: SpriteView(
                            rig.id,
                            height: height,
                            animate: false,
                            showWounds: false,
                            articulation: notifier,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              final image = await _raster(tester, key);
              final scale = height / 40;
              final origin = Offset(
                (180 - height * 0.8) / 2,
                (180 - height) / 2,
              );
              Offset world(Offset p) => origin + p * scale;
              final chest = sample
                  .part(RigPart.torso)
                  .map(rig.hip.translate(0, -6));
              final root = image.componentNear(world(chest), scale);
              final scenario = '${rig.id} $height $tier $vitality $beat';
              expect(root, isNot(0), reason: '$scenario torso is painted');
              for (final joint in {
                'head': sample
                    .part(RigPart.head)
                    .map(rig.neck.translate(0, -2)),
                'shoulder': sample.shoulder,
                'elbow': sample.elbow,
                'wrist': sample.wrist,
                'rear boot': sample.rearFoot,
                'front boot': sample.frontFoot,
                if (rig.id == 'warden')
                  'shield': sample
                      .part(RigPart.shield)
                      .map(const Offset(24, 18)),
              }.entries) {
                expect(
                  image.componentNear(world(joint.value), scale),
                  root,
                  reason: '$scenario ${joint.key} must connect to the torso',
                );
              }
              await tester.pumpWidget(const SizedBox.shrink());
              notifier.dispose();
            }
          }
        }
      }
    });
  }
}
