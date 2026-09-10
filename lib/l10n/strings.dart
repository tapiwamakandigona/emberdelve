// Offline interface translations. English source is the deliberate fallback:
// untranslated lore is never guessed and user-written names are never looked up.
import 'package:flutter/material.dart';

import 'catalog.dart';

const languageChoices = <String, String>{
  'system': 'System',
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'pt': 'Português (Brasil)',
};

const gameLocales = [
  Locale('en'),
  Locale('fr'),
  Locale('es'),
  Locale('pt', 'BR'),
];

class GameLanguage {
  static final choice = ValueNotifier<String>('system');

  static String validChoice(Object? value) =>
      value is String && languageChoices.containsKey(value) ? value : 'system';

  static Locale? localeFor(String value) => switch (value) {
    'en' => const Locale('en'),
    'fr' => const Locale('fr'),
    'es' => const Locale('es'),
    'pt' => const Locale('pt', 'BR'),
    _ => null,
  };
}

String translated(
  String english,
  String languageCode, {
  Map<String, Object> args = const {},
}) {
  var value = interfaceCatalog[languageCode]?[english] ?? english;
  // Replace placeholders in ONE pass. A player's name containing "{name}"
  // stays literally their name; it can never become another substitution.
  if (args.isNotEmpty) {
    value = value.replaceAllMapped(RegExp(r'\{([a-zA-Z]+)\}'), (match) {
      return args[match[1]]?.toString() ?? match[0]!;
    });
  }
  return value;
}

String tr(
  BuildContext context,
  String english, {
  Map<String, Object> args = const {},
}) => translated(
  english,
  Localizations.maybeLocaleOf(context)?.languageCode ?? 'en',
  args: args,
);
