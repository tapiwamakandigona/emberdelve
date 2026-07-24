// lib/ui/screens/reward_screen.dart — part of screens.dart (see library header there).
//
// The reward moment is the variable-ratio payoff of every fight, so it gets
// a ceremony (visuals.md #4 "reward flip"): offers present as physical cards
// that flip face-up one after another, then the player picks one. Honesty
// rules hold — the map telegraphed the best offer before the fight, every
// card auto-flips (no peek-gamble), and RECOMMENDED still marks the biggest
// die. Ceremony, not manipulation (docs/spec.md §Ethics).
part of '../screens.dart';

class RewardScreen extends StatefulWidget {
  final GameController c;
  const RewardScreen(this.c, {super.key});
  @override
  State<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    // Stale-frame guard (same as Shop/Event): offers is null for one frame
    // right after choose_reward while the phase cross-fade still shows this
    // screen — without the guard that frame throws a null cast.
    final offers = (c.state?['offers'] as List?)?.cast<String>();
    if (offers == null) return const SizedBox.shrink();
    var recIdx = 0, recSize = -1;
    for (var i = 0; i < offers.length; i++) {
      if (dieDef(offers[i]).size > recSize) {
        recSize = dieDef(offers[i]).size;
        recIdx = i;
      }
    }
    return Column(
      children: [
        _TopBar(c),
        const SizedBox(height: Space.l),
        Text('Choose a die', style: EmberText.h1),
        const SizedBox(height: Space.xs),
        Text(
          'It joins your pool for the rest of the run.',
          style: EmberText.bodyDim,
        ),
        // The cards: sized by the available box so 2–3 offers fit any phone
        // (overflow probes run down to 320×568 at 1.3x text).
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (context, box) {
                final n = offers.length;
                final cardW = ((box.maxWidth - Space.l * 2) - Space.m * (n - 1))
                        .clamp(0.0, double.infinity) /
                    n;
                final w = cardW.clamp(88.0, 150.0);
                final h = (w * 1.5).clamp(120.0, box.maxHeight - Space.m * 2);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                        for (var i = 0; i < n; i++) ...[
                          if (i > 0) const SizedBox(width: Space.m),
                          _FlipCard(
                            key: ValueKey('reward-${offers[i]}-$i'),
                            dieId: offers[i],
                            recommended: i == recIdx,
                            width: w,
                            height: h,
                            // Staggered reveal reads left-to-right.
                            flipDelayMs: 220 + i * 240,
                            onFlip: () {
                              c.audio?.playSfx('event_page', volume: 0.6);
                              Haptics.light();
                            },
                            onPick: () =>
                                c.apply({'type': 'choose_reward', 'index': i + 1}),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.l),
              child: SizedBox(
                width: double.infinity,
                child: EmberButton(
                  'Skip',
                  onTap: () => c.apply({'type': 'choose_reward', 'index': 0}),
                ),
              ),
            ),
          ],
        );
      }
    }

    /// One reward card: starts face-down (ember card back), flips face-up after
    /// [flipDelayMs] with a 3D turn, then becomes tappable to pick.
    class _FlipCard extends StatefulWidget {
      final String dieId;
      final bool recommended;
      final double width;
      final double height;
      final int flipDelayMs;
      final VoidCallback onFlip;
      final VoidCallback onPick;
      const _FlipCard({
        super.key,
        required this.dieId,
        required this.recommended,
        required this.width,
        required this.height,
        required this.flipDelayMs,
        required this.onFlip,
        required this.onPick,
      });

      @override
      State<_FlipCard> createState() => _FlipCardState();
    }

    class _FlipCardState extends State<_FlipCard>
        with SingleTickerProviderStateMixin {
      late final AnimationController _t = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 440),
      );
      Timer? _delay;
      bool _picked = false;

      @override
      void initState() {
        super.initState();
        _delay = Timer(Duration(milliseconds: widget.flipDelayMs), () {
          if (!mounted) return;
          widget.onFlip();
          _t.forward();
        });
      }

      @override
      void dispose() {
        _delay?.cancel();
        _t.dispose();
        super.dispose();
      }

      @override
      Widget build(BuildContext context) {
        return AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final v = Curves.easeInOutCubic.transform(_t.value);
            // Face-down = half a turn away; the face swaps in at the apex so
            // the back is never mirrored.
            final angle = math.pi * (1.0 - v);
            final showFace = v > 0.5;
            final flipped = _t.isCompleted;
            return GestureDetector(
              onTap: flipped && !_picked
                  ? () {
                      _picked = true; // double-tap guard until the phase moves on
                      Haptics.light();
                      widget.onPick();
                    }
                  : null,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012) // perspective
                  ..rotateY(angle),
                child: showFace
                    ? _face(context)
                    // The back is built pre-mirrored so it reads correctly
                    // through the first half of the turn.
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _back(),
                      ),
              ),
            );
          },
        );
      }

      /// Ember card back: charcoal panel, ember diamond, corner pips.
      Widget _back() {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EmberColors.line, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [EmberColors.raised, Color(0xFF17111F)],
            ),
          ),
          child: Center(
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: widget.width * 0.34,
                height: widget.width * 0.34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: EmberColors.ember, width: 2),
                  color: EmberColors.ember.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
        );
      }

      Widget _face(BuildContext context) {
        final def = dieDef(widget.dieId);
        return Container(
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.all(Space.s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.recommended ? EmberColors.ember : EmberColors.line,
              width: 2,
            ),
            color: widget.recommended ? EmberColors.raised : EmberColors.surface,
          ),
          // FittedBox over a width-pinned column: text wraps at card width and
          // the whole face scales down on short screens instead of overflowing
          // (probes go to 320×568 at 1.3x text).
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: widget.width - Space.s * 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              if (widget.recommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.s,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(bottom: Space.s),
                  decoration: BoxDecoration(
                    color: EmberColors.ember,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'RECOMMENDED',
                      maxLines: 1,
                      style: EmberText.micro.copyWith(
                        color: const Color(0xFF17110A),
                      ),
                    ),
                  ),
                ),
              DieChip(widget.dieId),
              const SizedBox(height: Space.s),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  def.name,
                  maxLines: 1,
                  style: EmberText.label.copyWith(
                    color: EmberColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                _dieDesc(def),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: EmberText.micro,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _dieDesc(DieDef d) {
  final parts = <String>['d${d.size}'];
  final m = d.mods;
  if (m['attack_bonus'] != null) parts.add('+${m['attack_bonus']} attack');
  if (m['block_bonus'] != null) parts.add('+${m['block_bonus']} block');
  if (m['min_value'] != null) parts.add('min ${m['min_value']}');
  if (m['on_max_bonus'] != null) parts.add('+${m['on_max_bonus']} on max');
  if (m['attack_only'] == true) parts.add('attack only');
  if (m['block_only'] == true) parts.add('block only');
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Rest + forge
// ---------------------------------------------------------------------------
