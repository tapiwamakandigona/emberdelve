// test/haptics_test.dart — the v0.3.4 haptics rebuild.
//
// Guards the owner-reported v0.3.2 bug: the in-game Haptics toggle did
// nothing on devices where the system "touch feedback" setting is off,
// because HapticFeedback.*Impact() is gated by that setting. The fix drives
// the Android Vibrator directly through the `emberdelve/haptics` channel.
//
// Verifies: (1) beats hit the platform channel with per-beat duration and
// amplitude, (2) the settings toggle gates everything, (3) when the channel
// reports no vibrator (false) or is missing entirely, the HapticFeedback
// fallback fires instead — and nothing ever throws.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emberdelve/audio/audio_service.dart';
import 'package:emberdelve/audio/settings.dart';
import 'package:emberdelve/ui/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger;

  final channelCalls = <MethodCall>[];
  final systemCalls = <MethodCall>[];

  void mockChannel({required dynamic reply}) {
    messenger.setMockMethodCallHandler(Haptics.channel, (call) async {
      channelCalls.add(call);
      return reply;
    });
  }

  void mockSystem() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      systemCalls.add(call);
      return null;
    });
  }

  setUp(() {
    channelCalls.clear();
    systemCalls.clear();
    AudioService.instance = AudioService(AudioSettings(haptics: true));
    mockSystem();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(Haptics.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    AudioService.instance = null;
  });

  // Let the async _beat future chain (channel send -> possible
  // MissingPluginException -> fallback send) fully drain.
  Future<void> settle() => pumpEventQueue();

  test('beats reach the vibrator channel with per-beat ms/amplitude',
      () async {
    mockChannel(reply: true);

    Haptics.light();
    Haptics.medium();
    Haptics.heavy();
    await settle();

    expect(channelCalls, hasLength(3));
    expect(channelCalls.every((c) => c.method == 'vibrate'), isTrue);
    final light = channelCalls[0].arguments as Map;
    final medium = channelCalls[1].arguments as Map;
    final heavy = channelCalls[2].arguments as Map;
    // Escalating strength: light < medium < heavy on both axes.
    expect((light['ms'] as int) < (medium['ms'] as int), isTrue);
    expect((medium['ms'] as int) < (heavy['ms'] as int), isTrue);
    expect(
        (light['amplitude'] as int) < (medium['amplitude'] as int), isTrue);
    expect(
        (medium['amplitude'] as int) < (heavy['amplitude'] as int), isTrue);
    // Vibrator handled it — no HapticFeedback fallback.
    expect(systemCalls, isEmpty);
  });

  test('settings toggle OFF silences every beat', () async {
    mockChannel(reply: true);
    AudioService.instance!.settings.haptics = false;

    Haptics.light();
    Haptics.medium();
    Haptics.heavy();
    await settle();

    expect(channelCalls, isEmpty);
    expect(systemCalls, isEmpty);
  });

  test('null AudioService (widget tests) means haptics stay off', () async {
    mockChannel(reply: true);
    AudioService.instance = null;

    Haptics.heavy();
    await settle();

    expect(channelCalls, isEmpty);
  });

  test('channel reporting no vibrator falls back to HapticFeedback',
      () async {
    mockChannel(reply: false);

    Haptics.heavy();
    await settle();

    expect(channelCalls, hasLength(1));
    expect(systemCalls, hasLength(1));
    expect(systemCalls.single.method, 'HapticFeedback.vibrate');
  });

  test('missing channel (no platform impl) falls back without throwing',
      () async {
    // No mockChannel: invokeMethod throws MissingPluginException.
    Haptics.medium();
    await settle();

    expect(systemCalls, hasLength(1));
    expect(systemCalls.single.method, 'HapticFeedback.vibrate');
  });

  test('preview buzzes even before settings are consulted', () async {
    mockChannel(reply: true);
    AudioService.instance = null; // even with no service at all

    Haptics.preview();
    await settle();

    expect(channelCalls, hasLength(1));
  });
}
