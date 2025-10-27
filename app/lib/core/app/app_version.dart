import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ビルド時に埋め込まれるアプリバージョン（`flutter build` の `--dart-define`）。
const String _embeddedAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0',
);

/// セマンティックバージョンを簡易比較するための値オブジェクト。
class AppVersion implements Comparable<AppVersion> {
  AppVersion._(this.raw, this._segments);

  factory AppVersion.parse(String raw) {
    final normalized = raw.trim();
    final segments = _parseSegments(normalized.isEmpty ? '0.0.0' : normalized);
    return AppVersion._(normalized.isEmpty ? '0.0.0' : normalized, segments);
  }

  /// 入力文字列（プレリリース/ビルドメタ含む）。
  final String raw;
  final List<int> _segments;

  bool get isUnknown => raw.trim().isEmpty;

  @override
  int compareTo(AppVersion other) {
    final maxLength = _segments.length > other._segments.length
        ? _segments.length
        : other._segments.length;
    for (var i = 0; i < maxLength; i++) {
      final a = i < _segments.length ? _segments[i] : 0;
      final b = i < other._segments.length ? other._segments[i] : 0;
      if (a == b) continue;
      return a.compareTo(b);
    }
    return 0;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  static List<int> _parseSegments(String raw) {
    final result = <int>[];
    for (final piece in raw.split('.')) {
      final match = RegExp(r'^(\d+)').firstMatch(piece);
      final value = match == null
          ? 0
          : int.tryParse(match.group(1) ?? '0') ?? 0;
      result.add(value);
    }
    if (result.length < 3) {
      return [...result, for (var i = result.length; i < 3; i++) 0];
    }
    return result;
  }
}

class _AppVersionNotifier extends Notifier<AppVersion> {
  @override
  AppVersion build() {
    return AppVersion.parse(_embeddedAppVersion);
  }
}

final appVersionProvider = NotifierProvider<_AppVersionNotifier, AppVersion>(
  _AppVersionNotifier.new,
);
