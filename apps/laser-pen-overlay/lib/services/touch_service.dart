import 'package:flutter/services.dart';

enum TouchAction { down, move, up, cancel }

class StylusTouch {
  final TouchAction action;
  final double x;
  final double y;
  final double pressure;
  final int toolType;

  StylusTouch({
    required this.action,
    required this.x,
    required this.y,
    required this.pressure,
    required this.toolType,
  });

  factory StylusTouch.fromMap(Map<dynamic, dynamic> map) {
    return StylusTouch(
      action: _parseAction(map['action'] as String),
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      pressure: (map['pressure'] as num).toDouble(),
      toolType: map['toolType'] as int,
    );
  }

  static TouchAction _parseAction(String action) {
    switch (action) {
      case 'down':
        return TouchAction.down;
      case 'move':
        return TouchAction.move;
      case 'up':
        return TouchAction.up;
      case 'cancel':
        return TouchAction.cancel;
      default:
        return TouchAction.cancel;
    }
  }

  bool get isStylus => toolType == 2; // TOOL_TYPE_STYLUS
  bool get isEraser => toolType == 4; // TOOL_TYPE_ERASER
}

class TouchService {
  static const _channel = MethodChannel('com.dtslib.laser_pen_overlay/touch');
  
  Function(StylusTouch)? onStylusTouch;

  TouchService() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onStylusTouch':
        if (onStylusTouch != null) {
          final touch = StylusTouch.fromMap(
            call.arguments as Map<dynamic, dynamic>,
          );
          onStylusTouch!(touch);
        }
        break;
    }
  }

  Future<String> getInputMode() async {
    try {
      final result = await _channel.invokeMethod<String>('getInputMode');
      return result ?? 'unknown';
    } catch (e) {
      return 'error';
    }
  }

  void dispose() {
    onStylusTouch = null;
  }
}
