import 'package:shared_preferences/shared_preferences.dart';

class GuideBookmarksRepository {
  GuideBookmarksRepository(this._preferences);

  static const _prefsKey = 'guides.bookmarks';
  final SharedPreferences _preferences;

  Set<String> loadBookmarks() {
    final stored = _preferences.getStringList(_prefsKey);
    if (stored == null) {
      return <String>{};
    }
    return stored.toSet();
  }

  Future<void> saveBookmarks(Set<String> bookmarks) async {
    final sorted = bookmarks.toList()..sort();
    final success = await _preferences.setStringList(_prefsKey, sorted);
    if (!success) {
      throw StateError('Failed to persist guide bookmarks');
    }
  }
}
