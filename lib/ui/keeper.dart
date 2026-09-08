// Keepers of the Flame: one quiet, personal thank-you. No new animation,
// network or automatic modal. A restored run never visits this title widget.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../meta/keeper.dart';
import 'theme.dart';
import 'widgets.dart';

class KeeperCrest extends StatelessWidget {
  const KeeperCrest({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Keeper of the Flame supporter crest',
    image: true,
    child: const ExcludeSemantics(
      child: SizedBox(
        width: 28,
        height: 32,
        child: CustomPaint(painter: _CrestPainter()),
      ),
    ),
  );
}

class _CrestPainter extends CustomPainter {
  const _CrestPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 28, size.height / 32);
    final shield = Path()
      ..moveTo(3, 3)
      ..lineTo(25, 3)
      ..lineTo(25, 17)
      ..quadraticBezierTo(24, 25, 14, 30)
      ..quadraticBezierTo(4, 25, 3, 17)
      ..close();
    canvas.drawPath(shield, Paint()..color = EmberColors.raised);
    canvas.drawPath(
      shield,
      Paint()
        ..color = EmberColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final flame = Path()
      ..moveTo(14, 6)
      ..cubicTo(16, 12, 22, 13, 20, 19)
      ..cubicTo(18, 26, 7, 24, 8, 17)
      ..cubicTo(8, 13, 12, 12, 14, 6)
      ..close();
    canvas.drawPath(flame, Paint()..color = EmberColors.gold);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CrestPainter oldDelegate) => false;
}

const _normalSubtitle = Text(
  'A dice-builder delve into the dark',
  style: EmberText.bodyDim,
  textAlign: TextAlign.center,
);

class KeeperTitle extends StatefulWidget {
  const KeeperTitle({super.key});

  @override
  State<KeeperTitle> createState() => _KeeperTitleState();
}

class _KeeperTitleState extends State<KeeperTitle> {
  bool _inviting = false;
  bool _scheduled = false;
  bool _saveFailed = false;

  Future<void> _edit(KeeperService service) async {
    await showKeeperEditor(context, service, firstTime: true);
    if (mounted) setState(() => _inviting = false);
  }

  @override
  Widget build(BuildContext context) {
    final service = KeeperService.instance;
    if (service == null) return _normalSubtitle;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        if (!service.loaded || !service.entitled) return _normalSubtitle;
        if (service.needsInvitation && !_scheduled) {
          _scheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            // This is inline, never a modal competing with consent/store UI.
            setState(() => _inviting = true);
            final saved = await service.markInvited();
            if (mounted && !saved) setState(() => _saveFailed = true);
          });
        }
        if (_inviting) {
          return Panel(
            key: const ValueKey('keeper-invitation'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You helped keep the Forge burning.',
                  style: EmberText.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.xs),
                const Text(
                  'Thank you. Leave a name by your flame, if you like.',
                  style: EmberText.label,
                  textAlign: TextAlign.center,
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Space.s,
                  children: [
                    TextButton(
                      key: const ValueKey('keeper-personalise'),
                      onPressed: () => _edit(service),
                      child: const Text('Add my tribute'),
                    ),
                    TextButton(
                      key: const ValueKey('keeper-skip'),
                      onPressed: () async {
                        final saved = await service.skip();
                        if (!context.mounted) return;
                        setState(() => _inviting = false);
                        if (!saved) _saveWarning(context);
                      },
                      child: const Text('No thanks'),
                    ),
                  ],
                ),
                if (_saveFailed)
                  const Text(
                    'This device could not save the choice yet.',
                    style: EmberText.label,
                  ),
              ],
            ),
          );
        }
        final profile = service.profile;
        final named = profile.showName && profile.name.isNotEmpty;
        if (!named && !profile.showCrest) return _normalSubtitle;
        return Semantics(
          container: true,
          child: Row(
            key: const ValueKey('keeper-inscription'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (profile.showCrest) ...[
                const KeeperCrest(),
                const SizedBox(width: Space.s),
              ],
              Flexible(
                child: Text(
                  named
                      ? 'The flame burns brighter thanks to ${profile.name}.'
                      : 'Keeper of the Flame',
                  style: EmberText.label.copyWith(color: EmberColors.gold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void _saveWarning(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(
      content: Text(
        'Your choice is active, but could not be saved on this device.',
      ),
    ),
  );
}

Future<void> showKeeperEditor(
  BuildContext context,
  KeeperService service, {
  bool firstTime = false,
}) async {
  if (!service.entitled || !service.loaded) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _KeeperEditor(service: service, firstTime: firstTime),
  );
}

class _KeeperEditor extends StatefulWidget {
  const _KeeperEditor({required this.service, required this.firstTime});
  final KeeperService service;
  final bool firstTime;

  @override
  State<_KeeperEditor> createState() => _KeeperEditorState();
}

class _KeeperEditorState extends State<_KeeperEditor> {
  late final _name = TextEditingController(text: widget.service.profile.name);
  late bool _showName = widget.firstTime || widget.service.profile.showName;
  late bool _showCrest = widget.firstTime || widget.service.profile.showCrest;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.service.personalise(
      name: _name.text,
      showName: _showName,
      showCrest: _showCrest,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error =
            'Your choice is active, but this device could not save it. '
            'Try again or come back through Settings.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('keeper-editor'),
    scrollable: true,
    title: const Text('Keepers of the Flame', style: EmberText.h2),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The Forge burns because people like you chose to support it. '
          'Thank you.',
          style: EmberText.body,
        ),
        const SizedBox(height: Space.m),
        const Text(
          'A nickname is enough. It stays on this device, is not uploaded '
          'or added to public credits, and is not included in save codes. '
          'You can edit, hide or remove it in Settings.',
          style: EmberText.label,
        ),
        const SizedBox(height: Space.m),
        TextField(
          key: const ValueKey('keeper-name'),
          controller: _name,
          maxLength: KeeperProfile.maxNameLength,
          inputFormatters: [
            LengthLimitingTextInputFormatter(KeeperProfile.maxNameLength),
          ],
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Name by your flame (optional)',
            hintText: 'Your nickname',
          ),
          style: EmberText.body,
        ),
        SwitchListTile(
          key: const ValueKey('keeper-show-name'),
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Show my name on the title',
            style: EmberText.label,
          ),
          value: _showName,
          onChanged: _saving ? null : (v) => setState(() => _showName = v),
        ),
        SwitchListTile(
          key: const ValueKey('keeper-show-crest'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Wear the supporter crest', style: EmberText.label),
          value: _showCrest,
          onChanged: _saving ? null : (v) => setState(() => _showCrest = v),
        ),
        if (_error != null) Text(_error!, style: EmberText.label),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('keeper-save'),
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save tribute'),
      ),
    ],
  );
}

class KeeperSettings extends StatelessWidget {
  const KeeperSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final service = KeeperService.instance;
    if (service == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        if (!service.loaded || !service.entitled) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: Space.m),
          child: Panel(
            key: const ValueKey('keeper-settings'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('KEEPERS OF THE FLAME', style: EmberText.label),
                const SizedBox(height: Space.s),
                const Text(
                  'A personal thank-you for keeping the Forge burning. '
                  'Your tribute stays on this device. No gameplay advantage.',
                  style: EmberText.label,
                ),
                Wrap(
                  spacing: Space.s,
                  children: [
                    TextButton(
                      key: const ValueKey('keeper-edit'),
                      onPressed: () => showKeeperEditor(context, service),
                      child: const Text('Edit / hide tribute'),
                    ),
                    if (service.profile.name.isNotEmpty)
                      TextButton(
                        key: const ValueKey('keeper-remove'),
                        onPressed: () async {
                          final saved = await service.removeName();
                          if (context.mounted && !saved) _saveWarning(context);
                        },
                        child: const Text('Remove name'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
