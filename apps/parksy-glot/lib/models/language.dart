enum Language {
  auto('auto', '자동 감지', '🌐'),
  english('en', 'English', '🇺🇸'),
  korean('ko', '한국어', '🇰🇷'),
  japanese('ja', '日本語', '🇯🇵'),
  spanish('es', 'Español', '🇪🇸'),
  french('fr', 'Français', '🇫🇷'),
  german('de', 'Deutsch', '🇩🇪'),
  chinese('zh', '中文', '🇨🇳'),
  portuguese('pt', 'Português', '🇧🇷'),
  italian('it', 'Italiano', '🇮🇹'),
  russian('ru', 'Русский', '🇷🇺');

  final String code;
  final String displayName;
  final String flag;

  const Language(this.code, this.displayName, this.flag);

  static Language fromCode(String code) {
    return Language.values.firstWhere(
      (l) => l.code == code,
      orElse: () => Language.auto,
    );
  }

  String get label => '$flag $displayName';
}

class LanguagePair {
  final Language source;
  final Language target1; // Korean
  final Language target2; // English

  const LanguagePair({
    required this.source,
    this.target1 = Language.korean,
    this.target2 = Language.english,
  });
}
