import 'package:app/core/domain/entities/design.dart';
import 'package:app/features/library/data/design_repository_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final libraryDesignProvider = FutureProvider.autoDispose.family<Design, String>(
  (ref, designId) async {
    final repository = ref.watch(designRepositoryProvider);
    final design = await repository.fetchDesign(designId);
    return design;
  },
);

final libraryDesignVersionsProvider = FutureProvider.autoDispose
    .family<List<Design>, String>((ref, designId) async {
      final repository = ref.watch(designRepositoryProvider);
      final versions = await repository.fetchVersions(designId);
      return List<Design>.unmodifiable(versions);
    });

final libraryDesignDetailProvider = FutureProvider.autoDispose
    .family<LibraryDesignDetail, String>((ref, designId) async {
      final design = await ref.watch(libraryDesignProvider(designId).future);
      final versions = await ref.watch(
        libraryDesignVersionsProvider(designId).future,
      );
      return LibraryDesignDetail(
        design: design,
        versions: versions,
        usageHistory: buildUsageHistory(design, versions),
      );
    });

class LibraryDesignDetail {
  const LibraryDesignDetail({
    required this.design,
    required this.versions,
    required this.usageHistory,
  });

  final Design design;
  final List<Design> versions;
  final List<LibraryUsageEvent> usageHistory;

  Design get latestVersion => versions.isNotEmpty ? versions.first : design;

  double? get aiScore => design.ai?.qualityScore;

  bool get isRegistrable => design.ai?.registrable ?? false;

  String get displayName => design.input?.rawName ?? design.id;
}

enum LibraryUsageEventType { created, updated, ordered, aiCheck, version }

@immutable
class LibraryUsageEvent {
  const LibraryUsageEvent({
    required this.type,
    required this.timestamp,
    this.version,
    this.score,
    this.registrable,
  });

  final LibraryUsageEventType type;
  final DateTime timestamp;
  final int? version;
  final double? score;
  final bool? registrable;
}

List<LibraryUsageEvent> buildUsageHistory(
  Design design,
  List<Design> versions,
) {
  final entries = <LibraryUsageEvent>[
    LibraryUsageEvent(
      type: LibraryUsageEventType.created,
      timestamp: design.createdAt,
      version: 1,
    ),
    LibraryUsageEvent(
      type: LibraryUsageEventType.updated,
      timestamp: design.updatedAt,
      version: design.version,
    ),
  ];
  if (design.lastOrderedAt != null) {
    entries.add(
      LibraryUsageEvent(
        type: LibraryUsageEventType.ordered,
        timestamp: design.lastOrderedAt!,
      ),
    );
  }
  final ai = design.ai;
  final qualityScore = ai?.qualityScore;
  if (qualityScore != null) {
    entries.add(
      LibraryUsageEvent(
        type: LibraryUsageEventType.aiCheck,
        timestamp: design.updatedAt,
        score: qualityScore,
        registrable: ai?.registrable,
      ),
    );
  }
  for (final version in versions.skip(1)) {
    entries.add(
      LibraryUsageEvent(
        type: LibraryUsageEventType.version,
        timestamp: version.updatedAt,
        version: version.version,
      ),
    );
  }
  entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return List<LibraryUsageEvent>.unmodifiable(entries.take(10));
}
