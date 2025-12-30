import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6366F1);
  static const secondary = Color(0xFF8B5CF6);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  static const background = Color(0xFF0F0F1A);
  static const surface = Color(0xFF1E1E2E);
  static const surfaceLight = Color(0xFF2E2E3E);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB3B3B3);
  static const textMuted = Color(0xFF666666);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class AppStrings {
  static const appName = 'Parksy Glot';
  static const appTagline = '다국어 실시간 자막';

  static const startCapture = '시작';
  static const stopCapture = '중지';
  static const settings = '설정';
  static const sourceLanguage = '소스 언어';
  static const apiKeyHint = 'OpenAI API 키 입력';
  static const waitingForAudio = '음성을 기다리는 중...';
  static const showOriginal = '원문 표시';
  static const subtitleSize = '자막 크기';

  static const errorNoApiKey = 'API 키를 설정해주세요';
  static const errorNoPermission = '권한이 필요합니다';
  static const errorCaptureFailed = '캡처 시작 실패';
}
