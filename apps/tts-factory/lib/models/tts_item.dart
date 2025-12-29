class TTSItem {
  final String id;
  String text;

  TTSItem({required this.id, required this.text});

  int get charCount => text.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'max_chars': 1100,
      };

  static List<TTSItem> parseFromText(String content) {
    final lines = content.split('\n');
    final items = <TTSItem>[];
    int idx = 1;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      items.add(TTSItem(
        id: idx.toString().padLeft(2, '0'),
        text: trimmed,
      ));
      idx++;
    }
    return items;
  }

  static String? validate(List<TTSItem> items) {
    if (items.isEmpty) return 'No items to process';
    if (items.length > 25) return 'Max 25 items allowed';

    for (int i = 0; i < items.length; i++) {
      if (items[i].text.length > 1100) {
        return 'Item ${i + 1} exceeds 1100 chars';
      }
    }
    return null;
  }
}

enum JobStatus {
  idle('Ready'),
  queued('Queued...'),
  processing('Processing...'),
  downloading('Downloading...'),
  completed('Completed');

  final String label;
  const JobStatus(this.label);
}
