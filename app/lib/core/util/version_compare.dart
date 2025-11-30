// ignore_for_file: public_member_api_docs

import 'dart:math';

/// Compares two dotted version strings (e.g., `1.2.3+4`).
///
/// Returns:
/// - `-1` if [a] is lower than [b]
/// - `0` if equal
/// - `1` if [a] is greater than [b]
///
/// Non-numeric segments are ignored; missing segments are treated as zero.
int compareVersions(String a, String b) {
  final aParts = _parseParts(a);
  final bParts = _parseParts(b);

  if (aParts.isEmpty || bParts.isEmpty) {
    // If parsing fails, fall back to "equal" to avoid false forced updates.
    return 0;
  }

  final length = max(aParts.length, bParts.length);
  for (var i = 0; i < length; i++) {
    final aVal = i < aParts.length ? aParts[i] : 0;
    final bVal = i < bParts.length ? bParts[i] : 0;
    if (aVal == bVal) continue;
    return aVal > bVal ? 1 : -1;
  }

  return 0;
}

bool isVersionAtLeast(String current, String minimum) {
  return compareVersions(current, minimum) >= 0;
}

List<int> _parseParts(String input) {
  return RegExp(r'(\d+)')
      .allMatches(input)
      .map((match) => int.tryParse(match.group(1) ?? '') ?? 0)
      .toList();
}
