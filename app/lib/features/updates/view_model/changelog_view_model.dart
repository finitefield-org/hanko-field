// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/analytics/analytics.dart';
import 'package:app/core/util/version_compare.dart';
import 'package:app/features/updates/data/models/changelog_models.dart';
import 'package:app/features/updates/data/repositories/changelog_repository.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum ChangelogFilter { all, major }

class ChangelogState {
  const ChangelogState({
    required this.releases,
    required this.filter,
    required this.isRefreshing,
    required this.latestVersion,
  });

  final List<ChangelogRelease> releases;
  final ChangelogFilter filter;
  final bool isRefreshing;
  final String? latestVersion;

  ChangelogState copyWith({
    List<ChangelogRelease>? releases,
    ChangelogFilter? filter,
    bool? isRefreshing,
    String? latestVersion,
  }) {
    return ChangelogState(
      releases: releases ?? this.releases,
      filter: filter ?? this.filter,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      latestVersion: latestVersion ?? this.latestVersion,
    );
  }

  List<ChangelogRelease> releasesFor(ChangelogFilter filter) {
    if (filter == ChangelogFilter.major) {
      return releases.where((release) => release.isMajor).toList();
    }
    return releases;
  }
}

final changelogViewModel = ChangelogViewModel();

class ChangelogViewModel extends AsyncProvider<ChangelogState> {
  ChangelogViewModel() : super.args(null, autoDispose: true);

  late final refreshMut = mutation<void>(#refresh);
  late final setFilterMut = mutation<ChangelogFilter>(#setFilter);
  late final trackViewedMut = mutation<void>(#trackViewed);
  late final trackExpandedMut = mutation<void>(#trackExpanded);
  late final trackLearnMoreMut = mutation<void>(#trackLearnMore);

  @override
  Future<ChangelogState> build(Ref ref) async {
    final repository = ref.watch(changelogRepositoryProvider);
    final releases = await repository.fetchChangelog();
    return ChangelogState(
      releases: releases,
      filter: ChangelogFilter.all,
      isRefreshing: false,
      latestVersion: _latestVersion(releases),
    );
  }

  Call<void> refresh() => mutate(refreshMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      ref.state = AsyncData(current.copyWith(isRefreshing: true));
    }

    final repository = ref.watch(changelogRepositoryProvider);
    final releases = await repository.fetchChangelog();
    ref.state = AsyncData(
      ChangelogState(
        releases: releases,
        filter: current?.filter ?? ChangelogFilter.all,
        isRefreshing: false,
        latestVersion: _latestVersion(releases),
      ),
    );
  }, concurrency: Concurrency.dropLatest);

  Call<ChangelogFilter> setFilter(ChangelogFilter filter) =>
      mutate(setFilterMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return filter;
        if (current.filter == filter) return filter;
        ref.state = AsyncData(current.copyWith(filter: filter));

        final analytics = ref.watch(analyticsClientProvider);
        unawaited(
          analytics.track(ChangelogFilterChangedEvent(filter: filter.name)),
        );
        return filter;
      }, concurrency: Concurrency.dropLatest);

  Call<void> trackViewed() => mutate(trackViewedMut, (ref) async {
    final analytics = ref.watch(analyticsClientProvider);
    final snapshot = ref.watch(this).valueOrNull;
    unawaited(
      analytics.track(
        ChangelogViewedEvent(
          latestVersion: snapshot?.latestVersion,
          releaseCount: snapshot?.releases.length,
        ),
      ),
    );
  }, concurrency: Concurrency.dropLatest);

  Call<void> trackExpanded({
    required ChangelogRelease release,
    required bool expanded,
  }) => mutate(trackExpandedMut, (ref) async {
    final analytics = ref.watch(analyticsClientProvider);
    unawaited(
      analytics.track(
        ChangelogReleaseExpandedEvent(
          version: release.version,
          expanded: expanded,
        ),
      ),
    );
  }, concurrency: Concurrency.dropLatest);

  Call<void> trackLearnMore({required ChangelogRelease release}) =>
      mutate(trackLearnMoreMut, (ref) async {
        final analytics = ref.watch(analyticsClientProvider);
        unawaited(
          analytics.track(
            ChangelogLearnMoreTappedEvent(version: release.version),
          ),
        );
      }, concurrency: Concurrency.dropLatest);

  String? _latestVersion(List<ChangelogRelease> releases) {
    if (releases.isEmpty) return null;
    return releases
        .map((release) => release.version)
        .reduce((a, b) => compareVersions(a, b) >= 0 ? a : b);
  }
}
