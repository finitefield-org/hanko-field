import 'package:app/core/model/value_objects.dart' as core_models;
import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/content/data/repositories/content_repository.dart';
import 'package:app/features/guides/view/guide_detail_page.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/shared/providers/session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_app.dart';

class _FakeContentRepository implements ContentRepository {
  String? lastSlug;
  String? lastLang;

  @override
  Future<Guide> getGuide(String slug, {String? lang}) async {
    lastSlug = slug;
    lastLang = lang;
    return Guide(
      slug: slug,
      category: GuideCategory.howto,
      isPublic: true,
      translations: {
        (lang ?? 'ja'): const GuideTranslation(title: 'Title', body: 'Body'),
      },
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
  }

  @override
  Future<core_models.Page<Guide>> listGuides({
    String? lang,
    GuideCategory? category,
    String? pageToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PageContent> getPage(String slug, {String? lang}) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets(
    'GuideDetailPage fetch uses preferred language when query missing',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repo = _FakeContentRepository();
      final overrides = [
        ...buildTestOverrides(
          locale: const Locale('en'),
          persona: UserPersona.foreigner,
          session: const UserSession.signedOut(),
        ),
        ContentRepository.fallback.overrideWithValue(repo),
      ];

      await tester.pumpWidget(
        buildTestApp(
          child: const GuideDetailPage(slug: 'example', lang: null),
          overrides: overrides,
          locale: const Locale('en'),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(repo.lastSlug, 'example');
      expect(repo.lastLang, 'en');
      expect(find.text('Title'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
