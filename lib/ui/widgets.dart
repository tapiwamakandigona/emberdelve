// lib/ui/widgets.dart — shared UI atoms built to the design system.
import 'package:flutter/material.dart';
import '../audio/audio_service.dart';
import '../data/dice.dart';
import 'theme.dart';

/// Primary/secondary CTA. Primary is the scarce ember accent; one per screen,
/// placed in the bottom thumb-zone by the screens themselves.
class EmberButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;
  final IconData? icon;
  const EmberButton(this.label,
      {super.key,
      this.onTap,
      this.primary = false,
      this.danger = false,
      this.icon});

  @override
  State<EmberButton> createState() => _EmberButtonState();
}

class _EmberButtonState extends State<EmberButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final Color base = widget.danger
        ? EmberColors.danger
        : widget.primary
            ? EmberColors.ember
            : EmberColors.raised;
    final bg = !enabled
        ? EmberColors.surface
        : (_down ? Color.lerp(base, Colors.black, 0.2)! : base);
    final fg = !enabled
        ? EmberColors.textDisabled
        : (widget.primary || widget.danger)
            ? const Color(0xFF17110A)
            : EmberColors.textPrimary;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              AudioService.instance?.playSfx('ui_tap', volume: 0.8);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Space.xl, vertical: Space.l),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: widget.primary || widget.danger
                ? null
                : Border.all(color: EmberColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: Space.s),
              ],
              Text(widget.label,
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: fg,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled resource pip (embers / gold), value bright, label micro.
class ResourcePip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  final String? imageAsset; // painted currency icon; falls back to [icon]
  const ResourcePip(this.icon, this.color, this.value, this.label,
      {super.key, this.imageAsset});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (imageAsset != null)
        Image.asset(imageAsset!,
            width: 18, height: 18, filterQuality: FilterQuality.medium)
      else
        Icon(icon, size: 18, color: color),
      const SizedBox(width: Space.xs),
      Text('$value',
          style: EmberText.value.copyWith(fontSize: 18, color: color)),
      const SizedBox(width: Space.xs),
      Text(label, style: EmberText.micro),
    ]);
  }
}

/// Animated HP/other bar. Value bright over the label (UXPeak: values first).
class StatBar extends StatelessWidget {
  final int value;
  final int max;
  final int block;
  final Color color;
  final String label;
  const StatBar(
      {super.key,
      required this.value,
      required this.max,
      required this.color,
      required this.label,
      this.block = 0});
  @override
  Widget build(BuildContext context) {
    final frac = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('$value', style: EmberText.value.copyWith(fontSize: 20)),
        Text(' / $max', style: EmberText.bodyDim.copyWith(fontSize: 14)),
        const Spacer(),
        if (block > 0)
          Row(children: [
            const Icon(Icons.shield, size: 14, color: EmberColors.block),
            const SizedBox(width: 2),
            Text('$block',
                style: EmberText.value
                    .copyWith(fontSize: 16, color: EmberColors.block)),
          ]),
      ]),
      const SizedBox(height: Space.xs),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(children: [
          Container(height: 10, color: EmberColors.raised),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            widthFactor: frac,
            child: Container(height: 10, color: color),
          ),
        ]),
      ),
      const SizedBox(height: Space.xs),
      Text(label, style: EmberText.micro),
    ]);
  }
}

/// A die face card showing its rolled value (or size when unrolled).
class DieChip extends StatelessWidget {
  final String dieId;
  final int? value;
  final bool assigned;
  final bool selected;
  final bool maxed;
  final VoidCallback? onTap;
  const DieChip(this.dieId,
      {super.key,
      this.value,
      this.assigned = false,
      this.selected = false,
      this.maxed = false,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final def = dieDef(dieId);
    return GestureDetector(
      onTap: assigned ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 64,
        height: 76,
        decoration: BoxDecoration(
          color: assigned ? EmberColors.surface : EmberColors.raised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? EmberColors.ember
                : maxed
                    ? EmberColors.gold
                    : EmberColors.line,
            width: selected ? 2.5 : 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value != null ? '$value' : 'd${def.size}',
                style: EmberText.value.copyWith(
                    fontSize: 28,
                    color: assigned
                        ? EmberColors.textDisabled
                        : EmberColors.textPrimary)),
            const SizedBox(height: 2),
            Text('d${def.size}',
                style: EmberText.micro.copyWith(fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

/// Small titled card container (shop slots, event options, panels).
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(Space.l),
      this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? EmberColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EmberColors.line),
        ),
        child: child,
      );
}

void showFlash(BuildContext context, String msg) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Text(msg, style: EmberText.body),
    backgroundColor: EmberColors.raised,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(milliseconds: 1400),
  ));
}
