import 'package:flutter_riverpod/flutter_riverpod.dart';

const _maxHistory = 8;
const _seedHistory = ['丸枠テンプレート', 'チタン印材', '配送状況の確認'];

class SearchHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => List.unmodifiable(_seedHistory);

  void add(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return;
    }
    final entries = state.toList();
    entries.removeWhere((element) => element == normalized);
    entries.insert(0, normalized);
    if (entries.length > _maxHistory) {
      entries.removeRange(_maxHistory, entries.length);
    }
    state = List.unmodifiable(entries);
  }

  void remove(String query) {
    final entries = state.toList()..removeWhere((element) => element == query);
    state = List.unmodifiable(entries);
  }

  void clear() {
    state = const [];
  }
}
