import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

class TranslationEntry {
  final int? id;
  final String english;
  final String filipino;
  final String emotion;
  final double confidence;
  final bool isFavorite;
  final DateTime time;

  TranslationEntry({
    this.id,
    required this.english,
    required this.filipino,
    required this.emotion,
    this.confidence = 0.8,
    this.isFavorite = false,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class Contact {
  String name;
  String phone;
  Contact({required this.name, required this.phone});
}

class AppState extends ChangeNotifier {
  final _db = DatabaseService();

  // Settings defaults
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

  List<Contact> contacts = [];
  List<TranslationEntry> history = [];
  Set<String> phrasebookFavs = {};

  // Live sentence builder
  final List<Map<String, String>> sentence = []; // {en, fil, emotion}
  String? lastDetectedSign;
  double lastSignConfidence = 0.0;
  String currentEmotion = 'Neutral';
  double currentEmotionConfidence = 0.0;

  String get englishSentence => sentence.map((e) => e['en'] ?? '').join(' ');
  String get filipinoSentence => sentence.map((e) => e['fil'] ?? '').join(' ');

  AppState() {
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    // 1. Load Settings
    final savedSettings = await _db.getSettings();
    if (savedSettings.isNotEmpty) {
      displayLanguage = savedSettings['displayLanguage'] ?? 'both';
      speechLanguage = savedSettings['speechLanguage'] ?? 'eng';
      showEmotion = savedSettings['showEmotion'] == 'true';
      autoSpeak = savedSettings['autoSpeak'] == 'true';
      speechSpeed = savedSettings['speechSpeed'] ?? 'normal';
      darkMode = savedSettings['darkMode'] == 'true';
      textSize = savedSettings['textSize'] ?? 'M';
      userName = savedSettings['userName'] ?? 'Juan Dela Cruz';
      includeGps = savedSettings['includeGps'] == 'true';
      waitAccurateGps = savedSettings['waitAccurateGps'] == 'true';
    }

    // 2. Load History
    history = await _db.getTranslations();

    // 3. Load Contacts
    final savedContacts = await _db.getContacts();
    contacts = savedContacts.isNotEmpty
        ? savedContacts
        : [
            Contact(name: 'Mom', phone: '+63 912 345 6789'),
            Contact(name: 'Dad', phone: '+63 917 234 5678'),
            Contact(name: 'Sister', phone: '+63 920 111 2222'),
          ];

    // 4. Load Favorites
    phrasebookFavs = await _db.getPhrasebookFavs();

    notifyListeners();
  }

  // ── Live Sign Capture ──
  void addToSentence(String en, String fil, String emotion) {
    sentence.add({'en': en, 'fil': fil, 'emotion': emotion});
    lastDetectedSign = en;
    notifyListeners();
  }

  void setSignState(String label, double confidence) {
    lastDetectedSign = label;
    lastSignConfidence = confidence;
    notifyListeners();
  }

  void setEmotion(String emotion, double confidence) {
    currentEmotion = emotion;
    currentEmotionConfidence = confidence;
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

  // ── History Operations ──
  Future<void> saveSentence() async {
    if (sentence.isEmpty) return;
    final entry = TranslationEntry(
      english: englishSentence,
      filipino: filipinoSentence,
      emotion: currentEmotion,
      confidence: lastSignConfidence,
    );
    final id = await _db.insertTranslation(entry);
    history.insert(
      0,
      TranslationEntry(
        id: id,
        english: entry.english,
        filipino: entry.filipino,
        emotion: entry.emotion,
        confidence: entry.confidence,
        time: entry.time,
      ),
    );
    sentence.clear();
    notifyListeners();
  }

  Future<void> toggleHistoryFav(TranslationEntry entry) async {
    if (entry.id == null) return;
    final newFav = !entry.isFavorite;
    await _db.toggleFavorite(entry.id!, newFav);

    final index = history.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      final old = history[index];
      history[index] = TranslationEntry(
        id: old.id,
        english: old.english,
        filipino: old.filipino,
        emotion: old.emotion,
        confidence: old.confidence,
        isFavorite: newFav,
        time: old.time,
      );
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    await _db.clearHistory();
    history.clear();
    notifyListeners();
  }

  // ── Phrasebook Operations ──
  Future<void> togglePhrasebookFav(String english) async {
    final isFav = phrasebookFavs.contains(english);
    await _db.togglePhraseFav(english, !isFav);
    if (isFav) {
      phrasebookFavs.remove(english);
    } else {
      phrasebookFavs.add(english);
    }
    notifyListeners();
  }

  // ── Emergency Operations ──
  Future<void> saveContacts(List<Contact> newContacts) async {
    await _db.clearContacts();
    for (final c in newContacts) {
      await _db.saveContact(c);
    }
    contacts = newContacts;
    notifyListeners();
  }

  // ── Setters (Saves to SQLite) ──
  Future<void> saveSetting(String key, String value) async {
    await _db.saveSetting(key, value);
  }

  void setDisplayLanguage(String v) {
    displayLanguage = v;
    saveSetting('displayLanguage', v);
    notifyListeners();
  }

  void setSpeechLanguage(String v) {
    speechLanguage = v;
    saveSetting('speechLanguage', v);
    notifyListeners();
  }

  void setShowEmotion(bool v) {
    showEmotion = v;
    saveSetting('showEmotion', v.toString());
    notifyListeners();
  }

  void setAutoSpeak(bool v) {
    autoSpeak = v;
    saveSetting('autoSpeak', v.toString());
    notifyListeners();
  }

  void setSpeechSpeed(String v) {
    speechSpeed = v;
    saveSetting('speechSpeed', v);
    notifyListeners();
  }

  void setDarkMode(bool v) {
    darkMode = v;
    saveSetting('darkMode', v.toString());
    notifyListeners();
  }

  void setTextSize(String v) {
    textSize = v;
    saveSetting('textSize', v);
    notifyListeners();
  }

  void setUserName(String v) {
    userName = v;
    saveSetting('userName', v);
    notifyListeners();
  }

  void setIncludeGps(bool v) {
    includeGps = v;
    saveSetting('includeGps', v.toString());
    notifyListeners();
  }

  void setWaitAccurateGps(bool v) {
    waitAccurateGps = v;
    saveSetting('waitAccurateGps', v.toString());
    notifyListeners();
  }
}
