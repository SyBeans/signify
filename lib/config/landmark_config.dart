// lib/config/landmark_config.dart
//
// Tuned values from plugin_test — DO NOT EDIT WITHOUT RE-TESTING.
// Source: plugin_test/lib/main.dart
//
// If you re-tune in plugin_test, copy the new values here.

import 'package:camera/camera.dart';

class LandmarkConfig {
  // ─── Camera ─────────────────────────────────────────────────
  // LOW (index 0) is the validated perf profile on TECNO CK7n (~15 FPS
  // with alternating MediaPipe). MED/HIGH drop to ~5 FPS.
  static const int defaultResolutionIndex = 0; // 0=low, 1=med, 2=high
  static const List<ResolutionPreset> resolutions = [
    ResolutionPreset.low, // index 0 ✓
    ResolutionPreset.medium, // index 1 ✓
    ResolutionPreset.high, // index 2 ✓
  ];
  static const List<String> resolutionLabels = ['LOW', 'MED', 'HIGH'];

  // ─── Transform ──────────────────────────────────────────────
  static const int backRotationMode = 1;
  static const double handScale =
      1.0; // ⚠ CRITICAL: 1.0 = dots glued to actual landmarks (matches plugin_test)
  static const double offsetShiftX = 0.0;
  static const double offsetShiftY = 0.0;
  static const bool swapDims = true;
  static const bool useContain = false;

  // ─── Visibility ─────────────────────────────────────────────
  static const double minHandSpan = 0.12;

  // ─── Visual (matches plugin_test/main.dart) ─────────────────
  static const double faceDotRadius = 3.0;
  static const double faceDotOpacity = 0.85;
  static const double handTipRadius = 4.0;
  static const double handJointRadius = 1.8; // unused in minimalist painter

  // ─── Performance ────────────────────────────────────────────
  // NOTE: frameSkip is NOT used by the current translate_screen.
  // Frame skip is computed per-resolution via _rawFrameSkipMod getter.
  // Kept here only as a reference value.
  static const int frameSkip = 1;

  // ─── Sign inference (REFERENCE ONLY — not used by translate_screen) ──
  // Current pipeline hardcodes these values inline in _TranslateScreenState.
  // Keep for documentation; do NOT assume the code reads these.
  static const int signBufferLen = 30;
  static const int signFeaturesPerFrame = 126;
  static const double motionStart = 0.02;
  static const double motionEnd = 0.008;
  static const int signCooldownFrames = 30;
  static const double signMinConfidence = 0.40;

  // ─── Emotion inference (REFERENCE ONLY) ─────────────────────
  // Cadence computed via _effectiveEmotionSkip getter (3 at LOW, 5 at MED/HIGH).
  static const int emotionEveryNFrames = 5;
  static const double emotionMinConfidence = 0.35;

  // ─── Debug ──────────────────────────────────────────────────
  static const bool showDebugFrame = false;
}
