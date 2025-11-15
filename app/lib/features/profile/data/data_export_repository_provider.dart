import 'package:app/features/profile/data/data_export_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dataExportRepositoryProvider = Provider<DataExportRepository>(
  (ref) => FakeDataExportRepository(),
);
