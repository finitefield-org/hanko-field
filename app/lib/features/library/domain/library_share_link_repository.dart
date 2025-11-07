import 'package:app/features/library/domain/library_share_link.dart';

abstract class LibraryShareLinkRepository {
  Future<List<LibraryShareLink>> fetchLinks(String designId);
  Future<LibraryShareLink> createLink(String designId, {Duration? ttl});
  Future<LibraryShareLink> extendLink(
    String designId,
    String linkId, {
    Duration? extension,
  });
  Future<LibraryShareLink> revokeLink(String designId, String linkId);
}
