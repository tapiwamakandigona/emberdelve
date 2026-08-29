// test/delvers_window_test.dart — v0.115.0 The Delver's Window.
//
// Vistas worn per delver, same shape as charDye (v0.67.0): absent key =
// legacy global selection, unlocks stay global and derived, the picker
// binds to the delver being dressed, and the delve paints the RUN
// delver's window.
import 'package:emberdelve/data/vistas.dart';
import 'package:emberdelve/game/controller.dart';
import 'package:emberdelve/meta/cloud_merge.dart';
import 'package:emberdelve/meta/meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('vistaFor: own binding, else the legacy global selection', () {
    final m = MetaState()..selectedVista = 'moonveil';
    expect(m.vistaFor('kindler'), 'moonveil');
    m.charVista['kindler'] = 'deepshale';
    expect(m.vistaFor('kindler'), 'deepshale');
    expect(m.vistaFor('warden'), 'moonveil', reason: 'others keep the global');
  });

  test('round-trip persists; junk chars and junk vistas are dropped', () {
    final m = MetaState();
    m.charVista['kindler'] = 'deepshale';
    final back = MetaState.fromJson(m.toJson());
    expect(back.charVista, {'kindler': 'deepshale'});
    final junk = MetaState.fromJson({
      'charVista': {'kindler': 'not_a_vista', 'not_a_delver': 'moonveil'},
    });
    expect(junk.charVista, isEmpty);
    // Absent key stays byte-identical for old saves.
    expect(MetaState().toJson().containsKey('charVista'), isFalse);
  });

  test('setVistaFor guards: locked vista, locked delver, then binds', () {
    final c = GameController();
    c.setVistaFor('deepshale', forChar: 'kindler');
    expect(c.meta.charVista, isEmpty, reason: 'locked vista refused');
    c.meta.bestFloor = 9; // deepshale milestone
    c.setVistaFor('deepshale', forChar: 'warden');
    expect(
      c.meta.charVista,
      isEmpty,
      reason: 'locked delver refused (fresh profile owns only the kindler)',
    );
    c.setVistaFor('deepshale', forChar: 'kindler');
    expect(c.meta.charVista['kindler'], 'deepshale');
    c.setVistaFor('nope', forChar: 'kindler');
    expect(c.meta.charVista['kindler'], 'deepshale');
  });

  test('the delve paints the run delver\'s window', () {
    final c = GameController();
    c.meta.bestFloor = 9;
    c.setVistaFor('deepshale', forChar: 'kindler');
    expect(
      c.activeRunVista,
      c.meta.selectedVista,
      reason: 'no run: the global selection paints (title, ledger)',
    );
    c.startRun(character: 'kindler', seed: 1, difficulty: 'easy');
    expect(c.activeRunVista, 'deepshale');
    c.startRun(character: 'warden', seed: 1, difficulty: 'easy');
    expect(
      c.activeRunVista,
      c.meta.selectedVista,
      reason: 'an unbound delver runs under the global selection',
    );
  });

  test('cloud merge keeps the fresh bindings (charDye precedent)', () {
    final local = MetaState()..charVista['kindler'] = 'deepshale';
    final merged = mergeMetaStates(local, MetaState());
    expect(merged.charVista, {'kindler': 'deepshale'});
  });

  test('every binding target the picker offers is a real vista', () {
    for (final id in vistasOrder) {
      expect(vistas.containsKey(id), isTrue, reason: id);
    }
  });
}
