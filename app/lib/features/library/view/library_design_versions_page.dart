// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/designs/view/design_versions_page.dart';
import 'package:app/features/designs/view_model/design_versions_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class LibraryDesignVersionsPage extends ConsumerWidget {
  const LibraryDesignVersionsPage({super.key, required this.designId});

  final String designId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final router = GoRouter.of(context);

    return DesignVersionsPage(
      viewModel: DesignVersionsViewModel(designId: designId),
      secondaryAction: VersionsSecondaryAction(
        label: prefersEnglish ? 'Export snapshot' : 'スナップショット出力',
        icon: Icons.cloud_download_outlined,
        onPressed: (focused) async {
          router.go(
            '${AppRoutePaths.library}/$designId/export',
            extra: focused.snapshot,
          );
        },
      ),
    );
  }
}
