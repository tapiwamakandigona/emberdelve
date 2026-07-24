// lib/ui/ledger_screen.dart — The Ledger (v0.3.3): lifetime stats + hearth
// colors. The macro-loop chase after all delvers unlock (gameplay analysis
// caveat 3): every number is REAL and earned (§Ethics honesty — no faked
// progress, no timers, no FOMO), and hearth colors are a pure-cosmetic ember
// sink with prices shown up front.
import 'package:flutter/material.dart';
import '../audio/audio_service.dart';
import '../data/characters.dart';
import '../data/themes.dart';
import '../game/controller.dart';
import 'theme.dart';
import 'widgets.dart';

class LedgerScreen extends StatelessWidget {
  final GameController c;
  const LedgerScreen(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('The Ledger', style: EmberText.h2),
        backgroundColor: EmberColors.bg,
        leading: BackButton(onPressed: () {
          AudioService.instance?.playSfx('ui_back');
          Navigator.of(context).pop();
        }),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            final m = c.meta;
            return ListView(
                padding: const EdgeInsets.all(Space.l),
                children: [
                  Text('LIFETIME', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  Panel(
                    child: Column(children: [
                      _row(Icons.local_fire_department, EmberColors.ember,
                          'Embers banked, all time', '${m.lifetimeEmbers}'),
                      const Divider(
                          color: EmberColors.line, height: Space.xl),
                      _row(Icons.sports_martial_arts, EmberColors.textPrimary,
                          'Delves won', '${m.runsWon} of ${m.runsPlayed}'),
                      const Divider(
                          color: EmberColors.line, height: Space.xl),
                      _row(Icons.trending_up, EmberColors.gold,
                          'Best ascension', '${m.bestAscension}'),
                      const Divider(
                          color: EmberColors.line, height: Space.xl),
                      _row(Icons.adjust, EmberColors.success, 'Exact kills',
                          '${m.exactKills}'),
                      const Divider(
                          color: EmberColors.line, height: Space.xl),
                      _row(Icons.bolt, EmberColors.gold,
                          'Best exact-kill streak', '${m.bestExactStreak}'),
                    ]),
                  ),
                  const SizedBox(height: Space.xl),
                  Text('DELVERS', style: EmberText.micro),
                  const SizedBox(height: Space.s),
                  Panel(
                    child: Column(children: [
                      for (final (i, id) in charactersOrder.indexed) ...[
                        if (i > 0)
                          const Divider(
                              color: EmberColors.line, height: Space.xl),
                        _delverRow(m, id),
                      ],
                    ]),
                  ),
                  const SizedBox(height: Space.xl),
                  // Hearth colors: tap an owned color to light it; tap a
                  // locked one to buy it with embers (price always shown).
                  Row(children: [
                    Expanded(
                        child: Text('HEARTH COLORS', style: EmberText.micro)),
                    const Icon(Icons.local_fire_department,
                        color: EmberColors.ember, size: 14),
                    const SizedBox(width: 4),
                    Text('${m.embers}',
                        style:
                            EmberText.label.copyWith(color: EmberColors.ember)),
                  ]),
                  const SizedBox(height: Space.s),
                  for (final id in hearthThemesOrder) ...[
                    _themeCard(context, id),
                    const SizedBox(height: Space.m),
                  ],
                  const SizedBox(height: Space.s),
                  Text(
                      'Hearth colors retint the fire on the title screen. '
                      'Pure cosmetics — the delve itself never changes.',
                      style: EmberText.micro
                          .copyWith(color: EmberColors.textDim)),
                ]);
          },
        ),
      ),
    );
  }

  Widget _row(IconData icon, Color color, String label, String value) {
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: Space.m),
      Expanded(child: Text(label, style: EmberText.body)),
      const SizedBox(width: Space.s),
      // Flexible + scale-down: six-digit lifetime values shrink on narrow
      // phones instead of overflowing the panel (same trick as _TopBar).
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: EmberText.value.copyWith(color: color)),
        ),
      ),
    ]);
  }

  Widget _delverRow(dynamic m, String id) {
    final ch = characters[id]!;
    final unlocked = m.isUnlocked(id) as bool;
    final runs = (m.charRuns[id] as int?) ?? 0;
    final wins = (m.charWins[id] as int?) ?? 0;
    return Row(children: [
      Icon(unlocked ? Icons.person : Icons.lock,
          color: unlocked ? EmberColors.textPrimary : EmberColors.textDisabled,
          size: 20),
      const SizedBox(width: Space.m),
      Expanded(
        child: Text(ch.name,
            style: EmberText.body.copyWith(
                color: unlocked
                    ? EmberColors.textPrimary
                    : EmberColors.textDisabled)),
      ),
      const SizedBox(width: Space.s),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(unlocked ? '$wins wins · $runs delves' : 'locked',
              style: EmberText.label.copyWith(
                  color: unlocked
                      ? EmberColors.textDim
                      : EmberColors.textDisabled)),
        ),
      ),
    ]);
  }

  Widget _themeCard(BuildContext context, String id) {
    final t = hearthThemes[id]!;
    final m = c.meta;
    final owned = m.ownedThemes.contains(id);
    final active = m.activeTheme == id;
    final affordable = m.embers >= t.costEmbers;
    return GestureDetector(
      key: ValueKey('theme-$id'),
      onTap: () {
        if (active) return;
        if (owned) {
          AudioService.instance?.playSfx('ui_tap');
          c.setActiveTheme(id);
        } else if (c.buyTheme(id)) {
          c.setActiveTheme(id);
        } else {
          AudioService.instance?.playSfx('ui_back');
        }
      },
      child: Panel(
        color: active ? EmberColors.raised : EmberColors.surface,
        child: Row(children: [
          // Swatch: the theme's warm->bright gradient.
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [Color(t.warmArgb), Color(t.brightArgb)],
              ),
              border: Border.all(
                  color: active ? EmberColors.ember : EmberColors.line),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: EmberText.body),
                  const SizedBox(height: 2),
                  Text(t.text,
                      style: EmberText.micro
                          .copyWith(color: EmberColors.textDim)),
                ]),
          ),
          const SizedBox(width: Space.s),
          if (active)
            Text('LIT',
                style: EmberText.micro.copyWith(
                    color: EmberColors.ember, fontWeight: FontWeight.w700))
          else if (owned)
            Text('OWNED',
                style:
                    EmberText.micro.copyWith(color: EmberColors.textDim))
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.local_fire_department,
                  size: 14,
                  color: affordable
                      ? EmberColors.ember
                      : EmberColors.textDisabled),
              const SizedBox(width: 2),
              Text('${t.costEmbers}',
                  style: EmberText.label.copyWith(
                      color: affordable
                          ? EmberColors.ember
                          : EmberColors.textDisabled)),
            ]),
        ]),
      ),
    );
  }
}
