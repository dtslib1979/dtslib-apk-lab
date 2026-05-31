import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


import '../core/api_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _deepseekController = TextEditingController();
  final _githubRepoController = TextEditingController();
  final _githubTokenController = TextEditingController();
  bool _obscureDeepSeek = true;
  bool _obscureGitHub = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _deepseekController.text = ApiConfig.deepseekKey ?? '';
    _githubRepoController.text = ApiConfig.githubRepo ?? '';
    _githubTokenController.text = ApiConfig.githubToken ?? '';
  }

  @override
  void dispose() {
    _deepseekController.dispose();
    _githubRepoController.dispose();
    _githubTokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await ApiConfig.save(
      deepseekKeyVal: _deepseekController.text.trim(),
      githubRepoVal: _githubRepoController.text.trim(),
      githubTokenVal: _githubTokenController.text.trim(),
    );
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장됨')));
      Navigator.pop(context, true);
    }
  }

  Future<void> _testDeepSeek() async {
    final key = _deepseekController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DeepSeek API 키를 입력하세요')));
      return;
    }
    setState(() { _isTesting = true; _testResult = null; });
    try {
      final res = await http.post(
        Uri.parse('https://api.deepseek.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'max_tokens': 64,
          'messages': [
            {'role': 'user', 'content': 'ping'}
          ],
        }),
      ).timeout(const Duration(seconds: 10));
      setState(() {
        _isTesting = false;
        _testResult = res.statusCode == 200 ? '✅ API 연결 성공' : '❌ HTTP ${res.statusCode}';
      });
    } catch (e) {
      setState(() { _isTesting = false; _testResult = '❌ $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        actions: [
          _isSaving
              ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('DeepSeek API', Icons.psychology),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AI 검색 및 분석에 사용됩니다.\n가입: platform.deepseek.com → API keys',
                style: TextStyle(fontSize: 12), textAlign: TextAlign.start),
            const SizedBox(height: 16),
            TextField(
              controller: _deepseekController,
              obscureText: _obscureDeepSeek,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'API Key', hintText: 'sk-...', filled: true, fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D))),
                suffixIcon: IconButton(icon: Icon(_obscureDeepSeek ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscureDeepSeek = !_obscureDeepSeek)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: _isTesting ? null : _testDeepSeek,
                icon: _isTesting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.science, size: 20),
                label: Text(_isTesting ? '테스트 중...' : '연결 테스트'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636), foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF21262D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Text(_testResult!, style: const TextStyle(fontSize: 14)),
            ],
          ]))),
          const SizedBox(height: 32),
          _buildSection('GitHub Sync', Icons.cloud_sync),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _githubRepoController,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(labelText: 'GitHub Repo', hintText: 'username/repo-name',
                  filled: true, fillColor: const Color(0xFF161B22),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D)))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _githubTokenController,
              obscureText: _obscureGitHub,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(labelText: 'GitHub Token', hintText: 'Your personal access token',
                  filled: true, fillColor: const Color(0xFF161B22),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D))),
                  suffixIcon: IconButton(icon: Icon(_obscureGitHub ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscureGitHub = !_obscureGitHub))),
            ),
          ]))),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 20, color: const Color(0xFF58A6FF)),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF))),
    ]);
  }
}
