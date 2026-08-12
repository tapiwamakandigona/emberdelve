// lib/telemetry/consent_dialog.dart — first-launch prominent-disclosure
// dialog (Play User Data policy). Compliance copy; do not edit casually.
//
// Rules it implements: shown in normal app usage before any analytics event
// can fire, describes what+why, affirmative tap required ("Allow"),
// back/dismiss counts as NOT consenting (recorded as declined so we don't
// nag every launch; the Settings toggle can turn it on later).
import 'package:flutter/material.dart';

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
  const body = TextStyle(color: Colors.white70, fontSize: 13, height: 1.35);
  const micro = TextStyle(color: Colors.white38, fontSize: 11, height: 1.3);
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
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Help improve Emberdelve',
          style: TextStyle(
            fontFamily: 'Cinzel',
            color: Color(0xFFE8A33D),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "To fix bugs and improve the game we'd like to collect, "
                'with your permission, anonymous gameplay analytics: which '
                'levels you play, whether you finish them, and which '
                'settings you use. No names, no emails, no personal data — '
                'ever.',
                style: body,
              ),
              SizedBox(height: 10),
              Text(
                'You can change this any time in Settings → Gameplay '
                'analytics. Data is processed by Google Firebase on our '
                'behalf. Details:\n$kPrivacyPolicyUrl',
                style: micro,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Not now',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE8A33D),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    ),
  );
  await TelemetryService.instance.setAnalyticsConsent(allowed ?? false);
}
