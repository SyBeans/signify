import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
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
  int _resIndex = LandmarkConfig.defaultResolutionIndex;
  bool _isSwitching = false;
  bool _isProcessing = false;
  int _frameCounter = 0;

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

  bool _isEmotionInFlight = false;
  int _emotionFrameCounter = 0;
  final List<String> _emotionVoteBuffer = [];

  List<MapEntry<String, double>> _topPredictions = [];

  // Hand-Drop Auto-Save Logic
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

  @override
  void initState() {
    super.initState();
    _loadModels();
    if (widget.isActive) _startCamera();
  }

  Future<void> _loadModels() async {
    try {
      await _signService.load();
      await _emotionService.load();
      if (mounted) setState(() => _modelsReady = true);
    } catch (e) {
      debugPrint('Model load error: $e');
    }
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
      for (final hand in hands) {
        for (final lm in hand.landmarks) {
          lms.add(LandmarkPoint(lm.x, lm.y, lm.z));
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
    if (_frameCounter % (LandmarkConfig.frameSkip + 1) != 0) return;

    _isProcessing = true;
    try {
      try {
        _handPlugin?.processFrame(
          image,
          _controller!.description.sensorOrientation,
        );
      } catch (_) {}

      final faces = await _faceDetector?.detectFacesFromCameraImage(image);
      final faceOut = <LandmarkPoint>[];
      final frameW = image.width.toDouble();
      final frameH = image.height.toDouble();

      if (faces != null) {
        for (final face in faces) {
          final mesh = face.mesh;
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
          _faceLandmarks = faceOut;
          _handLandmarks = List.from(_handLandmarks);
        });
      }

      if (_modelsReady) {
        _updateSignStream(image, faceOut);
        _updateEmotion(image, faceOut);
        _checkHandDropForAutoSave(); // <-- ADDED THIS
      }
    } catch (e) {
      debugPrint('Frame error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // HAND DROP AUTO-SAVE
  // ═══════════════════════════════════════════════════════════
  void _checkHandDropForAutoSave() {
    final state = context.read<AppState>();

    // If there's no sentence, make sure the timer is canceled and reset
    if (state.sentence.isEmpty) {
      _handDropTimer?.cancel();
      _handDropTimer = null;
      if (_handDropSecondsLeft != 0) {
        setState(() => _handDropSecondsLeft = 0);
      }
      return;
    }

    if (_handLandmarks.isEmpty) {
      // Hand is dropped. Start the timer if it's not already running.
      if (_handDropTimer == null || !_handDropTimer!.isActive) {
        setState(() => _handDropSecondsLeft = 3); // 3 seconds grace period

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
      // Hand is back in frame. Cancel the countdown so it doesn't save prematurely.
      if (_handDropTimer != null && _handDropTimer!.isActive) {
        _handDropTimer!.cancel();
        _handDropTimer = null;
        setState(() => _handDropSecondsLeft = 0);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SIGN — TIME-BASED NATURAL STREAMING
  // ═══════════════════════════════════════════════════════════
  void _updateSignStream(CameraImage image, List<LandmarkPoint> faceOut) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final bufferLimitMs = (4.0 * 1000).toInt();
    _signBuffer.removeWhere((e) => nowMs - e.key > bufferLimitMs);

    if (_handLandmarks.isEmpty) {
      if (_signBuffer.isNotEmpty) {
        _signBuffer.clear();
        _signMotionHistory.clear();
        _lastSignPositions = null;
        _signPredictCounter = 0;
      }
      return;
    }

    final frame = List<double>.filled(126, 0.0);
    final handCount = _handLandmarks.length ~/ 21;
    for (int h = 0; h < math.min(handCount, 2); h++) {
      for (int i = 0; i < 21; i++) {
        final lm = _handLandmarks[h * 21 + i];
        final base = h * 63 + i * 3;
        frame[base + 0] = lm.x;
        frame[base + 1] = lm.y;
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
    if (_emotionFrameCounter % 5 != 0) return;

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
      final bytes = yPlane.bytes;
      final rowStride = yPlane.bytesPerRow;
      final pixelStride = yPlane.bytesPerPixel ?? 1;
      final raw = List<double>.filled(48 * 48, 0.0);

      for (int yy = 0; yy < 48; yy++) {
        for (int xx = 0; xx < 48; xx++) {
          final px = x0 + (xx / 48.0) * (x1 - x0);
          final py = y0 + (yy / 48.0) * (y1 - y0);
          double rawX, rawY;
          if (_isFrontCamera) {
            rawX = 1.0 - py;
            rawY = px;
          } else {
            rawX = py;
            rawY = 1.0 - px;
          }
          final srcX = (rawX * image.width).toInt().clamp(0, image.width - 1);
          final srcY = (rawY * image.height).toInt().clamp(0, image.height - 1);
          final idx = srcY * rowStride + srcX * pixelStride;
          if (idx >= 0 && idx < bytes.length)
            raw[yy * 48 + xx] = bytes[idx] / 255.0;
        }
      }

      final lmVec = <double>[];
      for (final lm in preview) {
        lmVec.add(lm.x);
        lmVec.add(lm.y);
      }

      final result = _emotionService.predict(raw, lmVec);
      if (result != null) {
        final (_, _, rawProbs) = result;
        final weighted = List<double>.filled(4, 0.0);
        double wSum = 0.0;
        final weights = [1.0, 0.50, 1.0, 1.50];
        for (int i = 0; i < 4; i++) {
          weighted[i] = rawProbs[i] * weights[i];
          wSum += weighted[i];
        }
        if (wSum > 0) {
          for (int i = 0; i < 4; i++) weighted[i] /= wSum;
        }

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
    setState(() => _isSwitching = true);
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
            // ── Top row ──
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

            // ── Chips row: HAND | FACE | Emotion ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _detectChip('HAND', _handDetected),
                  const SizedBox(width: 8),
                  _detectChip('FACE', _faceDetected),
                  if (state.showEmotion) ...[
                    const SizedBox(width: 8),
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
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Live camera preview ──
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

            // ── Top-3 predictions ──
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

            // ── Confidence bar ──
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

            // ── Sentence builder ──
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
                    Row(
                      children: [
                        Text(
                          'SENTENCE BUILDER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.textSoft,
                          ),
                        ),
                        const Spacer(),
                        // AUTO-SAVE VISUAL COUNTDOWN (Only shows when hand drops)
                        if (_handDropSecondsLeft > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Hand dropped · Saving in $_handDropSecondsLeft s...',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else if (state.sentence.isNotEmpty)
                          Text(
                            '${(state.lastSignConfidence * 100).toStringAsFixed(0)}% confidence',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSoft,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (state.sentence.isNotEmpty)
                      Row(
                        children: [
                          Container(
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.6,
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
                                      // English display
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
                                                    backgroundColor:
                                                        i ==
                                                            state
                                                                    .sentence
                                                                    .length -
                                                                1
                                                        ? AppColors.greenSoft
                                                        : null,
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

                                      // Filipino display
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

                                      // Grammar/Emotion marker
                                      const SizedBox(height: 10),
                                      if (state.sentence.isNotEmpty)
                                        Row(
                                          children: [
                                            Text(
                                              emoData.$1,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              emo,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: emoData.$2,
                                              ),
                                            ),
                                            const Text(
                                              '  ·  grammatical marker: none',
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

                    // Actions
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

                        // Manual Save Button
                        _iconBtn(
                          Icons.save_outlined,
                          AppColors.blue,
                          bg: AppColors.blueSoft,
                          onTap: () async {
                            if (state.sentence.isEmpty) return;

                            // Cancel the hand-drop timer if it's running
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

  // ── Helper UI Methods ──
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
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: border ? Border.all(color: AppColors.border) : null,
      ),
      child: Icon(icon, color: color, size: 20),
    ),
  );

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
