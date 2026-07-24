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

  static Future<void> persist() => _store.save(save);
}
