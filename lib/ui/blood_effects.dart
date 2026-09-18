// Presentation-only comfort preference. Seeded from SettingsStore in main,
// changed in Settings, and observed by the combat body/effect bands.
// Never read this from the simulation or include it in a run/save seed.
import 'package:flutter/foundation.dart';

abstract final class BloodEffects {
  // Preserve the existing presentation for installs without this preference.
  static final ValueNotifier<bool> enabled = ValueNotifier(true);
}
