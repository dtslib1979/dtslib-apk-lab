import 'package:flutter/services.dart';

/// Service for managing overlay window
class OverlayService {
  static const _channel = MethodChannel('com.dtslib.parksy_glot/overlay');

  /// Check if overlay permission is granted
  static Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request overlay permission
  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestOverlayPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Start overlay service
  static Future<bool> startService() async {
    try {
      final result = await _channel.invokeMethod<bool>('startOverlayService');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Stop overlay service
  static Future<bool> stopService() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopOverlayService');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Show overlay window
  static Future<bool> showOverlay() async {
    try {
      final result = await _channel.invokeMethod<bool>('showOverlay');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Hide overlay window
  static Future<bool> hideOverlay() async {
    try {
      final result = await _channel.invokeMethod<bool>('hideOverlay');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if overlay is currently visible
  static Future<bool> isOverlayVisible() async {
    try {
      final result = await _channel.invokeMethod<bool>('isOverlayVisible');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Update subtitle text on overlay
  static Future<void> updateSubtitle({
    required String korean,
    required String english,
    String? original,
    bool showOriginal = false,
  }) async {
    try {
      await _channel.invokeMethod('updateSubtitle', {
        'korean': korean,
        'english': english,
        'original': original ?? '',
        'showOriginal': showOriginal,
      });
    } catch (e) {
      // Silently fail
    }
  }

  /// Set overlay position
  static Future<void> setPosition({
    required double x,
    required double y,
  }) async {
    try {
      await _channel.invokeMethod('setPosition', {
        'x': x,
        'y': y,
      });
    } catch (e) {
      // Silently fail
    }
  }

  /// Set subtitle font size
  static Future<void> setFontSize(double scale) async {
    try {
      await _channel.invokeMethod('setFontSize', {
        'scale': scale,
      });
    } catch (e) {
      // Silently fail
    }
  }

  /// Toggle original text visibility
  static Future<void> toggleOriginal(bool show) async {
    try {
      await _channel.invokeMethod('toggleOriginal', {
        'show': show,
      });
    } catch (e) {
      // Silently fail
    }
  }
}
