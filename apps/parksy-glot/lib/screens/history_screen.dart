import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/storage_service.dart';
import '../models/subtitle.dart';
import '../utils/constants.dart';
import '../widgets/dual_subtitle.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SessionInfo> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    final sessions = await StorageService.listSessions();
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _deleteSession(SessionInfo session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('세션 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '${session.title}을(를) 삭제하시겠습니까?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteSession(session.sessionId);
      _loadSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('저장된 세션'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _buildEmptyState()
              : _buildSessionList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '저장된 세션이 없습니다',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return _SessionCard(
          session: session,
          onTap: () => _openSession(session),
          onDelete: () => _deleteSession(session),
        );
      },
    );
  }

  void _openSession(SessionInfo session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(sessionId: session.sessionId),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionInfo session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.subtitles,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.subtitleCount}개 자막 • ${_formatDate(session.createdAt)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.white.withOpacity(0.5),
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '오늘 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '어제';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  SessionData? _sessionData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final data = await StorageService.loadSession(widget.sessionId);
    setState(() {
      _sessionData = data;
      _loading = false;
    });
  }

  Future<void> _exportSession(ExportFormat format) async {
    if (_sessionData == null) return;

    String content;
    switch (format) {
      case ExportFormat.txt:
        content = await StorageService.exportAsText(_sessionData!.subtitles);
        break;
      case ExportFormat.srt:
        content = await StorageService.exportAsSrt(_sessionData!.subtitles);
        break;
      case ExportFormat.json:
        content = await StorageService.exportAsJson(_sessionData!.subtitles);
        break;
    }

    final path = await StorageService.saveExport(
      content: content,
      filename: _sessionData!.info.sessionId,
      format: format,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장됨: $path'),
          action: SnackBarAction(
            label: '공유',
            onPressed: () => Share.shareXFiles([XFile(path)]),
          ),
        ),
      );
    }
  }

  Future<void> _copyAllText() async {
    if (_sessionData == null) return;

    final text = await StorageService.exportAsText(_sessionData!.subtitles);
    await Clipboard.setData(ClipboardData(text: text));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클립보드에 복사됨')),
      );
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '내보내기 형식',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _ExportOption(
              icon: Icons.text_snippet,
              title: '텍스트 (.txt)',
              subtitle: '일반 텍스트 형식',
              onTap: () {
                Navigator.pop(context);
                _exportSession(ExportFormat.txt);
              },
            ),
            _ExportOption(
              icon: Icons.subtitles,
              title: '자막 (.srt)',
              subtitle: 'SRT 자막 파일',
              onTap: () {
                Navigator.pop(context);
                _exportSession(ExportFormat.srt);
              },
            ),
            _ExportOption(
              icon: Icons.code,
              title: 'JSON (.json)',
              subtitle: '개발자용 데이터',
              onTap: () {
                Navigator.pop(context);
                _exportSession(ExportFormat.json);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_sessionData?.info.title ?? '로딩 중...'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyAllText,
            tooltip: '전체 복사',
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: _showExportOptions,
            tooltip: '내보내기',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessionData == null
              ? const Center(child: Text('세션을 찾을 수 없습니다'))
              : _buildSubtitleList(),
    );
  }

  Widget _buildSubtitleList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _sessionData!.subtitles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final subtitle = _sessionData!.subtitles[index];
        return _SubtitleCard(
          index: index + 1,
          subtitle: subtitle,
        );
      },
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withOpacity(0.5)),
      ),
      onTap: onTap,
    );
  }
}

class _SubtitleCard extends StatelessWidget {
  final int index;
  final Subtitle subtitle;

  const _SubtitleCard({
    required this.index,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#$index',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subtitle.detectedLanguage.flag,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 4),
              Text(
                subtitle.detectedLanguage.displayName,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (subtitle.original.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              subtitle.original,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🇰🇷', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle.korean,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🇺🇸', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle.english,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
