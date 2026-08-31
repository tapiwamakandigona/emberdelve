// ui/settings_screen.dart — music/sfx volume sliders (persisted via
// SettingsStore) and a confirm-guarded reset-save. Credits live on their own
// screen; this links to it too (license requirement: reachable in-app).
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/audio_service.dart';
import '../audio/settings.dart';
import '../core/save.dart';
import '../telemetry/telemetry_service.dart';
import 'app_state.dart';
import 'credits_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final audio = AudioService.instance;
    final settings = audio?.settings;
    return Scaffold(
      backgroundColor: const Color(0xFF141420),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('SETTINGS',
            style: TextStyle(
                fontFamily: 'Cinzel',
                color: Color(0xFFE8A33D),
                fontWeight: FontWeight.bold,
                letterSpacing: 3)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          // Stage 2 (owner-directed 2026-07-25): difficulty. Scales enemy
          // behaviour (speed / reaction windows / detection) + one heart of
          // slack on Easy. Never enemy hp/damage — no cheap stat walls.
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text('DIFFICULTY',
                style: TextStyle(
                    color: Color(0xFFE8A33D),
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                foregroundColor: Colors.white54,
                selectedForegroundColor: Colors.black,
                selectedBackgroundColor: const Color(0xFFE8A33D),
              ),
              segments: const [
                ButtonSegment(value: 'easy', label: Text('Easy')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'hard', label: Text('Hard')),
              ],
              selected: {AppState.save.difficulty},
              onSelectionChanged: (sel) {
                setState(() => AppState.save.difficulty = sel.first);
                AudioService.instance?.playSfx('ui_tap');
                unawaited(AppState.persist());
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 2, bottom: 8),
            child: Text(
                'Enemies think faster and reach farther on Hard. '
                'Easy adds a heart of slack.',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          const Divider(color: Colors.white12, height: 32),
          if (settings != null) ...[
            _SliderTile(
              label: 'Music',
              value: settings.musicVolume,
              onChanged: (v) {
                setState(() => settings.musicVolume = v);
                audio!.applySettings();
              },
              onChangeEnd: (_) => SettingsStore.save(settings),
            ),
            _SliderTile(
              label: 'Sound effects',
              value: settings.sfxVolume,
              onChanged: (v) => setState(() => settings.sfxVolume = v),
              onChangeEnd: (v) {
                audio!.playSfx('ui_tap');
                SettingsStore.save(settings);
              },
            ),
            SwitchListTile(
              title: const Text('Haptics',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Vibrate on hits and boss beats',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              activeThumbColor: const Color(0xFFE8A33D),
              value: settings.haptics,
              onChanged: (v) {
                setState(() => settings.haptics = v);
                if (v) HapticFeedback.mediumImpact(); // instant preview
                SettingsStore.save(settings);
              },
            ),
          ] else
            const ListTile(
              title: Text('Audio unavailable',
                  style: TextStyle(color: Colors.white38)),
            ),
          const Divider(color: Colors.white12, height: 32),
          SwitchListTile(
            title: const Text('Gameplay analytics',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text(
                'Anonymous level/settings stats to help improve the game. '
                'Off by default; no personal data ever.',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            activeThumbColor: const Color(0xFFE8A33D),
            value: TelemetryService.instance.analyticsConsented,
            onChanged: (v) {
              TelemetryService.instance
                  .logEvent('settings_changed', {'setting': 'analytics_consent', 'value': '$v'});
              TelemetryService.instance.setAnalyticsConsent(v);
              setState(() {});
            },
          ),
          const Divider(color: Colors.white12, height: 32),
          ListTile(
            leading:
                const Icon(Icons.menu_book, color: Color(0xFFE8A33D)),
            title: const Text('Credits & Licenses',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreditsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text('Reset save',
                style: TextStyle(color: Colors.redAccent)),
            subtitle: const Text('Erases coins, purchases and level progress',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            onTap: _confirmReset,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Reset save?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'All coins, feathers, purchases and level progress will be '
            'erased. This cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    AppState.save = SaveData();
    unawaited(AppState.persist()); // atomic write; UI must not block on disk
    setState(() {});
    AudioService.instance?.playSfx('ui_tap');
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  const _SliderTile({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
          width: 120,
          child:
              Text(label, style: const TextStyle(color: Colors.white70))),
      Expanded(
        child: Slider(
          value: value.clamp(0.0, 1.0),
          activeColor: const Color(0xFFE8A33D),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
      SizedBox(
          width: 40,
          child: Text('${(value * 100).round()}%',
              style: const TextStyle(color: Colors.white38, fontSize: 12))),
    ]);
  }
}
