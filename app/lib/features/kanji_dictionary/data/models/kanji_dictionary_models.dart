// ignore_for_file: public_member_api_docs

import 'package:app/features/designs/data/models/kanji_mapping_models.dart';

class KanjiDictionaryEntry {
  const KanjiDictionaryEntry({
    required this.candidate,
    required this.examples,
    required this.strokeOrderPreview,
  });

  final KanjiCandidate candidate;
  final List<String> examples;
  final String strokeOrderPreview;
}
