// lib/widgets/landmark_painter.dart
import 'package:flutter/material.dart';
import '../config/landmark_config.dart';

/// Our own landmark type — named LandmarkPoint to avoid conflict
/// with hand_landmarker's Landmark class when both are imported.
class LandmarkPoint {
  final double x, y, z;
  const LandmarkPoint(this.x, this.y, this.z);
}

class LandmarkPainter extends CustomPainter {
  final List<LandmarkPoint> faceLandmarks;
  final List<LandmarkPoint> handLandmarks;
  final Size previewSize;
  final bool isFrontCamera;
  final bool showFullHand; // 🆕 true = 21 pts + skeleton; false = 6 minimal
  final bool faceIsGreen; // 🆕 true = green; false = light green

  LandmarkPainter({
    required this.faceLandmarks,
    required this.handLandmarks,
    required this.previewSize,
    required this.isFrontCamera,
    required this.showFullHand,
    required this.faceIsGreen,
  });

  static const _faceIndices = [10, 234, 152, 454, 1];
  static const _handIndices = [0, 4, 8, 12, 16, 20];

  // Full 21-point skeleton connections (used only when showFullHand)
  static const List<List<int>> _handConnections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [17, 18],
    [18, 19],
    [19, 20],
    [0, 17],
  ];

  Offset _rotate(double x, double y) {
    if (isFrontCamera) {
      final t = x;
      return Offset(y, 1.0 - t);
    }
    switch (LandmarkConfig.backRotationMode) {
      case 0:
        final t = x;
        return Offset(y, 1.0 - t);
      case 1:
        final t = x;
        return Offset(1.0 - y, t);
      case 2:
        return Offset(1.0 - x, 1.0 - y);
      case 3:
        return Offset(x, y);
      default:
        final t = x;
        return Offset(1.0 - y, t);
    }
  }

  Offset _mapFace(
    LandmarkPoint lm,
    double sw,
    double sh,
    double ox,
    double oy,
  ) {
    final p = _rotate(lm.x, lm.y);
    double nx = p.dx, ny = p.dy;
    if (isFrontCamera) nx = 1.0 - nx;
    nx += LandmarkConfig.offsetShiftX;
    ny += LandmarkConfig.offsetShiftY;
    return Offset(nx * sw + ox, ny * sh + oy);
  }

  Offset _mapHand(
    LandmarkPoint lm,
    double sw,
    double sh,
    double ox,
    double oy,
    Offset anchor,
  ) {
    final sx = anchor.dx + (lm.x - anchor.dx) * LandmarkConfig.handScale;
    final sy = anchor.dy + (lm.y - anchor.dy) * LandmarkConfig.handScale;
    final p = _rotate(sx, sy);
    double nx = p.dx, ny = p.dy;
    if (isFrontCamera) nx = 1.0 - nx;
    nx += LandmarkConfig.offsetShiftX;
    ny += LandmarkConfig.offsetShiftY;
    return Offset(nx * sw + ox, ny * sh + oy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final frameW = LandmarkConfig.swapDims
        ? previewSize.height
        : previewSize.width;
    final frameH = LandmarkConfig.swapDims
        ? previewSize.width
        : previewSize.height;

    double scale;
    if (LandmarkConfig.useContain) {
      scale = (size.width / frameW) < (size.height / frameH)
          ? (size.width / frameW)
          : (size.height / frameH);
    } else {
      scale = (size.width / frameW) > (size.height / frameH)
          ? (size.width / frameW)
          : (size.height / frameH);
    }

    final scaledW = frameW * scale;
    final scaledH = frameH * scale;
    final offsetX = (size.width - scaledW) / 2;
    final offsetY = (size.height - scaledH) / 2;

    if (LandmarkConfig.showDebugFrame) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..color = Colors.green
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke,
      );
    }

    // ─── FACE: 5 dots — green if GPU, light green if CPU ───
    if (faceLandmarks.length >= 455) {
      final faceColor = faceIsGreen
          ? Colors.green.withOpacity(LandmarkConfig.faceDotOpacity)
          : Colors.lightGreen.withOpacity(LandmarkConfig.faceDotOpacity * 0.8);
      final facePaint = Paint()
        ..color = faceColor
        ..style = PaintingStyle.fill;
      final faceInner = Paint()..color = Colors.white;

      for (final idx in _faceIndices) {
        final p = _mapFace(
          faceLandmarks[idx],
          scaledW,
          scaledH,
          offsetX,
          offsetY,
        );
        canvas.drawCircle(p, LandmarkConfig.faceDotRadius, facePaint);
        canvas.drawCircle(p, 1.0, faceInner);
      }
    }

    // ─── HANDS: 21 points if GPU, 6 points if CPU ───
    final handPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    final handLine = Paint()
      ..color = Colors.green.withOpacity(0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final handInner = Paint()..color = Colors.white;

    const perHand = 21;
    const rejectRadius = 0.35;

    for (int h = 0; h + perHand <= handLandmarks.length; h += perHand) {
      final slice = handLandmarks.sublist(h, h + perHand);

      double cx = 0, cy = 0;
      for (final lm in slice) {
        cx += lm.x;
        cy += lm.y;
      }
      cx /= slice.length;
      cy /= slice.length;
      final anchor = Offset(cx, cy);

      if (showFullHand) {
        // ── FULL 21-POINT SKELETON ──
        final pts = <Offset?>[];
        for (final lm in slice) {
          final dx = (lm.x - cx).abs();
          final dy = (lm.y - cy).abs();
          if (dx > rejectRadius || dy > rejectRadius) {
            pts.add(null);
            continue;
          }
          pts.add(_mapHand(lm, scaledW, scaledH, offsetX, offsetY, anchor));
        }

        // Skeleton lines
        for (final c in _handConnections) {
          final a = pts[c[0]];
          final b = pts[c[1]];
          if (a != null && b != null) canvas.drawLine(a, b, handLine);
        }

        // All 21 dots
        for (int i = 0; i < pts.length; i++) {
          final p = pts[i];
          if (p == null) continue;
          final isTip =
              i == 0 || i == 4 || i == 8 || i == 12 || i == 16 || i == 20;
          canvas.drawCircle(
            p,
            isTip
                ? LandmarkConfig.handTipRadius
                : LandmarkConfig.handJointRadius,
            handPaint,
          );
          if (isTip) canvas.drawCircle(p, 1.5, handInner);
        }
      } else {
        // ── MINIMAL 6-POINT (wrist + 5 fingertips) ──
        for (final idx in _handIndices) {
          final lm = slice[idx];
          final dx = (lm.x - cx).abs();
          final dy = (lm.y - cy).abs();
          if (dx > rejectRadius || dy > rejectRadius) continue;

          final p = _mapHand(lm, scaledW, scaledH, offsetX, offsetY, anchor);
          canvas.drawCircle(p, LandmarkConfig.handTipRadius, handPaint);
          canvas.drawCircle(p, 1.5, handInner);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
