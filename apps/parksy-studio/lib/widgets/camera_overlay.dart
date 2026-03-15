import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/studio_scenario.dart'; // CameraFrame enum (model layer 정의)

// ── 드래그 가능한 카메라 오버레이 ──────────────────────────────────
class CameraOverlay extends StatefulWidget {
  final CameraController controller;
  final CameraFrame frame;
  final double size;

  const CameraOverlay({
    super.key,
    required this.controller,
    required this.frame,
    this.size = 120,
  });

  @override
  State<CameraOverlay> createState() => _CameraOverlayState();
}

class _CameraOverlayState extends State<CameraOverlay> {
  Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.value.isInitialized) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 절대 좌표 clamp: 부모 크기 - 오버레이 크기
        final maxDx = constraints.maxWidth.isFinite  ? constraints.maxWidth  / 2 : 200.0;
        final maxDy = constraints.maxHeight.isFinite ? constraints.maxHeight / 2 : 400.0;

        return GestureDetector(
          onPanUpdate: (d) {
            setState(() {
              _offset = Offset(
                (_offset.dx + d.delta.dx).clamp(-maxDx, maxDx).toDouble(),
                (_offset.dy + d.delta.dy).clamp(-maxDy, maxDy).toDouble(),
              );
            });
          },
          child: Transform.translate(
            offset: _offset,
            child: _buildFramed(),
          ),
        );
      },
    );
  }

  Widget _buildFramed() {
    final s = widget.size;
    return switch (widget.frame) {
      CameraFrame.plain   => _plain(s),
      CameraFrame.iphone  => _iphone(s),
      CameraFrame.retroTv => _retroTv(s),
    };
  }

  // #3 fix: FittedBox.cover로 비율 왜곡 방지
  // #4 fix: 전면 카메라 좌우 반전 (셀카 미러링)
  Widget _coverCamera(double w, double h) {
    final isFront = widget.controller.description.lensDirection == CameraLensDirection.front;
    final preview = FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: widget.controller.value.previewSize?.height ?? w,
        height: widget.controller.value.previewSize?.width ?? h,
        child: CameraPreview(widget.controller),
      ),
    );
    return isFront ? Transform.flip(flipX: true, child: preview) : preview;
  }

  // ── 기본 원형 ──────────────────────────────────────────────────
  Widget _plain(double s) {
    return SizedBox(
      width: s, height: s,
      child: Stack(children: [
        ClipOval(child: SizedBox(width: s, height: s, child: _coverCamera(s, s))),
        CustomPaint(size: Size(s, s), painter: _PlainPainter()),
      ]),
    );
  }

  // ── 아이폰 영상통화 (9:16 세로) ────────────────────────────────
  Widget _iphone(double s) {
    final w = s * 0.72;
    final h = s;
    return SizedBox(
      width: w, height: h,
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(width: w, height: h, child: _coverCamera(w, h)),
        ),
        CustomPaint(size: Size(w, h), painter: _IPhonePainter()),
      ]),
    );
  }

  // ── 로타리 TV (4:3 가로) ───────────────────────────────────────
  Widget _retroTv(double s) {
    final w = s;
    final h = s * 0.80;
    return SizedBox(
      width: w, height: h,
      child: Stack(children: [
        Positioned(
          left: 10, top: 10, right: 10, bottom: 18,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _coverCamera(w - 20, h - 28),
          ),
        ),
        CustomPaint(size: Size(w, h), painter: _RetroTvPainter()),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Painters
// ══════════════════════════════════════════════════════════════════

class _PlainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 - 1.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
  @override bool shouldRepaint(_) => false;
}

class _IPhonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size sz) {
    final w = sz.width;
    final h = sz.height;
    const r = Radius.circular(22);
    const bezelColor = Color(0xFF1A1A1E);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), r),
      Paint()..color = bezelColor..style = PaintingStyle.stroke..strokeWidth = 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, 11), width: w * 0.38, height: 14),
        const Radius.circular(7),
      ),
      Paint()..color = bezelColor,
    );
    final btnPaint = Paint()..color = const Color(0xFF2A2A2E)..strokeWidth = 5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-1, h * 0.28), Offset(-1, h * 0.40), btnPaint);
    canvas.drawLine(Offset(-1, h * 0.45), Offset(-1, h * 0.57), btnPaint);
    canvas.drawLine(
      Offset(w / 2 - 22, h - 5), Offset(w / 2 + 22, h - 5),
      Paint()..color = Colors.white.withValues(alpha: 0.5)..strokeWidth = 3..strokeCap = StrokeCap.round..style = PaintingStyle.stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0.5, 0.5, w - 1, h - 1), r),
      Paint()..color = Colors.white.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 1,
    );
  }
  @override bool shouldRepaint(_) => false;
}

class _RetroTvPainter extends CustomPainter {
  static const _bezel  = Color(0xFFD4C9A8);
  static const _shadow = Color(0xFF8B7355);
  static const _knob   = Color(0xFF4A3728);

  @override
  void paint(Canvas canvas, Size sz) {
    final w = sz.width;
    final h = sz.height;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(14)),
      Paint()..color = _bezel..style = PaintingStyle.stroke..strokeWidth = 18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(9, 9, w - 18, h - 18), const Radius.circular(8)),
      Paint()..color = _shadow..style = PaintingStyle.stroke..strokeWidth = 2.5,
    );
    final scanPaint = Paint()..color = Colors.black.withValues(alpha: 0.10)..strokeWidth = 1;
    for (double y = 10; y < h - 18; y += 3.5) {
      canvas.drawLine(Offset(10, y), Offset(w - 10, y), scanPaint);
    }
    final dotPaint = Paint()..color = _shadow;
    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 3; col++) {
        canvas.drawCircle(Offset(w - 18 + col * 4.5, h - 14 + row * 4.5), 1.5, dotPaint);
      }
    }
    canvas.drawCircle(Offset(w - 12, 12), 6, Paint()..color = _knob);
    canvas.drawCircle(Offset(w - 12, 12), 2.5, Paint()..color = _bezel);
    canvas.drawCircle(Offset(13, 12), 3.5, Paint()..color = Colors.red.withValues(alpha: 0.85));
    canvas.drawCircle(Offset(13, 12), 1.5, Paint()..color = Colors.red.shade300);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 - 20, h - 14, 40, 8), const Radius.circular(2)),
      Paint()..color = _shadow.withValues(alpha: 0.4),
    );
  }
  @override bool shouldRepaint(_) => false;
}
