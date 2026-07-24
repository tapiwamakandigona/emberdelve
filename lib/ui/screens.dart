// lib/ui/screens.dart — every screen, routed by sim.phase. Screens render only
// from controller.state() and never poke sim internals. Layout is portrait,
// one-thumb: the primary action lives in the bottom zone on every screen.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../audio/audio_service.dart';
import '../data/boons.dart';
import '../data/characters.dart';
import '../data/dice.dart';
import '../data/events.dart';
import '../data/relics.dart';
import '../data/themes.dart';
import '../game/controller.dart';
import '../game/daily_share.dart';
import '../game/seed_input.dart';
import 'art.dart';
import 'fx.dart';
import 'haptics.dart';
import 'ledger_screen.dart';
import 'logo.dart';
import 'settings_screen.dart';
import 'sprites.dart';
import 'theme.dart';
import 'widgets.dart';


part 'screens/game_root.dart';
part 'screens/title_screen.dart';
part 'screens/boon_screen.dart';
part 'screens/character_screen.dart';
part 'screens/map_screen.dart';
part 'screens/combat_screen.dart';
part 'screens/reward_screen.dart';
part 'screens/rest_screen.dart';
part 'screens/shop_screen.dart';
part 'screens/event_screen.dart';
part 'screens/summary_screen.dart';
part 'screens/top_bar.dart';
part 'screens/tutorial_overlay.dart';
