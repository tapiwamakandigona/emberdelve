// lib/ui/settings_screen.dart — audio settings (music/SFX volume + mutes),
// persisted via SettingsStore, applied live to the AudioService. Also the
// route to Credits & Licenses.
import 'package:flutter/material.dart';
import '../audio/audio_service.dart';
import '../audio/settings.dart';
import '../meta/play_games_service.dart';
import '../meta/store_service.dart';
import '../telemetry/telemetry_service.dart';
import 'credits_screen.dart';
import 'haptics.dart';
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

  void _changed({bool preview = false, bool persist = true}) {
    AudioService.instance?.applySettings();
    if (persist) SettingsStore.save(_s);
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
                // Live volume preview while dragging; persist once on release.
                onVolume: (v) {
                  _s.musicVolume = v;
                  _changed(persist: false);
                },
                onVolumeEnd: (v) {
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
                // No SFX per drag tick; single confirm tap + save on release.
                onVolume: (v) {
                  _s.sfxVolume = v;
                  _changed(persist: false);
                },
                onVolumeEnd: (v) {
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
          Text('FEEDBACK', style: EmberText.micro),
          const SizedBox(height: Space.s),
          Panel(
            child: Row(children: [
              const Icon(Icons.vibration,
                  color: EmberColors.textDim, size: 20),
              const SizedBox(width: Space.m),
              Expanded(child: Text('Haptics', style: EmberText.body)),
              _EmberToggle(
                  value: _s.haptics,
                  onChanged: (v) {
                    _s.haptics = v;
                    _changed(preview: true);
                    // Answer "ON" with a buzz you can feel — instant
                    // on-device confirmation that haptics actually work.
                    if (v) Haptics.preview();
                  }),
            ]),
          ),
          const SizedBox(height: Space.xl),
          Text('PRIVACY', style: EmberText.micro),
          const SizedBox(height: Space.s),
          Panel(
            child: Row(children: [
              const Icon(Icons.insights,
                  color: EmberColors.textDim, size: 20),
              const SizedBox(width: Space.m),
              Expanded(
                  child: Text('Gameplay analytics', style: EmberText.body)),
              _EmberToggle(
                  value: TelemetryService.instance.analyticsConsented,
                  onChanged: (v) {
                    TelemetryService.instance.logEvent('settings_changed',
                        {'setting': 'analytics_consent', 'value': '$v'});
                    TelemetryService.instance.setAnalyticsConsent(v);
                    setState(() {});
                  }),
            ]),
          ),
          // Play Games (v0.5.0, P4+P5): opt-in connect. Hidden entirely on
          // builds without the platform backends (tests, web, desktop).
          if (PlayGamesService.instance.available) ...[
            const SizedBox(height: Space.xl),
            Text('PLAY GAMES', style: EmberText.micro),
            const SizedBox(height: Space.s),
            AnimatedBuilder(
              animation: PlayGamesService.instance.tick,
              builder: (context, _) {
                final pgs = PlayGamesService.instance;
                final on = pgs.connected;
                return Column(children: [
                  Panel(
                    child: Row(children: [
                      Icon(Icons.cloud_done,
                          color: on ? EmberColors.ember : EmberColors.textDim,
                          size: 20),
                      const SizedBox(width: Space.m),
                      Expanded(
                          child: Text(
                              on
                                  ? 'Connected — progress backed up, '
                                      'Delve leaderboards on.'
                                  : 'Back up progress and join the '
                                      'Delve leaderboards.',
                              style: EmberText.body)),
                      EmberButton(on ? 'Disconnect' : 'Connect',
                          key: const ValueKey('pgs-connect'),
                          dense: true, onTap: () async {
                        AudioService.instance?.playSfx('ui_tap');
                        if (on) {
                          await pgs.disconnect();
                        } else {
                          await pgs.connect();
                        }
                        if (mounted) setState(() {});
                      }),
                    ]),
                  ),
                  if (on) ...[
                    const SizedBox(height: Space.s),
                    Panel(
                      child: Row(children: [
                        const Icon(Icons.leaderboard,
                            color: EmberColors.textDim, size: 20),
                        const SizedBox(width: Space.m),
                        Expanded(
                            child: Text('Daily & Weekly Delve boards',
                                style: EmberText.body)),
                        EmberButton('View',
                            key: const ValueKey('pgs-leaderboards'),
                            dense: true, onTap: () {
                          AudioService.instance?.playSfx('ui_tap');
                          pgs.showLeaderboards();
                        }),
                      ]),
                    ),
                  ],
                ]);
              },
            ),
          ],
          const SizedBox(height: Space.xl),
          // Ember Forge (v0.4.0, spec R8): the restore path lives here too —
          // a player on a new device must never have to hunt for it.
          Text('THE EMBER FORGE', style: EmberText.micro),
          const SizedBox(height: Space.s),
          if (StoreService.instance != null)
            AnimatedBuilder(
              animation: StoreService.instance!.tick,
              builder: (context, _) {
                final store = StoreService.instance!;
                final owned = store.state == ForgeStoreState.owned;
                return Panel(
                  child: Row(children: [
                    Icon(Icons.local_fire_department,
                        color: owned
                            ? EmberColors.ember
                            : EmberColors.textDim,
                        size: 20),
                    const SizedBox(width: Space.m),
                    Expanded(
                        child: Text(
                            owned
                                ? 'The Forge is open on this profile.'
                                : 'Bought the Forge before? Bring it here.',
                            style: EmberText.body)),
                    if (!owned)
                      EmberButton('Restore',
                          key: const ValueKey('settings-restore'),
                          dense: true, onTap: () {
                        AudioService.instance?.playSfx('ui_tap');
                        store.restore();
                      }),
                  ]),
                );
              },
            )
          else
            Panel(
                child: Text('Purchases are unavailable in this build.',
                    style: EmberText.bodyDim)),
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
    required ValueChanged<double> onVolumeEnd,
    required ValueChanged<bool> onMute,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 20, color: EmberColors.textDim),
        const SizedBox(width: Space.m),
        Expanded(child: Text(label, style: EmberText.body)),
        _EmberToggle(value: !muted, onChanged: onMute),
      ]),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 8,
          activeTrackColor: EmberColors.ember,
          inactiveTrackColor: const Color(0xFF171021),
          thumbShape: const _EmberThumb(),
          overlayShape: SliderComponentShape.noOverlay,
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: Slider(
          value: value,
          onChanged: muted ? null : onVolume,
          onChangeEnd: muted ? null : onVolumeEnd,
        ),
      ),
    ]);
  }
}

/// Skinned slider thumb: a glowing ember bead with a charcoal rim (no stock
/// Material thumb/overlay).
class _EmberThumb extends SliderComponentShape {
  const _EmberThumb();
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(22, 22);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    final enabled = enableAnimation.value > 0.5;
    if (enabled) {
      canvas.drawCircle(
          center,
          10,
          Paint()
            ..color = EmberColors.ember.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    canvas.drawCircle(
        center,
        8,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFD98A),
            enabled ? EmberColors.ember : EmberColors.textDisabled,
          ]).createShader(Rect.fromCircle(center: center, radius: 8)));
    canvas.drawCircle(
        center,
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF17110A));
  }
}

/// Drawn on/off toggle: an ember coal that lights when on (replaces the stock
/// Material Switch).
class _EmberToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _EmberToggle({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: const Color(0xFF171021),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: value ? EmberColors.ember : EmberColors.line, width: 1.4),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              value ? const Color(0xFFFFD98A) : EmberColors.textDisabled,
              value ? EmberColors.ember : const Color(0xFF3A3148),
            ]),
            boxShadow: value
                ? [
                    BoxShadow(
                        color: EmberColors.ember.withValues(alpha: 0.6),
                        blurRadius: 8)
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
