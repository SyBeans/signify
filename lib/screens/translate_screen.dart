import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:provider/provider.dart';

import '../config/landmark_config.dart';
import '../providers/app_state.dart';
import '../services/sign_model_service.dart';
import '../services/emotion_model_service.dart';
import '../services/tts_service.dart';
import '../theme.dart';
import '../widgets/landmark_painter.dart';
import '../utils/sign_mapping.dart';

List<double> _extractFaceCropInBackground(Map<String, dynamic> data) {
  final Uint8List bytes = data['bytes'];
  final int width = data['width'];
  final int height = data['height'];
  final int rowStride = data['rowStride'];
  final int pixelStride = data['pixelStride'];
  final double x0 = data['x0'];
  final double x1 = data['x1'];
  final double y0 = data['y0'];
  final double y1 = data['y1'];
  final bool isFrontCamera = data['isFrontCamera'];

  final raw = List<double>.filled(48 * 48, 0.0);
  for (int yy = 0; yy < 48; yy++) {
    for (int xx = 0; xx < 48; xx++) {
      final px = x0 + (xx / 48.0) * (x1 - x0);
      final py = y0 + (yy / 48.0) * (y1 - y0);
      double rawX, rawY;
      if (isFrontCamera) {
        rawX = 1.0 - py;
        rawY = px;
      } else {
        rawX = py;
        rawY = 1.0 - px;
      }
      final srcX = (rawX * width).toInt().clamp(0, width - 1);
      final srcY = (rawY * height).toInt().clamp(0, height - 1);
      final idx = srcY * rowStride + srcX * pixelStride;
      if (idx >= 0 && idx < bytes.length) {
        raw[yy * 48 + xx] = bytes[idx] / 255.0;
      }
    }
  }
  return raw;
}

class TranslateScreen extends StatefulWidget {
  final bool isActive;
  const TranslateScreen({super.key, this.isActive = true});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  static const _emotionMap = {
    'Positive': ('😊', AppColors.emoPositive),
    'Negative': ('😢', AppColors.emoNegative),
    'Surprise': ('😲', AppColors.emoSurprise),
    'Neutral': ('😐', AppColors.emoNeutral),
    'Urgent': ('🚨', AppColors.red),
  };

  CameraController? _controller;
  FaceDetector? _faceDetector;
  HandLandmarkerPlugin? _handPlugin;
  StreamSubscription<List<Hand>>? _handSub;

  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  int _resIndex = 0;

  bool _isSwitching = false;
  bool _isProcessing = false;

  int _frameCounter = 0;
  int _processFrameCounter = 0;

  List<LandmarkPoint> _faceLandmarks = [];
  List<LandmarkPoint> _handLandmarks = [];

  final SignModelService _signService = SignModelService();
  final EmotionModelService _emotionService = EmotionModelService();
  bool _modelsReady = false;

  final List<MapEntry<int, List<double>>> _signBuffer = [];
  List<double>? _lastSignPositions;
  final List<double> _signMotionHistory = [];
  int _signPredictCounter = 0;
  int _signCooldownUntil = 0;
  final List<String> _signVoteBuffer = [];
  int _framesSinceHandSeen = 0;

  bool _isEmotionInFlight = false;
  int _emotionFrameCounter = 0;
  final List<String> _emotionVoteBuffer = [];

  bool _signUsesGpu = false;
  bool _emotionUsesGpu = false;
  int _restBlockedCount = 0;

  List<MapEntry<String, double>> _topPredictions = [];

  Timer? _handDropTimer;
  int _handDropSecondsLeft = 0;

  int _framesSinceFps = 0;
  int _lastFpsTime = DateTime.now().millisecondsSinceEpoch;
  double _fps = 0;

  bool get _isFrontCamera =>
      _cameras.isNotEmpty &&
      _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;
  bool get _handDetected => _handLandmarks.isNotEmpty;
  bool get _faceDetected => _faceLandmarks.isNotEmpty;
  bool get _cameraReady =>
      _controller != null && _controller!.value.isInitialized;

  int get _rawFrameSkipMod => _resIndex == 2 ? 2 : 1;
  bool get _alternateMediaPipe => true;
  int get _effectiveEmotionSkip =>
      _resIndex == 0 ? 5 : (_resIndex == 1 ? 6 : 8);

  @override
  void initState() {
    super.initState();
    _loadModels();
    if (widget.isActive) _startCamera();
  }

  Future<void> _loadModels() async {
    try {
      await _signService.load();
      _signUsesGpu = _signService.isGpu;
    } catch (e, st) {
      debugPrint('❌ Sign Model load error: $e\n$st');
    }
    try {
      await _emotionService.load();
      _emotionUsesGpu = _emotionService.isGpu;
    } catch (e, st) {
      debugPrint('❌ Emotion Model load error: $e\n$st');
    }
    if (mounted) setState(() => _modelsReady = true);
    debugPrint('✅ SIGN GPU: $_signUsesGpu | EMO GPU: $_emotionUsesGpu');
  }

  @override
  void didUpdateWidget(covariant TranslateScreen old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _startCamera();
    } else if (!widget.isActive && old.isActive) {
      _stopCamera();
    }
  }

  Future<void> _startCamera() async {
    if (_controller != null) return;
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) return;
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;
    }
    await _openCamera();
  }

  Future<void> _openCamera() async {
    if (_cameras.isEmpty) return;
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _controller = CameraController(
      _cameras[_cameraIndex],
      LandmarkConfig.resolutions[_resIndex],
      enableAudio: false,
    );
    try {
      await _controller!.initialize();
    } catch (e) {
      return;
    }
    _faceDetector ??= await FaceDetector.create();
    _handPlugin ??= HandLandmarkerPlugin.create(
      numHands: 2,
      minHandDetectionConfidence: 0.3,
      delegate: HandLandmarkerDelegate.gpu,
    );

    _handSub ??= _handPlugin!.landmarkStream.listen((hands) {
      final lms = <LandmarkPoint>[];
      if (hands.isNotEmpty) {
        for (final lm in hands[0].landmarks) {
          lms.add(LandmarkPoint(lm.x, lm.y, lm.z));
        }
        if (hands.length > 1) {
          final h1Wrist = hands[0].landmarks[0];
          final h2Wrist = hands[1].landmarks[0];
          final dx = h1Wrist.x - h2Wrist.x;
          final dy = h1Wrist.y - h2Wrist.y;
          final dist = math.sqrt(dx * dx + dy * dy);
          if (dist > 0.12) {
            for (final lm in hands[1].landmarks) {
              lms.add(LandmarkPoint(lm.x, lm.y, lm.z));
            }
          }
        }
      }
      _handLandmarks = lms;
    });

    if (mounted) setState(() => _isSwitching = false);
    _controller!.startImageStream(_processFrame);
  }

  Future<void> _stopCamera() async {
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _faceLandmarks = [];
    _handLandmarks = [];
    _fps = 0;
    if (mounted) setState(() {});
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing || _isSwitching) return;
    _frameCounter++;
    if (_frameCounter % _rawFrameSkipMod != 0) return;
    _isProcessing = true;
    try {
      _processFrameCounter++;
      final bool isHandFrame = (_processFrameCounter % 2 == 0);
      final bool isFaceFrame = (_processFrameCounter % 2 == 1);

      if (isHandFrame) {
        try {
          _handPlugin?.processFrame(
            image,
            _controller!.description.sensorOrientation,
          );
        } catch (_) {}
      }

      final faceOut = <LandmarkPoint>[];
      if (isFaceFrame) {
        final faces = await _faceDetector?.detectFacesFromCameraImage(image);
        final frameW = image.width.toDouble();
        final frameH = image.height.toDouble();
        if (faces != null && faces.isNotEmpty) {
          final mesh = faces.first.mesh;
          if (mesh != null) {
            for (final p in mesh.points) {
              final px = p.x ?? 0.0;
              final py = p.y ?? 0.0;
              final pz = p.z ?? 0.0;
              faceOut.add(
                LandmarkPoint(
                  (px > 1.5) ? (px / frameW) : px,
                  (py > 1.5) ? (py / frameH) : py,
                  pz,
                ),
              );
            }
          }
        }
      }

      _framesSinceFps++;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastFpsTime >= 1000) {
        _fps = _framesSinceFps * 1000 / (now - _lastFpsTime);
        _framesSinceFps = 0;
        _lastFpsTime = now;
      }

      if (mounted) {
        setState(() {
          if (isFaceFrame) _faceLandmarks = faceOut;
          _handLandmarks = List.from(_handLandmarks);
        });
      }

      if (_modelsReady) {
        if (isHandFrame) _updateSignStream(image, faceOut);
        if (isFaceFrame) _updateEmotion(image, faceOut);
        _checkHandDropForAutoSave();
      }
    } catch (e) {
      debugPrint('Frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _checkHandDropForAutoSave() {
    final state = context.read<AppState>();
    if (state.sentence.isEmpty) {
      _handDropTimer?.cancel();
      _handDropTimer = null;
      if (_handDropSecondsLeft != 0) {
        setState(() => _handDropSecondsLeft = 0);
      }
      return;
    }
    if (_handLandmarks.isEmpty) {
      if (_handDropTimer == null || !_handDropTimer!.isActive) {
        setState(() => _handDropSecondsLeft = 3);
        _handDropTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          if (_handDropSecondsLeft <= 1) {
            timer.cancel();
            _handDropTimer = null;
            if (state.sentence.isNotEmpty) {
              final sentenceCopy = state.englishSentence;
              state.saveSentence();
              setState(() => _handDropSecondsLeft = 0);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Auto-saved: "$sentenceCopy"'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            setState(() => _handDropSecondsLeft--);
          }
        });
      }
    } else {
      if (_handDropTimer != null && _handDropTimer!.isActive) {
        _handDropTimer!.cancel();
        _handDropTimer = null;
        setState(() => _handDropSecondsLeft = 0);
      }
    }
  }

  void _updateSignStream(CameraImage image, List<LandmarkPoint> faceOut) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final bufferLimitMs = (4.0 * 1000).toInt();
    _signBuffer.removeWhere((e) => nowMs - e.key > bufferLimitMs);

    if (_handLandmarks.isEmpty) {
      _framesSinceHandSeen++;
      if (_framesSinceHandSeen >= 6) {
        if (_signBuffer.isNotEmpty ||
            _signVoteBuffer.isNotEmpty ||
            _topPredictions.isNotEmpty) {
          _signBuffer.clear();
          _signVoteBuffer.clear();
          _signMotionHistory.clear();
          _lastSignPositions = null;
          _signPredictCounter = 0;
          if (mounted) setState(() => _topPredictions = []);
        }
      }
      return;
    }
    _framesSinceHandSeen = 0;

    final frame = List<double>.filled(126, 0.0);
    final handCount = _handLandmarks.length ~/ 21;
    for (int h = 0; h < math.min(handCount, 2); h++) {
      for (int i = 0; i < 21; i++) {
        final lm = _handLandmarks[h * 21 + i];
        final base = h * 63 + i * 3;
        double lx, ly;
        if (_isFrontCamera) {
          lx = 1.0 - lm.y;
          ly = 1.0 - lm.x;
        } else {
          lx = lm.y;
          ly = lm.x;
        }
        frame[base + 0] = lx;
        frame[base + 1] = ly;
        frame[base + 2] = lm.z;
      }
    }

    double motion = 0.0;
    if (_lastSignPositions != null) {
      double sumSq = 0.0;
      for (int i = 0; i < 126; i++) {
        final d = frame[i] - _lastSignPositions![i];
        sumSq += d * d;
      }
      motion = math.sqrt(sumSq);
    }
    _lastSignPositions = frame;

    _signMotionHistory.add(motion);
    if (_signMotionHistory.length > 10) _signMotionHistory.removeAt(0);
    final anyMotion = _signMotionHistory.any((m) => m > 0.015);
    if (!anyMotion) {
      _signBuffer.clear();
      return;
    }

    _signBuffer.add(MapEntry(nowMs, frame));
    if (nowMs < _signCooldownUntil) return;
    _signPredictCounter++;
    if (_signPredictCounter % 2 != 0) return;
    if (_signBuffer.length < 8) return;

    final tMin = _signBuffer.first.key;
    final tMax = _signBuffer.last.key;
    if (tMax <= tMin) return;

    final sampled = <List<double>>[];
    int bufIdx = 0;
    for (int i = 0; i < 30; i++) {
      final targetTs = tMin + ((tMax - tMin) * i / 29).round();
      while (bufIdx < _signBuffer.length - 1 &&
          (_signBuffer[bufIdx + 1].key - targetTs).abs() <
              (_signBuffer[bufIdx].key - targetTs).abs()) {
        bufIdx++;
      }
      sampled.add(_signBuffer[bufIdx].value);
    }

    final sequence = <List<double>>[];
    for (int i = 0; i < 30; i++) {
      final f = List<double>.filled(252, 0.0);
      for (int j = 0; j < 126; j++) f[j] = sampled[i][j];
      if (i > 0) {
        for (int j = 0; j < 126; j++)
          f[126 + j] = sampled[i][j] - sampled[i - 1][j];
      }
      sequence.add(f);
    }

    final result = _signService.predict(sequence);
    if (result == null) return;
    final (label, conf, probs) = result;

    final indexedProbs = List.generate(
      probs.length,
      (i) => MapEntry(_signService.labels[i], probs[i]),
    );
    indexedProbs.sort((a, b) => b.value.compareTo(a.value));

    if (mounted) {
      setState(() {
        _topPredictions = indexedProbs.take(3).toList();
      });
    }

    if (conf >= 0.50) {
      _signVoteBuffer.add(label);
      if (_signVoteBuffer.length > 6) _signVoteBuffer.removeAt(0);

      if (_signVoteBuffer.length == 6) {
        final counts = <String, int>{};
        for (final l in _signVoteBuffer) counts[l] = (counts[l] ?? 0) + 1;
        final winner = counts.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
        );

        if (winner.value >= 4) {
          if (winner.key == "REST") {
            debugPrint('🛑 REST BLOCKED (${winner.value}/6)');
            _restBlockedCount++;
            _signVoteBuffer.clear();
            _signCooldownUntil = DateTime.now().millisecondsSinceEpoch + 1000;
            return;
          }

          final state = context.read<AppState>();
          if (state.sentence.isEmpty ||
              state.sentence.last['en'] != winner.key) {
            final englishWord = winner.key;
            final filipinoWord = getFilipino(englishWord);
            state.addToSentence(
              englishWord,
              filipinoWord,
              state.currentEmotion,
            );
            state.setSignState(englishWord, conf);
            _signVoteBuffer.clear();
            _signCooldownUntil = DateTime.now().millisecondsSinceEpoch + 1000;
            if (state.autoSpeak) {
              final textToSpeak = state.speechLanguage == 'fil'
                  ? filipinoWord
                  : englishWord;
              TtsService.speak(
                textToSpeak,
                lang: state.speechLanguage,
                speed: state.speechSpeed,
              );
            }
          }
        }
      }
    }
  }

  Future<void> _updateEmotion(
    CameraImage image,
    List<LandmarkPoint> faceOut,
  ) async {
    if (faceOut.length < 400 || _isEmotionInFlight) return;
    _emotionFrameCounter++;
    if (_emotionFrameCounter % _effectiveEmotionSkip != 0) return;
    _isEmotionInFlight = true;
    try {
      final preview = <LandmarkPoint>[];
      for (final lm in faceOut) {
        if (_isFrontCamera) {
          preview.add(LandmarkPoint(lm.y, 1.0 - lm.x, lm.z));
        } else {
          preview.add(LandmarkPoint(1.0 - lm.y, lm.x, lm.z));
        }
      }

      double xMin = preview.map((l) => l.x).reduce(math.min);
      double xMax = preview.map((l) => l.x).reduce(math.max);
      double yMin = preview.map((l) => l.y).reduce(math.min);
      double yMax = preview.map((l) => l.y).reduce(math.max);
      final cx = (xMin + xMax) / 2;
      final cy = (yMin + yMax) / 2;
      final size = math.max(xMax - xMin, yMax - yMin) * 1.55;
      final x0 = (cx - size * 0.50).clamp(0.0, 1.0);
      final x1 = (cx + size * 0.50).clamp(0.0, 1.0);
      final y0 = (cy - size * 0.65).clamp(0.0, 1.0);
      final y1 = (cy + size * 0.35).clamp(0.0, 1.0);

      final yPlane = image.planes[0];
      final raw = await compute(_extractFaceCropInBackground, {
        'bytes': yPlane.bytes,
        'width': image.width,
        'height': image.height,
        'rowStride': yPlane.bytesPerRow,
        'pixelStride': yPlane.bytesPerPixel ?? 1,
        'x0': x0,
        'x1': x1,
        'y0': y0,
        'y1': y1,
        'isFrontCamera': _isFrontCamera,
      });

      final lmVec = <double>[];
      for (final lm in preview) {
        lmVec.add(lm.x);
        lmVec.add(lm.y);
      }

      final result = _emotionService.predict(raw, lmVec);
      if (result != null) {
        final (_, _, rawProbs) = result;
        final weighted = rawProbs;
        int frameIdx = 0;
        double frameTop = weighted[0];
        for (int i = 1; i < 4; i++) {
          if (weighted[i] > frameTop) {
            frameTop = weighted[i];
            frameIdx = i;
          }
        }
        String frameLabel = EmotionModelService.classNames[frameIdx];
        if (frameTop > 0.6 && frameLabel == 'Surprise') frameLabel = 'Urgent';
        if (frameTop >= 0.40) {
          _emotionVoteBuffer.add(frameLabel);
          if (_emotionVoteBuffer.length > 8) _emotionVoteBuffer.removeAt(0);
        }
        if (_emotionVoteBuffer.isNotEmpty) {
          final counts = <String, int>{};
          for (final lbl in _emotionVoteBuffer)
            counts[lbl] = (counts[lbl] ?? 0) + 1;
          final winner = counts.entries.reduce(
            (a, b) => a.value >= b.value ? a : b,
          );
          if (mounted) {
            context.read<AppState>().setEmotion(winner.key, frameTop);
          }
        }
      }
    } finally {
      _isEmotionInFlight = false;
    }
  }

  Future<void> _switchCamera() async {
    if (_isSwitching || _cameras.length < 2) return;
    setState(() {
      _isSwitching = true;
      _frameCounter = 0;
      _processFrameCounter = 0;
    });
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    _faceLandmarks = [];
    _handLandmarks = [];
    await _openCamera();
  }

  Future<void> _applyResolution(int newIndex) async {
    if (_isSwitching || newIndex == _resIndex) return;
    setState(() {
      _isSwitching = true;
      _resIndex = newIndex;
      _frameCounter = 0;
      _processFrameCounter = 0;
    });
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    await _openCamera();
  }

  @override
  void dispose() {
    _handDropTimer?.cancel();
    _handSub?.cancel();
    _controller?.dispose();
    _faceDetector?.dispose();
    _handPlugin?.dispose();
    _signService.dispose();
    _emotionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final emo = state.currentEmotion;
    final emoData = _emotionMap[emo] ?? _emotionMap['Neutral']!;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String topChipText = '';
    if (state.sentence.isNotEmpty) {
      final lastEn = state.sentence.last['en'] ?? '';
      final lastFil = state.sentence.last['fil'] ?? '';
      if (state.displayLanguage == 'fil') {
        topChipText = lastFil.toUpperCase();
      } else if (state.displayLanguage == 'both') {
        topChipText = '$lastEn / $lastFil'.toUpperCase();
      } else {
        topChipText = lastEn.toUpperCase();
      }
    }

    return Container(
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _cameraReady
                                ? AppColors.green
                                : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _cameraReady ? 'LIVE' : 'STARTING',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _miniChip(
                    child: Text(
                      '${_fps.toStringAsFixed(0)}fps',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _miniIconChip(
                    onTap: _switchCamera,
                    child: Text(
                      _isFrontCamera ? 'F' : 'B',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.cyan,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _miniIconChip(
                    onTap: () => _applyResolution(
                      (_resIndex + 1) % LandmarkConfig.resolutions.length,
                    ),
                    child: Text(
                      LandmarkConfig.resolutionLabels[_resIndex],
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.yellow,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'low') _applyResolution(0);
                      if (v == 'med') _applyResolution(1);
                      if (v == 'high') _applyResolution(2);
                      if (v == 'flip') _switchCamera();
                    },
                    itemBuilder: (context) => [
                      CheckedPopupMenuItem(
                        value: 'low',
                        checked: _resIndex == 0,
                        child: const Text('Low (240p)'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'med',
                        checked: _resIndex == 1,
                        child: const Text('Medium (480p)'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'high',
                        checked: _resIndex == 2,
                        child: const Text('High (720p)'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'flip',
                        child: Text('Flip camera'),
                      ),
                    ],
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🆕 FIX 1: Wrap instead of Row — prevents overflow with L text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _detectChip('HAND', _handDetected),
                    _detectChip('FACE', _faceDetected),
                    if (state.showEmotion)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              emoData.$1,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              emo.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: emoData.$2,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _cameraReady
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.previewSize!.height,
                                height: _controller!.value.previewSize!.width,
                                child: CameraPreview(_controller!),
                              ),
                            ),
                            if (_faceLandmarks.isNotEmpty ||
                                _handLandmarks.isNotEmpty)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: LandmarkPainter(
                                    faceLandmarks: _faceLandmarks,
                                    handLandmarks: _handLandmarks,
                                    previewSize:
                                        _controller!.value.previewSize!,
                                    isFrontCamera: _isFrontCamera,
                                    showFullHand: _signUsesGpu,
                                    faceIsGreen: _emotionUsesGpu,
                                  ),
                                ),
                              ),
                            ..._corners(),
                            if (_isSwitching)
                              const Positioned.fill(
                                child: ColoredBox(
                                  color: Colors.black54,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : _placeholder(),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (_topPredictions.isNotEmpty) ...[
                    _predChip(
                      _topPredictions[0].key,
                      (_topPredictions[0].value * 100).toInt(),
                      primary: true,
                    ),
                    const SizedBox(width: 8),
                    if (_topPredictions.length > 1)
                      _predChip(
                        _topPredictions[1].key,
                        (_topPredictions[1].value * 100).toInt(),
                      ),
                    const SizedBox(width: 8),
                    if (_topPredictions.length > 2)
                      _predChip(
                        _topPredictions[2].key,
                        (_topPredictions[2].value * 100).toInt(),
                      ),
                  ] else ...[
                    _predChip('—', 0, primary: true),
                    const SizedBox(width: 8),
                    _predChip('—', 0),
                    const SizedBox(width: 8),
                    _predChip('—', 0),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CONFIDENCE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '${(state.lastSignConfidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: state.lastSignConfidence,
                      minHeight: 5,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation(AppColors.green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🆕 FIX 2: Expanded on header text, Flexible on status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'SENTENCE BUILDER',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: AppColors.textSoft,
                            ),
                          ),
                        ),
                        if (_handDropSecondsLeft > 0)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Hand dropped · $_handDropSecondsLeft s',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        else if (state.sentence.isNotEmpty)
                          Text(
                            '${(state.lastSignConfidence * 100).toStringAsFixed(0)}% conf',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSoft,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 🆕 FIX 3: Blue chip — Flexible + ellipsis (main overflow fix)
                    if (state.sentence.isNotEmpty)
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.blue,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                topChipText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            state.sentence.isEmpty
                                ? const Text(
                                    'Start signing to build a sentence…',
                                    style: TextStyle(color: AppColors.textSoft),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (state.displayLanguage == 'eng' ||
                                          state.displayLanguage == 'both')
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              for (
                                                int i = 0;
                                                i < state.sentence.length;
                                                i++
                                              )
                                                TextSpan(
                                                  text:
                                                      '${state.sentence[i]['en']} ',
                                                  style: TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.color ??
                                                        AppColors.textDark,
                                                  ),
                                                ),
                                              if (state.currentEmotion ==
                                                  'Urgent')
                                                const TextSpan(
                                                  text: '🚨',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      if (state.displayLanguage == 'fil' ||
                                          state.displayLanguage == 'both')
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            state.filipinoSentence,
                                            style: TextStyle(
                                              fontSize:
                                                  state.displayLanguage == 'fil'
                                                  ? 22
                                                  : 15,
                                              fontWeight:
                                                  state.displayLanguage == 'fil'
                                                  ? FontWeight.w800
                                                  : FontWeight.normal,
                                              color:
                                                  state.displayLanguage == 'fil'
                                                  ? (Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.color ??
                                                        AppColors.textDark)
                                                  : AppColors.textSoft,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 10),
                                      if (state.sentence.isNotEmpty)
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              emoData.$1,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              emo,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: emoData.$2,
                                              ),
                                            ),
                                            const Text(
                                              '· grammatical marker: none',
                                              style: AppText.small,
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ),

                    Row(
                      children: [
                        _iconBtn(
                          Icons.arrow_back,
                          AppColors.textDark,
                          border: true,
                          onTap: state.backspace,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              final textToSpeak = state.speechLanguage == 'fil'
                                  ? state.filipinoSentence
                                  : state.englishSentence;
                              TtsService.speak(
                                textToSpeak,
                                lang: state.speechLanguage,
                                speed: state.speechSpeed,
                              );
                            },
                            icon: const Icon(Icons.volume_up, size: 18),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Speak Sentence',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _iconBtn(
                          Icons.save_outlined,
                          AppColors.blue,
                          bg: AppColors.blueSoft,
                          onTap: () async {
                            if (state.sentence.isEmpty) return;
                            _handDropTimer?.cancel();
                            _handDropTimer = null;
                            setState(() => _handDropSecondsLeft = 0);
                            final sentenceCopy = state.englishSentence;
                            await state.saveSentence();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('💾 Saved: "$sentenceCopy"'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.blue,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        _iconBtn(
                          Icons.delete_outline_rounded,
                          AppColors.red,
                          bg: AppColors.redSoft,
                          onTap: () {
                            _handDropTimer?.cancel();
                            _handDropTimer = null;
                            setState(() => _handDropSecondsLeft = 0);
                            state.clearSentence();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Stack(
      children: [
        ..._corners(),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_outlined, color: Colors.white24, size: 48),
              SizedBox(height: 8),
              Text(
                'Starting camera…',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniChip({required Widget child}) => Container(
    constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    alignment: Alignment.center,
    child: child,
  );

  Widget _miniIconChip({required Widget child, required VoidCallback onTap}) =>
      InkWell(
        onTap: _isSwitching ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: _miniChip(child: child),
      );

  Widget _detectChip(String label, bool active) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: active
          ? AppColors.green.withOpacity(0.15)
          : Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: active ? AppColors.green : Colors.grey,
          ),
        ),
      ],
    ),
  );

  Widget _predChip(String label, int pct, {bool primary = false}) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: primary ? AppColors.blue : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '· $pct%',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _iconBtn(
    IconData icon,
    Color color, {
    Color? bg,
    bool border = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg ?? Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: border
              ? Border.all(color: isDark ? Colors.white12 : AppColors.border)
              : null,
        ),
        child: Icon(
          icon,
          color: isDark && color == AppColors.textDark ? Colors.white : color,
          size: 20,
        ),
      ),
    );
  }

  List<Widget> _corners() {
    final style = Paint()
      ..color = AppColors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    return [
      Positioned(
        top: 12,
        left: 12,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(painter: _CornerPainter(style, topLeft: true)),
        ),
      ),
      Positioned(
        top: 12,
        right: 12,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(painter: _CornerPainter(style, topRight: true)),
        ),
      ),
      Positioned(
        bottom: 12,
        left: 12,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(painter: _CornerPainter(style, bottomLeft: true)),
        ),
      ),
      Positioned(
        bottom: 12,
        right: 12,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(painter: _CornerPainter(style, bottomRight: true)),
        ),
      ),
    ];
  }
}

class _CornerPainter extends CustomPainter {
  final Paint paintStyle;
  final bool topLeft, topRight, bottomLeft, bottomRight;

  _CornerPainter(
    this.paintStyle, {
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size s) {
    final p = Path();
    if (topLeft) {
      p.moveTo(0, s.height);
      p.lineTo(0, 0);
      p.lineTo(s.width, 0);
    }
    if (topRight) {
      p.moveTo(0, 0);
      p.lineTo(s.width, 0);
      p.lineTo(s.width, s.height);
    }
    if (bottomLeft) {
      p.moveTo(0, 0);
      p.lineTo(0, s.height);
      p.lineTo(s.width, s.height);
    }
    if (bottomRight) {
      p.moveTo(s.width, 0);
      p.lineTo(s.width, s.height);
      p.lineTo(0, s.height);
    }
    canvas.drawPath(p, paintStyle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
