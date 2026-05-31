import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api_config.dart';
import '../widgets/stat_item.dart';
import '../widgets/ai_search_tab.dart';
import '../widgets/tools_tab.dart';
import 'settings_screen.dart';
import 'log_detail_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.parksy.capture/share');
  String get _githubRepoUrl => ApiConfig.githubRepo != null
      ? 'https://github.com/${ApiConfig.githubRepo}/tree/main/logs'
      : '';
  // Logs tab state
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _showStarredOnly = false;
  String _searchQuery = '';
  String _sortBy = 'date';
  final TextEditingController _searchController = TextEditingController();
  // Tab controller
  late TabController _tabController;
  // Tools state
  bool _isExporting = false;
  String? _exportResult;
  // MCP Generator state
  bool _isGeneratingMCP = false;
  String? _mcpResult;
  // AI Search state
  bool _isAiSearching = false;
  String? _aiAnswer;
  List<Map<String, dynamic>> _aiReferences = [];
  String? _aiError;
  // Search mode: 'search' or 'generate'
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final logs = await platform.invokeMethod<List>('getLogFiles');
      final stats = await platform.invokeMethod<Map>('getStats');
      setState(() {
        _logs = logs?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        _stats = Map<String, dynamic>.from(stats ?? {});
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  void _applyFilters() {
    var filtered = List<Map<String, dynamic>>.from(_logs);
    if (_showStarredOnly) {
      filtered = filtered.where((log) => log['starred'] == true).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((log) {
        final name = (log['name'] as String).toLowerCase();
        final preview = (log['preview'] as String? ?? '').toLowerCase();
        return name.contains(query) || preview.contains(query);
      }).toList();
    }
    switch (_sortBy) {
      case 'size':
        filtered.sort((a, b) => (b['size'] as int).compareTo(a['size'] as int));
        break;
      case 'name':
        filtered.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        break;
      default:
        filtered.sort((a, b) => (b['modified'] as int).compareTo(a['modified'] as int));
    }
    _filteredLogs = filtered;
  }
  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _searchQuery = '';
      _applyFilters();
      setState(() {});
      return;
    }
    try {
      final results = await platform.invokeMethod<List>('searchLogs', {'query': query});
      setState(() {
        _filteredLogs = results?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        _searchQuery = query;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }
  Future<void> _toggleStar(String filename, bool currentValue) async {
    await platform.invokeMethod('updateLogMeta', {
      'filename': filename,
      'starred': !currentValue,
    });
    _loadData();
  }
  Future<void> _deleteLog(String filename) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Delete Log'),
        content: Text('Delete "$filename"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF85149)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await platform.invokeMethod('deleteLogFile', {'filename': filename});
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted')),
        );
      }
    }
  }
  Future<void> _openGitHub() async {
    if (_githubRepoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GitHub Repo not configured. Go to Settings.')),
      );
      return;
    }
    final uri = Uri.parse(_githubRepoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  Future<void> _openSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (result == true) {
      setState(() {}); // Refresh to reflect new settings
    }
  }
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MM/dd').format(date);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLogsTab(),
                  AiSearchTab(
                    isAiConfigured: ApiConfig.isDeepSeekConfigured,
                    isSearching: _isAiSearching,
                    onSearch: _askAi,
                    aiAnswer: _aiAnswer,
                    aiError: _aiError,
                    aiReferences: _aiReferences,
                    onCopyAnswer: (text) {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied')),
                      );
                    },
                  ),
                  ToolsTab(
                    isExporting: _isExporting,
                    exportResult: _exportResult,
                    isGeneratingMCP: _isGeneratingMCP,
                    mcpResult: _mcpResult,
                    onExportJsonl: _exportAllJsonl,
                    onGenerateProfile: _generateProfile,
                    onGenerateMCP: _generateMCP,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openGitHub,
              backgroundColor: const Color(0xFF21262D),
              icon: const Icon(Icons.open_in_new, size: 20),
              label: const Text('View on GitHub'),
            )
          : null,
    );
  }
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        indicator: BoxDecoration(
          color: const Color(0xFF58A6FF).withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: const Color(0xFF58A6FF),
        unselectedLabelColor: Colors.grey,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_outlined, size: 18),
                SizedBox(width: 8),
                Text('Logs'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.psychology_outlined, size: 18),
                SizedBox(width: 8),
                Text('AI'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.build_outlined, size: 18),
                SizedBox(width: 8),
                Text('Tools'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildLogsTab() {
    return Column(
      children: [
        if (_stats.isNotEmpty) _buildStats(),
        _buildSearchBar(),
        Expanded(child: _buildList()),
      ],
    );
  }
  // ============================================================
  // TOOLS FUNCTIONS
  // ============================================================
  Future<void> _exportAllJsonl() async {
    setState(() {
      _isExporting = true;
      _exportResult = null;
    });
    try {
      final results = await platform.invokeMethod<List>('convertAllToJsonl');
      if (results == null || results.isEmpty) {
        setState(() {
          _isExporting = false;
          _exportResult = '변환할 로그가 없습니다.';
        });
        return;
      }
      final sb = StringBuffer();
      int totalLines = 0;
      for (final r in results) {
        final map = Map<String, dynamic>.from(r);
        final name = map['filename'] as String? ?? 'unknown';
        final count = map['count'] as int? ?? 0;
        totalLines += count;
        sb.writeln('✅ $name  (${count}개 메시지 쌍)');
      }
      sb.writeln('\n총 ${results.length}개 파일, $totalLines개 메시지 쌍');
      setState(() {
        _isExporting = false;
        _exportResult = sb.toString();
      });
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportResult = '오류: $e';
      });
    }
  }
  Future<void> _generateProfile() async {
    setState(() {
      _isExporting = true;
      _exportResult = null;
    });
    try {
      final result = await platform.invokeMethod<Map>('generateProfile');
      if (result == null || result.containsKey('error')) {
        setState(() {
          _isExporting = false;
          _exportResult = result?['error'] as String? ?? '프로파일 생성 실패';
        });
        return;
      }
      final profile = Map<String, dynamic>.from(result);
      final sb = StringBuffer();
      final isAI = profile['ai_analyzed'] == true;
      sb.writeln('📊 박씨 워딩 프로파일');
      sb.writeln('═══════════════════════');
      if (isAI) sb.writeln('🤖 AI 분석 (DeepSeek)');
      sb.writeln();
      if (isAI) {
        // === AI 기반 프로파일 포맷 ===
        final raw = profile['raw_profile'] as String?;
        if (raw != null) {
          sb.writeln(raw);
        } else {
          // 동사 패턴
          final verbPatterns = profile['verb_patterns'] as List<dynamic>? ?? [];
          if (verbPatterns.isNotEmpty) {
            sb.writeln('🔤 동사 패턴 (명령/지시형):');
            for (final v in verbPatterns) {
              final p = v as Map<String, dynamic>;
              sb.writeln('  • ${p['pattern']} (${p['count']}회) — ${p['context']}');
            }
            sb.writeln();
          }
          // 판단 표현
          final judgments = profile['judgment_expressions'] as List<dynamic>? ?? [];
          if (judgments.isNotEmpty) {
            sb.writeln('⚖️  판단/확인 표현:');
            for (final j in judgments) {
              final jm = j as Map<String, dynamic>;
              sb.writeln('  • ${jm['expression']} (${jm['count']}회) — ${jm['context']}');
            }
            sb.writeln();
          }
          // 의사결정 패턴
          final decisions = profile['decision_patterns'] as List<dynamic>? ?? [];
          if (decisions.isNotEmpty) {
            sb.writeln('🧠 의사결정 패턴:');
            for (final d in decisions) {
              final dm = d as Map<String, dynamic>;
              sb.writeln('  • ${dm['pattern']} (${dm['count']}회)');
              if (dm['example'] != null) sb.writeln('    예: ${dm['example']}');
            }
            sb.writeln();
          }
          // 도메인 용어
          final terms = profile['domain_terminology'] as List<dynamic>? ?? [];
          if (terms.isNotEmpty) {
            sb.writeln('📁 도메인 용어:');
            for (final t in terms) {
              final tm = t as Map<String, dynamic>;
              sb.writeln('  • ${tm['term']} (${tm['count']}회, ${tm['category'] ?? "?"})');
            }
            sb.writeln();
          }
          // 말투 스펙트럼
          final tone = profile['tone_spectrum'] as Map<String, dynamic>? ?? {};
          if (tone.isNotEmpty) {
            sb.writeln('🎭 말투 스펙트럼:');
            final toneList = tone.entries.toList()
              ..sort((a, b) => (b.value as num).compareTo(a.value as num));
            for (final entry in toneList) {
              final pct = ((entry.value as num) * 100).toStringAsFixed(0);
              final label = switch (entry.key) {
                'direct_command' => '직접 명령',
                'casual_question' => '편한 질문',
                'formal_statement' => '격식 진술',
                _ => entry.key,
              };
              sb.writeln('  • $label: $pct%');
            }
            sb.writeln();
          }
          // 커뮤니케이션 스타일
          final style = profile['communication_style'] as Map<String, dynamic>? ?? {};
          if (style.isNotEmpty) {
            sb.writeln('💬 커뮤니케이션 스타일:');
            sb.writeln('  • 문장 길이: ${style['avg_sentence_length'] ?? "?"}');
            sb.writeln('  • 이모지 사용: ${style['emoji_usage'] ?? "?"}');
            sb.writeln('  • 타이핑 스타일: ${style['typing_style'] ?? "?"}');
            sb.writeln('  • 격식 수준: ${style['formality'] ?? "?"}');
            final phrases = style['key_phrases'] as List<dynamic>? ?? [];
            if (phrases.isNotEmpty) {
              sb.writeln('  • 핵심 구문: ${phrases.join(", ")}');
            }
            sb.writeln();
          }
          // 액션 트리거
          final triggers = profile['action_triggers'] as List<dynamic>? ?? [];
          if (triggers.isNotEmpty) {
            sb.writeln('🚀 액션 트리거:');
            for (final t in triggers) {
              final tm = t as Map<String, dynamic>;
              sb.writeln('  • "${tm['trigger']}" → ${tm['intent']} (${tm['frequency']})');
            }
            sb.writeln();
          }
          // 추천 MCP 도구
          final tools = profile['recommended_mcp_tools'] as List<dynamic>? ?? [];
          if (tools.isNotEmpty) {
            sb.writeln('🛠️  추천 MCP 도구:');
            for (final t in tools) {
              final tm = t as Map<String, dynamic>;
              sb.writeln('  • ${tm['name']}: ${tm['description']} (trigger: ${tm['trigger']})');
            }
            sb.writeln();
          }
        }
        // 날짜 범위 (공통)
        final dates = profile['date_range'] as Map<String, dynamic>? ?? {};
        if (dates.isNotEmpty) {
          sb.writeln('📅 분석 기간: ${dates['earliest']} ~ ${dates['latest']}');
          sb.writeln('📁 로그 파일: ${profile['total_logs']}개');
        }
      } else {
        // === 규칙 기반 프로파일 포맷 (fallback) ===
        final vocab = profile['vocabulary'] as Map<String, dynamic>? ?? {};
        final freqTerms = (vocab['frequent_terms'] as List<dynamic>?) ?? [];
        sb.writeln('🔤 자주 사용하는 단어 (${vocab['total_unique_words']}개 고유 단어):');
        for (final word in freqTerms.take(15)) {
          sb.writeln('  • $word');
        }
        final patterns = (vocab['sentence_patterns'] as List<dynamic>?) ?? [];
        if (patterns.isNotEmpty) {
          sb.writeln();
          sb.writeln('💬 문장 패턴:');
          for (final p in patterns) {
            sb.writeln('  • $p');
          }
        }
        final domains = profile['domain_weights'] as Map<String, dynamic>? ?? {};
        if (domains.isNotEmpty) {
          sb.writeln();
          sb.writeln('📁 기술 도메인:');
          final domainList = domains.entries.toList()
            ..sort((a, b) => (b.value as num).compareTo(a.value as num));
          for (final entry in domainList) {
            final pct = ((entry.value as num) * 100).toStringAsFixed(0);
            sb.writeln('  • ${entry.key}: $pct%');
          }
        }
        final stats = profile['conversation_stats'] as Map<String, dynamic>? ?? {};
        sb.writeln();
        sb.writeln('📐 대화 통계:');
        sb.writeln('  • 총 턴: ${profile['total_turns']}');
        sb.writeln('  • User 길이: ${(stats['avg_user_tokens'] as num?)?.toStringAsFixed(0) ?? "?"}자');
        sb.writeln('  • Assistant 길이: ${(stats['avg_assistant_tokens'] as num?)?.toStringAsFixed(0) ?? "?"}자');
        final dates = profile['date_range'] as Map<String, dynamic>? ?? {};
        sb.writeln('  • 기간: ${dates['earliest']} ~ ${dates['latest']}');
      }
      setState(() {
        _isExporting = false;
        _exportResult = sb.toString();
      });
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportResult = '프로파일 오류: $e';
      });
    }
  }
  /// MCP 서버 코드 생성 (DeepSeek API 경유)
  Future<void> _generateMCP() async {
    setState(() {
      _isGeneratingMCP = true;
      _mcpResult = null;
    });
    try {
      // 먼저 프로파일 추출
      final profile = await platform.invokeMethod<Map>('generateProfile');
      if (profile == null || profile.containsKey('error')) {
        setState(() {
          _isGeneratingMCP = false;
          _mcpResult = profile?['error'] as String? ?? '프로파일이 없습니다. 먼저 프로파일을 추출해주세요.';
        });
        return;
      }
      // 프로파일을 JSON 문자열로 변환
      final profileJson = jsonEncode(profile);
      // MCP 생성 요청
      final code = await platform.invokeMethod<String>('generateMCP', {
        'profile': profileJson,
      }).timeout(const Duration(seconds: 35));
      setState(() {
        _isGeneratingMCP = false;
        _mcpResult = code ?? '생성 실패';
      });
    } catch (e) {
      setState(() {
        _isGeneratingMCP = false;
        _mcpResult = 'MCP 생성 오류: Settings에서 DeepSeek API 키를 확인하세요.\n$e';
      });
    }
  }
  Future<void> _askAi(String query, String mode) async {
    if (query.isEmpty) return;
    setState(() {
      _isAiSearching = true;
      _aiError = null;
      _aiAnswer = null;
      _aiReferences = [];
    });
    try {
      // 1. 로컬 텍스트 검색 (키워드)
      final searchResults = await platform.invokeMethod<List>('searchLogs', {'query': query});
      final refs = searchResults?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      // 2. DeepSeek API 직접 호출
      if (ApiConfig.isDeepSeekConfigured) {
        final contextText = refs.take(5).map((r) =>
          '--- ${r['name']} ---\n${r['preview'] ?? ''}'
        ).join('\n');
        final systemPrompt = mode == 'generate'
            ? '당신은 박씨의 개인 지식 비서입니다. 주어진 대화 로그를 분석하고 종합하여 명확하게 답변하세요. 한국어로 응답하세요.'
            : '당신은 박씨의 개인 지식 비서입니다. 주어진 대화 로그에서 질문과 관련된 내용을 찾아 인용하여 답변하세요. 한국어로 응답하세요.';
        final userPrompt = contextText.isNotEmpty
            ? '참고 대화 로그:\n$contextText\n\n질문: $query'
            : query;
        final res = await http.post(
          Uri.parse('https://api.deepseek.com/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${ApiConfig.deepseekKey}',
          },
          body: jsonEncode({
            'model': 'deepseek-chat',
            'max_tokens': 2048,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
          }),
        ).timeout(const Duration(seconds: 30));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          setState(() {
            _isAiSearching = false;
            _aiAnswer = data['choices'][0]['message']['content'] as String? ?? '응답 없음';
            _aiReferences = refs;
          });
          return;
        }
      }
      // 3. DeepSeek 없으면 로컬 검색 결과만 표시
      setState(() {
        _isAiSearching = false;
        _aiAnswer = refs.isEmpty
            ? '관련 기록을 찾을 수 없습니다.\nSettings에서 DeepSeek API 키를 설정하면 AI가 분석해드립니다.'
            : '🔍 ${refs.length}개의 관련 기록을 찾았습니다.\nSettings에서 DeepSeek API 키를 설정하면 AI 분석이 가능합니다.';
        _aiReferences = refs;
      });
    } catch (e) {
      setState(() {
        _isAiSearching = false;
        _aiError = e.toString();
      });
    }
  }
  // ============================================================
  // LOGS TAB UI
  // ============================================================
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const Icon(Icons.catching_pokemon, color: Color(0xFF58A6FF), size: 28),
          const SizedBox(width: 12),
          const Text(
            'Parksy Capture',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAbout(),
          ),
        ],
      ),
    );
  }
  Widget _buildStats() {
    final total = _stats['totalLogs'] ?? 0;
    final starred = _stats['starredCount'] ?? 0;
    final size = _formatSize(_stats['totalSize'] ?? 0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          StatItem(label: 'Logs', value: '$total'),
          StatItem(label: 'Starred', value: '$starred'),
          StatItem(label: 'Size', value: size),
        ],
      ),
    );
  }
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search logs...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => _search(value),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _showStarredOnly ? const Color(0xFF58A6FF).withOpacity(0.2) : const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showStarredOnly ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
              ),
            ),
            child: IconButton(
              icon: Icon(
                _showStarredOnly ? Icons.star : Icons.star_border,
                color: _showStarredOnly ? const Color(0xFF58A6FF) : Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _showStarredOnly = !_showStarredOnly;
                  _applyFilters();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            color: const Color(0xFF161B22),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _applyFilters();
              });
            },
            itemBuilder: (context) => [
              _buildSortItem('date', 'Date', Icons.schedule),
              _buildSortItem('size', 'Size', Icons.storage),
              _buildSortItem('name', 'Name', Icons.sort_by_alpha),
            ],
          ),
        ],
      ),
    );
  }
  PopupMenuItem<String> _buildSortItem(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? const Color(0xFF58A6FF) : Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: isSelected ? const Color(0xFF58A6FF) : Colors.white)),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check, size: 18, color: Color(0xFF58A6FF)),
          ],
        ],
      ),
    );
  }
  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox,
              size: 64,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No results found' : 'No logs yet',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Share text from browser to capture',
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF58A6FF),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredLogs.length,
        itemBuilder: (context, index) => _buildLogCard(_filteredLogs[index]),
      ),
    );
  }
  Widget _buildLogCard(Map<String, dynamic> log) {
    final name = log['name'] as String;
    final size = log['size'] as int;
    final modified = log['modified'] as int;
    final preview = log['preview'] as String? ?? '';
    final starred = log['starred'] as bool? ?? false;
    final displayName = name.replaceAll('ParksyLog_', '').replaceAll('.md', '');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LogDetailScreen(filename: name)),
          ).then((_) => _loadData());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _toggleStar(name, starred),
                    child: Icon(
                      starred ? Icons.star : Icons.star_border,
                      color: starred ? Colors.amber : Colors.grey[600],
                      size: 22,
                    ),
                  ),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(modified),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.storage, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatSize(size),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _deleteLog(name),
                    child: Icon(Icons.delete_outline, size: 20, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            const Icon(Icons.catching_pokemon, color: Color(0xFF58A6FF)),
            const SizedBox(width: 12),
            const Text('Parksy Capture'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version 11.0.0'),
            const SizedBox(height: 16),
            Text(
              'Lossless conversation capture for LLM power users.\n\n'
              'When copy-paste fails, share to capture.',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
