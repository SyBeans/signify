import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:provider/provider.dart';

import '../config/landmark_config.dart';
import '../providers/app_state.dart';
import '../services/tts_service.dart';
import '../theme.dart';
import '../widgets/landmark_painter.dart';

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
    if (widget.isActive) _startCamera();
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
      debugPrint('Camera init failed: $e');
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
      } catch (e) {
        debugPrint('Hand error: $e');
      }

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

      if (mounted) {
        setState(() {
          _faceLandmarks = faceOut;
          _handLandmarks = List.from(_handLandmarks);
        });
      }
    } catch (e) {
      debugPrint('Frame error: $e');
    } finally {
      _isProcessing = false;
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
    _handSub?.cancel();
    _controller?.dispose();
    _faceDetector?.dispose();
    _handPlugin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final emo = state.currentEmotion;
    final emoData = _emotionMap[emo] ?? _emotionMap['Neutral']!;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                          _cameraReady ? 'DETECTING' : 'STARTING',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Options',
                    offset: const Offset(0, 40),
                    onSelected: (value) {
                      switch (value) {
                        case 'low':
                          _applyResolution(0);
                          break;
                        case 'med':
                          _applyResolution(1);
                          break;
                        case 'high':
                          _applyResolution(2);
                          break;
                        case 'flip':
                          _switchCamera();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        enabled: false,
                        height: 28,
                        child: Text(
                          'CAMERA RESOLUTION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      CheckedPopupMenuItem<String>(
                        value: 'low',
                        checked: _resIndex == 0,
                        child: const Text('Low  (240p)'),
                      ),
                      CheckedPopupMenuItem<String>(
                        value: 'med',
                        checked: _resIndex == 1,
                        child: const Text('Medium  (480p)'),
                      ),
                      CheckedPopupMenuItem<String>(
                        value: 'high',
                        checked: _resIndex == 2,
                        child: const Text('High  (720p)'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'flip',
                        child: Row(
                          children: [
                            Icon(Icons.cameraswitch, size: 18),
                            SizedBox(width: 10),
                            Text('Flip camera'),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Chips row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _detectChip('HAND', _handDetected),
                  const SizedBox(width: 8),
                  _detectChip('FACE', _faceDetected),
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
                        Text(emoData.$1, style: const TextStyle(fontSize: 12)),
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
            const SizedBox(height: 14),

            // ── Camera preview (aspect-correct) ──
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
                            // BoxFit.cover preserves the camera's aspect ratio
                            // (fills box, crops edges) — matches painter math
                            FittedBox(
                              fit: BoxFit.cover,
                              clipBehavior: Clip.hardEdge,
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

            // ── Top-3 predictions (static for now) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _predChip('Doctor', 87, primary: true),
                  const SizedBox(width: 8),
                  _predChip('Nurse', 6),
                  const SizedBox(width: 8),
                  _predChip('Help', 4),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Confidence bar (static for now) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.87,
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                // Bottom padding includes system navigation inset
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SENTENCE BUILDER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppColors.textSoft,
                      ),
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
                              (state.sentence.last['en'] ?? '').toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(state.lastSignConfidence * 100).toStringAsFixed(0)}% confidence',
                            style: AppText.small,
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
                                : Text.rich(
                                    TextSpan(
                                      children: [
                                        for (
                                          int i = 0;
                                          i < state.sentence.length;
                                          i++
                                        )
                                          TextSpan(
                                            text: '${state.sentence[i]['en']} ',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textDark,
                                              backgroundColor:
                                                  i == state.sentence.length - 1
                                                  ? AppColors.greenSoft
                                                  : null,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                            const SizedBox(height: 8),
                            if (state.sentence.isNotEmpty)
                              Text(
                                state.filipinoSentence,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSoft,
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (state.sentence.isNotEmpty)
                              Row(
                                children: [
                                  Text(
                                    emoData.$1,
                                    style: const TextStyle(fontSize: 14),
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
                      ),
                    ),

                    // ── Actions ──
                    Row(
                      children: [
                        _iconBtn(
                          Icons.arrow_back,
                          Colors.white,
                          border: true,
                          onTap: state.backspace,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => TtsService.speak(
                              state.speechLanguage == 'fil'
                                  ? state.filipinoSentence
                                  : state.englishSentence,
                              lang: state.speechLanguage,
                              speed: state.speechSpeed,
                            ),
                            icon: const Icon(Icons.volume_up, size: 18),
                            label: const Text(
                              'Speak Sentence',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _iconBtn(
                          Icons.copy_rounded,
                          AppColors.textDark,
                          border: true,
                          onTap: () {},
                        ),
                        const SizedBox(width: 8),
                        _iconBtn(
                          Icons.delete_outline_rounded,
                          AppColors.red,
                          bg: AppColors.redSoft,
                          onTap: state.clearSentence,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: primary ? AppColors.blue : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
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

  // Smaller buttons (44 instead of 48) so the row fits comfortably
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
        color: bg ?? Colors.white,
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
