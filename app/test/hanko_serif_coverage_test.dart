import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hankofield/app/theme/app_theme.dart';
import 'package:hankofield/app/theme/hanko_serif_coverage.dart';

void main() {
  test('serif coverage table matches the bundled Noto Serif JP font', () {
    final covered = _format12CodePoints(
      File('assets/fonts/NotoSerifJP.ttf').readAsBytesSync(),
    );
    final length = hankoSerifCoverageLast - hankoSerifCoverageFirst + 1;
    final bits = Uint8List((length + 7) ~/ 8);
    for (var index = 0; index < length; index++) {
      if (covered.contains(hankoSerifCoverageFirst + index)) {
        bits[index >> 3] |= 1 << (index & 7);
      }
    }

    final expected = base64Encode(bits);
    expect(
      hankoSerifCoverageBase64,
      expected,
      reason:
          'assets/fonts/NotoSerifJP.ttf no longer matches the table. Replace '
          'hankoSerifCoverageBase64 with:\n$expected',
    );
  });

  test('offers the serif fallback only for text the font fully covers', () {
    // Japanese names, kana and Latin text keep the Japanese serif.
    expect(HankoFonts.serifFallbackFor('美空'), HankoFonts.serifFallback);
    expect(HankoFonts.serifFallbackFor('あなた専用の印影'), HankoFonts.serifFallback);
    expect(HankoFonts.serifFallbackFor('Misora'), HankoFonts.serifFallback);
    expect(HankoFonts.serifFallbackFor(''), HankoFonts.serifFallback);
    // Traditional forms that Japanese sets also carry are covered.
    expect(HankoFonts.serifFallbackFor('張偉'), HankoFonts.serifFallback);

    // One uncovered Simplified character sends the whole name to the platform
    // font, so it is never drawn in two typefaces.
    expect(HankoFonts.serifFallbackFor('美丽'), isEmpty);
    expect(HankoFonts.serifFallbackFor('张伟'), isEmpty);
    // Ideographs outside the table are treated as not covered.
    expect(HankoFonts.serifFallbackFor('\u{20BB7}野'), isEmpty);
  });
}

/// Code points mapped by the font's format 12 `cmap` subtable.
Set<int> _format12CodePoints(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final tableCount = data.getUint16(4);
  int? cmapOffset;
  for (var index = 0; index < tableCount; index++) {
    final record = 12 + 16 * index;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') {
      cmapOffset = data.getUint32(record + 8);
    }
  }
  if (cmapOffset == null) {
    fail('font has no cmap table');
  }

  final subtableCount = data.getUint16(cmapOffset + 2);
  for (var index = 0; index < subtableCount; index++) {
    final subtable =
        cmapOffset + data.getUint32(cmapOffset + 4 + 8 * index + 4);
    if (data.getUint16(subtable) != 12) {
      continue;
    }
    final groupCount = data.getUint32(subtable + 12);
    final codePoints = <int>{};
    for (var group = 0; group < groupCount; group++) {
      final offset = subtable + 16 + 12 * group;
      final start = data.getUint32(offset);
      final end = data.getUint32(offset + 4);
      for (var codePoint = start; codePoint <= end; codePoint++) {
        codePoints.add(codePoint);
      }
    }
    return codePoints;
  }
  fail('font has no format 12 cmap subtable');
}
