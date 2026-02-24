class AppConstants {
  static const String appName = 'Parksy Liner';
  static const String version = '1.0.0';
  static const int versionCode = 1;
  static const String package = 'kr.parksy.liner';

  // Canvas
  static const int canvasWidth = 2160;
  static const int canvasHeight = 3060;

  // Line spec
  static const int lineColorR = 0xC3;
  static const int lineColorG = 0xC3;
  static const int lineColorB = 0xC3;
  static const double lineAlphaMin = 0.70;
  static const double lineAlphaMax = 0.85;

  // Shade spec
  static const int shadeColorR = 0xC8;
  static const int shadeColorG = 0xC8;
  static const int shadeColorB = 0xC8;
  static const double shadeAlphaMin = 0.25;
  static const double shadeAlphaMax = 0.45;

  // XDoG
  static const double xdogSigma = 0.5;
  static const double xdogK = 1.6;
  static const double xdogEpsilon = 0.01;
  static const double xdogPhi = 10.0;

  // Samsung Notes
  static const String samsungNotesPackage = 'com.samsung.android.app.notes';
  static const String samsungNotesActivity =
      'com.samsung.android.app.notes.NoteEditActivity';
}
