// Combat-only, native-pixel articulation. No simulation or save imports.
// The same sampled joints drive both the source-art limbs and weapon grip.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'combat_pose.dart';

enum RigBeat { ready, windup, strike, guard, recoil }

enum RigPart {
  cape,
  rearLeg,
  frontLeg,
  torso,
  head,
  upperArm,
  forearm,
  shield,
  rearFoot,
  frontFoot,
  hand,
}

/// Two-dimensional affine transform in the original 32 x 40 pixel cell.
class RigTransform {
  final double a, b, c, d, x, y;
  RigTransform(this.a, this.b, this.c, this.d, this.x, this.y);
  static final identity = RigTransform(1, 0, 0, 1, 0, 0);

  Offset map(Offset p) =>
      Offset(a * p.dx + c * p.dy + x, b * p.dx + d * p.dy + y);

  factory RigTransform.pivot(Offset source, Offset target, double angle) {
    final co = math.cos(angle), si = math.sin(angle);
    return RigTransform(
      co,
      si,
      -si,
      co,
      target.dx - co * source.dx + si * source.dy,
      target.dy - si * source.dx - co * source.dy,
    );
  }

  /// Maps BOTH ends of a limb to the sampled joints. Width is unchanged;
  /// only the length axis stretches, within the rig's bounded reach.
  factory RigTransform.bone(Offset from, Offset to, Offset start, Offset end) {
    final s = to - from, t = end - start;
    final sl = s.distance, tl = t.distance;
    final u = s / sl, v = t / tl;
    final k = tl / sl;
    final a = k * v.dx * u.dx + v.dy * u.dy;
    final b = k * v.dy * u.dx - v.dx * u.dy;
    final c = k * v.dx * u.dy - v.dy * u.dx;
    final d = k * v.dy * u.dy + v.dx * u.dx;
    return RigTransform(
      a,
      b,
      c,
      d,
      start.dx - a * from.dx - c * from.dy,
      start.dy - b * from.dx - d * from.dy,
    );
  }

  late final Float64List matrix = Float64List.fromList([
    a,
    b,
    0,
    0,
    c,
    d,
    0,
    0,
    0,
    0,
    1,
    0,
    x,
    y,
    0,
    1,
  ]);
}

class CombatRig {
  final String id;
  final Offset hip, neck, shoulder, elbow, wrist, rearFoot, frontFoot;
  const CombatRig({
    required this.id,
    required this.hip,
    required this.neck,
    required this.shoulder,
    required this.elbow,
    required this.wrist,
    required this.rearFoot,
    required this.frontFoot,
  });

  static const kindler = CombatRig(
    id: 'kindler',
    hip: Offset(16, 27),
    neck: Offset(17, 10),
    shoulder: Offset(17.5, 14.5),
    elbow: Offset(19.5, 18.5),
    wrist: Offset(24.5, 17.5),
    rearFoot: Offset(10.5, 37.5),
    frontFoot: Offset(21.5, 37.5),
  );
  static const warden = CombatRig(
    id: 'warden',
    hip: Offset(15, 25),
    neck: Offset(16, 8),
    shoulder: Offset(10, 11),
    elbow: Offset(8.5, 15.5),
    wrist: Offset(10.5, 18.5),
    rearFoot: Offset(8.5, 37.5),
    frontFoot: Offset(20.5, 37.5),
  );
  static CombatRig? forId(String id) => switch (id) {
    'kindler' => kindler,
    'warden' => warden,
    _ => null,
  };

  /// Partition the shipped first idle cell, not bounding-box copies of
  /// the entire sprite. A pixel belongs to one anatomical layer only.
  RigPart partAt(int x, int y) {
    if (id == 'kindler') {
      if (y >= 35) return x < 14 ? RigPart.rearFoot : RigPart.frontFoot;
      if (x >= 24 && y >= 16 && y <= 19) return RigPart.hand;
      if (x >= 20 && y >= 16 && y <= 20) return RigPart.forearm;
      if (x >= 16 && x <= 20 && y >= 14 && y <= 19) return RigPart.upperArm;
      if (y < 10) return RigPart.head;
      if (y >= 28 && x >= 8 && x < 15) return RigPart.rearLeg;
      if (y >= 28 && x >= 15) return RigPart.frontLeg;
      if (x < 10 && y < 18) return RigPart.cape;
      return RigPart.torso;
    }
    if (x >= 21 && y >= 9 && y <= 30) return RigPart.shield;
    if (y >= 35) return x < 14 ? RigPart.rearFoot : RigPart.frontFoot;
    if (x >= 9 && x <= 12 && y >= 17 && y <= 19) return RigPart.hand;
    if (x < 13 && y >= 15 && y < 20) return RigPart.forearm;
    if (x < 13 && y >= 7 && y < 15) return RigPart.upperArm;
    if (x >= 12 && y < 8) return RigPart.head;
    if (y >= 28) return x < 14 ? RigPart.rearLeg : RigPart.frontLeg;
    return RigPart.torso;
  }

  /// A cutout needs a small overlap at each hinge. Merely putting two
  /// exclusive pixel edges at the same mathematical joint opens a crack
  /// when those edges rotate or rasterize at a non-integer phone scale.
  /// These caps copy the ORIGINAL pixels on both sides of the hinge; no
  /// flat-color limbs, stretched filler or new atlas allocation.
  bool includesPixel(RigPart part, int x, int y) {
    if (partAt(x, y) == part) return true;
    bool near(Offset center, double radius) {
      final dx = x + 0.5 - center.dx, dy = y + 0.5 - center.dy;
      return dx * dx + dy * dy <= radius * radius;
    }

    final atShoulder = near(shoulder, id == 'warden' ? 3.75 : 2.6);
    final atElbow = near(elbow, id == 'warden' ? 2.8 : 2.2);
    final atNeck = near(neck, 2.1);
    final atRearHip = near(hip.translate(-2, 0), 2.6);
    final atFrontHip = near(hip.translate(2, 0), 2.6);
    final atRearAnkle = near(rearFoot.translate(0, -2), 2.0);
    final atFrontAnkle = near(frontFoot.translate(0, -2), 2.0);
    final atShieldGrip = id == 'warden' && near(shieldGrip, 2.2);
    return switch (part) {
      RigPart.torso =>
        atShoulder || atNeck || atRearHip || atFrontHip || atShieldGrip,
      RigPart.head => atNeck,
      RigPart.upperArm => atShoulder || atElbow,
      RigPart.forearm => atElbow,
      RigPart.rearLeg => atRearHip || atRearAnkle,
      RigPart.frontLeg => atFrontHip || atFrontAnkle,
      RigPart.rearFoot => atRearAnkle,
      RigPart.frontFoot => atFrontAnkle,
      RigPart.shield => atShieldGrip,
      RigPart.cape || RigPart.hand => false,
    };
  }

  static const shieldGrip = Offset(21, 16);

  // Redesigned models have an empty primary grip, so no destructive
  // equipment masks or invented underpaint are needed.
}

/// Authored key pose, interpolated before solving the actual joints.
class RigPose {
  final Offset hips, handFromShoulder;
  final double chest, head, shield, spread, cape;
  const RigPose({
    this.hips = Offset.zero,
    required this.handFromShoulder,
    this.chest = 0,
    this.head = 0,
    this.shield = 0,
    this.spread = 0,
    this.cape = 0,
  });

  static RigPose at(CombatRig rig, RigBeat beat, StrikePlan plan) {
    final w = tierWeight(plan.tier);
    final heavy = rig.id == 'warden';
    switch (beat) {
      case RigBeat.ready:
        return RigPose(
          handFromShoulder: heavy
              ? const Offset(3.5, 4)
              : rig.wrist - rig.shoulder,
        );
      case RigBeat.windup:
        return heavy
            ? RigPose(
                hips: Offset(-0.9 * w, 1.7 * w),
                handFromShoulder: Offset(-2.0, -3.4 - 2.2 * w),
                chest: 0.08 + 0.12 * w,
                head: -0.16 * w,
                shield: 0.04,
                spread: 0.7 * w,
              )
            : RigPose(
                hips: Offset(-1.1 * w, 0.8 * w),
                handFromShoulder: Offset(-2.4 - 1.0 * w, -1.5 - 1.5 * w),
                chest: 0.06 + 0.10 * w,
                head: -0.11 * w,
                cape: 0.06 * w,
                spread: 0.5 * w,
              );
      case RigBeat.strike:
        return heavy
            ? RigPose(
                hips: Offset(0.8 * w, 1.4 + 0.9 * w),
                handFromShoulder: Offset(5.4 + 0.8 * w, 3.4 + 0.7 * w),
                chest: -0.07 - 0.10 * w,
                head: 0.08 * w,
                shield: -0.07,
                spread: 0.8 + 0.8 * w,
              )
            : RigPose(
                hips: Offset(1.0 * w, -0.4 * w),
                handFromShoulder: Offset(4.2 + 0.8 * w, 1.2 + 0.8 * w),
                chest: -0.08 - 0.12 * w,
                head: 0.13 * w,
                cape: -0.13 * w,
                spread: 0.9 + 1.1 * w,
              );
      case RigBeat.guard:
        return RigPose(
          hips: Offset(heavy ? -0.7 : -0.4, heavy ? 1.6 : 0.8),
          handFromShoulder: heavy
              ? const Offset(2.5, 5)
              : const Offset(3.2, 0.6),
          chest: 0.04,
          head: -0.04,
          shield: heavy ? -0.18 : 0,
          spread: heavy ? 1.3 : 0.6,
        );
      case RigBeat.recoil:
        return RigPose(
          hips: const Offset(-0.9, 1),
          handFromShoulder: heavy
              ? const Offset(0.5, 5.5)
              : const Offset(2.3, 2.5),
          chest: 0.15,
          head: 0.1,
          shield: 0.07,
          spread: 0.6,
        );
    }
  }

  static RigPose lerp(RigPose a, RigPose b, double t) {
    double mix(double a, double b) => a + (b - a) * t;
    return RigPose(
      hips: Offset.lerp(a.hips, b.hips, t)!,
      handFromShoulder: Offset.lerp(a.handFromShoulder, b.handFromShoulder, t)!,
      chest: mix(a.chest, b.chest),
      head: mix(a.head, b.head),
      shield: mix(a.shield, b.shield),
      spread: mix(a.spread, b.spread),
      cape: mix(a.cape, b.cape),
    );
  }
}

/// One frame's solution, cached by the shared motion driver. All coordinates
/// stay native until the two painters apply the same height / 40 scale.
class CombatRigSample {
  final CombatRig rig;
  final RigPose pose;
  final List<RigTransform> parts;
  final Offset shoulder, elbow, wrist, rearFoot, frontFoot;
  final double weaponAngle, previousWeaponAngle, smear, sparkTime;

  CombatRigSample._({
    required this.rig,
    required this.pose,
    required this.parts,
    required this.shoulder,
    required this.elbow,
    required this.wrist,
    required this.rearFoot,
    required this.frontFoot,
    required this.weaponAngle,
    required this.previousWeaponAngle,
    required this.smear,
    required this.sparkTime,
  });

  RigTransform part(RigPart p) => parts[p.index];
  Offset weaponGrip(double height) => wrist * (height / 40);

  static CombatRigSample solve({
    required CombatRig rig,
    required RigPose pose,
    required Condition condition,
    required double life,
    required double weaponAngle,
    double previousWeaponAngle = 0,
    double smear = 0,
    bool reduced = false,
    bool striking = false,
  }) {
    final phase = life * math.pi * 2;
    final breath = reduced
        ? 0.0
        : math.sin(phase * (2 * condition.breathRate).round());
    final heave = breath * 0.32 * condition.breathAmp * (striking ? 0.2 : 1.0);
    final jitter = reduced
        ? 0.0
        : math.sin(phase * 41) * condition.tremor * 0.28;
    final hips = rig.hip + pose.hips + Offset(0, condition.hurt * 0.5);
    // Positive native rotation leans left; fatigue inclines the chest right.
    final chestAngle = pose.chest - condition.slump;
    final torso = RigTransform.pivot(
      rig.hip,
      hips + Offset(jitter, heave),
      chestAngle,
    );
    final shoulder = torso.map(rig.shoulder);
    final wanted = shoulder + pose.handFromShoulder;
    final l1 = (rig.elbow - rig.shoulder).distance;
    final l2 = (rig.wrist - rig.elbow).distance;
    final delta = wanted - shoulder;
    final distance = delta.distance.clamp(
      (l1 - l2).abs() + 0.05,
      l1 + l2 - 0.05,
    );
    final direction = math.atan2(delta.dy, delta.dx);
    final wrist =
        shoulder + Offset(math.cos(direction), math.sin(direction)) * distance;
    final inner = math.acos(
      ((l1 * l1 + distance * distance - l2 * l2) / (2 * l1 * distance)).clamp(
        -1.0,
        1.0,
      ),
    );
    final elbow =
        shoulder +
        Offset(math.cos(direction + inner), math.sin(direction + inner)) * l1;
    final rearFoot = rig.rearFoot.translate(-pose.spread, 0);
    final frontFoot = rig.frontFoot.translate(pose.spread, 0);
    final transforms = List<RigTransform>.filled(
      RigPart.values.length,
      RigTransform.identity,
    );
    void put(RigPart p, RigTransform m) => transforms[p.index] = m;
    put(RigPart.torso, torso);
    put(
      RigPart.cape,
      RigTransform.pivot(rig.hip, hips, chestAngle * 0.35 + pose.cape),
    );
    put(
      RigPart.head,
      RigTransform.pivot(rig.neck, torso.map(rig.neck), chestAngle + pose.head),
    );
    for (final (part, sourceFoot, targetFoot, side) in [
      (RigPart.rearLeg, rig.rearFoot, rearFoot, -1.0),
      (RigPart.frontLeg, rig.frontFoot, frontFoot, 1.0),
    ]) {
      final from = rig.hip.translate(side * 2.0, 0);
      put(
        part,
        RigTransform.bone(
          from,
          sourceFoot.translate(0, -2),
          torso.map(from),
          targetFoot.translate(0, -2),
        ),
      );
    }
    put(RigPart.rearFoot, RigTransform.pivot(rig.rearFoot, rearFoot, 0));
    put(RigPart.frontFoot, RigTransform.pivot(rig.frontFoot, frontFoot, 0));
    put(
      RigPart.upperArm,
      RigTransform.bone(rig.shoulder, rig.elbow, shoulder, elbow),
    );
    put(RigPart.forearm, RigTransform.bone(rig.elbow, rig.wrist, elbow, wrist));
    put(RigPart.hand, transforms[RigPart.forearm.index]);
    // Attach at the off-hand grip, not the bottom-center of the plate.
    const shieldPivot = CombatRig.shieldGrip;
    put(
      RigPart.shield,
      RigTransform.pivot(
        shieldPivot,
        torso.map(shieldPivot),
        pose.shield + chestAngle * 0.35,
      ),
    );
    return CombatRigSample._(
      rig: rig,
      pose: pose,
      parts: transforms,
      shoulder: shoulder,
      elbow: elbow,
      wrist: wrist,
      rearFoot: rearFoot,
      frontFoot: frontFoot,
      weaponAngle: weaponAngle,
      previousWeaponAngle: previousWeaponAngle,
      smear: smear,
      sparkTime: reduced ? 0 : life,
    );
  }
}
