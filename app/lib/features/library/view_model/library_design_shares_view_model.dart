// ignore_for_file: public_member_api_docs

import 'package:app/features/library/data/models/design_share_link_models.dart';
import 'package:app/features/library/data/repositories/design_share_link_repository.dart';
import 'package:miniriverpod/miniriverpod.dart';

class LibraryDesignSharesState {
  const LibraryDesignSharesState({
    required this.designId,
    required this.activeLinks,
    required this.historyLinks,
    required this.isCreating,
    required this.busyLinkIds,
    required this.feedbackMessage,
    required this.feedbackId,
  });

  final String designId;
  final List<DesignShareLink> activeLinks;
  final List<DesignShareLink> historyLinks;
  final bool isCreating;
  final Set<String> busyLinkIds;
  final String? feedbackMessage;
  final int feedbackId;

  LibraryDesignSharesState copyWith({
    List<DesignShareLink>? activeLinks,
    List<DesignShareLink>? historyLinks,
    bool? isCreating,
    Set<String>? busyLinkIds,
    String? feedbackMessage,
    int? feedbackId,
  }) {
    return LibraryDesignSharesState(
      designId: designId,
      activeLinks: activeLinks ?? this.activeLinks,
      historyLinks: historyLinks ?? this.historyLinks,
      isCreating: isCreating ?? this.isCreating,
      busyLinkIds: busyLinkIds ?? this.busyLinkIds,
      feedbackMessage: feedbackMessage,
      feedbackId: feedbackId ?? this.feedbackId,
    );
  }
}

class LibraryDesignSharesViewModel
    extends AsyncProvider<LibraryDesignSharesState> {
  LibraryDesignSharesViewModel({required this.designId})
    : super.args((designId,), autoDispose: true);

  final String designId;

  late final refreshMut = mutation<void>(#refresh);
  late final createMut = mutation<DesignShareLink>(#create);
  late final revokeMut = mutation<void>(#revoke);
  late final extendMut = mutation<DesignShareLink>(#extend);

  @override
  Future<LibraryDesignSharesState> build(Ref ref) async {
    final repository = ref.watch(designShareLinkRepositoryProvider);
    final links = await repository.listLinks(designId);
    final split = _split(links);
    return LibraryDesignSharesState(
      designId: designId,
      activeLinks: split.active,
      historyLinks: split.history,
      isCreating: false,
      busyLinkIds: <String>{},
      feedbackMessage: null,
      feedbackId: 0,
    );
  }

  Call<void> refresh() => mutate(refreshMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    final repository = ref.watch(designShareLinkRepositoryProvider);
    final links = await repository.listLinks(designId);
    final split = _split(links);
    final next =
        (current ??
                LibraryDesignSharesState(
                  designId: designId,
                  activeLinks: const [],
                  historyLinks: const [],
                  isCreating: false,
                  busyLinkIds: <String>{},
                  feedbackMessage: null,
                  feedbackId: 0,
                ))
            .copyWith(activeLinks: split.active, historyLinks: split.history);
    ref.state = AsyncData(next);
  }, concurrency: Concurrency.restart);

  Call<DesignShareLink> create({required Duration ttl}) =>
      mutate(createMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) throw StateError('Shares not loaded');
        if (current.isCreating) throw StateError('Already creating');

        ref.state = AsyncData(
          current.copyWith(
            isCreating: true,
            feedbackMessage: null,
            feedbackId: current.feedbackId + 1,
          ),
        );

        try {
          final repository = ref.watch(designShareLinkRepositoryProvider);
          final created = await repository.createLink(designId, ttl: ttl);
          final refreshed = await repository.listLinks(designId);
          final split = _split(refreshed);
          ref.state = AsyncData(
            current.copyWith(
              activeLinks: split.active,
              historyLinks: split.history,
              isCreating: false,
              feedbackMessage: 'created:${created.id}',
              feedbackId: current.feedbackId + 2,
            ),
          );
          return created;
        } catch (e, stack) {
          ref.state = AsyncError(
            e,
            stack,
            previous: AsyncData(current.copyWith(isCreating: false)),
          );
          rethrow;
        }
      }, concurrency: Concurrency.dropLatest);

  Call<void> revoke(String linkId) => mutate(revokeMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) throw StateError('Shares not loaded');
    if (current.busyLinkIds.contains(linkId)) return;

    final nextBusy = {...current.busyLinkIds, linkId};
    ref.state = AsyncData(
      current.copyWith(
        busyLinkIds: nextBusy,
        feedbackMessage: null,
        feedbackId: current.feedbackId + 1,
      ),
    );

    try {
      final repository = ref.watch(designShareLinkRepositoryProvider);
      await repository.revokeLink(designId, linkId);
      final refreshed = await repository.listLinks(designId);
      final split = _split(refreshed);
      ref.state = AsyncData(
        current.copyWith(
          activeLinks: split.active,
          historyLinks: split.history,
          busyLinkIds: {...nextBusy}..remove(linkId),
          feedbackMessage: 'revoked:$linkId',
          feedbackId: current.feedbackId + 2,
        ),
      );
    } catch (e, stack) {
      ref.state = AsyncError(
        e,
        stack,
        previous: AsyncData(
          current.copyWith(busyLinkIds: {...nextBusy}..remove(linkId)),
        ),
      );
    }
  }, concurrency: Concurrency.dropLatest);

  Call<DesignShareLink> extend(String linkId, {required Duration extendBy}) =>
      mutate(extendMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) throw StateError('Shares not loaded');
        if (current.busyLinkIds.contains(linkId)) {
          throw StateError('Link busy');
        }

        final nextBusy = {...current.busyLinkIds, linkId};
        ref.state = AsyncData(
          current.copyWith(
            busyLinkIds: nextBusy,
            feedbackMessage: null,
            feedbackId: current.feedbackId + 1,
          ),
        );

        try {
          final repository = ref.watch(designShareLinkRepositoryProvider);
          final updated = await repository.extendLink(
            designId,
            linkId,
            extendBy: extendBy,
          );
          final refreshed = await repository.listLinks(designId);
          final split = _split(refreshed);
          ref.state = AsyncData(
            current.copyWith(
              activeLinks: split.active,
              historyLinks: split.history,
              busyLinkIds: {...nextBusy}..remove(linkId),
              feedbackMessage: 'extended:$linkId',
              feedbackId: current.feedbackId + 2,
            ),
          );
          return updated;
        } catch (e, stack) {
          ref.state = AsyncError(
            e,
            stack,
            previous: AsyncData(
              current.copyWith(busyLinkIds: {...nextBusy}..remove(linkId)),
            ),
          );
          rethrow;
        }
      }, concurrency: Concurrency.dropLatest);
}

({List<DesignShareLink> active, List<DesignShareLink> history}) _split(
  List<DesignShareLink> links,
) {
  final active = <DesignShareLink>[];
  final history = <DesignShareLink>[];
  for (final link in links) {
    if (link.isActive) {
      active.add(link);
    } else {
      history.add(link);
    }
  }
  active.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return (active: active, history: history);
}
