import 'package:app/core/model/enums.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('DesignTypeSelectionPage shows CTA for selected type', (
    tester,
  ) async {
    await mockNetworkImagesFor(() async {
      await tester.binding.setSurfaceSize(const Size(428, 926));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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

      await tester.pumpWidget(
        buildTestNavApp(
          initialLocation: AppRoutePaths.designNew,
          overrides: overrides,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Start with text'), findsOneWidget);
      expect(find.text('Choose creation mode'), findsOneWidget);
    });
  });
}
