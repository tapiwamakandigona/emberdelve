// lib/ui/art.dart — static art lookups: backgrounds per phase, node/relic/
// event/currency icon assets, and the shared full-bleed background widget.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../data/attire.dart';
import '../data/vistas.dart';
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

  /// v0.28.0 The Shifting Strata: background grade for a run depth
  /// (0 surface .. 1 boss layer). Null at the surface = identity — the
  /// title and every pre-run phase render byte-identical to pre-strata
  /// builds. The grade cools the kiln-brown rock toward ash by mid-delve
  /// and toward wyrm-violet at the bottom; it sits UNDER the scrim, so
  /// text contrast never changes.
  static ColorFilter? strataFilter(double depth) {
    final t = depth.clamp(0.0, 1.0);
    if (t <= 0) return null;
    // The backdrop art is near-black, so a polite grade is invisible (first
    // plate pass proved it). The hue swing is therefore LARGE — the warm
    // ember specks and rock seams visibly turn ash-teal by mid-delve and
    // wyrm-violet at the bottom — and saturation RISES with depth so the
    // recolored accents glow instead of draining away.
    final hue = t < 0.5
        ? _lerp(0, -60, t * 2)
        : _lerp(-60, -115, (t - 0.5) * 2);
    final sat = _lerp(1.0, 1.45, t);
    final val = _lerp(1.0, 0.94, t);
    return ColorFilter.matrix(_dyeMatrix(hue, sat, val));
  }

  /// v0.35.0 The Vistas: combined vista + strata grade for the painted
  /// backgrounds. Both grades live in the same hue/sat/val matrix family,
  /// so they compose as one matrix (hues add, sat/val multiply) — the vista
  /// costs ZERO extra render passes on top of what strata already pays.
  /// Emberlight at depth 0 returns null: byte-identical to every build
  /// since v0.28.0.
  static ColorFilter? backgroundGrade(double depth, String vistaId) {
    final v = vistas[vistaId];
    final t = depth.clamp(0.0, 1.0);
    final strataHue = t <= 0
        ? 0.0
        : (t < 0.5 ? _lerp(0, -60, t * 2) : _lerp(-60, -115, (t - 0.5) * 2));
    final strataSat = t <= 0 ? 1.0 : _lerp(1.0, 1.45, t);
    final strataVal = t <= 0 ? 1.0 : _lerp(1.0, 0.94, t);
    final hue = (v?.hueDeg ?? 0) + strataHue;
    final sat = (v?.satMul ?? 1) * strataSat;
    final val = (v?.valMul ?? 1) * strataVal;
    if (hue == 0 && sat == 1 && val == 1) return null;
    return ColorFilter.matrix(_dyeMatrix(hue, sat, val));
  }

  /// v0.35.0: vista wash composed UNDER the strata wash (paint order: art,
  /// vista breath, depth breath, scrim). Source-over math folded into one
  /// color so ScreenBackground still paints a single wash Container.
  static Color backgroundWash(double depth, String vistaId) {
    final vista = vistas[vistaId]?.wash ?? const Color(0x00000000);
    final strata = strataWash(depth);
    if (strata.a <= 0) return vista;
    if (vista.a <= 0) return strata;
    final a = strata.a + vista.a * (1 - strata.a);
    double ch(double top, double bot) =>
        (top * strata.a + bot * vista.a * (1 - strata.a)) / a;
    return Color.from(
      alpha: a,
      red: ch(strata.r, vista.r),
      green: ch(strata.g, vista.g),
      blue: ch(strata.b, vista.b),
    );
  }

  /// Depth wash above the graded art but under the scrim: a colored breath
  /// the eye catches even where the rock is pitch black. Transparent at the
  /// surface; ash-blue mid; violet at the boss layer.
  static Color strataWash(double depth) {
    final t = depth.clamp(0.0, 1.0);
    if (t <= 0) return const Color(0x00000000);
    const mid = Color(0xFF2A3A55); // ash-blue
    const deep = Color(0xFF3A2450); // wyrm-violet
    final c = t < 0.5
        ? Color.lerp(mid, mid, t * 2)!
        : Color.lerp(mid, deep, (t - 0.5) * 2)!;
    return c.withValues(alpha: 0.30 * (t < 0.5 ? t * 2 : 1.0));
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

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
    // v0.95.0 The Known Relic: the 14 relics that shared the fallback
    // lantern each get a deliberate icon. Constraint (test-pinned): no
    // icon serves more than two relics, and reuse pairs are chosen so
    // the two effects read nothing alike.
    'cinder_lantern': 'relic_lantern',
    'serpent_fang': 'relic_fire_breath',
    'pumice_plate': 'relic_metal_bar',
    'hearth_kettle': 'relic_fire_bowl',
    'siege_hook': 'relic_anvil',
    'kings_ransom': 'relic_crown',
    'drowned_bell': 'relic_gem_pendant',
    'ashglass_prism': 'relic_fire_gem',
    'wyrmscale_cloak': 'relic_fire_tail',
    'choir_censer': 'relic_candelabra',
    'cairn_stone': 'relic_rune_stone',
    'rivals_compass': 'relic_ring',
    'keepers_lantern': 'relic_candle_flame',
    'tally_chain': 'relic_skeleton_key',
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
    // v0.46.0 "The Delvers Before" (unlisted ids fall back to event_scroll)
    'the_cold_camp': 'event_coal_pile',
    'delvers_cairn': 'event_stone_tower',
    'the_old_rope': 'event_cave_entrance',
    'the_first_delver': 'event_mining',
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

  /// v0.28.0 strata grade (Art.strataFilter). Null = identity, no wrapper.
  final ColorFilter? grade;

  /// v0.28.0 depth wash (Art.strataWash). Fully transparent = skipped.
  final Color wash;
  const ScreenBackground({
    super.key,
    required this.asset,
    required this.child,
    this.scrim = 0.45,
    this.grade,
    this.wash = const Color(0x00000000),
  });

  @override
  Widget build(BuildContext context) {
    // PERF/MEM (Play 2027 memory thresholds, DEMAND 2026-09-01c): the
    // background sources are 1080x1920 and decode to ~7.9 MB EACH at full
    // size; Flutter's image cache keeps every visited one resident (~32 MB
    // for all four). cacheWidth decodes at the device's physical width
    // instead (BoxFit.cover never upscales past it) — a 720p phone now pays
    // ~3.5 MB per background instead of 7.9. Height follows aspect ratio.
    final mq = MediaQuery.of(context);
    final physW = (mq.size.width * mq.devicePixelRatio).round();
    final img = Image.asset(
      asset,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: physW.clamp(1, 1080),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (grade == null)
          img
        else
          ColorFiltered(colorFilter: grade!, child: img),
        if (wash.a > 0) Container(color: wash),
        Container(color: EmberColors.bg.withValues(alpha: scrim)),
        child,
      ],
    );
  }
}
