// lib/config/landmark_config.dart
//
// Tuned values from plugin_test — DO NOT EDIT WITHOUT RE-TESTING.
// Source: plugin_test/lib/main.dart
//
// If you re-tune in plugin_test, copy the new values here.

import 'package:camera/camera.dart';

class LandmarkConfig {
  // ─── Camera ─────────────────────────────────────────────────
  static const int defaultResolutionIndex = 1; // 0=low, 1=med, 2=high
  static const List<ResolutionPreset> resolutions = [
    ResolutionPreset.low,
    ResolutionPreset.medium,
    ResolutionPreset.high,
  ];
  static const List<String> resolutionLabels = ['LOW', 'MED', 'HIGH'];

  // ─── Transform ──────────────────────────────────────────────
  static const int backRotationMode = 1;
  static const double handScale = 0.55;
  static const double offsetShiftX = 0.0;
  static const double offsetShiftY = 0.0;
  static const bool swapDims = true;
  static const bool useContain = false;

  // ─── Visibility ─────────────────────────────────────────────
  static const double minHandSpan = 0.12;

  // ─── Visual ─────────────────────────────────────────────────
  static const double faceDotRadius = 1.0;
  static const double faceDotOpacity = 0.55;
  static const double handTipRadius = 3.0;
  static const double handJointRadius = 1.8;

  // ─── Performance ────────────────────────────────────────────
  static const int frameSkip = 1;

  // ─── Sign inference (for later) ─────────────────────────────
  static const int signBufferLen = 30;
  static const int signFeaturesPerFrame = 126;
  static const double motionStart = 0.02;
  static const double motionEnd = 0.008;
  static const int signCooldownFrames = 30;
  static const double signMinConfidence = 0.40;

  // ─── Emotion inference (for later) ──────────────────────────
  static const int emotionEveryNFrames = 5;
  static const double emotionMinConfidence = 0.35;

  // ─── Debug ──────────────────────────────────────────────────
  static const bool showDebugFrame = false;
}
