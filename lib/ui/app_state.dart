// ui/app_state.dart — single mutable app-state holder (save + store).
// Kept deliberately tiny: screens read AppState.save, mutate, then
// AppState.persist(). No state-management framework needed at this scale.
import '../core/save.dart';

class AppState {
  static late SaveStore _store;
  static late SaveData save;
  static bool _ready = false;

  static void init({required SaveStore store, required SaveData save}) {
    _store = store;
    AppState.save = save;
    _ready = true;
  }

  static bool get isReady => _ready;

  /// Persist the current save. Writes are chained on a queue so rapid
  /// buy/equip taps can never interleave bytes in the save file (same
  /// durability contract as SettingsStore.save).
  static Future<void> _writes = Future.value();

  /// Widget tests set this false: real file IO started inside a FakeAsync
  /// test zone can never complete (cross-zone deadlock). Disk round-trips
  /// are covered by headless tests instead.
  static bool diskWrites = true;

  static Future<void> persist() {
    if (!diskWrites) return Future.value();
    final next = _writes.then((_) => _store.save(save));
    _writes = next.catchError((_) {});
    return next;
  }
}
