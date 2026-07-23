// Shared building blocks: stat bars, badges, panels, event log text.
import 'package:flutter/material.dart';

import '../theme.dart';

/// Animated horizontal resource bar (HP etc). Tweens on value change.
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.value,
    required this.max,
    required this.color,
    this.height = 12,
  });

  final int value;
  final int max;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final frac = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(children: [
        Container(height: height, color: Ember.surfaceHigh),
        TweenAnimationBuilder<double>(
          tween: Tween(end: frac),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, f, _) => FractionallySizedBox(
            widthFactor: f,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.75), color],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Small icon+number badge (block, embers, ...).
class StatBadge extends StatelessWidget {
  const StatBadge({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
    this.label,
  });

  final IconData icon;
  final String value;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: EmberRadius.chip,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(
          label == null ? value : '$label $value',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ]),
    );
  }
}

/// Standard raised panel.
class EmberPanel extends StatelessWidget {
  const EmberPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Ember.surface,
        borderRadius: EmberRadius.card,
        border: Border.all(color: borderColor ?? Ember.line),
      ),
      child: child,
    );
  }
}

/// Player HP / block / embers / fights header shown on map & combat screens.
class RunHeader extends StatelessWidget {
  const RunHeader({super.key, required this.player, required this.run});

  final Map<String, dynamic> player;
  final Map run;

  @override
  Widget build(BuildContext context) {
    final hp = player['hp'] as int;
    final maxHp = player['max_hp'] as int;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: EmberPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          const Icon(Icons.favorite_rounded, color: Ember.hp, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$hp / $maxHp',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 4),
                StatBar(value: hp, max: maxHp, color: Ember.hp, height: 8),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatBadge(
            icon: Icons.local_fire_department_rounded,
            value: '${run['embers'] ?? 0}',
            color: Ember.primaryBright,
          ),
          const SizedBox(width: 8),
          StatBadge(
            icon: Icons.military_tech_rounded,
            value: '${run['fights_won'] ?? 0}',
            color: Ember.eliteGold,
          ),
        ]),
      ),
    );
  }
}

/// Human-readable one-liner for a sim event; null for events that need no
/// log line. Used by the combat log strip.
String? describeEvent(Map<String, dynamic> ev) {
  switch (ev['type']) {
    case 'damage_dealt':
      final blocked = ev['blocked'] as int? ?? 0;
      return blocked > 0
          ? 'You hit for ${ev['amount']} ($blocked blocked)'
          : 'You hit for ${ev['amount']}';
    case 'block_gained':
      return '+${ev['amount']} block (${ev['total_block']} total)';
    case 'enemy_attacked':
      final soaked = ev['blocked'] as int? ?? 0;
      return soaked > 0
          ? 'Enemy attacks ${ev['amount']} — you take ${ev['damage']} ($soaked blocked)'
          : 'Enemy attacks — you take ${ev['damage']}';
    case 'turn_started':
      return 'Turn ${ev['turn']}';
    case 'encounter_won':
      return 'Victory in ${ev['turns']} turns!';
    case 'encounter_lost':
      return 'Defeated after ${ev['turns']} turns…';
    case 'boss_defeated':
      return 'BOSS DOWN in ${ev['turns']} turns!';
    case 'rested':
      return 'Rested: +${ev['healed']} hp (${ev['hp']} now)';
    case 'reward_chosen':
      return 'Took ${ev['die']}';
    case 'invalid_command':
      return null; // sim guards; UI should not surface these
    default:
      return null;
  }
}
