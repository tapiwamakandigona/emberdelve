// THE FIRST SPARK: the shader warm-up scene must stay drawable.
//
// EmberShaderWarmUp runs once at boot, before the first frame — if any
// draw-op in it throws, startup breaks silently-ish (warm-up failure is
// easy to miss in the field). This pin rasterizes the exact scene the
// way ShaderWarmUp.execute does. It cannot verify GPU-side compilation
// (test env is software Skia); it verifies the scene is valid and stays
// in step with the paint code it mirrors.
import 'package:flutter_test/flutter_test.dart';
import 'package:emberdelve/ui/warmup.dart';

void main() {
  test('warm-up scene rasterizes without error', () async {
    const w = EmberShaderWarmUp();
    await w.execute(); // draws + toImage; throws on any invalid op
  });
}
