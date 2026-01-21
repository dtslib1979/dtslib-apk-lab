/// Parksy Axis v9.0.0 - 설정 화면
/// 탭 기반 UI + 개선된 UX

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/settings.dart';
import '../models/theme.dart';
import '../widgets/tree_view.dart';

class SettingsScreen extends StatefulWidget {
  final AxisSettings initial;

  const SettingsScreen({super.key, required this.initial});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AxisSettings _cfg;
  late TextEditingController _rootCtrl;
  int _preview = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cfg = widget.initial.copyWith();
    _rootCtrl = TextEditingController(text: _cfg.rootName);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rootCtrl.dispose();
    super.dispose();
  }

  void _saveAsTemplate() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('템플릿으로 저장', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '템플릿 이름',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cfg = _cfg.copyWith(rootName: _rootCtrl.text);
              Navigator.pop(context, {
                'settings': _cfg,
                'name': nameCtrl.text,
              });
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _applyAndSave() {
    _cfg = _cfg.copyWith(rootName: _rootCtrl.text);
    Navigator.pop(context, {
      'settings': _cfg,
      'name': null,
    });
  }

  void _addStage() => _showInputDialog('스테이지 추가', '', (v) {
        if (v.isNotEmpty) {
          setState(() {
            _cfg = _cfg.copyWith(stages: [..._cfg.stages, v]);
          });
        }
      });

  void _editStage(int i) => _showInputDialog('스테이지 수정', _cfg.stages[i], (v) {
        if (v.isNotEmpty) {
          final newStages = List<String>.from(_cfg.stages);
          newStages[i] = v;
          setState(() {
            _cfg = _cfg.copyWith(stages: newStages);
          });
        }
      });

  void _delStage(int i) {
    if (_cfg.stages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('최소 1개 필요'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }
    final newStages = List<String>.from(_cfg.stages)..removeAt(i);
    setState(() {
      _cfg = _cfg.copyWith(stages: newStages);
    });
  }

  void _showInputDialog(String title, String init, Function(String) onOk) {
    final ctrl = TextEditingController(text: init);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '이름',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
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
    final t = AxisTheme.byId(_cfg.themeId);
    final f = AxisFont.byId(_cfg.fontId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('커스터마이징'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            color: t.accent,
            onPressed: _applyAndSave,
            tooltip: '저장 및 적용',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            color: Colors.green,
            onPressed: _saveAsTemplate,
            tooltip: '템플릿으로 저장',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: t.accent,
          labelColor: t.accent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.palette), text: '스타일'),
            Tab(icon: Icon(Icons.list), text: '스테이지'),
            Tab(icon: Icon(Icons.aspect_ratio), text: '크기'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 미리보기
          Container(
            padding: const EdgeInsets.all(UIDefaults.paddingMedium),
            child: Center(
              child: SizedBox(
                width: _cfg.width.toDouble() * 0.8,
                height: _cfg.height.toDouble() * 0.6,
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
                  enableAnimation: false,
                ),
              ),
            ),
          ),
          const Divider(color: Colors.grey, height: 1),

          // 탭 콘텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _StyleTab(
                  cfg: _cfg,
                  theme: t,
                  onThemeChanged: (id) => setState(() {
                    _cfg = _cfg.copyWith(themeId: id);
                  }),
                  onFontChanged: (id) => setState(() {
                    _cfg = _cfg.copyWith(fontId: id);
                  }),
                  onOpacityChanged: (v) => setState(() {
                    _cfg = _cfg.copyWith(bgOpacity: v);
                  }),
                  onStrokeChanged: (v) => setState(() {
                    _cfg = _cfg.copyWith(strokeWidth: v);
                  }),
                ),
                _StagesTab(
                  cfg: _cfg,
                  theme: t,
                  font: f,
                  rootCtrl: _rootCtrl,
                  onRootChanged: () => setState(() {}),
                  onAddStage: _addStage,
                  onEditStage: _editStage,
                  onDelStage: _delStage,
                  onReorder: (oldIdx, newIdx) {
                    setState(() {
                      if (newIdx > oldIdx) newIdx--;
                      final stages = List<String>.from(_cfg.stages);
                      final item = stages.removeAt(oldIdx);
                      stages.insert(newIdx, item);
                      _cfg = _cfg.copyWith(stages: stages);
                    });
                  },
                ),
                _SizeTab(
                  cfg: _cfg,
                  theme: t,
                  onWidthChanged: (v) => setState(() {
                    _cfg = _cfg.copyWith(width: v.toInt());
                  }),
                  onHeightChanged: (v) => setState(() {
                    _cfg = _cfg.copyWith(height: v.toInt());
                  }),
                  onPositionChanged: (pos) => setState(() {
                    _cfg = _cfg.copyWith(position: pos);
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 스타일 탭
class _StyleTab extends StatelessWidget {
  final AxisSettings cfg;
  final AxisTheme theme;
  final ValueChanged<String> onThemeChanged;
  final ValueChanged<String> onFontChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onStrokeChanged;

  const _StyleTab({
    required this.cfg,
    required this.theme,
    required this.onThemeChanged,
    required this.onFontChanged,
    required this.onOpacityChanged,
    required this.onStrokeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(UIDefaults.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('테마', theme.accent),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AxisTheme.presets.map((x) {
              final sel = cfg.themeId == x.id;
              return GestureDetector(
                onTap: () => onThemeChanged(x.id),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: x.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: sel ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: sel
                        ? [BoxShadow(color: x.glow, blurRadius: 8, spreadRadius: 2)]
                        : null,
                  ),
                  child: sel ? const Icon(Icons.check, color: Colors.black) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          _SectionHeader('폰트', theme.accent),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AxisFont.presets.map((x) {
              final sel = cfg.fontId == x.id;
              return ChoiceChip(
                label: Text(x.name),
                selected: sel,
                onSelected: (_) => onFontChanged(x.id),
                selectedColor: theme.accent,
                labelStyle: TextStyle(
                  color: sel ? Colors.black : Colors.white,
                  fontFamily: x.family,
                  fontWeight: x.weight,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          _SectionHeader('스타일', theme.accent),
          const SizedBox(height: 8),
          _SliderRow(
            label: '투명도',
            value: cfg.bgOpacity,
            min: SliderRanges.opacityMin,
            max: SliderRanges.opacityMax,
            onChanged: onOpacityChanged,
            theme: theme,
            isPercent: true,
          ),
          _SliderRow(
            label: '테두리',
            value: cfg.strokeWidth,
            min: SliderRanges.strokeMin,
            max: SliderRanges.strokeMax,
            onChanged: onStrokeChanged,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

/// 스테이지 탭
class _StagesTab extends StatelessWidget {
  final AxisSettings cfg;
  final AxisTheme theme;
  final AxisFont font;
  final TextEditingController rootCtrl;
  final VoidCallback onRootChanged;
  final VoidCallback onAddStage;
  final ValueChanged<int> onEditStage;
  final ValueChanged<int> onDelStage;
  final void Function(int, int) onReorder;

  const _StagesTab({
    required this.cfg,
    required this.theme,
    required this.font,
    required this.rootCtrl,
    required this.onRootChanged,
    required this.onAddStage,
    required this.onEditStage,
    required this.onDelStage,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(UIDefaults.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('루트 이름', theme.accent),
          const SizedBox(height: 8),
          TextField(
            controller: rootCtrl,
            style: font.style(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.accent),
              ),
            ),
            onChanged: (_) => onRootChanged(),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionHeader('스테이지', theme.accent),
              IconButton(
                icon: Icon(Icons.add_circle, color: theme.accent),
                onPressed: onAddStage,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cfg.stages.length,
            onReorder: onReorder,
            itemBuilder: (_, i) => Card(
              key: ValueKey('stage_$i'),
              color: Colors.grey[900],
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.drag_handle, color: theme.dim),
                title: Text(
                  cfg.stages[i],
                  style: font.style(color: Colors.white),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => onEditStage(i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => onDelStage(i),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 크기 탭
class _SizeTab extends StatelessWidget {
  final AxisSettings cfg;
  final AxisTheme theme;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<OverlayPosition> onPositionChanged;

  const _SizeTab({
    required this.cfg,
    required this.theme,
    required this.onWidthChanged,
    required this.onHeightChanged,
    required this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(UIDefaults.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('오버레이 크기', theme.accent),
          const SizedBox(height: 8),
          _SliderRow(
            label: '너비',
            value: cfg.width.toDouble(),
            min: SliderRanges.widthMin,
            max: SliderRanges.widthMax,
            onChanged: onWidthChanged,
            theme: theme,
            suffix: 'px',
          ),
          _SliderRow(
            label: '높이',
            value: cfg.height.toDouble(),
            min: SliderRanges.heightMin,
            max: SliderRanges.heightMax,
            onChanged: onHeightChanged,
            theme: theme,
            suffix: 'px',
          ),
          const SizedBox(height: 24),

          _SectionHeader('기본 위치', theme.accent),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: OverlayPosition.values.map((pos) {
              final sel = cfg.position == pos;
              return ChoiceChip(
                label: Text(pos.label),
                selected: sel,
                onSelected: (_) => onPositionChanged(pos),
                selectedColor: theme.accent,
                labelStyle: TextStyle(
                  color: sel ? Colors.black : Colors.white,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 섹션 헤더
class _SectionHeader extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionHeader(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: UIDefaults.fontSizeLarge,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// 슬라이더 행
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final AxisTheme theme;
  final bool isPercent;
  final String? suffix;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.theme,
    this.isPercent = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final display = isPercent
        ? '${(value * 100).toInt()}%'
        : suffix != null
            ? '${value.toInt()}$suffix'
            : value.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: $display',
          style: const TextStyle(color: Colors.white70),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: theme.accent,
          inactiveColor: theme.dim.withOpacity(0.3),
        ),
      ],
    );
  }
}
