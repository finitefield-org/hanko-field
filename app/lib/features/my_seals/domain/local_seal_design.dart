class LocalSealDesign {
  const LocalSealDesign({
    required this.id,
    required this.inputName,
    required this.selectedKanji,
    required this.reading,
    required this.impression,
    required this.characterCount,
    required this.shape,
    required this.style,
    required this.strokeWeight,
    required this.balance,
    required this.aiGenerationId,
    required this.aiVariantId,
    required this.previewImageStoragePath,
    required this.previewImageDownloadUrl,
    required this.localImagePath,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
    this.meaning,
    this.strokeComplexity,
    this.engravingSuitability,
  });

  final String id;
  final String inputName;
  final String selectedKanji;
  final String reading;
  final String? meaning;
  final List<String> impression;
  final int characterCount;
  final String? strokeComplexity;
  final String? engravingSuitability;
  final String shape;
  final String style;
  final String strokeWeight;
  final String balance;
  final String aiGenerationId;
  final String aiVariantId;
  final String previewImageStoragePath;
  final String previewImageDownloadUrl;
  final String localImagePath;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  LocalSealDesign copyWith({
    String? id,
    String? inputName,
    String? selectedKanji,
    String? reading,
    String? meaning,
    List<String>? impression,
    int? characterCount,
    String? strokeComplexity,
    String? engravingSuitability,
    String? shape,
    String? style,
    String? strokeWeight,
    String? balance,
    String? aiGenerationId,
    String? aiVariantId,
    String? previewImageStoragePath,
    String? previewImageDownloadUrl,
    String? localImagePath,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocalSealDesign(
      id: id ?? this.id,
      inputName: inputName ?? this.inputName,
      selectedKanji: selectedKanji ?? this.selectedKanji,
      reading: reading ?? this.reading,
      meaning: meaning ?? this.meaning,
      impression: impression ?? this.impression,
      characterCount: characterCount ?? this.characterCount,
      strokeComplexity: strokeComplexity ?? this.strokeComplexity,
      engravingSuitability: engravingSuitability ?? this.engravingSuitability,
      shape: shape ?? this.shape,
      style: style ?? this.style,
      strokeWeight: strokeWeight ?? this.strokeWeight,
      balance: balance ?? this.balance,
      aiGenerationId: aiGenerationId ?? this.aiGenerationId,
      aiVariantId: aiVariantId ?? this.aiVariantId,
      previewImageStoragePath:
          previewImageStoragePath ?? this.previewImageStoragePath,
      previewImageDownloadUrl:
          previewImageDownloadUrl ?? this.previewImageDownloadUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
