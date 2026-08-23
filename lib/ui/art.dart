// lib/ui/art.dart — static art lookups: backgrounds per phase, node/relic/
// event/currency icon assets, and the shared full-bleed background widget.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../data/attire.dart';
import 'theme.dart';

class Art {
  /// v0.27.0 Delver's Wardrobe: ColorFilter for a dye id, or null for the
  /// identity (undyed/unknown — a stale id can never mispaint the delver).
  /// Hue rotation + saturation/value scaling; a plain multiply tint was
  /// rejected by visual critique (it can only darken, so dyes were invisible
  /// on the red-cloaked sprites).
  static ColorFilter? dyeFilter(String dyeId) {
    final d = delverDyes[dyeId];
    if (d == null || (d.hueDeg == 0 && d.satMul == 1 && d.valMul == 1)) {
      return null;
    }
    return ColorFilter.matrix(_dyeMatrix(d.hueDeg, d.satMul, d.valMul));
  }

  /// 4x5 color matrix = value ∘ saturation ∘ hueRotate (standard SVG
  /// feColorMatrix luminance weights). Alpha untouched.
  static List<double> _dyeMatrix(double hueDeg, double sat, double val) {
    const lr = 0.213, lg = 0.715, lb = 0.072;
    final rad = hueDeg * math.pi / 180.0;
    final c = math.cos(rad), s = math.sin(rad);
    final hue = <double>[
      lr + c * (1 - lr) - s * lr,
      lg - c * lg - s * lg,
      lb - c * lb + s * (1 - lb),
      0,
      0, //
      lr - c * lr + s * 0.143,
      lg + c * (1 - lg) + s * 0.140,
      lb - c * lb - s * 0.283,
      0,
      0, //
      lr - c * lr - s * (1 - lr),
      lg - c * lg + s * lg,
      lb + c * (1 - lb) + s * lb,
      0,
      0, //
      0, 0, 0, 1, 0,
    ];
    final satM = <double>[
      lr + (1 - lr) * sat, lg * (1 - sat), lb * (1 - sat), 0, 0, //
      lr * (1 - sat), lg + (1 - lg) * sat, lb * (1 - sat), 0, 0, //
      lr * (1 - sat), lg * (1 - sat), lb + (1 - lb) * sat, 0, 0, //
      0, 0, 0, 1, 0,
    ];
    var m = _mul(satM, hue);
    if (val != 1) {
      final valM = <double>[
        val, 0, 0, 0, 0, //
        0, val, 0, 0, 0, //
        0, 0, val, 0, 0, //
        0, 0, 0, 1, 0,
      ];
      m = _mul(valM, m);
    }
    return m;
  }

  /// Compose two 4x5 affine color matrices: result = a ∘ b.
  static List<double> _mul(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        var v = 0.0;
        for (var k = 0; k < 4; k++) {
          v += a[row * 5 + k] * b[k * 5 + col];
        }
        if (col == 4) v += a[row * 5 + 4];
        out[row * 5 + col] = v;
      }
    }
    return out;
  }

  static const bgTitle = 'assets/images/backgrounds/bg_title.png';
  static const bgMap = 'assets/images/backgrounds/bg_map.png';
  static const bgCombat = 'assets/images/backgrounds/bg_combat.png';
  static const bgBoss = 'assets/images/backgrounds/bg_boss.png';

  /// Background asset per sim phase (boss/elite fights get the boss arena).
  static String backgroundForPhase(String? phase, {bool bossFight = false}) {
    switch (phase) {
      case 'player_turn':
        return bossFight ? bgBoss : bgCombat;
      case 'boon':
      case 'map':
      case 'reward':
      case 'rest':
      case 'shop':
      case 'event':
        return bgMap;
      case 'run_won':
      case 'run_lost':
        return bgBoss;
      default:
        return bgTitle;
    }
  }

  static const currencyCoin = 'assets/images/ui/currency/currency_coin.png';
  static const currencyEmber = 'assets/images/ui/currency/currency_ember.png';
  static const currencyInsight =
      'assets/images/ui/currency/currency_insight.png';

  /// Map node icons (start keeps its material glyph).
  static const Map<String, String> nodeIcons = {
    'fight': 'assets/images/ui/nodes/node_fight.png',
    'elite': 'assets/images/ui/nodes/node_elite.png',
    'rest': 'assets/images/ui/nodes/node_rest.png',
    'shop': 'assets/images/ui/nodes/node_shop.png',
    'event': 'assets/images/ui/nodes/node_event.png',
    'boss': 'assets/images/ui/nodes/node_boss.png',
  };

  /// Curated relic-id -> icon mapping (game-icons.net set, tinted).
  static const Map<String, String> relicIcons = {
    'ember_ring': 'relic_fire_ring',
    'kiln_key': 'relic_skeleton_key',
    'ashen_idol': 'relic_rune_stone',
    'midas_die': 'relic_crown',
    'lucky_coin': 'relic_gem_pendant',
    'iron_scale': 'relic_fire_shield',
    'bulwark_sigil': 'relic_metal_bar',
    'whetstone': 'relic_sword_smithing',
    'war_drum': 'relic_fire_breath',
    'kite_charm': 'relic_ring',
    'loaded_pips': 'relic_ember_shot',
    'gamblers_eye': 'relic_fire_gem',
    'twin_eye': 'relic_candelabra',
    'fire_salve': 'relic_fire_bottle',
    'phoenix_feather': 'relic_fire_tail',
    'thorn_band': 'relic_hammer_nails',
    'slayers_mark': 'relic_fire_axe',
    'tyrant_bane': 'relic_fireball',
    'bedroll': 'relic_candle_flame',
    'haggler_tongue': 'relic_locked_chest',
    'blood_ruby': 'relic_heart_bottle',
    'ember_heartstone': 'relic_fire_bowl',
  };

  static String relicIcon(String relicId) =>
      'assets/images/ui/relics/${relicIcons[relicId] ?? 'relic_lantern'}.png';

  /// Curated event-id -> icon mapping (10 icons cover 16 events).
  static const Map<String, String> eventIcons = {
    'abandoned_forge': 'event_blacksmith',
    'ember_shrine': 'event_stone_tower',
    'collapsed_tunnel': 'event_cave_entrance',
    'wandering_peddler': 'event_mine_wagon',
    'dice_ghost': 'event_dust_cloud',
    'molten_spring': 'event_coal_pile',
    'beggar_wisp': 'event_conversation',
    'cracked_geode': 'event_mining',
    'old_delver': 'event_conversation',
    'ash_garden': 'event_dust_cloud',
    'tyrants_echo': 'event_stone_tower',
    'gamblers_table': 'event_scroll',
    'sealed_vault': 'event_open_chest',
    'ember_moths': 'event_dust_cloud',
    'broken_cart': 'event_mine_wagon',
    'whispering_coals': 'event_coal_pile',
  };

  static String eventIcon(String eventId) =>
      'assets/images/ui/events/${eventIcons[eventId] ?? 'event_scroll'}.png';

  static String dieIcon(int size) => 'assets/images/ui/dice/die_d$size.png';
}

/// Full-bleed painted background (BoxFit.cover, portrait) with a dark scrim
/// so panels and text keep their contrast on top of the art.
class ScreenBackground extends StatelessWidget {
  final String asset;
  final Widget child;
  final double scrim;
  const ScreenBackground({
    super.key,
    required this.asset,
    required this.child,
    this.scrim = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.cover, gaplessPlayback: true),
        Container(color: EmberColors.bg.withValues(alpha: scrim)),
        child,
      ],
    );
  }
}
