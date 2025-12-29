import 'package:flutter/material.dart';
import '../models/tts_item.dart';

class TTSItemCard extends StatelessWidget {
  final TTSItem item;
  final int index;
  final bool enabled;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TTSItemCard({
    super.key,
    required this.item,
    required this.index,
    this.enabled = true,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOverLimit = item.charCount > 1100;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverLimit
              ? const Color(0xFFF85149).withValues(alpha: 0.3)
              : const Color(0xFF21262D),
          child: Text(
            item.id,
            style: TextStyle(
              fontSize: 12,
              color: isOverLimit ? const Color(0xFFF85149) : Colors.white,
            ),
          ),
        ),
        title: Text(
          item.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: isOverLimit
            ? Text(
                '${item.charCount}/1100 - Too long!',
                style: const TextStyle(color: Color(0xFFF85149), fontSize: 11),
              )
            : null,
        trailing: enabled
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${item.charCount}',
                    style: TextStyle(
                      color: isOverLimit
                          ? const Color(0xFFF85149)
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (onEdit != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: onEdit,
                      color: Colors.grey[500],
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onDelete,
                      color: Colors.grey[500],
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              )
            : Text(
                '${item.charCount}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
      ),
    );
  }
}
