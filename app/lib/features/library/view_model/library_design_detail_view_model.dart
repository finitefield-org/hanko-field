// ignore_for_file: public_member_api_docs

import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/data/repositories/design_repository.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum LibraryDesignActivityKind { created, updated, ordered }

class LibraryDesignActivityItem {
  const LibraryDesignActivityItem({
    required this.kind,
    required this.timestamp,
    required this.title,
    required this.detail,
  });

  final LibraryDesignActivityKind kind;
  final DateTime timestamp;
  final String title;
  final String detail;
}

class LibraryDesignDetailState {
  const LibraryDesignDetailState({
    required this.design,
    required this.activity,
  });

  final Design design;
  final List<LibraryDesignActivityItem> activity;
}

class LibraryDesignDetailViewModel
    extends AsyncProvider<LibraryDesignDetailState> {
  LibraryDesignDetailViewModel({required this.designId})
    : super.args((designId,), autoDispose: true);

  final String designId;

  late final refreshMut = mutation<LibraryDesignDetailState>(#refresh);
  late final duplicateMut = mutation<Design>(#duplicate);
  late final deleteMut = mutation<void>(#delete);

  @override
  Future<LibraryDesignDetailState> build(
    Ref<AsyncValue<LibraryDesignDetailState>> ref,
  ) async {
    final repository = ref.watch(designRepositoryProvider);
    final design = await repository.getDesign(designId);
    return LibraryDesignDetailState(
      design: design,
      activity: _seedActivity(design),
    );
  }

  Call<LibraryDesignDetailState, AsyncValue<LibraryDesignDetailState>>
  refresh() => mutate(refreshMut, (ref) async {
    final repository = ref.watch(designRepositoryProvider);
    final design = await repository.getDesign(designId);
    final updated = LibraryDesignDetailState(
      design: design,
      activity: _seedActivity(design),
    );
    ref.state = AsyncData(updated);
    return updated;
  }, concurrency: Concurrency.restart);

  Call<Design, AsyncValue<LibraryDesignDetailState>> duplicate() =>
      mutate(duplicateMut, (ref) async {
        final repository = ref.watch(designRepositoryProvider);
        final duplicated = await repository.duplicateDesign(designId);
        return duplicated;
      }, concurrency: Concurrency.dropLatest);

  Call<void, AsyncValue<LibraryDesignDetailState>> delete() =>
      mutate(deleteMut, (ref) async {
        final repository = ref.watch(designRepositoryProvider);
        await repository.deleteDesign(designId);
      }, concurrency: Concurrency.dropLatest);
}

List<LibraryDesignActivityItem> _seedActivity(Design design) {
  final items = <LibraryDesignActivityItem>[
    LibraryDesignActivityItem(
      kind: LibraryDesignActivityKind.created,
      timestamp: design.createdAt,
      title: 'Created',
      detail: 'Saved as v${design.version}',
    ),
  ];

  if (design.updatedAt.isAfter(design.createdAt)) {
    items.add(
      LibraryDesignActivityItem(
        kind: LibraryDesignActivityKind.updated,
        timestamp: design.updatedAt,
        title: 'Updated',
        detail: 'Latest edit applied',
      ),
    );
  }

  final orderedAt = design.lastOrderedAt;
  if (orderedAt != null) {
    items.add(
      LibraryDesignActivityItem(
        kind: LibraryDesignActivityKind.ordered,
        timestamp: orderedAt,
        title: 'Used in an order',
        detail: 'Reorder available from Shop',
      ),
    );
  }

  items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return items;
}
