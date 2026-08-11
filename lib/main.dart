// lib/main.dart — Emberdelve entry point.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';
import 'audio/audio_service.dart';
import 'audio/settings.dart';
import 'game/controller.dart';
import 'meta/play_games_service.dart';
import 'meta/store_service.dart';
import 'telemetry/consent_dialog.dart';
import 'telemetry/telemetry_bootstrap.dart';
import 'telemetry/telemetry_service.dart';
import 'ui/screens.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Must run before the first AudioPlayer exists — see initPlatformAudio.
  await AudioService.initPlatformAudio();
  final audio = AudioService(await SettingsStore.load());
  AudioService.instance = audio;
  final controller = GameController()..audio = audio;
  await controller.boot();
  // Ember Forge billing (v0.4.0, spec R8). Wired after boot so the
  // entitlement check reads the loaded profile; init is deliberately not
  // awaited — startup never blocks on Google Play, and a purchase event
  // arriving later just lands through the stream.
  final store = StoreService(
    gateway: PlayStoreGateway(),
    alreadyOwned: () => controller.meta.forgeUnlocked,
    onEntitled: controller.grantForgeUnlock,
  );
  StoreService.instance = store;
  unawaited(store.init());
  // Decode the first-touch SFX into SoundPool in the background so the very
  // first tap doesn't pay the load. Deliberately not awaited: startup must
  // not wait on audio, and a failure here just means load-on-demand.
  unawaited(audio.warmUp());
  // Play Games Services (P4 cloud save + P5 leaderboards, v0.5.0). Backends
  // are wired only on Android; everywhere else every call is a silent no-op.
  // Connecting is OPT-IN via Settings — resumeIfWanted only acts on a
  // remembered "Connect" choice and never pops UI on its own.
  final pgs = PlayGamesService.instance;
  await pgs.load();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    pgs.signInBackend = () async {
      await GameAuth.signIn();
      return await GameAuth.isSignedIn;
    };
    pgs.saveGameBackend =
        (data, name) async => SaveGame.saveGame(data: data, name: name);
    pgs.loadGameBackend = (name) => SaveGame.loadGame(name: name);
    pgs.submitScoreBackend = (id, value) async => Leaderboards.submitScore(
        score: Score(androidLeaderboardID: id, value: value));
    pgs.showLeaderboardsBackend = (id) async =>
        Leaderboards.showLeaderboards(androidLeaderboardID: id ?? '');
  }
  pgs.loadLocalHook = () async => controller.meta;
  pgs.adoptMergedHook = controller.adoptMeta;
  unawaited(pgs.resumeIfWanted());
  // Consent-gated, opt-in analytics (docs/telemetry-events.md). Silent
  // no-op if Firebase is unconfigured; nothing fires before opt-in.
  await initTelemetry();
  TelemetryService.instance.logEvent('app_open');
  runApp(EmberdelveApp(controller));
}

class EmberdelveApp extends StatefulWidget {
  final GameController controller;
  const EmberdelveApp(this.controller, {super.key});
  @override
  State<EmberdelveApp> createState() => _EmberdelveAppState();
}

/// App-lifecycle audio handling (v0.3.1 F3): pause music/ambience when the
/// app leaves the foreground (Home button, lock screen, incoming call) and
/// resume on return — Android keeps audioplayers running otherwise.
class _EmberdelveAppState extends State<EmberdelveApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audio = widget.controller.audio;
    if (audio == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        audio.resumeAll();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        audio.pauseAll();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emberdelve',
      debugShowCheckedModeBanner: false,
      theme: buildEmberTheme(),
      home: TelemetryConsentGate(child: GameRoot(widget.controller)),
    );
  }
}
