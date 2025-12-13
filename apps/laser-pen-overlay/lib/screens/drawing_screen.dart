import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/stroke.dart';
import '../services/touch_service.dart';
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

  @override
  void initState() {
    super.initState();
    _startFadeTimer();
    _initTouchService();
  }

  void _initTouchService() {
    _touchService = TouchService();
    _touchService.onStylusTouch = _handleStylusTouch;
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _touchService.dispose();
    super.dispose();
  }

  void _handleStylusTouch(StylusTouch touch) {
    if (!_useStylusOnly) return;
    
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
    if (_useStylusOnly) return; // Native handles stylus
    _startStroke(d.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_useStylusOnly) return;
    _updateStroke(d.localPosition);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_useStylusOnly) return;
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
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() {
      _undoStack.add(_strokes.removeLast());
    });
  }

  void _redo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _strokes.add(_undoStack.removeLast());
    });
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _undoStack.clear();
    });
  }

  void _exit() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Drawing area
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
          // Mode indicator
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
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
                canUndo: _strokes.isNotEmpty,
                canRedo: _undoStack.isNotEmpty,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
