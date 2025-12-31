import 'language.dart';

class Subtitle {
  final String id;
  final String original;
  final Language detectedLanguage;
  final String korean;
  final String english;
  final DateTime timestamp;
  final Duration? audioDuration;

  Subtitle({
    String? id,
    required this.original,
    required this.detectedLanguage,
    required this.korean,
    required this.english,
    DateTime? timestamp,
    this.audioDuration,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  Subtitle copyWith({
    String? original,
    Language? detectedLanguage,
    String? korean,
    String? english,
    Duration? audioDuration,
  }) {
    return Subtitle(
      id: id,
      original: original ?? this.original,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      korean: korean ?? this.korean,
      english: english ?? this.english,
      timestamp: timestamp,
      audioDuration: audioDuration ?? this.audioDuration,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'original': original,
        'detectedLanguage': detectedLanguage.code,
        'korean': korean,
        'english': english,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Subtitle.fromJson(Map<String, dynamic> json) => Subtitle(
        id: json['id'],
        original: json['original'],
        detectedLanguage: Language.fromCode(json['detectedLanguage']),
        korean: json['korean'],
        english: json['english'],
        timestamp: DateTime.parse(json['timestamp']),
      );

  factory Subtitle.empty() => Subtitle(
        original: '',
        detectedLanguage: Language.auto,
        korean: '',
        english: '',
      );

  bool get isEmpty => original.isEmpty && korean.isEmpty && english.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

class TranscriptionResult {
  final String text;
  final String language;
  final double confidence;
  final List<WordTiming>? words;

  TranscriptionResult({
    required this.text,
    required this.language,
    this.confidence = 1.0,
    this.words,
  });

  factory TranscriptionResult.fromWhisperResponse(Map<String, dynamic> json) {
    return TranscriptionResult(
      text: json['text'] ?? '',
      language: json['language'] ?? 'unknown',
      confidence: (json['confidence'] ?? 1.0).toDouble(),
    );
  }
}

class WordTiming {
  final String word;
  final double start;
  final double end;

  WordTiming({
    required this.word,
    required this.start,
    required this.end,
  });
}

class TranslationResult {
  final String korean;
  final String english;
  final String? nativeNote; // 네이티브 뉘앙스 설명

  TranslationResult({
    required this.korean,
    required this.english,
    this.nativeNote,
  });
}
