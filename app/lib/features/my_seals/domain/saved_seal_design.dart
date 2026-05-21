class SavedSealDesign {
  const SavedSealDesign({
    required this.id,
    required this.kanji,
    required this.reading,
    required this.imagePath,
    required this.createdAt,
    this.meaning,
    this.styleLabel,
  });

  final String id;
  final String kanji;
  final String reading;
  final String imagePath;
  final DateTime createdAt;
  final String? meaning;
  final String? styleLabel;
}
