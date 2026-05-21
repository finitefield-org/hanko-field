import '../domain/saved_seal_design.dart';

abstract interface class SavedSealDesignRepository {
  Future<List<SavedSealDesign>> listSavedSealDesigns();

  Future<SavedSealDesign?> getSavedSealDesign(String id);

  Future<void> saveSealDesign(SavedSealDesign design);

  Future<void> deleteSealDesign(String id);
}
