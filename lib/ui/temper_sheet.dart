// lib/ui/temper_sheet.dart — the v7 Face Forge: temper one face of one die,
// once per run, at a rest.
//
// Three decisions in one sheet, in the order a player thinks about them:
// which die, which face, which rune. Nothing is committed until the last
// button, and the sheet states plainly that this is the run's only temper.
import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../data/dice.dart' show dieDef;
import '../game/controller.dart';
import '../sim/run_dice.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showTemperSheet(BuildContext context, GameController c) {
  AudioService.instance?.playSfx('ui_tap');
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: EmberColors.bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => TemperSheet(c),
  );
}

class TemperSheet extends StatefulWidget {
  final GameController c;
  const TemperSheet(this.c, {super.key});

  @override
  State<TemperSheet> createState() => _TemperSheetState();
}

class _TemperSheetState extends State<TemperSheet> {
  int? _die; // 1-based pool index
  int? _face;
  String? _rune;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final run = c.state!['run'] as Map?;
    final pool = ((c.state!['player'] as Map)['dice'] as List).cast<String>();
    final die = _die;
    final resolved = die == null ? null : resolveRunDie(run, pool[die - 1]);
    final size = resolved?.def.size ?? 0;
    // v0.155.0 The Deep Mark: picking the same face and rune a die already
    // bears deepens the mark instead of re-writing it. The sheet says so
    // before the commit, and a mark that is already deep disables the button
    // (the sim would reject it; the sheet never offers a dead command).
    final wouldDeepen =
        resolved != null &&
        resolved.custom &&
        _face == resolved.temperedFace &&
        _rune == resolved.rune;
    final alreadyDeep = wouldDeepen && resolved.tier >= 2;
    final ready = die != null && _face != null && _rune != null && !alreadyDeep;

    // The three steps scroll; the header and the commit button never do, so
    // the sheet works on short phones and at large text scales (it overflowed
    // by 273px before this — caught by test/temper_ui_test.dart).
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Temper a face', style: EmberText.h2)),
                  IconButton(
                    key: const ValueKey('temper-close'),
                    icon: const Icon(Icons.close, color: EmberColors.textDim),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Mark one face of one die with a rune. Two tempers '
                        'a delve, and each lasts the whole run.',
                        style: EmberText.bodyDim,
                      ),
                      if (resolved != null && resolved.custom) ...[
                        const SizedBox(height: Space.s),
                        Text(
                          'This die bears '
                          '${runeTierName(resolved.rune, resolved.tier)} on '
                          '${resolved.temperedFace}. '
                          '${resolved.tier >= 2 ? 'That mark is already deep.' : 'The same face and rune deepens the mark: ${runeDeepBlurb(resolved.rune!)}'}',
                          key: const ValueKey('temper-deepen-hint'),
                          style: EmberText.bodyDim,
                        ),
                      ],
                      const SizedBox(height: Space.l),

                      const Text('1 · WHICH DIE', style: EmberText.micro),
                      const SizedBox(height: Space.s),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: pool.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: Space.s),
                          itemBuilder: (context, i) {
                            final selected = die == i + 1;
                            // v0.122.0 The Spoken Delve: the picker rows
                            // are pure paint to a screen reader — name each
                            // die, face, and rune, and say what is chosen.
                            return Semantics(
                              label:
                                  'Die ${i + 1}, ${dieDef(pool[i]).name}'
                                  '${selected ? ', chosen' : ''}',
                              button: true,
                              excludeSemantics: true,
                              child: GestureDetector(
                                key: ValueKey('temper-die-${i + 1}'),
                                onTap: () => setState(() {
                                  _die = i + 1;
                                  _face = null;
                                }),
                                child: Opacity(
                                  opacity: selected || die == null ? 1 : 0.45,
                                  child: SizedBox(
                                    width: 60,
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: DieChip(
                                        pool[i],
                                        run: run,
                                        skin: c.activeRunSkin,
                                        selected: selected,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: Space.l),

                      const Text('2 · WHICH FACE', style: EmberText.micro),
                      const SizedBox(height: Space.s),
                      if (die == null)
                        const Text('Pick a die first.', style: EmberText.bodyDim)
                      else
                        Wrap(
                          spacing: Space.s,
                          runSpacing: Space.s,
                          children: [
                            for (var f = 1; f <= size; f++)
                              _pill(
                                key: ValueKey('temper-face-$f'),
                                label: '$f',
                                selected: _face == f,
                                onTap: () => setState(() => _face = f),
                              ),
                          ],
                        ),
                      const SizedBox(height: Space.l),

                      const Text('3 · WHICH RUNE', style: EmberText.micro),
                      const SizedBox(height: Space.s),
                      for (final rune in [
                        'blade',
                        'aegis',
                        'surge',
                        'echo',
                        'mend',
                        'gilt',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.s),
                          child: _runeRow(rune),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.m),

              EmberButton(
                ready
                    ? (wouldDeepen
                          ? 'Deepen ${runeName(_rune)} on $_face'
                          : 'Temper ${runeName(_rune)} on $_face')
                    : (alreadyDeep
                          ? 'That mark is already deep'
                          : 'Choose a die, a face and a rune'),
                key: const ValueKey('temper-confirm'),
                primary: ready,
                icon: Icons.local_fire_department,
                // Disabled by a null callback (house pattern) until all three
                // choices exist, so the sheet can never emit a partial command.
                onTap: !ready
                    ? null
                    : () {
                        c.apply({
                          'type': 'temper_face',
                          'die': die,
                          'face': _face,
                          'rune': _rune,
                        });
                        Navigator.of(context).pop();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => Semantics(
    label: 'Face $label${selected ? ', chosen' : ''}',
    button: true,
    excludeSemantics: true,
    child: GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? EmberColors.ember : EmberColors.raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? EmberColors.ember : EmberColors.line,
          ),
        ),
        child: Text(
          label,
          style: EmberText.body.copyWith(
            color: selected ? const Color(0xFF17110A) : EmberColors.textPrimary,
          ),
        ),
      ),
    ),
  );

  Widget _runeRow(String rune) {
    final selected = _rune == rune;
    return Semantics(
      label:
          '${runeName(rune)}${selected ? ', chosen' : ''}. '
          '${runeBlurb(rune)}',
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('temper-rune-$rune'),
        onTap: () => setState(() => _rune = rune),
        child: Container(
          padding: const EdgeInsets.all(Space.m),
          decoration: BoxDecoration(
            color: selected ? EmberColors.raised : EmberColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? EmberColors.ember : EmberColors.line,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? EmberColors.ember : EmberColors.textDim,
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(runeName(rune), style: EmberText.body),
                    const SizedBox(height: 2),
                    Text(runeBlurb(rune), style: EmberText.bodyDim),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
