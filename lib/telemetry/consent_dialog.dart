// lib/telemetry/consent_dialog.dart — first-launch prominent-disclosure
// dialog (Play User Data policy). Copy is the approved text from the
// telemetry recommendation; do not edit casually — it is compliance copy.
//
// Rules it implements: shown in normal app usage before any analytics event
// can fire, describes what+why, affirmative tap required ("Allow"),
// back/dismiss counts as NOT consenting (recorded as declined so we don't
// nag every launch; the Settings toggle can turn it on later).
import 'package:flutter/material.dart';
import '../ui/theme.dart';
import 'telemetry_service.dart';

const String kPrivacyPolicyUrl =
    'https://tapiwamakandigona.github.io/emberdelve/store/privacy-policy.html';

/// Wraps the game root; on first launch (no recorded choice) shows the
/// disclosure dialog after the first frame. Everything else renders
/// normally underneath.
class TelemetryConsentGate extends StatefulWidget {
  final Widget child;
  const TelemetryConsentGate({required this.child, super.key});
  @override
  State<TelemetryConsentGate> createState() => _TelemetryConsentGateState();
}

class _TelemetryConsentGateState extends State<TelemetryConsentGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (TelemetryService.instance.needsConsentDialog) {
        showTelemetryConsentDialog(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows the prominent-disclosure dialog and persists the player's choice.
Future<void> showTelemetryConsentDialog(BuildContext context) async {
  final allowed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      // System back = "not now" (never consent-by-dismiss).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(ctx).pop(false);
      },
      child: AlertDialog(
        backgroundColor: EmberColors.surface,
        title: Text('Help improve Emberdelve (beta)', style: EmberText.h2),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "To fix bugs and improve the game we'd like to collect, "
                'with your permission:',
                style: EmberText.body,
              ),
              const SizedBox(height: 10),
              _bullet(
                  'Gameplay analytics',
                  'which screens, runs and features you use.'),
              const SizedBox(height: 6),
              _bullet(
                  'Session recordings',
                  'video-like recordings of your game screen while you play '
                      '(game screens only; this app has no chat or personal '
                      'text entry).'),
              const SizedBox(height: 10),
              Text(
                'Crash reports (technical error data) are collected '
                'automatically so we can fix crashes; you can turn them off '
                'in Settings.',
                style: EmberText.body,
              ),
              const SizedBox(height: 10),
              Text(
                'Data is processed by Google Firebase and PostHog on our '
                'behalf. Details: Privacy Policy —\n$kPrivacyPolicyUrl',
                style: EmberText.micro,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('No thanks', style: EmberText.body),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Allow',
                style: EmberText.body.copyWith(color: EmberColors.ember)),
          ),
        ],
      ),
    ),
  );
  await TelemetryService.instance.setAnalyticsConsent(allowed ?? false);
}

Widget _bullet(String head, String rest) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•  ', style: EmberText.body),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: '$head — ',
                style: EmberText.body
                    .copyWith(fontWeight: FontWeight.bold)),
            TextSpan(text: rest, style: EmberText.body),
          ])),
        ),
      ],
    );
