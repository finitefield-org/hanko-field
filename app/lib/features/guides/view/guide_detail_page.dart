// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/routes.dart';
import 'package:app/features/content/data/models/content_models.dart';
import 'package:app/features/content/data/repositories/cached_content_repository.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miniriverpod/miniriverpod.dart';

class GuideDetailPage extends ConsumerWidget {
  const GuideDetailPage({super.key, required this.slug, this.lang});

  final String slug;
  final String? lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = DesignTokensTheme.of(context);
    final router = GoRouter.of(context);
    final prefersEnglish = ref.watch(appExperienceGatesProvider).prefersEnglish;
    final preferredLang = _normalizeLang(lang, prefersEnglish: prefersEnglish);

    final guide = ref.watch(
      GuideDetailViewModel(slug: slug, lang: preferredLang),
    );

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        title: Text(prefersEnglish ? 'Guide' : 'ガイド'),
        leading: IconButton(
          tooltip: prefersEnglish ? 'Back' : '戻る',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => router.pop(),
        ),
        actions: [
          IconButton(
            tooltip: prefersEnglish ? 'Open list' : '一覧へ',
            icon: const Icon(Icons.list_alt_rounded),
            onPressed: () => router.go('${AppRoutePaths.profile}/guides'),
          ),
        ],
      ),
      body: switch (guide) {
        AsyncLoading() => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        AsyncError(:final error) => Center(child: Text(error.toString())),
        AsyncData(:final value) => _GuideBody(
          guide: value,
          lang: preferredLang,
        ),
      },
    );
  }
}

class GuideDetailViewModel extends AsyncProvider<Guide> {
  GuideDetailViewModel({required this.slug, required this.lang})
    : super.args((slug, lang), autoDispose: true);

  final String slug;
  final String lang;

  @override
  Future<Guide> build(Ref ref) async {
    final repository = ref.watch(contentRepositoryProvider);
    return repository.getGuide(slug, lang: lang);
  }
}

class _GuideBody extends StatelessWidget {
  const _GuideBody({required this.guide, required this.lang});

  final Guide guide;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final translation =
        guide.translations[lang] ?? guide.translations.values.first;

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.lg),
      children: [
        Text(
          translation.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: tokens.spacing.sm),
        if (translation.summary != null && translation.summary!.isNotEmpty) ...[
          Text(
            translation.summary!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: tokens.spacing.lg),
        ],
        Text(
          _stripHtml(translation.body),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

String _stripHtml(String input) {
  final stripped = input.replaceAll(RegExp(r'<[^>]*>'), '');
  return stripped.replaceAll('&nbsp;', ' ').trim();
}

String _normalizeLang(String? lang, {required bool prefersEnglish}) {
  final normalized = lang?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return prefersEnglish ? 'en' : 'ja';
  }
  if (normalized.startsWith('en')) return 'en';
  if (normalized.startsWith('ja')) return 'ja';
  return normalized.split('-').first;
}
