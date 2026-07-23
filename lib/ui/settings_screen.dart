// lib/ui/settings_screen.dart — audio settings (music/SFX volume + mutes),
// persisted via SettingsStore, applied live to the AudioService. Also the
// route to Credits & Licenses.
import 'package:flutter/material.dart';
import '../audio/audio_service.dart';
import '../audio/settings.dart';
import 'credits_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AudioSettings get _s =>
      AudioService.instance?.settings ?? _fallback;
  static final AudioSettings _fallback = AudioSettings();

  void _changed({bool preview = false}) {
    AudioService.instance?.applySettings();
    SettingsStore.save(_s);
    if (preview) AudioService.instance?.playSfx('ui_tap');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: EmberText.h2),
        backgroundColor: EmberColors.bg,
        leading: BackButton(onPressed: () {
          AudioService.instance?.playSfx('ui_back');
          Navigator.of(context).pop();
        }),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(Space.l), children: [
          Text('AUDIO', style: EmberText.micro),
          const SizedBox(height: Space.s),
          Panel(
            child: Column(children: [
              _volumeRow(
                icon: Icons.music_note,
                label: 'Music',
                value: _s.musicVolume,
                muted: _s.musicMuted,
                onVolume: (v) {
                  _s.musicVolume = v;
                  _changed();
                },
                onMute: (m) {
                  _s.musicMuted = !m;
                  _changed();
                },
              ),
              const Divider(color: EmberColors.line, height: Space.xl),
              _volumeRow(
                icon: Icons.graphic_eq,
                label: 'Sound effects',
                value: _s.sfxVolume,
                muted: _s.sfxMuted,
                onVolume: (v) {
                  _s.sfxVolume = v;
                  _changed(preview: true);
                },
                onMute: (m) {
                  _s.sfxMuted = !m;
                  _changed(preview: true);
                },
              ),
            ]),
          ),
          const SizedBox(height: Space.xl),
          Text('ABOUT', style: EmberText.micro),
          const SizedBox(height: Space.s),
          Panel(
            child: Row(children: [
              const Icon(Icons.menu_book,
                  color: EmberColors.textDim, size: 20),
              const SizedBox(width: Space.m),
              Expanded(
                  child: Text('Credits & Licenses', style: EmberText.body)),
              EmberButton('View', onTap: () {
                AudioService.instance?.playSfx('ui_tap');
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreditsScreen()));
              }),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _volumeRow({
    required IconData icon,
    required String label,
    required double value,
    required bool muted,
    required ValueChanged<double> onVolume,
    required ValueChanged<bool> onMute,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 20, color: EmberColors.textDim),
        const SizedBox(width: Space.m),
        Expanded(child: Text(label, style: EmberText.body)),
        Switch(
          value: !muted,
          activeColor: EmberColors.ember,
          onChanged: onMute,
        ),
      ]),
      Slider(
        value: value,
        onChanged: muted ? null : onVolume,
        activeColor: EmberColors.ember,
        inactiveColor: EmberColors.raised,
      ),
    ]);
  }
}
