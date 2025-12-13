import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/stroke.dart';
import '../services/touch_service.dart';
import '../services/overlay_service.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/control_bar.dart';

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final List<Stroke> _strokes = [];
  final List<Stroke> _undoStack = [];
  Stroke? _currentStroke;
  PenColor _penColor = PenColor.white;
  Timer? _fadeTimer;
  
  late TouchService _touchService;
  bool _useStylusOnly = true;
  bool _overlayActive = false;

  @override
  void initState() {
    super.initState();
    _startFadeTimer();
    _initTouchService();
    _checkOverlayStatus();
  }

  void _initTouchService() {
    _touchService = TouchService();
    _touchService.onStylusTouch = _handleStylusTouch;
  }
  
  Future<void> _checkOverlayStatus() async {
    final visible = await OverlayServiceController.isOverlayVisible();
    if (mounted) {
      setState(() => _overlayActive = visible);
    }
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _touchService.dispose();
    super.dispose();
  }

  void _handleStylusTouch(StylusTouch touch) {
    if (!_useStylusOnly || _overlayActive) return;
    
    final pos = Offset(touch.x, touch.y);
    
    switch (touch.action) {
      case TouchAction.down:
        _startStroke(pos);
        break;
      case TouchAction.move:
        _updateStroke(pos);
        break;
      case TouchAction.up:
      case TouchAction.cancel:
        _endStroke();
        break;
    }
  }

  void _startFadeTimer() {
    _fadeTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _updateFades(),
    );
  }

  void _updateFades() {
    if (_strokes.isEmpty) return;
    
    final hasExpired = _strokes.any((s) => s.isExpired);
    final hasFading = _strokes.any((s) => s.shouldFade);
    
    if (hasExpired) {
      setState(() {
        _strokes.removeWhere((s) => s.isExpired);
      });
    } else if (hasFading) {
      setState(() {});
    }
  }

  Color get _currentColor {
    switch (_penColor) {
      case PenColor.white:
        return Colors.white;
      case PenColor.yellow:
        return Colors.yellow;
      case PenColor.black:
        return Colors.black;
    }
  }
  
  String get _colorName {
    switch (_penColor) {
      case PenColor.white:
        return 'white';
      case PenColor.yellow:
        return 'yellow';
      case PenColor.black:
        return 'black';
    }
  }

  void _startStroke(Offset pos) {
    setState(() {
      _currentStroke = Stroke(
        points: [pos],
        color: _currentColor,
        width: 4.0,
      );
    });
  }

  void _updateStroke(Offset pos) {
    if (_currentStroke == null) return;
    setState(() {
      _currentStroke = _currentStroke!.copyWith(
        points: [..._currentStroke!.points, pos],
      );
    });
  }

  void _endStroke() {
    if (_currentStroke == null) return;
    setState(() {
      _strokes.add(_currentStroke!);
      _currentStroke = null;
      _undoStack.clear();
    });
  }

  // Fallback: GestureDetector for non-stylus or testing
  void _onPanStart(DragStartDetails d) {
    if (_useStylusOnly || _overlayActive) return;
    _startStroke(d.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_useStylusOnly || _overlayActive) return;
    _updateStroke(d.localPosition);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_useStylusOnly || _overlayActive) return;
    _endStroke();
  }

  void _cycleColor() {
    setState(() {
      switch (_penColor) {
        case PenColor.white:
          _penColor = PenColor.yellow;
          break;
        case PenColor.yellow:
          _penColor = PenColor.black;
          break;
        case PenColor.black:
          _penColor = PenColor.white;
          break;
      }
    });
    
    // 오버레이 서비스에도 색상 전달
    if (_overlayActive) {
      OverlayServiceController.setColor(_colorName);
    }
  }

  void _undo() {
    if (_overlayActive) {
      OverlayServiceController.undo();
      return;
    }
    
    if (_strokes.isEmpty) return;
    setState(() {
      _undoStack.add(_strokes.removeLast());
    });
  }

  void _redo() {
    if (_overlayActive) {
      OverlayServiceController.redo();
      return;
    }
    
    if (_undoStack.isEmpty) return;
    setState(() {
      _strokes.add(_undoStack.removeLast());
    });
  }

  void _clear() {
    if (_overlayActive) {
      OverlayServiceController.clear();
      return;
    }
    
    setState(() {
      _strokes.clear();
      _undoStack.clear();
    });
  }

  void _exit() {
    // 오버레이 활성화 상태면 서비스도 중지
    if (_overlayActive) {
      OverlayServiceController.stopService();
    }
    Navigator.of(context).pop();
  }

  void _toggleInputMode() {
    setState(() {
      _useStylusOnly = !_useStylusOnly;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _useStylusOnly 
            ? 'S Pen 전용 모드' 
            : '모든 입력 모드',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
  
  Future<void> _toggleOverlay() async {
    if (_overlayActive) {
      await OverlayServiceController.hideOverlay();
      setState(() => _overlayActive = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오버레이 비활성화'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      // 서비스 시작 후 오버레이 표시
      await OverlayServiceController.startService();
      await Future.delayed(const Duration(milliseconds: 200));
      await OverlayServiceController.showOverlay();
      await OverlayServiceController.setColor(_colorName);
      
      setState(() => _overlayActive = true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오버레이 활성화 - 다른 앱 위에 판서 가능'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Drawing area (앱 내 판서 - 오버레이 비활성화 시만)
          if (!_overlayActive)
            Positioned.fill(
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: DrawingCanvas(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                  ),
                ),
              ),
            ),
          
          // 오버레이 모드 안내 (활성화 시)
          if (_overlayActive)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.layers,
                        size: 64,
                        color: Colors.white54,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '오버레이 모드 활성화',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '다른 앱 위에서 S Pen으로 판서 가능\n손가락은 하위 앱 조작',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Top bar: Mode indicator + Overlay toggle
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Overlay toggle
                GestureDetector(
                  onTap: _toggleOverlay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _overlayActive 
                        ? Colors.green.withOpacity(0.8)
                        : Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.layers,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _overlayActive ? '오버레이 ON' : '오버레이 OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Input mode indicator (오버레이 비활성화 시만)
                if (!_overlayActive)
                  GestureDetector(
                    onTap: _toggleInputMode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _useStylusOnly ? Icons.edit : Icons.touch_app,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _useStylusOnly ? 'S Pen' : 'All',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Control bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: ControlBar(
                currentColor: _penColor,
                onColorChange: _cycleColor,
                onUndo: _undo,
                onRedo: _redo,
                onClear: _clear,
                onExit: _exit,
                canUndo: _overlayActive || _strokes.isNotEmpty,
                canRedo: _overlayActive || _undoStack.isNotEmpty,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
