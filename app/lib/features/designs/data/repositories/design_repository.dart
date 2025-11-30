// ignore_for_file: public_member_api_docs

import 'package:app/core/model/value_objects.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class DesignRepository {
  static const fallback = Scope<DesignRepository>.required('design.repository');

  Future<Page<Design>> listDesigns({
    DesignStatus? status,
    DesignSourceType? sourceType,
    String? pageToken,
  });

  Future<Design> getDesign(String designId);

  Future<Design> createDesign(Design design);

  Future<Design> updateDesign(Design design);

  Future<void> deleteDesign(String designId);

  Future<Design> duplicateDesign(String designId);

  Future<Page<DesignVersion>> listVersions(
    String designId, {
    String? pageToken,
  });

  Future<List<AiSuggestion>> listAiSuggestions(String designId);

  Future<AiSuggestion> getAiSuggestion(String designId, String suggestionId);

  Future<AiSuggestion> requestAiSuggestion(
    String designId, {
    required AiSuggestionMethod method,
    String? model,
  });

  Future<AiSuggestion> acceptSuggestion(String designId, String suggestionId);

  Future<AiSuggestion> rejectSuggestion(
    String designId,
    String suggestionId, {
    String? reason,
  });

  Future<void> runRegistrabilityCheck(String designId);
}
