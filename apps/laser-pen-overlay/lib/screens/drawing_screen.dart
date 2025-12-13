import 'dart:async';
import 'package:flutter/material.dart';
import '../models/stroke.dart';
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

  @override
  void initState() {
    super.initState();
    _startFadeTimer();
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _startFadeTimer() {
    _fadeTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _updateFades(),
    );
  }

  void _updateFades() {
    if (_strokes.isEmpty) return;
    
    final expired = _strokes.where((s) => s.isExpired).toList();
    if (expired.isNotEmpty) {
      setState(() {
        _strokes.removeWhere((s) => s.isExpired);
      });
    } else if (_strokes.any((s) => s.shouldFade)) {
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

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = Stroke(
        points: [details.localPosition],
        color: _currentColor,
        width: 4.0,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentStroke == null) return;
    
    setState(() {
      _currentStroke = _currentStroke!.copyWith(
        points: [..._currentStroke!.points, details.localPosition],
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke == null) return;
    
    setState(() {
      _strokes.add(_currentStroke!);
      _currentStroke = null;
      _undoStack.clear();
    });
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
