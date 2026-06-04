typedef JsonMap = Map<String, Object?>;

JsonMap asJsonMap(Object? value, String context) {
  if (value is! Map) {
    throw FormatException('$context must be a JSON object');
  }

  return value.map((key, value) {
    if (key is! String) {
      throw FormatException('$context contains a non-string key');
    }
    return MapEntry(key, value);
  });
}

List<Object?> readJsonList(JsonMap json, String key) {
  final value = json[key];
  if (value is List) {
    return value;
  }
  if (value == null) {
    return const [];
  }
  throw FormatException('$key must be a JSON array');
}

String readString(
  JsonMap json,
  String key, {
  String? fallbackKey,
  String defaultValue = '',
}) {
  final value = json[key] ?? (fallbackKey == null ? null : json[fallbackKey]);
  if (value is String) {
    return value;
  }
  if (value == null) {
    return defaultValue;
  }
  throw FormatException('$key must be a string');
}

String? readOptionalString(JsonMap json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  if (value == null) {
    return null;
  }
  throw FormatException('$key must be a string');
}

int readInt(JsonMap json, String key, {int defaultValue = 0}) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value == null) {
    return defaultValue;
  }
  throw FormatException('$key must be a number');
}

bool readBool(JsonMap json, String key, {bool defaultValue = false}) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  if (value == null) {
    return defaultValue;
  }
  throw FormatException('$key must be a boolean');
}

List<String> readStringList(JsonMap json, String key) {
  return readJsonList(json, key)
      .map((value) {
        if (value is! String) {
          throw FormatException('$key must contain strings');
        }
        return value;
      })
      .toList(growable: false);
}

Map<String, String> readStringMap(JsonMap json, String key) {
  final value = json[key];
  if (value is! Map) {
    if (value == null) {
      return const {};
    }
    throw FormatException('$key must be a JSON object');
  }

  return value.map((entryKey, entryValue) {
    if (entryKey is! String || entryValue is! String) {
      throw FormatException('$key must contain string values');
    }
    return MapEntry(entryKey, entryValue);
  });
}

Map<String, int> readIntMap(JsonMap json, String key) {
  final value = json[key];
  if (value is! Map) {
    if (value == null) {
      return const {};
    }
    throw FormatException('$key must be a JSON object');
  }

  return value.map((entryKey, entryValue) {
    if (entryKey is! String) {
      throw FormatException('$key contains a non-string key');
    }
    if (entryValue is int) {
      return MapEntry(entryKey, entryValue);
    }
    if (entryValue is num) {
      return MapEntry(entryKey, entryValue.toInt());
    }
    throw FormatException('$key must contain number values');
  });
}
