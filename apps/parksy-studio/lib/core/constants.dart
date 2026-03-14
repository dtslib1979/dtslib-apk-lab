import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Parksy Studio';
  static const String version = '1.0.0';
  static const int versionCode = 1;

  // 배경색
  static const Color kBackground = Color(0xFF0A0A0A);
  static const Color kSurface = Color(0xFF1A1A1A);
  static const Color kAccent = Color(0xFFE8D5B7);
  static const Color kDim = Color(0xFF333333);

  // cloud-appstore 도구 URL 베이스
  static const String cloudAppstoreBase =
      'https://dtslib1979.github.io/dtslib-cloud-appstore';

  // parksy-audio 배경음악 채널 (YouTube URL JSON)
  static const String bgmChannelUrl =
      'https://raw.githubusercontent.com/dtslib1979/parksy-audio/main/tools/bgm-channel.json';
}

// 도구 모델
class StudioTool {
  final String id;
  final String name;
  final String icon;
  final String url;
  final String category;

  const StudioTool({
    required this.id,
    required this.name,
    required this.icon,
    required this.url,
    required this.category,
  });
}

// cloud-appstore 13개 도구
const List<StudioTool> kTools = [
  StudioTool(id: 'lecture-shorts', name: 'Lecture Shorts', icon: '🎓', url: '/apps/lecture-shorts/', category: 'video'),
  StudioTool(id: 'lecture-long', name: 'Lecture Long', icon: '📹', url: '/apps/lecture-long/', category: 'video'),
  StudioTool(id: 'auto-shorts', name: 'Auto Shorts', icon: '🎬', url: '/apps/auto-shorts/', category: 'video'),
  StudioTool(id: 'clip-shorts', name: 'Clip Shorts', icon: '🎞️', url: '/apps/clip-shorts/', category: 'video'),
  StudioTool(id: 'audio-studio', name: 'Audio Studio', icon: '🎵', url: '/apps/audio-studio/', category: 'audio'),
  StudioTool(id: 'slim-lens', name: 'Slim Lens', icon: '📷', url: '/apps/slim-lens/', category: 'image'),
  StudioTool(id: 'image-pack', name: 'Image Pack', icon: '📦', url: '/apps/image-pack/', category: 'image'),
  StudioTool(id: 'bilingual-aligner', name: 'Bilingual Aligner', icon: '📘', url: '/apps/bilingual-aligner/', category: 'util'),
  StudioTool(id: 'project-manager', name: 'Project Manager', icon: '📋', url: '/apps/project-manager/', category: 'util'),
  StudioTool(id: 'math-tutor', name: 'Math Tutor', icon: '📐', url: '/apps/math-tutor/', category: 'game'),
  StudioTool(id: 'music-curation', name: 'Music Curation', icon: '🎧', url: '/apps/music-curation/', category: 'game'),
  StudioTool(id: 'memorial-tribute', name: 'Memorial Tribute', icon: '🕯️', url: '/apps/memorial-tribute/', category: 'util'),
  StudioTool(id: 'luxury-editorial', name: 'Luxury Editorial', icon: '✨', url: '/apps/luxury-editorial/', category: 'util'),
];
