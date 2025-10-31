import 'package:app/features/design_creation/data/style_template_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final styleTemplateRepositoryProvider = Provider<StyleTemplateRepository>((
  ref,
) {
  return StyleTemplateRepository();
});
