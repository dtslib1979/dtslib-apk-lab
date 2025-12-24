import 'package:flutter/services.dart';

class OverlayServiceController {
  static const _channel = MethodChannel('com.dtslib.overlay_dual_sub/overlay');
  
  /// 오버레이 서비스 시작 (Foreground Service)
  static Future<bool> startService() async {
    try {
      final result = await _channel.invokeMethod<bool>('startService');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// 오버레이 서비스 중지
  static Future<bool> stopService() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopService');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// 오버레이 캔버스 표시
  static Future<bool> showOverlay() async {
    try {
      final result = await _channel.invokeMethod<bool>('showOverlay');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// 오버레이 캔버스 숨김
  static Future<bool> hideOverlay() async {
    try {
      final result = await _channel.invokeMethod<bool>('hideOverlay');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// 오버레이 표시 상태 확인
  static Future<bool> isOverlayVisible() async {
    try {
      final result = await _channel.invokeMethod<bool>('isOverlayVisible');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// 펜 색상 변경
  static Future<bool> setColor(String colorName) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setColor',
        {'color': colorName},
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// 캔버스 클리어
  static Future<bool> clear() async {
    try {
      final result = await _channel.invokeMethod<bool>('clear');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Undo
  static Future<bool> undo() async {
    try {
      final result = await _channel.invokeMethod<bool>('undo');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
  
  /// Redo
  static Future<bool> redo() async {
    try {
      final result = await _channel.invokeMethod<bool>('redo');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
