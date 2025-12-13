import 'package:flutter/material.dart';
import '../models/stroke.dart';

class DrawingCanvas extends StatelessWidget {
  final List<Stroke> strokes;
  final Stroke? currentStroke;

  const DrawingCanvas({
    super.key,
    required this.strokes,
    this.currentStroke,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StrokePainter(
        strokes: strokes,
        currentStroke: currentStroke,
      ),
      size: Size.infinite,
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? currentStroke;

  _StrokePainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, stroke.currentOpacity);
    }
    
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!, 1.0);
    }
  }

  void _drawStroke(Canvas canvas, Stroke stroke, double opacity) {
    if (stroke.points.length < 2) return;
    if (opacity <= 0) return;

    final paint = Paint()
      ..color = stroke.color.withOpacity(opacity)
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
    
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
