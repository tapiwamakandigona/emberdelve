// ui/title_screen.dart — art-directed title: layered forest parallax
// backdrop (ansimuz CC0 layers, gently drifting), Cinzel logo with ember
// glow, and the four meta routes: Play / Shop / Settings / Credits.
import 'package:flutter/material.dart';

import '../audio/audio_service.dart';
import '../meta/daily.dart';
import '../meta/progress_state.dart';
import 'app_state.dart';
import 'credits_screen.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    AudioService.instance?.playMusic('title_menu');
    AudioService.instance?.setAmbience(true); // ember-crackle bed under title
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  void _open(Widget screen) {
    AudioService.instance?.playSfx('ui_tap');
    AudioService.instance?.setAmbience(false);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)).then((
      _,
    ) {
      // Coming back from gameplay: restore the menu theme and refresh
      // the Daily Delve best-time line.
      AudioService.instance?.playMusic('title_menu');
      AudioService.instance?.setAmbience(true);
      if (mounted) setState(() {});
    });
  }

  /// 'Old Orchard · best 1:07' or 'Old Orchard' if no run today.
  String get _dailySubtitle {
    final now = DateTime.now();
    final id = dailyLevelId(now);
    final title = kWorld1
        .firstWhere((e) => e.id == id, orElse: () => LevelEntry(id, id))
        .title;
    if (AppState.isReady &&
        AppState.save.dailyBestDate == dailyKey(now) &&
        AppState.save.dailyBestTimeMs > 0) {
      final s = AppState.save.dailyBestTimeMs ~/ 1000;
      return '$title  ·  best ${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    }
    return title;
  }

  void _playDaily() {
    final now = DateTime.now();
    _open(
      GameScreen(levelId: dailyLevelId(now), seed: dailySeed(now), daily: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Parallax forest backdrop: three CC0 layers drifting at different
          // speeds (slow ambient motion, not gameplay parallax).
          AnimatedBuilder(
            animation: _drift,
            builder: (context, _) {
              final t = _drift.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _layer('assets/images/bg/forest_back.png', t * 0.25),
                  _layer('assets/images/bg/forest_middle.png', t * 0.5),
                  _layer('assets/images/bg/forest_front.png', t * 1.0),
                  // Dark vignette so the menu reads over the art.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x66000000), Color(0xB3000000)],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            // Overflow sweep (alpha.16): the menu column is taller than a
            // small landscape phone at 1.3x text and wider than a 320 px
            // portrait — FittedBox(scaleDown) shrinks it to fit either axis
            // instead of clipping content (DEMAND: nothing unseeable).
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo treatment: ember glow behind the wordmark.
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 340,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(60),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55E8A33D),
                                blurRadius: 48,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'EMBERDELVE',
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            fontSize: 44,
                            letterSpacing: 7,
                            color: Color(0xFFE8A33D),
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black, offset: Offset(0, 3)),
                              Shadow(color: Color(0x88E8631A), blurRadius: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Delve the Emberwood',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3E8948),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 56,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => _open(const LevelSelectScreen()),
                      child: const Text(
                        'PLAY',
                        style: TextStyle(
                          fontSize: 20,
                          fontFamily: 'Cinzel',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Daily Delve — deterministic daily remix. No streaks, no
                    // countdown copy: just today's level and today's best.
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE8A33D),
                        side: const BorderSide(color: Color(0x66E8A33D)),
                        backgroundColor: const Color(0x66141420),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 10,
                        ),
                      ),
                      onPressed: _playDaily,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'DAILY DELVE',
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            _dailySubtitle,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MenuButton(
                          label: 'SHOP',
                          icon: Icons.storefront,
                          onTap: () => _open(const ShopScreen()),
                        ),
                        const SizedBox(width: 10),
                        _MenuButton(
                          label: 'SETTINGS',
                          icon: Icons.settings,
                          onTap: () => _open(const SettingsScreen()),
                        ),
                        const SizedBox(width: 10),
                        _MenuButton(
                          label: 'CREDITS',
                          icon: Icons.menu_book,
                          onTap: () => _open(const CreditsScreen()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _layer(String asset, double phase) {
    // Two copies side by side, sliding left and wrapping for a seamless loop.
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final dx = -(phase % 1.0) * w;
        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: dx,
                top: 0,
                bottom: 0,
                width: w + 1,
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.none,
                ),
              ),
              Positioned(
                left: dx + w,
                top: 0,
                bottom: 0,
                width: w + 1,
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFE8A33D),
        side: const BorderSide(color: Color(0x66E8A33D)),
        backgroundColor: const Color(0x66141420),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Cinzel',
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
