import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../models/theme.dart';
import '../widgets/tree_view.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AxisSettings _s;
  bool _loading = true;
  final _rootCtrl = TextEditingController();
  int _previewStage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _s = await SettingsService.load();
    _rootCtrl.text = _s.rootName;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    _s.rootName = _rootCtrl.text;
    await SettingsService.save(_s);
    if (mounted) Navigator.pop(context, true);
  }

  void _addStage() {
    _showInputDialog('스테이지 추가', '', (val) {
      if (val.isNotEmpty) {
        setState(() => _s.stages.add(val));
      }
    });
  }

  void _editStage(int i) {
    _showInputDialog('스테이지 수정', _s.stages[i], (val) {
      if (val.isNotEmpty) {
        setState(() => _s.stages[i] = val);
      }
    });
  }

  void _deleteStage(int i) {
    if (_s.stages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 1개 스테이지 필요')),
      );
      return;
    }
    setState(() => _s.stages.removeAt(i));
  }

  void _showInputDialog(String title, String init, Function(String) onOk) {
    final ctrl = TextEditingController(text: init);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '이름 입력'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              onOk(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = AxisTheme.byId(_s.themeId);
    final font = AxisFont.byId(_s.fontId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('커스터마이징'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: theme.accent),
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 실시간 미리보기
            Center(
              child: SizedBox(
                width: _s.width.toDouble(),
                height: _s.height.toDouble(),
                child: TreeView(
                  active: _previewStage,
                  onTap: () {
                    setState(() {
                      _previewStage = (_previewStage + 1) % _s.stages.length;
                    });
                  },
                  rootName: _rootCtrl.text,
                  stages: _s.stages,
                  theme: theme,
                  font: font,
                  bgOpacity: _s.bgOpacity,
                  strokeWidth: _s.strokeWidth,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 테마 선택
            _section('테마', theme.accent),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AxisTheme.presets.map((t) {
                final sel = _s.themeId == t.id;
                return GestureDetector(
                  onTap: () => setState(() => _s.themeId = t.id),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(12),
                      border: sel ? Border.all(color: Colors.white, width: 3) : null,
                    ),
                    child: sel ? const Icon(Icons.check, color: Colors.black) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 폰트 선택
            _section('폰트', theme.accent),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AxisFont.presets.map((f) {
                final sel = _s.fontId == f.id;
                return ChoiceChip(
                  label: Text(f.name),
                  selected: sel,
                  onSelected: (_) => setState(() => _s.fontId = f.id),
                  selectedColor: theme.accent,
                  labelStyle: TextStyle(
                    color: sel ? Colors.black : Colors.white,
                    fontFamily: f.family,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 크기 조절
            _section('오버레이 크기', theme.accent),
            _slider('너비', _s.width.toDouble(), 150, 400, (v) {
              setState(() => _s.width = v.toInt());
            }),
            _slider('높이', _s.height.toDouble(), 100, 500, (v) {
              setState(() => _s.height = v.toInt());
            }),
            const SizedBox(height: 24),

            // 스타일 조절
            _section('스타일', theme.accent),
            _slider('배경 투명도', _s.bgOpacity, 0.3, 1.0, (v) {
              setState(() => _s.bgOpacity = v);
            }, pct: true),
            _slider('테두리 굵기', _s.strokeWidth, 0.5, 4.0, (v) {
              setState(() => _s.strokeWidth = v);
            }),
            const SizedBox(height: 24),

            // 위치 선택
            _section('오버레이 위치', theme.accent),
            Wrap(
              spacing: 8,
              children: [
                _posChip('topLeft', '좌상', theme),
                _posChip('topRight', '우상', theme),
                _posChip('bottomLeft', '좌하', theme),
                _posChip('bottomRight', '우하', theme),
              ],
            ),
            const SizedBox(height: 24),

            // 루트 이름
            _section('루트 이름', theme.accent),
            TextField(
              controller: _rootCtrl,
              style: TextStyle(color: Colors.white, fontFamily: font.family),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // 스테이지 목록
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _section('스테이지', theme.accent),
                IconButton(
                  icon: Icon(Icons.add, color: theme.accent),
                  onPressed: _addStage,
                ),
              ],
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _s.stages.length,
              onReorder: (old, now) {
                setState(() {
                  if (now > old) now--;
                  final item = _s.stages.removeAt(old);
                  _s.stages.insert(now, item);
                });
              },
              itemBuilder: (_, i) => ListTile(
                key: ValueKey('s_$i'),
                tileColor: Colors.grey[900],
                leading: Icon(Icons.drag_handle, color: theme.dim),
                title: Text(
                  _s.stages[i],
                  style: TextStyle(color: Colors.white, fontFamily: font.family),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => _editStage(i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteStage(i),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _section(String t, Color c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _slider(
    String label,
    double val,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    bool pct = false,
  }) {
    final display = pct ? '${(val * 100).toInt()}%' : val.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $display', style: const TextStyle(color: Colors.white70)),
        Slider(
          value: val,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: AxisTheme.byId(_s.themeId).accent,
        ),
      ],
    );
  }

  Widget _posChip(String val, String label, AxisTheme theme) {
    final sel = _s.position == val;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) => setState(() => _s.position = val),
      selectedColor: theme.accent,
      labelStyle: TextStyle(color: sel ? Colors.black : Colors.white),
    );
  }
}
