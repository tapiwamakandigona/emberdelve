// game/input_intent.dart — one input struct shared by touch, keyboard, tests.
class InputIntent {
  double dirX = 0; // -1..1
  bool down = false; // held: camera peek / drop through platforms
  bool jumpPressed = false; // edge, consumed by player
  bool jumpHeld = false;
  bool attackPressed = false; // edge
  bool throwPressed = false; // edge

  void clearEdges() {
    jumpPressed = false;
    attackPressed = false;
    throwPressed = false;
  }
}
