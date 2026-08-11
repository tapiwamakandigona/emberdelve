// Haptics gating: impact haptics must respect the persisted setting and be
// silent (not crash) when audio/settings never initialized.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emberwood/audio/audio_service.dart';
import 'package:emberwood/audio/settings.dart';
import 'package:emberwood/game/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    AudioService.instance = null;
  });

  test('no AudioService -> haptics are silently off', () {
    AudioService.instance = null;
    Haptics.medium();
    expect(calls, isEmpty);
  });

  test('setting off -> no vibration; on -> impact fires', () async {
    AudioService.instance = AudioService(AudioSettings(haptics: false));
    Haptics.light();
    Haptics.medium();
    Haptics.heavy();
    await null; // flush platform channel microtasks
    expect(calls, isEmpty);

    AudioService.instance!.settings.haptics = true;
    Haptics.light();
    Haptics.medium();
    Haptics.heavy();
    await null;
    expect(calls, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });
}
