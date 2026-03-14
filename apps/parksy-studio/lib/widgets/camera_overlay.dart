import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

// ── 프레임 종류 ────────────────────────────────────────────────────
enum CameraFrame { plain, iphone, retroTv }

extension CameraFrameLabel on CameraFrame {
  String get icon => switch (this) {
    CameraFrame.plain   => '⭕',
    CameraFrame.iphone  => '📱',
    CameraFrame.retroTv => '📺',
  };
  String get label => switch (this) {
    CameraFrame.plain   => '원형',
    CameraFrame.iphone  => '아이폰',
    CameraFrame.retroTv => 'TV',
  };
}

// ── 드래그 가능한 카메라 오버레이 ──────────────────────────────────
class CameraOverlay extends StatefulWidget {
  final CameraController controller;
  final CameraFrame frame;
  final double size; // base size (원형 지름 기준)

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
    return GestureDetector(
      onPanUpdate: (d) => setState(() => _offset += d.delta),
      child: Transform.translate(
        offset: _offset,
        child: _buildFramed(),
      ),
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

  // ── 기본 원형 ──────────────────────────────────────────────────
  Widget _plain(double s) {
    return SizedBox(
      width: s, height: s,
      child: Stack(children: [
        ClipOval(child: SizedBox(width: s, height: s, child: CameraPreview(widget.controller))),
        CustomPaint(size: Size(s, s), painter: _PlainPainter()),
      ]),
    );
  }

  // ── 아이폰 영상통화 (9:16 세로) ────────────────────────────────
  Widget _iphone(double s) {
    final w = s * 0.72;
    final h = s;
    const r = Radius.circular(22);
    return SizedBox(
      width: w, height: h,
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.all(r),
          child: SizedBox(width: w, height: h, child: CameraPreview(widget.controller)),
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
        // 스크린 영역만 클립 (베젤 안쪽)
        Positioned(
          left: 10, top: 10, right: 10, bottom: 18,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CameraPreview(widget.controller),
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

// ── 원형 — 흰 테두리 ──────────────────────────────────────────────
class _PlainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r - 1.5,
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }
  @override bool shouldRepaint(_) => false;
}

// ── 아이폰 영상통화 ────────────────────────────────────────────────
class _IPhonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size sz) {
    final w = sz.width;
    final h = sz.height;
    const r = Radius.circular(22);
    const bezelColor = Color(0xFF1A1A1E);

    // 외부 베젤
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), r),
      Paint()..color = bezelColor..style = PaintingStyle.stroke..strokeWidth = 8,
    );

    // 다이나믹 아일랜드 (상단 중앙 pill)
    final islandRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, 11), width: w * 0.38, height: 14),
      const Radius.circular(7),
    );
    canvas.drawRRect(islandRect, Paint()..color = bezelColor);

    // 사이드 버튼 (왼쪽)
    final btnPaint = Paint()..color = const Color(0xFF2A2A2E)..strokeWidth = 5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-1, h * 0.28), Offset(-1, h * 0.40), btnPaint);
    canvas.drawLine(Offset(-1, h * 0.45), Offset(-1, h * 0.57), btnPaint);

    // 홈 바 (하단)
    canvas.drawLine(
      Offset(w / 2 - 22, h - 5), Offset(w / 2 + 22, h - 5),
      Paint()..color = Colors.white.withOpacity(0.5)..strokeWidth = 3..strokeCap = StrokeCap.round..style = PaintingStyle.stroke,
    );

    // 외곽 광택 (얇은 흰 선)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0.5, 0.5, w - 1, h - 1), r),
      Paint()..color = Colors.white.withOpacity(0.12)..style = PaintingStyle.stroke..strokeWidth = 1,
    );
  }
  @override bool shouldRepaint(_) => false;
}

// ── 로타리 TV ─────────────────────────────────────────────────────
class _RetroTvPainter extends CustomPainter {
  static const _bezel  = Color(0xFFD4C9A8); // 크림색 베젤
  static const _shadow = Color(0xFF8B7355); // 어두운 갈색 내부 섀도
  static const _knob   = Color(0xFF4A3728); // 노브 색

  @override
  void paint(Canvas canvas, Size sz) {
    final w = sz.width;
    final h = sz.height;

    // 외부 베젤 (두꺼운 크림색)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(14)),
      Paint()..color = _bezel..style = PaintingStyle.stroke..strokeWidth = 18,
    );

    // 내부 섀도 테두리
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(9, 9, w - 18, h - 18), const Radius.circular(8)),
      Paint()..color = _shadow..style = PaintingStyle.stroke..strokeWidth = 2.5,
    );

    // 스캔라인 (수평선 반복)
    final scanPaint = Paint()..color = Colors.black.withOpacity(0.10)..strokeWidth = 1;
    for (double y = 10; y < h - 18; y += 3.5) {
      canvas.drawLine(Offset(10, y), Offset(w - 10, y), scanPaint);
    }

    // 우하단 스피커 격자 (3×2)
    final dotPaint = Paint()..color = _shadow..style = PaintingStyle.fill;
    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 3; col++) {
        canvas.drawCircle(
          Offset(w - 18 + col * 4.5, h - 14 + row * 4.5), 1.5, dotPaint,
        );
      }
    }

    // 우상단 채널 노브
    canvas.drawCircle(Offset(w - 12, 12), 6, Paint()..color = _knob);
    canvas.drawCircle(Offset(w - 12, 12), 2.5, Paint()..color = _bezel);

    // 좌상단 전원 표시등 (빨간 점)
    canvas.drawCircle(Offset(13, 12), 3.5, Paint()..color = Colors.red.withOpacity(0.85));
    canvas.drawCircle(Offset(13, 12), 1.5, Paint()..color = Colors.red.shade300);

    // 하단 채널 텍스트 영역 (장식)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w / 2 - 20, h - 14, 40, 8), const Radius.circular(2),
      ),
      Paint()..color = _shadow.withOpacity(0.4),
    );
  }
  @override bool shouldRepaint(_) => false;
}
