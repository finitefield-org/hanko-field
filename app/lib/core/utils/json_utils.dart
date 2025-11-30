// ignore_for_file: public_member_api_docs

DateTime? parseDateTime(Object? value) {
  if (value is String) return DateTime.parse(value);
  return null;
}

List<T> mapList<T>(
  Object? value,
  T Function(Map<String, Object?> map) builder,
) {
  if (value is List) {
    return value
        .whereType<Object?>()
        .map((item) => builder(Map<String, Object?>.from(item as Map)))
        .toList();
  }
  return <T>[];
}

Map<String, Object?>? asMap(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return null;
}
