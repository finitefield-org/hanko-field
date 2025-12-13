// ignore_for_file: public_member_api_docs

import 'package:app/core/model/value_objects.dart';
import 'package:app/features/content/data/models/content_models.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class ContentRepository {
  static const fallback = Scope<ContentRepository>.required(
    'content.repository',
  );

  Future<Page<Guide>> listGuides({
    String? lang,
    GuideCategory? category,
    String? pageToken,
  });

  Future<Guide> getGuide(String slug, {String? lang});

  Future<PageContent> getPage(String slug, {String? lang});
}
