// lib/main.dart — Emberdelve entry point.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:games_services/games_services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'audio/audio_service.dart';
import 'audio/settings.dart';
import 'game/controller.dart';
import 'meta/play_games_service.dart';
import 'meta/save_transfer.dart';
import 'meta/reminder_service.dart';
import 'meta/review_service.dart';
import 'meta/unlock_codes.dart';
import 'meta/store_service.dart';
import 'meta/update_service.dart';
import 'telemetry/consent_dialog.dart';
import 'telemetry/telemetry_bootstrap.dart';
import 'telemetry/telemetry_service.dart';
import 'ui/motion.dart';
import 'ui/screens.dart';
import 'ui/warmup.dart';
import 'ui/theme.dart';

Future<void> main() async {
  // THE FIRST SPARK: must be set BEFORE the binding initializes —
  // PaintingBinding.initInstances() executes the warm-up (see
  // lib/ui/warmup.dart for why Skia + no default warm-up = first-use
  // shader jank on low-end devices without this).
  PaintingBinding.shaderWarmUp = const EmberShaderWarmUp();
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Must run before the first AudioPlayer exists — see initPlatformAudio.
  await AudioService.initPlatformAudio();
  final audio = AudioService(await SettingsStore.load());
  AudioService.instance = audio;
  // Reduce motion (v0.16.0): seed the resolver with the persisted choice;
  // the MaterialApp builder below keeps the OS flag side current.
  Motion.instance.update(setting: audio.settings.reduceMotion);
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
  // THE SWIFT LANTERN: the four service loads below are mutually
  // independent (three SharedPreferences reads + Firebase init) but ran
  // in strict sequence — on a slow phone the title screen was waiting on
  // Firebase before it could exist. Overlap them; everything is still
  // fully loaded before runApp, so no wiring below changes meaning.
  final reminder = ReminderService.instance;
  final updates = UpdateService.instance;
  await Future.wait([
    pgs.load(),
    reminder.load(),
    updates.load(),
    initTelemetry(),
  ]);
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    pgs.signInBackend = () async {
      await GameAuth.signIn();
      return await GameAuth.isSignedIn;
    };
    pgs.saveGameBackend = (data, name) async =>
        SaveGame.saveGame(data: data, name: name);
    pgs.loadGameBackend = (name) => SaveGame.loadGame(name: name);
    pgs.submitScoreBackend = (id, value) async => Leaderboards.submitScore(
      score: Score(androidLeaderboardID: id, value: value),
    );
    pgs.showLeaderboardsBackend = (id) async =>
        Leaderboards.showLeaderboards(androidLeaderboardID: id ?? '');
  }
  pgs.loadLocalHook = () async => controller.meta;
  pgs.adoptMergedHook = controller.adoptMeta;
  // In-app review (REVENUE ASK #1): backend wired on Android only; the
  // service is a silent no-op everywhere else. One quiet ask per profile —
  // see lib/meta/review_service.dart for the charter.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    ReviewService.instance.backend = () =>
        InAppReview.instance.requestReview();
  }
  // The Carried Ember (v0.24.0): the Settings save-code panel reads and
  // adopts meta through the same two doors as the cloud path.
  SaveTransfer.loadLocalHook = () async => controller.meta;
  SaveTransfer.adoptMergedHook = controller.adoptMeta;
  // Offline unlock codes (UNLOCK-CODES-SPEC): Settings redeems through this
  // hook. Verification is pure Dart — wired on every platform.
  UnlockRedeem.redeemHook = controller.redeemUnlockCode;
  unawaited(pgs.resumeIfWanted());
  // Daily Delve reminder (v0.6.0): OFF by default, enabled only by an
  // explicit Settings tap. Backends wired on Android only; the service is a
  // silent no-op everywhere else. Rescheduling is not awaited — startup
  // never blocks on the notifications plugin.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    unawaited(_wireReminderBackends(reminder));
  }
  // The Watchtower (v0.21.0): update awareness for GitHub-only builds.
  // The fetcher is wired on Android only; the launch check runs only on a
  // remembered opt-in and is not awaited — startup never blocks on GitHub.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    updates.fetcher = _fetchReleaseJson;
    unawaited(updates.launchCheckIfEnabled());
  }
  // Consent-gated, opt-in analytics (docs/telemetry-events.md) was
  // brought up in the Future.wait above; only the first event fires here.
  TelemetryService.instance.logEvent('app_open');
  runApp(EmberdelveApp(controller));
}

/// One GET against GitHub's public releases API (The Watchtower, v0.21.0).
/// Plain dart:io — no new dependency. Throws on any failure; UpdateService
/// maps every throw to a quiet inline error, never a crash.
Future<String> _fetchReleaseJson(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client.getUrl(url);
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final res = await req.close().timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }
    return await res.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

/// Wire the real notification backends (Android). Kept out of main()'s
/// critical path: plugin init, the TZ database load and the reschedule all
/// happen after the first frame is on its way.
Future<void> _wireReminderBackends(ReminderService reminder) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
        tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier),
      );
    } catch (_) {
      // Unknown zone name => keep the timezone package default; a shifted
      // reminder hour is acceptable, a crash is not.
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_delve',
        'Daily Delve reminder',
        channelDescription:
            'One optional notification when a new Daily Delve seed is live.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    reminder.permissionBackend = () async =>
        await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
    reminder.scheduleBackend = (id, when, title, body) => plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    reminder.cancelAllBackend = () => plugin.cancelAll();
    await reminder.rescheduleIfEnabled();
  } catch (_) {
    // Notifications unavailable => the Settings section stays hidden.
  }
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
      builder: (context, child) {
        // Feed the OS accessibility flag into the reduce-motion resolver;
        // this builder re-runs whenever the system setting changes.
        Motion.instance.update(
          systemFlag: MediaQuery.of(context).disableAnimations,
        );
        return child!;
      },
      home: TelemetryConsentGate(child: GameRoot(widget.controller)),
    );
  }
}
