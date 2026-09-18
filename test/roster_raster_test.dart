// Whole-roster alpha connectivity. A mathematically coincident elbow is not
// enough: source-pixel body, head, grip and boots must remain one raster body.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:emberdelve/data/characters.dart';
import 'package:emberdelve/ui/combat_articulation.dart';
import 'package:emberdelve/ui/combat_pose.dart';
import 'package:emberdelve/ui/motion.dart';
import 'package:emberdelve/ui/sprites.dart';
import 'package:emberdelve/ui/weapons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _Raster {
  final int width, height;
  final Uint8List rgba;
  late final Int32List components = _label();
  _Raster(this.width, this.height, this.rgba);

  bool painted(int x, int y) =>
      x >= 0 && y >= 0 && x < width && y < height &&
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
        queue..clear()..add(start);
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

  int near(Offset point, double radius) {
    var distance = double.infinity, label = 0;
    for (var y = (point.dy - radius).floor();
        y <= (point.dy + radius).ceil(); y++) {
      for (var x = (point.dx - radius).floor();
          x <= (point.dx + radius).ceil(); x++) {
        if (!painted(x, y)) continue;
        final d = (Offset(x + 0.5, y + 0.5) - point).distance;
        if (d <= radius && d < distance) {
          distance = d;
          label = components[y * width + x];
        }
      }
    }
    return label;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => Motion.instance.reset());
  for (final id in charactersOrder) {
    testWidgets('$id raster anatomy remains connected in poses and transitions',
        (tester) async {
      await tester.runAsync(warmSpriteSheets);
      Motion.instance.update(setting: 'on');
      final rig = CombatRig.forId(id)!;
      final key = GlobalKey();
      final failures = <Map<String, Object?>>[];
      var frames = 0;
      for (final height in [72.0, 96.0, 104.0]) {
        for (final tier in [DieTier.low, DieTier.high]) {
          final plan = planStrike(familyForWeapon(weaponFor(id).id), tier);
          for (final health in [1.0, 0.2]) {
            for (final beat in RigBeat.values) {
              for (final fraction in [0.25, 0.6, 1.0]) {
                final pose = RigPose.lerp(
                  RigPose.at(rig, RigBeat.ready, plan),
                  RigPose.at(rig, beat, plan), fraction,
                );
                final sample = CombatRigSample.solve(
                  rig: rig, pose: pose, condition: Condition(health),
                  life: 0.3, weaponAngle: 0,
                );
                final notifier = ValueNotifier(sample);
                await tester.pumpWidget(Directionality(
                  textDirection: TextDirection.ltr,
                  child: Center(child: RepaintBoundary(
                    key: key,
                    child: SizedBox(width: 160, height: 160,
                      child: Center(child: SpriteView(
                        id, height: height, animate: false, showWounds: false,
                        articulation: notifier,
                      )),
                    ),
                  )),
                ));
                await tester.pump();
                final image = (await tester.runAsync(() async {
                  final boundary = key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
                  final img = await boundary.toImage(pixelRatio: 1);
                  final bytes = (await img.toByteData())!;
                  final raster = _Raster(img.width, img.height,
                      Uint8List.fromList(bytes.buffer.asUint8List()));
                  img.dispose();
                  return raster;
                }))!;
                final scale = height / 40;
                final origin = Offset((160 - height * 0.8) / 2, (160 - height) / 2);
                Offset world(Offset p) => origin + p * scale;
                final chest = sample.part(RigPart.torso)
                    .map(rig.hip.translate(0, -6));
                final root = image.near(world(chest), scale);
                final joints = {
                  'head': sample.part(RigPart.head).map(rig.neck.translate(0, -2)),
                  'shoulder': sample.shoulder,
                  'elbow': sample.elbow,
                  'wrist': sample.wrist,
                  'rear boot': sample.rearFoot,
                  'front boot': sample.frontFoot,
                  if (id == 'warden')
                    'shield': sample.part(RigPart.shield).map(const Offset(24, 18)),
                };
                if (root == 0) {
                  failures.add({'height': height, 'tier': tier.name, 'health': health,
                    'beat': beat.name, 'fraction': fraction, 'joint': 'torso',
                    'expected': 'painted', 'actual': root});
                }
                for (final joint in joints.entries) {
                  final actual = image.near(world(joint.value), scale);
                  if (actual == 0 || actual != root) {
                    failures.add({'height': height, 'tier': tier.name, 'health': health,
                      'beat': beat.name, 'fraction': fraction, 'joint': joint.key,
                      'expected': root, 'actual': actual});
                  }
                }
                frames++;
                await tester.pumpWidget(const SizedBox.shrink());
                notifier.dispose();
              }
            }
          }
        }
      }
      File('build/roster_raster/$id.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
          'character': id, 'rendered_bodies': frames, 'failures': failures,
          'device_fps': 'NOT MEASURED',
        }));
      expect(frames, 180);
      expect(failures.length, 0,
          reason: '$id native disconnected anatomy: ${failures.take(8).toList()}');
    });
  }
}
