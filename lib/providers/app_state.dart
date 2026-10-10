import 'package:flutter/foundation.dart';

class TranslationEntry {
  final String english;
  final String filipino;
  final String emotion;
  final DateTime time;
  TranslationEntry({
    required this.english,
    required this.filipino,
    required this.emotion,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class Contact {
  String name;
  String phone;
  Contact({required this.name, required this.phone});
}

class AppState extends ChangeNotifier {
  // Settings
  String userName = 'Juan Dela Cruz';
  String displayLanguage = 'both'; // 'eng' | 'both' | 'fil'
  String speechLanguage = 'eng'; // 'eng' | 'fil'
  bool showEmotion = true;
  bool autoSpeak = true;
  String speechSpeed = 'normal'; // 'slow' | 'normal' | 'fast'
  bool darkMode = false;
  String textSize = 'M'; // 'S' | 'M' | 'L'
  bool includeGps = true;
  bool waitAccurateGps = true;

  final List<Contact> contacts = [
    Contact(name: 'Mom', phone: '+63 912 345 6789'),
    Contact(name: 'Dad', phone: '+63 917 234 5678'),
    Contact(name: 'Sister', phone: '+63 920 111 2222'),
  ];

  // Live sentence builder
  final List<Map<String, String>> sentence = []; // {en, fil, emotion}
  String? lastDetectedSign;
  double lastSignConfidence = 0.0;
  String currentEmotion = 'Neutral';
  double currentEmotionConfidence = 0.0;

  String get englishSentence => sentence.map((e) => e['en'] ?? '').join(' ');
  String get filipinoSentence => sentence.map((e) => e['fil'] ?? '').join(' ');

  // History
  final List<TranslationEntry> history = [
    TranslationEntry(
      english: 'Thank you',
      filipino: 'Salamat po',
      emotion: 'Positive',
      time: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    TranslationEntry(
      english: 'How are you?',
      filipino: 'Kumusta ka?',
      emotion: 'Neutral',
      time: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    TranslationEntry(
      english: 'Help me',
      filipino: 'Tulungan mo ako',
      emotion: 'Negative',
      time: DateTime.now().subtract(const Duration(hours: 8)),
    ),
  ];

  void addToSentence(String en, String fil, String emotion) {
    sentence.add({'en': en, 'fil': fil, 'emotion': emotion});
    lastDetectedSign = en;
    lastSignConfidence =
        0.7 + (DateTime.now().millisecondsSinceEpoch % 25) / 100;
    notifyListeners();
  }

  void backspace() {
    if (sentence.isNotEmpty) {
      sentence.removeLast();
      notifyListeners();
    }
  }

  void clearSentence() {
    sentence.clear();
    notifyListeners();
  }

  void saveSentence() {
    if (sentence.isEmpty) return;
    history.insert(
      0,
      TranslationEntry(
        english: englishSentence,
        filipino: filipinoSentence,
        emotion: currentEmotion,
      ),
    );
    sentence.clear();
    notifyListeners();
  }

  void setDisplayLanguage(String v) {
    displayLanguage = v;
    notifyListeners();
  }

  void setSpeechLanguage(String v) {
    speechLanguage = v;
    notifyListeners();
  }

  void setShowEmotion(bool v) {
    showEmotion = v;
    notifyListeners();
  }

  void setAutoSpeak(bool v) {
    autoSpeak = v;
    notifyListeners();
  }

  void setSpeechSpeed(String v) {
    speechSpeed = v;
    notifyListeners();
  }

  void setDarkMode(bool v) {
    darkMode = v;
    notifyListeners();
  }

  void setTextSize(String v) {
    textSize = v;
    notifyListeners();
  }

  void setUserName(String v) {
    userName = v;
    notifyListeners();
  }

  void setIncludeGps(bool v) {
    includeGps = v;
    notifyListeners();
  }

  void setWaitAccurateGps(bool v) {
    waitAccurateGps = v;
    notifyListeners();
  }
}
