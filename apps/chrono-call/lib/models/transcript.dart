import 'dart:convert';

class TranscriptSegment {
  final double start;
  final double end;
  final String text;
  final String? speaker; // Phase 3: speaker diarization

  TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
    this.speaker,
  });

  String get startFormatted => _formatTime(start);
  String get endFormatted => _formatTime(end);

  static String _formatTime(double seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'text': text,
    if (speaker != null) 'speaker': speaker,
  };

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      text: json['text'] as String,
      speaker: json['speaker'] as String?,
    );
  }
}

class Transcript {
  final String id;
  final String fileName;
  final String filePath;
  final DateTime createdAt;
  final String fullText;
  final List<TranscriptSegment> segments;
  final Duration audioDuration;
  final String language;

  Transcript({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.createdAt,
    required this.fullText,
    required this.segments,
    required this.audioDuration,
    this.language = 'ko',
  });

  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# $fileName');
    buf.writeln('');
    buf.writeln('- Date: ${createdAt.toIso8601String().substring(0, 10)}');
    buf.writeln('- Duration: ${_fmtDuration(audioDuration)}');
    buf.writeln('- Language: $language');
    buf.writeln('');
    buf.writeln('---');
    buf.writeln('');

    if (segments.isNotEmpty) {
      for (final seg in segments) {
        final prefix = seg.speaker != null ? '[${seg.speaker}] ' : '';
        buf.writeln('[${seg.startFormatted}] $prefix${seg.text}');
      }
    } else {
      buf.writeln(fullText);
    }

    return buf.toString();
  }

  String toShareText() {
    final buf = StringBuffer();
    buf.writeln('[ChronoCall] ${createdAt.toIso8601String().substring(0, 10)} $fileName');
    buf.writeln('');
    if (segments.isNotEmpty) {
      for (final seg in segments) {
        final prefix = seg.speaker != null ? '${seg.speaker}: ' : '';
        buf.writeln('$prefix${seg.text}');
      }
    } else {
      buf.writeln(fullText);
    }
    return buf.toString();
  }

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'filePath': filePath,
    'createdAt': createdAt.toIso8601String(),
    'fullText': fullText,
    'segments': segments.map((s) => s.toJson()).toList(),
    'audioDurationMs': audioDuration.inMilliseconds,
    'language': language,
  };

  factory Transcript.fromJson(Map<String, dynamic> json) {
    return Transcript(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      fullText: json['fullText'] as String,
      segments: (json['segments'] as List)
          .map((s) => TranscriptSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
      audioDuration: Duration(milliseconds: json['audioDurationMs'] as int),
      language: json['language'] as String? ?? 'ko',
    );
  }

  static List<Transcript> listFromJsonString(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => Transcript.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJsonString(List<Transcript> transcripts) {
    return jsonEncode(transcripts.map((t) => t.toJson()).toList());
  }
}
