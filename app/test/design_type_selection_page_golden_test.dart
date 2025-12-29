import 'package:app/core/model/enums.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view/design_type_selection_page.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('DesignTypeSelectionPage golden', (tester) async {
    const state = DesignCreationState(
      selectedType: DesignSourceType.typed,
      activeFilters: {'personal'},
      storagePermissionGranted: false,
      nameDraft: NameInputDraft(),
      previewStyle: WritingStyle.tensho,
      savedInput: null,
      selectedShape: null,
      selectedSize: null,
      selectedStyle: null,
      selectedTemplate: null,
    );

    final designOverride = Provider<AsyncValue<DesignCreationState>>(
      (_) => const AsyncData<DesignCreationState>(state),
    );
    final overrides = [
      ...buildTestOverrides(),
      designCreationViewModel.overrideWith(designOverride),
    ];

    final router = GoRouter(
      initialLocation: AppRoutePaths.designNew,
      routes: [
        GoRoute(
          path: AppRoutePaths.designNew,
          builder: (_, __) => const DesignTypeSelectionPage(),
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(428, 926));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildTestRouterApp(router: router, overrides: overrides),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DesignTypeSelectionPage),
      matchesGoldenFile('goldens/design_type_selection_page.png'),
    );
  });
}
