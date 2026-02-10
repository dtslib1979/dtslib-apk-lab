/// Parksy Axis v9.0.0 - 상수 정의
/// 모든 매직 넘버와 기본값을 중앙 관리

library;

/// 앱 정보
abstract final class AppInfo {
  static const String name = 'Parksy Axis';
  static const String version = '10.0.1';
  static const int versionCode = 4;
  static const String packageName = 'kr.parksy.axis';
}

/// 오버레이 기본값
abstract final class OverlayDefaults {
  static const int width = 260;
  static const int height = 300;
  static const double minScale = 0.5;
  static const double maxScale = 2.5;
  static const double defaultScale = 1.0;
  static const double scaleSmoothing = 0.3;
  static const String position = 'bottomLeft';
}

/// UI 기본값
abstract final class UIDefaults {
  static const double bgOpacity = 0.92;
  static const double strokeWidth = 1.5;
  static const double borderRadius = 12.0;
  static const double animationDuration = 200; // ms

  // 폰트 크기
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeXLarge = 28.0;

  // 패딩
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
}

/// 기본 스테이지
abstract final class DefaultStages {
  static const String rootName = '[Idea]';
  static const List<String> stages = [
    'Capture',
    'Note',
    'Build',
    'Test',
    'Publish',
  ];

  // 프리셋: 방송용
  static const String broadcastRoot = '[LIVE]';
  static const List<String> broadcastStages = [
    '대기',
    '인트로',
    '본방',
    '마무리',
    '종료',
  ];

  // 프리셋: 회의용
  static const String meetingRoot = '[회의]';
  static const List<String> meetingStages = [
    '안건',
    '토론',
    '결론',
    '액션',
  ];

  // 프리셋: 개발용
  static const String devRoot = '[DEV]';
  static const List<String> devStages = [
    'Plan',
    'Code',
    'Test',
    'Deploy',
  ];
}

/// 스토리지 키
abstract final class StorageKeys {
  static const String configFileName = 'axis_overlay_config.json';
  static const String templatesKey = 'axis_templates_v9';
  static const String selectedTemplateKey = 'axis_selected_v9';
}

/// 슬라이더 범위
abstract final class SliderRanges {
  static const double widthMin = 150;
  static const double widthMax = 400;
  static const double heightMin = 100;
  static const double heightMax = 500;
  static const double opacityMin = 0.3;
  static const double opacityMax = 1.0;
  static const double strokeMin = 0.5;
  static const double strokeMax = 4.0;
}
