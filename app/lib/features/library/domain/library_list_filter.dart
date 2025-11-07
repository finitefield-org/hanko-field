import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/features/library/domain/library_query_fields.dart';
import 'package:flutter/foundation.dart';

enum LibrarySortOption { recent, aiScore, name }

enum LibraryViewMode { grid, list }

enum LibraryDateRange { last7Days, last30Days, last90Days, anytime }

enum LibraryAiScoreFilter { all, high, medium, low }

@immutable
class LibraryListFilter {
  LibraryListFilter({
    Set<DesignStatus> statuses = const <DesignStatus>{},
    this.dateRange = LibraryDateRange.last30Days,
    this.aiScore = LibraryAiScoreFilter.all,
    this.persona,
  }) : statuses = Set<DesignStatus>.unmodifiable(statuses);

  final Set<DesignStatus> statuses;
  final LibraryDateRange dateRange;
  final LibraryAiScoreFilter aiScore;
  final UserPersona? persona;

  LibraryListFilter copyWith({
    Set<DesignStatus>? statuses,
    LibraryDateRange? dateRange,
    LibraryAiScoreFilter? aiScore,
    UserPersona? persona,
    bool clearPersona = false,
  }) {
    return LibraryListFilter(
      statuses: statuses ?? this.statuses,
      dateRange: dateRange ?? this.dateRange,
      aiScore: aiScore ?? this.aiScore,
      persona: clearPersona ? null : persona ?? this.persona,
    );
  }

  LibraryListFilter toggleStatus(DesignStatus status) {
    final next = Set<DesignStatus>.from(statuses);
    if (!next.add(status)) {
      next.remove(status);
    }
    return copyWith(statuses: next);
  }

  LibraryListFilter clearStatuses() {
    if (statuses.isEmpty) {
      return this;
    }
    return copyWith(statuses: const <DesignStatus>{});
  }

  bool isStatusSelected(DesignStatus status) => statuses.contains(status);

  Map<String, dynamic> toQueryMap({
    required LibrarySortOption sort,
    required String searchQuery,
  }) {
    final map = <String, dynamic>{LibraryQueryFields.sort: sort.queryValue};
    if (statuses.isNotEmpty) {
      map[LibraryQueryFields.statuses] = statuses
          .map((status) => status.name)
          .toList();
    }
    final dateValue = dateRange.queryValue;
    if (dateValue != null) {
      map[LibraryQueryFields.dateRange] = dateValue;
    }
    final aiValue = aiScore.queryValue;
    if (aiValue != null) {
      map[LibraryQueryFields.aiScore] = aiValue;
    }
    if (persona != null) {
      map[LibraryQueryFields.persona] = persona!.name;
    }
    final trimmedQuery = searchQuery.trim();
    if (trimmedQuery.isNotEmpty) {
      map[LibraryQueryFields.search] = trimmedQuery;
    }
    return map;
  }

  @override
  int get hashCode {
    final ordered = statuses.map((status) => status.index).toList()..sort();
    return Object.hash(Object.hashAll(ordered), dateRange, aiScore, persona);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is LibraryListFilter &&
            setEquals(other.statuses, statuses) &&
            other.dateRange == dateRange &&
            other.aiScore == aiScore &&
            other.persona == persona);
  }
}

extension LibrarySortOptionQuery on LibrarySortOption {
  String get queryValue => switch (this) {
    LibrarySortOption.recent => 'recent',
    LibrarySortOption.aiScore => 'aiScore',
    LibrarySortOption.name => 'name',
  };
}

extension LibraryDateRangeQuery on LibraryDateRange {
  String? get queryValue => switch (this) {
    LibraryDateRange.last7Days => 'last7Days',
    LibraryDateRange.last30Days => 'last30Days',
    LibraryDateRange.last90Days => 'last90Days',
    LibraryDateRange.anytime => null,
  };
}

extension LibraryAiScoreFilterQuery on LibraryAiScoreFilter {
  String? get queryValue => switch (this) {
    LibraryAiScoreFilter.all => null,
    LibraryAiScoreFilter.high => 'high',
    LibraryAiScoreFilter.medium => 'medium',
    LibraryAiScoreFilter.low => 'low',
  };
}
