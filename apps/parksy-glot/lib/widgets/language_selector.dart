import 'package:flutter/material.dart';
import '../models/language.dart';

class LanguageSelector extends StatelessWidget {
  final Language selectedLanguage;
  final ValueChanged<Language> onChanged;
  final bool compact;

  const LanguageSelector({
    super.key,
    required this.selectedLanguage,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLanguagePicker(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedLanguage.flag,
              style: TextStyle(fontSize: compact ? 14 : 18),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Text(
                selectedLanguage.displayName,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white.withOpacity(0.7),
              size: compact ? 18 : 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _LanguagePickerSheet(
        selectedLanguage: selectedLanguage,
        onSelected: (lang) {
          onChanged(lang);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  final Language selectedLanguage;
  final ValueChanged<Language> onSelected;

  const _LanguagePickerSheet({
    required this.selectedLanguage,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '소스 언어 선택',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Language list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: Language.values.length,
              itemBuilder: (context, index) {
                final lang = Language.values[index];
                final isSelected = lang == selectedLanguage;

                return ListTile(
                  leading: Text(
                    lang.flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    lang.displayName,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : Colors.white.withOpacity(0.9),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle,
                          color: Color(0xFF6366F1),
                        )
                      : null,
                  onTap: () => onSelected(lang),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
