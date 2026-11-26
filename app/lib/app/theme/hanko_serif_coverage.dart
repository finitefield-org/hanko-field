import 'dart:convert';
import 'dart:typed_data';

/// Which ideographs the bundled `Noto Serif JP` font can draw.
///
/// The font follows Japanese character sets, so many Simplified Chinese (and
/// some Traditional Chinese) characters have no glyph in it. Text that mixes
/// covered and uncovered characters would be drawn half in this serif and half
/// in the platform's sans-serif fallback, so callers check a string here before
/// asking for the serif fallback.
///
/// The table is one bit per code point from U+3400 to U+9FFF (CJK Extension A
/// and CJK Unified Ideographs), least significant bit first, taken from the
/// font's format 12 `cmap`. `test/hanko_serif_coverage_test.dart` compares it
/// with `assets/fonts/NotoSerifJP.ttf` and prints a fresh table when the font
/// changes.
const hankoSerifCoverageFirst = 0x3400;
const hankoSerifCoverageLast = 0x9FFF;

const hankoSerifCoverageBase64 =
    'ZAAAAIBQAAAAAAAAAAUAAAABBAAAACAQggAACAAAAAAAAACAAAAAQAAAAGAIQAAAAAAAAEAB'
    'AAAgAABEAAAQACAAEAAAAAAAAAQAAAAAAAAAAEICAAAAAACAAAAAAAAAAAAAAAAAAAAAAAAA'
    'BhggAAAgAAAAAAAAAgAAAAQBECABAAAAAIBAAAEAABACAAAAAAAAAAIgAAAAAAAAAAAABAAA'
    'gAQAAAAAAAAAAACAAAAAAAAAEAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAQAEAIACAAAAAAAAAA'
    'EAjAAAAECAAAQAAUBAAAAAAAAAAAIIAAgCEAABAAQAAIIAAAAAAJAACAAABAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAgABAAAAAAAAAACQAAAAgAAQAAAEAAAAAAAAAQAAAAAARAQAAAAAAAgAAAA'
    'AAAAgAEAAABBAQAACAQQAAAAAAAAAAAEAAAAAAAAAAAAAAAAAACAAAAApAAAAAAAAEACAAAC'
    'gBAAAAAAAAAAAAAAAAIAAAABAAAAAAAACAAAAAAAAAAAAAAAAAAoAAAAAAAAAACBAAAIAAAA'
    'AAAAAAAAEIAAAAAAQEAIAIBAAAAAAAAAAAAAABAAAAAAAAgAAAAAAEAAQCAAAAAABAAAAAAI'
    'AAAIAAAAAAAAAAAAAAAAAAAAAAAAAABAAQAAEYAQBAAAAAAACAgAAEAEAAACAAAACEAAABAA'
    'AAAAAAAhAAAgAAAACAAAAAAAAAQAAAAgAAAAQQAAAAAgBAAAAIABAAAAAAACAAAAIAAAAAAA'
    'AAACwAAAAAAAAAAAAAAAEACAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAQAAAIAAAQEAAAAAA'
    'EEAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAIAA'
    'AAQQAAAAAAIAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAJAAAAAAAAAEAAAAAA'
    'AAAAAAQEBAAAAQAAAACAAAEAAAEAAAAAAAAAAAAAAAAAAAAAEAACAAIAAACAAAAAAAAAAAAA'
    'AAAAAIAAAAAAAAAAAAAAAAAAAAAAAL//98Na/+ebv+ni/wwDOsJlf/b7d/lJHt/t8e8/6e/4'
    'D//nNgDI+3/N+///Gdbr/37/3+8D6OT6f/+fvX/Ab/X3/t///n9tCu/X75btNPche+V/3w+0'
    'v2699nv3/uN/Tt979f+Ktb6f//+9lfV/+lt9/u8jfz//9Xy/fvnndv9n/03+IfRP7x+4vvD9'
    'e9a/o703/p35vvN/+7f3+/8X/8/vvev/u78v/+8/nl/78r/vnENYp3Pv/S0///zu////BR7/'
    'D+zT/3r73fciwNR/+7h7/2eQ9/+O/99nAAFn90708/NxAIDMbnvztst9WwAA+N/PnveYf0WA'
    '+lqe/RxSwuPg59cLAZP/u9/6GUhfv3YF8Z0w5uV73lAv/4v/+2nPpp+/br3/95np5fQHgvbv'
    'u94OG7j2n1cJIcnZ/PDbIvH/fT8g6tOkN6YDvrfHlisl06u/2fFHTw5fvnX/9zfanz5kvn2/'
    'vv/v49jDv++v/3w7HnzsqrjxjV5aLx/2+N3WiRtyjt25p2EQ8xMhROw0gMwQCE3ehRAu/Vab'
    'wRRrRmEsAxvAKiY0VUErGPf9eMtr9f//+7988/+X//Ld7/fbe+X+/97GXX9n/2PtK96/83M+'
    'gJUXoM8//l2gCoUiQ+d3LMJo96/dChKizF0vkhe2ScaeHb2qlViVN4h6z2v/S77rzTh2ryHp'
    '7WG5WvPZHn39/5vM4Bb1PerjTt9//i8b2//f//v7/vvz/bN12zv/vr/3v7/Pc5f/uzO4O99z'
    'F/9vvYDk/b/3ryoEzz/3pr+/o8B+f/7t/Qf/efTPOv+vQf8/z/f/3ocd8/b2fyjnvdn/+Z9s'
    '37exf0RXz/8h8O6z9PWbd3/8z85f6997f10b4Ur+Peb/W0AZ6v709/8/A/T+8J4/S4uAr2T+'
    'Xv69G+B79r2d13XP//80aHvDfxwrfvwHQKbdUXW3ceQEyB69i6JYL6iBL+96ew36tn63Bf+2'
    '9+wzh1j7XN72/7jj9+PNGLUlvlenu/v4vfN+29WL7zM33t33fvD///uef9+G////+d+be8e/'
    'VWg+29/TUL5BW73/q+v8+uV9+uXq83vyf/T/2LPa7z9Xgv97f8eff9bS/94+ANnjhr8f+393'
    'v7uIyPfefuHZv+/vfx54v/+3u/3nPvv/zx5uBXurZEa4fn//v/9HZHYZ4+mX3av9y2Os737q'
    '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';

final Uint8List _coverage = base64Decode(hankoSerifCoverageBase64);

/// Whether `Noto Serif JP` has a glyph for every ideograph in [text].
///
/// Characters outside the ideograph blocks (kana, Latin, punctuation) do not
/// affect the answer. Ideographs beyond the table (supplementary planes) are
/// treated as not covered.
bool hankoSerifCoversIdeographs(String text) {
  for (final rune in text.runes) {
    if (rune >= hankoSerifCoverageFirst && rune <= hankoSerifCoverageLast) {
      final index = rune - hankoSerifCoverageFirst;
      if (_coverage[index >> 3] & (1 << (index & 7)) == 0) {
        return false;
      }
    } else if (rune >= 0x20000 && rune <= 0x3FFFF) {
      return false;
    }
  }
  return true;
}
