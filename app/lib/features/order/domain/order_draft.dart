class OrderDraftSealSelection {
  const OrderDraftSealSelection({
    required this.localSealDesignId,
    required this.selectedKanji,
    required this.reading,
    required this.shape,
    required this.style,
    required this.strokeWeight,
    required this.balance,
    required this.aiGenerationId,
    required this.aiVariantId,
    required this.previewImageStoragePath,
    required this.previewImageDownloadUrl,
    required this.localImagePath,
  });

  final String localSealDesignId;
  final String selectedKanji;
  final String reading;
  final String shape;
  final String style;
  final String strokeWeight;
  final String balance;
  final String aiGenerationId;
  final String aiVariantId;
  final String previewImageStoragePath;
  final String previewImageDownloadUrl;
  final String localImagePath;
}
