import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AxisSettings _settings;
  bool _loading = true;
  final _rootController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settings = await SettingsService.load();
    _rootController.text = _settings.rootName;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    _settings.rootName = _rootController.text;
    await SettingsService.save(_settings);
    if (mounted) Navigator.pop(context, true);
  }

  void _addStage() {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('스테이지 추가'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '스테이지 이름'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() => _settings.stages.add(controller.text));
                }
                Navigator.pop(ctx);
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  void _editStage(int index) {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: _settings.stages[index]);
        return AlertDialog(
          title: const Text('스테이지 수정'),
          content: TextField(
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() => _settings.stages[index] = controller.text);
                }
                Navigator.pop(ctx);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  void _deleteStage(int index) {
    if (_settings.stages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 1개의 스테이지가 필요합니다')),
      );
      return;
    }
    setState(() => _settings.stages.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 루트 이름
          const Text('루트 이름', style: TextStyle(color: Colors.amber, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _rootController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),

          // 오버레이 위치
          const Text('오버레이 위치', style: TextStyle(color: Colors.amber, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _positionChip('topLeft', '좌상단'),
              _positionChip('topRight', '우상단'),
              _positionChip('bottomLeft', '좌하단'),
              _positionChip('bottomRight', '우하단'),
            ],
          ),
          const SizedBox(height: 24),

          // 오버레이 크기
          const Text('오버레이 크기', style: TextStyle(color: Colors.amber, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('너비: ${_settings.width}', style: const TextStyle(color: Colors.white70)),
                    Slider(
                      value: _settings.width.toDouble(),
                      min: 150,
                      max: 350,
                      onChanged: (v) => setState(() => _settings.width = v.toInt()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('높이: ${_settings.height}', style: const TextStyle(color: Colors.white70)),
                    Slider(
                      value: _settings.height.toDouble(),
                      min: 100,
                      max: 400,
                      onChanged: (v) => setState(() => _settings.height = v.toInt()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 스테이지 목록
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('스테이지', style: TextStyle(color: Colors.amber, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.amber),
                onPressed: _addStage,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _settings.stages.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _settings.stages.removeAt(oldIndex);
                _settings.stages.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              return ListTile(
                key: ValueKey('stage_$index'),
                tileColor: Colors.grey[900],
                leading: const Icon(Icons.drag_handle, color: Colors.grey),
                title: Text(
                  _settings.stages[index],
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => _editStage(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteStage(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _positionChip(String value, String label) {
    final selected = _settings.position == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _settings.position = value),
      selectedColor: Colors.amber,
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white),
    );
  }
}
