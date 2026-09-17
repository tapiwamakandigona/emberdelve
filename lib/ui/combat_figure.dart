// One clock, two painters: body and held tool share the solved wrist.
// Never rebuilds the combat stage on an animation tick.
import 'package:flutter/material.dart';

import 'build_identity.dart';
import 'combat_articulation.dart';
import 'combat_pose.dart';
import 'motion.dart';
import 'sprites.dart';
import 'weapons.dart';

class CombatFigure extends StatefulWidget {
  final CombatRig rig;
  final double height, charge;
  final WeaponPhase phase;
  final StrikePlan plan;
  final bool knock, showWounds;
  final Condition condition;
  final ColorFilter? dye;
  final RunBuildIdentity? identity;
  const CombatFigure({
    super.key,
    required this.rig,
    required this.height,
    required this.phase,
    required this.plan,
    required this.condition,
    required this.showWounds,
    this.knock = false,
    this.charge = 0,
    this.dye,
    this.identity,
  });

  @override
  State<CombatFigure> createState() => _CombatFigureState();
}

class _CombatFigureState extends State<CombatFigure>
    with TickerProviderStateMixin {
  late final _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  late final _move = AnimationController(vsync: this);
  late final ValueNotifier<CombatRigSample> _sample;
  late RigPose _from, _to;
  late double _angleFrom, _angleTo;
  Curve _curve = Curves.easeOutCubic;
  bool _swinging = false;

  RigBeat get _beat {
    if (widget.knock) return RigBeat.recoil;
    return switch (widget.phase) {
      WeaponPhase.idle => RigBeat.ready,
      WeaponPhase.raise => RigBeat.windup,
      WeaponPhase.swing => RigBeat.strike,
      WeaponPhase.guard => RigBeat.guard,
    };
  }

  double get _targetAngle => switch (widget.phase) {
    WeaponPhase.idle => weaponFor(widget.rig.id).idleAngle,
    // A maul is raised ABOVE the shoulder, not inverted down its back.
    WeaponPhase.raise =>
      widget.rig.id == 'warden'
          ? -0.28 - tierWeight(widget.plan.tier) * 0.38
          : -0.7 - tierWeight(widget.plan.tier) * 0.65,
    WeaponPhase.swing => widget.plan.swingAngle,
    WeaponPhase.guard => 0.12,
  };

  @override
  void initState() {
    super.initState();
    _from = _to = RigPose.at(widget.rig, _beat, widget.plan);
    _angleFrom = _angleTo = _targetAngle;
    _move.value = 1;
    _sample = ValueNotifier(_solve());
    _life.addListener(_tick);
    _move.addListener(_tick);
    Motion.instance.addListener(_motionChanged);
    _syncLife();
  }

  void _syncLife() {
    if (Motion.instance.reduced) {
      _life
        ..stop()
        ..value = 0;
    } else if (!_life.isAnimating) {
      _life.repeat();
    }
  }

  void _motionChanged() {
    if (!mounted) return;
    _syncLife();
    _tick();
  }

  CombatRigSample _solve() {
    final t = _curve.transform(_move.value);
    return CombatRigSample.solve(
      rig: widget.rig,
      pose: RigPose.lerp(_from, _to, t),
      condition: widget.condition,
      life: _life.value,
      weaponAngle: _angleFrom + (_angleTo - _angleFrom) * t,
      previousWeaponAngle: _angleFrom,
      smear: _swinging && _move.isAnimating ? widget.plan.smear : 0,
      reduced: Motion.instance.reduced,
      striking:
          widget.phase == WeaponPhase.raise ||
          widget.phase == WeaponPhase.swing,
    );
  }

  void _tick() => _sample.value = _solve();

  @override
  void didUpdateWidget(CombatFigure old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase ||
        old.knock != widget.knock ||
        old.rig != widget.rig) {
      _from = _sample.value.pose;
      _angleFrom = _sample.value.weaponAngle;
      _to = RigPose.at(widget.rig, _beat, widget.plan);
      _angleTo = _targetAngle;
      _swinging = widget.phase == WeaponPhase.swing;
      final ms = widget.knock
          ? 140
          : switch (widget.phase) {
              WeaponPhase.raise => widget.plan.windupMs,
              WeaponPhase.swing => widget.plan.travelMs,
              WeaponPhase.guard => 160,
              WeaponPhase.idle => widget.plan.recoverMs,
            };
      _curve = _swinging ? Curves.easeInCubic : Curves.easeOutCubic;
      _move
        ..duration = Duration(milliseconds: ms)
        ..forward(from: 0);
    }
    _tick();
  }

  @override
  void dispose() {
    Motion.instance.removeListener(_motionChanged);
    _life.dispose();
    _move.dispose();
    _sample.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.height * 32 / 40;
    return SizedBox(
      width: width,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SpriteView(
            widget.rig.id,
            key: ValueKey('hero-${widget.rig.id}'),
            height: widget.height,
            dye: widget.dye,
            condition: widget.condition,
            showWounds: widget.showWounds,
            articulation: _sample,
          ),
          // Same origin and scale as the sprite: no static metadata offset.
          Positioned(
            left: 0,
            top: 0,
            width: widget.height,
            height: widget.height,
            child: WeaponView(
              widget.rig.id,
              key: const ValueKey('combat-weapon'),
              height: widget.height,
              phase: widget.phase,
              plan: widget.plan,
              charge: widget.charge,
              identity: widget.identity,
              articulation: _sample,
            ),
          ),
          Positioned.fill(
            child: SpriteGripOverlay(
              widget.rig.id,
              articulation: _sample,
              dye: widget.dye,
            ),
          ),
        ],
      ),
    );
  }
}
