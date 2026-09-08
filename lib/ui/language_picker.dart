import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'theme.dart';
import 'widgets.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Panel(
    key: const ValueKey('language-picker'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.language, color: EmberColors.gold),
            const SizedBox(width: Space.s),
            Expanded(
              child: Text(tr(context, 'Language'), style: EmberText.body),
            ),
          ],
        ),
        const SizedBox(height: Space.s),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: const ValueKey('game-language'),
            value: GameLanguage.validChoice(GameLanguage.choice.value),
            isExpanded: true,
            dropdownColor: EmberColors.surface,
            items: [
              for (final item in languageChoices.entries)
                DropdownMenuItem(
                  value: item.key,
                  child: Text(
                    item.key == 'system' ? tr(context, item.value) : item.value,
                    style: EmberText.body,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
        const SizedBox(height: Space.s),
        Text(
          tr(
            context,
            'Menus, the play guide and supporter tribute are translated. '
            'Some stories and advanced descriptions remain in English.',
          ),
          key: const ValueKey('translation-coverage'),
          style: EmberText.label,
        ),
      ],
    ),
  );
}
