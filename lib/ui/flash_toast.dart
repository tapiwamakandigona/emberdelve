// lib/ui/flash_toast.dart — the in-run toast (experimental C2-01).
//
// The toast used to be a stock floating SnackBar. It sat in the bottom
// zone, which is where every screen keeps its primary button (screens.dart
// header: "the primary action lives in the bottom zone on every screen").
// For 1.4 s it hid DELVE AGAIN after a death, LEAVE SHOP and ROLL, and it
// took the tap. A child tapping the toast got nothing.
//
// Now the toast is a pill anchored near the TOP, under the run's top bar,
// centred with side gutters that keep it off corner buttons (the enemy
// panel's "?" help). It is wrapped in IgnorePointer, so a tap that lands on
// it reaches whatever sits underneath. It fades in, holds, and fades out
// inside its own RepaintBoundary, so a toast frame repaints only the toast
// (quiet_shell_test). Reduced motion drops the small slide; the fade stays,
// because the toast carries information.
//
// TalkBack: the text is still a live region, so heals, forges, rerolls and
// invalid-move reasons are spoken the moment they appear.
import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

/// Top of the toast, measured from the top safe-area inset. Clears the
/// run's top bar (Space.m padding × 2 + a ~20 dp row + 1 dp border ≈ 45 dp)
/// and the title screen's icon row (48 dp icon buttons from y 16 → 64 dp)
/// with an 8 dp gap.
const double kFlashToastTop = 72.0;

/// Side gutter on each side. Keeps the pill clear of buttons that sit in the
/// top corners of a screen (enemy panel "?", map/settings icons).
const double kFlashToastGutter = 64.0;

/// How long the toast is readable (full opacity), plus its fades.
const Duration kFlashToastHold = Duration(milliseconds: 1400);
const Duration kFlashToastFade = Duration(milliseconds: 180);

/// Key on the visible pill, for tests and review harnesses.
const Key kFlashToastKey = ValueKey('flash-toast');

class FlashToastHost extends StatefulWidget {
  final Widget child;
  const FlashToastHost({super.key, required this.child});

  /// The nearest host above [context], if any.
  static FlashToastHostState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<FlashToastHostState>();

  @override
  State<FlashToastHost> createState() => FlashToastHostState();
}

class FlashToastHostState extends State<FlashToastHost>
    with SingleTickerProviderStateMixin {
  static final Duration _total =
      kFlashToastFade + kFlashToastHold + kFlashToastFade;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: _total,
  )..addStatusListener(_onStatus);

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.0),
      weight: kFlashToastFade.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: ConstantTween(1.0),
      weight: kFlashToastHold.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0),
      weight: kFlashToastFade.inMilliseconds.toDouble(),
    ),
  ]).animate(_anim);

  String? _message;

  /// The message currently on screen (null when none).
  String? get message => _message;

  /// Show [message], replacing any toast already on screen.
  void show(String message) {
    setState(() => _message = message);
    _anim.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _message = null);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = _message;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (msg != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + kFlashToastTop,
            left: kFlashToastGutter,
            right: kFlashToastGutter,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, child) {
                      final o = _opacity.value;
                      final dy = Motion.instance.reduced ? 0.0 : (1 - o) * -6;
                      return Opacity(
                        opacity: o,
                        child: Transform.translate(
                          offset: Offset(0, dy),
                          child: child,
                        ),
                      );
                    },
                    child: _Pill(key: kFlashToastKey, message: msg),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String message;
  const _Pill({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: EmberColors.raised.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: EmberColors.ember.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.l,
          vertical: Space.s,
        ),
        child: Semantics(
          liveRegion: true,
          child: Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EmberText.body.copyWith(fontSize: 15, height: 1.3),
          ),
        ),
      ),
    );
  }
}
