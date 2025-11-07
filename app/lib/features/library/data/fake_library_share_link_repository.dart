import 'dart:math';

import 'package:app/features/library/domain/library_share_link.dart';
import 'package:app/features/library/domain/library_share_link_repository.dart';

class FakeLibraryShareLinkRepository implements LibraryShareLinkRepository {
  FakeLibraryShareLinkRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Map<String, List<LibraryShareLink>> _store = {};
  final DateTime Function() _now;
  final _random = Random();

  Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 260));

  @override
  Future<List<LibraryShareLink>> fetchLinks(String designId) async {
    await _delay();
    final links = _store.putIfAbsent(designId, () => _seedLinks(designId));
    return List<LibraryShareLink>.unmodifiable(_sorted(links));
  }

  @override
  Future<LibraryShareLink> createLink(String designId, {Duration? ttl}) async {
    await _delay();
    final now = _now();
    final expiresAt = ttl == null
        ? now.add(const Duration(days: 7))
        : now.add(ttl);
    final link = LibraryShareLink(
      id: _newLinkId(designId),
      url: _linkUrl(designId),
      status: LibraryShareLinkStatus.active,
      createdAt: now,
      label: 'Share link ${_shortSuffix(now)}',
      expiresAt: expiresAt,
      accessCount: 0,
      maxAccessCount: 100,
    );
    final links = _store.putIfAbsent(designId, () => _seedLinks(designId));
    links.insert(0, link);
    return link;
  }

  @override
  Future<LibraryShareLink> extendLink(
    String designId,
    String linkId, {
    Duration? extension,
  }) async {
    await _delay();
    final links = _store.putIfAbsent(designId, () => _seedLinks(designId));
    final index = links.indexWhere((link) => link.id == linkId);
    if (index == -1) {
      throw StateError('Link $linkId not found');
    }
    final now = _now();
    final extendBy = extension ?? const Duration(days: 7);
    final current = links[index];
    final base = current.expiresAt != null && current.expiresAt!.isAfter(now)
        ? current.expiresAt!
        : now;
    final updated = current.copyWith(
      expiresAt: base.add(extendBy),
      status: LibraryShareLinkStatus.active,
    );
    links[index] = updated;
    return updated;
  }

  @override
  Future<LibraryShareLink> revokeLink(String designId, String linkId) async {
    await _delay();
    final links = _store.putIfAbsent(designId, () => _seedLinks(designId));
    final index = links.indexWhere((link) => link.id == linkId);
    if (index == -1) {
      throw StateError('Link $linkId not found');
    }
    final now = _now();
    final current = links[index];
    final updated = current.copyWith(
      status: LibraryShareLinkStatus.revoked,
      revokedAt: now,
    );
    links[index] = updated;
    return updated;
  }

  List<LibraryShareLink> _sorted(List<LibraryShareLink> source) {
    final sorted = List<LibraryShareLink>.from(source);
    sorted.sort((a, b) {
      final statusCompare =
          _statusPriority(a.status) - _statusPriority(b.status);
      if (statusCompare != 0) {
        return statusCompare;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  int _statusPriority(LibraryShareLinkStatus status) {
    switch (status) {
      case LibraryShareLinkStatus.active:
        return 0;
      case LibraryShareLinkStatus.expired:
        return 1;
      case LibraryShareLinkStatus.revoked:
        return 2;
    }
  }

  List<LibraryShareLink> _seedLinks(String designId) {
    final now = _now();
    return [
      LibraryShareLink(
        id: '${designId.toUpperCase()}-SHR-A',
        url: _linkUrl(designId),
        status: LibraryShareLinkStatus.active,
        createdAt: now.subtract(const Duration(days: 3)),
        label: 'Supplier review',
        expiresAt: now.add(const Duration(days: 10)),
        lastAccessedAt: now.subtract(const Duration(hours: 6)),
        accessCount: 24,
        maxAccessCount: 200,
      ),
      LibraryShareLink(
        id: '${designId.toUpperCase()}-SHR-B',
        url: '${_linkUrl(designId)}?proof',
        status: LibraryShareLinkStatus.expired,
        createdAt: now.subtract(const Duration(days: 14)),
        label: 'Proof approval',
        expiresAt: now.subtract(const Duration(days: 1)),
        lastAccessedAt: now.subtract(const Duration(days: 2)),
        accessCount: 12,
        maxAccessCount: 30,
      ),
      LibraryShareLink(
        id: '${designId.toUpperCase()}-SHR-C',
        url: '${_linkUrl(designId)}?revoked',
        status: LibraryShareLinkStatus.revoked,
        createdAt: now.subtract(const Duration(days: 28)),
        label: 'Design sprint',
        revokedAt: now.subtract(const Duration(days: 5)),
        lastAccessedAt: now.subtract(const Duration(days: 6)),
        accessCount: 48,
        maxAccessCount: 80,
      ),
    ];
  }

  String _newLinkId(String designId) {
    final normalized = designId.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    final suffix = (_random.nextInt(9000) + 1000).toString();
    return '$normalized-SHR-$suffix';
  }

  String _linkUrl(String designId) {
    final slug = designId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return 'https://hanko.field/share/$slug';
  }

  String _shortSuffix(DateTime now) {
    return now.millisecondsSinceEpoch.toRadixString(36).toUpperCase();
  }
}
