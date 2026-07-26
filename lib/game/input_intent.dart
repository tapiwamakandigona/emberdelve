// game/input_intent.dart — one input struct shared by touch, keyboard, tests.
class InputIntent {
  double dirX = 0; // -1..1
  bool down = false; // held: camera peek / drop through platforms
  bool jumpPressed = false; // edge, consumed by player
  bool jumpHeld = false;
  bool attackPressed = false; // edge
  bool throwPressed = false; // edge
  // AKP-4c: held while the throw button is down — drives the apple arc
  // preview only, never gameplay. Not an edge: not cleared by clearEdges.
  bool throwHeld = false;
  // AKP-2a: dash/roll as a first-class verb (dedicated touch button + Shift).
  // The DOWN+JUMP chord in PlayerCore still works as a keyboard alternative.
  bool rollPressed = false; // edge

  void clearEdges() {
    jumpPressed = false;
    attackPressed = false;
    throwPressed = false;
    rollPressed = false;
  }
}
