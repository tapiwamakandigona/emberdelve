// test/motion_test.dart — The Still Flame, headless half (v0.16.0).
//
//   1. AudioSettings round-trips reduceMotion; absent/garbage keys default
//      to 'system' (old settings files keep working).
//   2. Motion resolver truth table: 'system' follows the OS flag, 'on' and
//      'off' override it in both directions.
//   3. The resolver notifies exactly when the answer flips, not on every
//      write (continuously-visible FX listen to it).
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/audio/settings.dart';
import 'package:emberdelve/ui/motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Motion.instance.reset);

  test('settings round-trip reduceMotion; bad values fall back to system', () {
    final s = AudioSettings()..reduceMotion = 'on';
    final back = AudioSettings.fromJson(s.toJson().cast<String, dynamic>());
    expect(back.reduceMotion, 'on');
    expect(AudioSettings.fromJson(const {}).reduceMotion, 'system');
    expect(
      AudioSettings.fromJson(const {'reduceMotion': 'sideways'}).reduceMotion,
      'system',
    );
  });

  test('resolver truth table', () {
    final m = Motion.instance;
    // system + flag
    m.update(setting: 'system', systemFlag: false);
    expect(m.reduced, isFalse);
    m.update(systemFlag: true);
    expect(m.reduced, isTrue);
    // explicit on/off beat the flag both ways
    m.update(setting: 'off');
    expect(m.reduced, isFalse);
    m.update(setting: 'on', systemFlag: false);
    expect(m.reduced, isTrue);
    // garbage setting is ignored, answer unchanged
    m.update(setting: 'sideways');
    expect(m.setting, 'on');
    expect(m.reduced, isTrue);
  });

  test('notifies only when the answer flips', () {
    final m = Motion.instance;
    var fired = 0;
    m.addListener(() => fired++);
    addTearDown(() => m.dispose); // listener drops with reset
    m.update(setting: 'system', systemFlag: false); // false -> false
    expect(fired, 0);
    m.update(setting: 'on'); // false -> true
    expect(fired, 1);
    m.update(systemFlag: true); // true -> true ('on' masks the flag)
    expect(fired, 1);
    m.update(setting: 'off'); // true -> false
    expect(fired, 2);
  });
}
