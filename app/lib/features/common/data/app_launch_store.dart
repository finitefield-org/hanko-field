import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppLaunchStore {
  const AppLaunchStore();

  static const _databaseName = 'hanko_field_app.db';
  static const _settingsTable = 'app_settings';
  static const _keyColumn = 'key';
  static const _valueColumn = 'value';
  static const _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const _preferredLanguageCodeKey = 'preferred_language_code';

  Future<bool> hasSeenOnboarding() async {
    final db = await _openDatabase();
    final rows = await db.query(
      _settingsTable,
      columns: [_valueColumn],
      where: '$_keyColumn = ?',
      whereArgs: [_hasSeenOnboardingKey],
      limit: 1,
    );

    if (rows.isEmpty) {
      return false;
    }

    return rows.first[_valueColumn] == 'true';
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    final db = await _openDatabase();
    await db.insert(_settingsTable, {
      _keyColumn: _hasSeenOnboardingKey,
      _valueColumn: value ? 'true' : 'false',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> preferredLanguageCode() async {
    final db = await _openDatabase();
    final rows = await db.query(
      _settingsTable,
      columns: [_valueColumn],
      where: '$_keyColumn = ?',
      whereArgs: [_preferredLanguageCodeKey],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first[_valueColumn]?.toString();
  }

  Future<void> setPreferredLanguageCode(String languageCode) async {
    final normalized = languageCode.trim().toLowerCase();
    final db = await _openDatabase();
    await db.insert(_settingsTable, {
      _keyColumn: _preferredLanguageCodeKey,
      _valueColumn: normalized,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Database> _openDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = p.join(documentsDirectory.path, _databaseName);
    return openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, _) => _ensureSchema(db),
      onOpen: _ensureSchema,
    );
  }

  Future<void> _ensureSchema(Database db) {
    return db.execute('''
CREATE TABLE IF NOT EXISTS $_settingsTable (
  $_keyColumn TEXT PRIMARY KEY,
  $_valueColumn TEXT NOT NULL
)
''');
  }
}
