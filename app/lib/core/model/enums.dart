// ignore_for_file: public_member_api_docs

enum SealShape { round, square }

extension SealShapeX on SealShape {
  String toJson() => switch (this) {
    SealShape.round => 'round',
    SealShape.square => 'square',
  };

  static SealShape fromJson(String value) {
    switch (value) {
      case 'round':
        return SealShape.round;
      case 'square':
        return SealShape.square;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported SealShape');
  }
}

enum WritingStyle { tensho, reisho, kaisho, gyosho, koentai, custom }

extension WritingStyleX on WritingStyle {
  String toJson() => switch (this) {
    WritingStyle.tensho => 'tensho',
    WritingStyle.reisho => 'reisho',
    WritingStyle.kaisho => 'kaisho',
    WritingStyle.gyosho => 'gyosho',
    WritingStyle.koentai => 'koentai',
    WritingStyle.custom => 'custom',
  };

  static WritingStyle fromJson(String value) {
    switch (value) {
      case 'tensho':
        return WritingStyle.tensho;
      case 'reisho':
        return WritingStyle.reisho;
      case 'kaisho':
        return WritingStyle.kaisho;
      case 'gyosho':
        return WritingStyle.gyosho;
      case 'koentai':
        return WritingStyle.koentai;
      case 'custom':
        return WritingStyle.custom;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported WritingStyle');
  }
}
