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
  late AxisSettings _cfg;
  bool _loading = true;
  final _rootCtrl = TextEditingController();
  int _preview = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _cfg = await SettingsService.load();
    _rootCtrl.text = _cfg.rootName;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    _cfg.rootName = _rootCtrl.text;
    await SettingsService.save(_cfg);
    if (mounted) Navigator.pop(context, true);
  }

  void _addStage() => _input('스테이지 추가', '', (v) {
        if (v.isNotEmpty) setState(() => _cfg.stages.add(v));
      });

  void _editStage(int i) => _input('스테이지 수정', _cfg.stages[i], (v) {
        if (v.isNotEmpty) setState(() => _cfg.stages[i] = v);
      });

  void _delStage(int i) {
    if (_cfg.stages.length <= 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('최소 1개 필요')));
      return;
    }
    setState(() => _cfg.stages.removeAt(i));
  }

  void _input(String title, String init, Function(String) ok) {
    final c = TextEditingController(text: init);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: '이름'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              ok(c.text);
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final t = AxisTheme.byId(_cfg.themeId);
    final f = AxisFont.byId(_cfg.fontId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('커스터마이징'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: Icon(Icons.check, color: t.accent), onPressed: _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 미리보기
            Center(
              child: SizedBox(
                width: _cfg.width.toDouble(),
                height: _cfg.height.toDouble(),
                child: TreeView(
                  active: _preview,
                  onTap: () => setState(() {
                    _preview = (_preview + 1) % _cfg.stages.length;
                  }),
                  root: _rootCtrl.text,
                  items: _cfg.stages,
                  theme: t,
                  font: f,
                  opacity: _cfg.bgOpacity,
                  stroke: _cfg.strokeWidth,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 테마
            _sec('테마', t.accent),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AxisTheme.presets.map((x) {
                final sel = _cfg.themeId == x.id;
                return GestureDetector(
                  onTap: () => setState(() => _cfg.themeId = x.id),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: x.accent,
                      borderRadius: BorderRadius.circular(12),
                      border: sel ? Border.all(color: Colors.white, width: 3) : null,
                    ),
                    child: sel ? const Icon(Icons.check, color: Colors.black) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 폰트
            _sec('폰트', t.accent),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AxisFont.presets.map((x) {
                final sel = _cfg.fontId == x.id;
                return ChoiceChip(
                  label: Text(x.name),
                  selected: sel,
                  onSelected: (_) => setState(() => _cfg.fontId = x.id),
                  selectedColor: t.accent,
                  labelStyle: TextStyle(
                    color: sel ? Colors.black : Colors.white,
                    fontFamily: x.family,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 크기
            _sec('크기', t.accent),
            _slider('너비', _cfg.width.toDouble(), 150, 400, (v) {
              setState(() => _cfg.width = v.toInt());
            }),
            _slider('높이', _cfg.height.toDouble(), 100, 500, (v) {
              setState(() => _cfg.height = v.toInt());
            }),
            const SizedBox(height: 24),

            // 스타일
            _sec('스타일', t.accent),
            _slider('투명도', _cfg.bgOpacity, 0.3, 1.0, (v) {
              setState(() => _cfg.bgOpacity = v);
            }, pct: true),
            _slider('테두리', _cfg.strokeWidth, 0.5, 4.0, (v) {
              setState(() => _cfg.strokeWidth = v);
            }),
            const SizedBox(height: 24),

            // 위치
            _sec('위치', t.accent),
            Wrap(
              spacing: 8,
              children: [
                _pos('topLeft', '좌상', t),
                _pos('topRight', '우상', t),
                _pos('bottomLeft', '좌하', t),
                _pos('bottomRight', '우하', t),
              ],
            ),
            const SizedBox(height: 24),

            // 루트
            _sec('루트 이름', t.accent),
            TextField(
              controller: _rootCtrl,
              style: TextStyle(color: Colors.white, fontFamily: f.family),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // 스테이지
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sec('스테이지', t.accent),
                IconButton(icon: Icon(Icons.add, color: t.accent), onPressed: _addStage),
              ],
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _cfg.stages.length,
              onReorder: (o, n) {
                setState(() {
                  if (n > o) n--;
                  final x = _cfg.stages.removeAt(o);
                  _cfg.stages.insert(n, x);
                });
              },
              itemBuilder: (_, i) => ListTile(
                key: ValueKey('s$i'),
                tileColor: Colors.grey[900],
                leading: Icon(Icons.drag_handle, color: t.dim),
                title: Text(_cfg.stages[i],
                    style: TextStyle(color: Colors.white, fontFamily: f.family)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => _editStage(i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _delStage(i),
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

  Widget _sec(String t, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _slider(String lbl, double val, double min, double max, ValueChanged<double> fn,
      {bool pct = false}) {
    final disp = pct ? '${(val * 100).toInt()}%' : val.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$lbl: $disp', style: const TextStyle(color: Colors.white70)),
        Slider(
          value: val,
          min: min,
          max: max,
          onChanged: fn,
          activeColor: AxisTheme.byId(_cfg.themeId).accent,
        ),
      ],
    );
  }

  Widget _pos(String v, String lbl, AxisTheme t) {
    final sel = _cfg.position == v;
    return ChoiceChip(
      label: Text(lbl),
      selected: sel,
      onSelected: (_) => setState(() => _cfg.position = v),
      selectedColor: t.accent,
      labelStyle: TextStyle(color: sel ? Colors.black : Colors.white),
    );
  }
}
