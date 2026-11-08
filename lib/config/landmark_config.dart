import 'package:camera/camera.dart';

class LandmarkConfig {
  // ─── Camera ─────────────────────────────────────────────────
  // LOW (index 0) is the validated default on TECNO CK7n (~15 FPS).
  static const int defaultResolutionIndex = 0; // 0=low, 1=med, 2=high
  static const List<ResolutionPreset> resolutions = [
    ResolutionPreset.low,
    ResolutionPreset.medium,
    ResolutionPreset.high,
  ];
  static const List<String> resolutionLabels = ['LOW', 'MED', 'HIGH'];

  // ─── Transform ──────────────────────────────────────────────
  static const int backRotationMode = 1;
  static const double handScale = 1.0; // MUST BE 1.0 (Glued)
  static const double offsetShiftX = 0.0;
  static const double offsetShiftY = 0.0;
  static const bool swapDims = true;
  static const bool useContain = false;

  // ─── Visibility ─────────────────────────────────────────────
  static const double minHandSpan = 0.12;

  // ─── Visual ─────────────────────────────────────────────────
  static const double faceDotRadius = 3.0;
  static const double faceDotOpacity = 0.85;
  static const double handTipRadius = 4.0;
  static const double handJointRadius = 1.8; // unused in minimalist painter

  // ─── Performance ────────────────────────────────────────────
  // Frame skip, alternating, and emotion cadence are now computed
  // dynamically in translate_screen.dart to support Universal Optimization.
  static const int frameSkip = 1;
  static const int emotionEveryNFrames = 5;
  static const double emotionMinConfidence = 0.35;
  static const double signMinConfidence = 0.40;
  static const bool showDebugFrame = false;
}
