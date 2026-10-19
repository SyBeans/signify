import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

class SignModelService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<String> get labels => _labels;

  static const int numFrames = 30;
  static const int numFeatures = 252;

  Future<void> load() async {
    if (_loaded) return;
    final labelsJson = await rootBundle.loadString('assets/models/labels.json');
    _labels = List<String>.from(jsonDecode(labelsJson));
    final modelData = await rootBundle.load('assets/models/sign_model.tflite');

    _interpreter = Interpreter.fromBuffer(modelData.buffer.asUint8List());
    _interpreter!.allocateTensors();
    _loaded = true;
  }

  (String, double, List<double>)? predict(List<List<double>> sequence) {
    if (!_loaded) return null;
    if (sequence.length != numFrames) return null;

    try {
      final in0 = _interpreter!.getInputTensor(0);
      final out0 = _interpreter!.getOutputTensor(0);

      final input = sequence.reshape([1, numFrames, numFeatures]);
      in0.setTo(input);

      _interpreter!.invoke();

      final outData = out0.data;
      final probs = List<double>.from(
        outData.buffer.asFloat32List(
          outData.offsetInBytes,
          outData.lengthInBytes ~/ 4,
        ),
      );

      int bestIdx = 0;
      double bestProb = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > bestProb) {
          bestProb = probs[i];
          bestIdx = i;
        }
      }
      return (_labels[bestIdx], bestProb, probs);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _loaded = false;
  }
}
