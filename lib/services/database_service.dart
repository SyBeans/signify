import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../providers/app_state.dart'; // For TranslationEntry and Contact models

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'signify.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE translations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            english_text TEXT NOT NULL,
            filipino_text TEXT NOT NULL,
            emotion TEXT,
            confidence REAL,
            is_favorite INTEGER DEFAULT 0,
            timestamp INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE phrasebook_favs (
            english_phrase TEXT PRIMARY KEY
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ── TRANSLATIONS ──
  Future<List<TranslationEntry>> getTranslations() async {
    final db = await database;
    final maps = await db.query('translations', orderBy: 'timestamp DESC');
    return maps
        .map(
          (m) => TranslationEntry(
            id: m['id'] as int,
            english: m['english_text'] as String,
            filipino: m['filipino_text'] as String,
            emotion: m['emotion'] as String? ?? 'Neutral',
            confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
            isFavorite: (m['is_favorite'] as int) == 1,
            time: DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
          ),
        )
        .toList();
  }

  Future<int> insertTranslation(TranslationEntry entry) async {
    final db = await database;
    return await db.insert('translations', {
      'english_text': entry.english,
      'filipino_text': entry.filipino,
      'emotion': entry.emotion,
      'confidence': entry.confidence,
      'is_favorite': entry.isFavorite ? 1 : 0,
      'timestamp': entry.time.millisecondsSinceEpoch,
    });
  }

  Future<void> toggleFavorite(int id, bool isFav) async {
    final db = await database;
    await db.update(
      'translations',
      {'is_favorite': isFav ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTranslation(int id) async {
    final db = await database;
    await db.delete('translations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('translations');
  }

  // ── CONTACTS ──
  Future<List<Contact>> getContacts() async {
    final db = await database;
    final maps = await db.query('contacts');
    return maps
        .map(
          (m) =>
              Contact(name: m['name'] as String, phone: m['phone'] as String),
        )
        .toList();
  }

  Future<void> saveContact(Contact contact) async {
    final db = await database;
    await db.insert('contacts', {'name': contact.name, 'phone': contact.phone});
  }

  Future<void> clearContacts() async {
    final db = await database;
    await db.delete('contacts');
  }

  // ── PHRASEBOOK FAVORITES ──
  Future<Set<String>> getPhrasebookFavs() async {
    final db = await database;
    final maps = await db.query('phrasebook_favs');
    return maps.map((m) => m['english_phrase'] as String).toSet();
  }

  Future<void> togglePhraseFav(String english, bool isFav) async {
    final db = await database;
    if (isFav) {
      await db.insert('phrasebook_favs', {
        'english_phrase': english,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.delete(
        'phrasebook_favs',
        where: 'english_phrase = ?',
        whereArgs: [english],
      );
    }
  }

  // ── SETTINGS ──
  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final maps = await db.query('settings');
    return {for (var m in maps) m['key'] as String: m['value'] as String};
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
