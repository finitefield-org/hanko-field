// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/core/model/enums.dart';
import 'package:app/features/catalog/data/models/catalog_models.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum ScriptFamily { kanji, kana, roman }

class DesignStyleState {
  const DesignStyleState({
    required this.templates,
    required this.visibleTemplates,
    required this.fonts,
    required this.selectedScript,
    required this.selectedShape,
    required this.activeFilters,
    this.selectedTemplate,
    this.input,
    this.prefetchedTemplateRefs = const <String>{},
    this.isPrefetching = false,
  });

  final List<Template> templates;
  final List<Template> visibleTemplates;
  final List<Font> fonts;
  final ScriptFamily selectedScript;
  final SealShape selectedShape;
  final Set<String> activeFilters;
  final Template? selectedTemplate;
  final DesignInput? input;
  final Set<String> prefetchedTemplateRefs;
  final bool isPrefetching;

  DesignStyleState copyWith({
    List<Template>? templates,
    List<Template>? visibleTemplates,
    List<Font>? fonts,
    ScriptFamily? selectedScript,
    SealShape? selectedShape,
    Set<String>? activeFilters,
    Template? selectedTemplate,
    DesignInput? input,
    Set<String>? prefetchedTemplateRefs,
    bool? isPrefetching,
  }) {
    return DesignStyleState(
      templates: templates ?? this.templates,
      visibleTemplates: visibleTemplates ?? this.visibleTemplates,
      fonts: fonts ?? this.fonts,
      selectedScript: selectedScript ?? this.selectedScript,
      selectedShape: selectedShape ?? this.selectedShape,
      activeFilters: activeFilters ?? this.activeFilters,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      input: input ?? this.input,
      prefetchedTemplateRefs:
          prefetchedTemplateRefs ?? this.prefetchedTemplateRefs,
      isPrefetching: isPrefetching ?? this.isPrefetching,
    );
  }
}

class DesignStyleViewModel extends AsyncProvider<DesignStyleState> {
  DesignStyleViewModel() : super.args(null, autoDispose: false);

  late final setScriptMut = mutation<ScriptFamily>(#setScript);
  late final setShapeMut = mutation<SealShape>(#setShape);
  late final updateFiltersMut = mutation<Set<String>>(#updateFilters);
  late final selectTemplateMut = mutation<Template?>(#selectTemplate);
  late final prefetchMut = mutation<String?>(#prefetchTemplate);

  @override
  Future<DesignStyleState> build(Ref ref) async {
    final gates = ref.watch(appExperienceGatesProvider);
    final creation = ref.watch(designCreationViewModel).valueOrNull;
    final script = gates.prefersEnglish
        ? ScriptFamily.roman
        : ScriptFamily.kanji;
    final filters = creation?.activeFilters ?? const <String>{};
    final shape = _defaultShape(gates, filters);

    ref.listen(designCreationViewModel, (next) {
      final input = next.valueOrNull?.savedInput;
      final current = ref.watch(this).valueOrNull;
      if (input == null || current == null || current.input == input) return;
      ref.state = AsyncData(current.copyWith(input: input));
    });

    await Future<void>.delayed(const Duration(milliseconds: 140));

    final fonts = _seedFonts(gates);
    final templates = _seedTemplates(gates, fonts);
    final visible = _filterTemplates(
      templates: templates,
      fonts: fonts,
      script: script,
      shape: shape,
      filters: filters,
      gates: gates,
    );
    final selected = visible.isNotEmpty ? visible.first : null;

    return DesignStyleState(
      templates: templates,
      visibleTemplates: visible,
      fonts: fonts,
      selectedScript: script,
      selectedShape: shape,
      activeFilters: filters,
      selectedTemplate: selected,
      input: creation?.savedInput,
      prefetchedTemplateRefs: selected != null
          ? {selected.id ?? selected.slug ?? selected.name}
          : <String>{},
    );
  }

  Call<ScriptFamily> setScript(ScriptFamily script) =>
      mutate(setScriptMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return script;

        final gates = ref.watch(appExperienceGatesProvider);
        final visible = _filterTemplates(
          templates: current.templates,
          fonts: current.fonts,
          script: script,
          shape: current.selectedShape,
          filters: current.activeFilters,
          gates: gates,
        );
        final selected =
            visible.contains(current.selectedTemplate) &&
                current.selectedTemplate != null
            ? current.selectedTemplate
            : (visible.isNotEmpty ? visible.first : null);

        ref.state = AsyncData(
          current.copyWith(
            selectedScript: script,
            visibleTemplates: visible,
            selectedTemplate: selected,
          ),
        );
        return script;
      }, concurrency: Concurrency.dropLatest);

  Call<SealShape> setShape(SealShape shape) => mutate(setShapeMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return shape;
    final gates = ref.watch(appExperienceGatesProvider);
    final visible = _filterTemplates(
      templates: current.templates,
      fonts: current.fonts,
      script: current.selectedScript,
      shape: shape,
      filters: current.activeFilters,
      gates: gates,
    );
    final selected =
        visible.contains(current.selectedTemplate) &&
            current.selectedTemplate != null
        ? current.selectedTemplate
        : (visible.isNotEmpty ? visible.first : null);

    ref.state = AsyncData(
      current.copyWith(
        selectedShape: shape,
        visibleTemplates: visible,
        selectedTemplate: selected,
      ),
    );
    return shape;
  }, concurrency: Concurrency.dropLatest);

  Call<Set<String>> updateFilters(Set<String> filters) =>
      mutate(updateFiltersMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return filters;
        final gates = ref.watch(appExperienceGatesProvider);
        final visible = _filterTemplates(
          templates: current.templates,
          fonts: current.fonts,
          script: current.selectedScript,
          shape: current.selectedShape,
          filters: filters,
          gates: gates,
        );
        final selected =
            visible.contains(current.selectedTemplate) &&
                current.selectedTemplate != null
            ? current.selectedTemplate
            : (visible.isNotEmpty ? visible.first : null);

        ref.state = AsyncData(
          current.copyWith(
            activeFilters: filters,
            visibleTemplates: visible,
            selectedTemplate: selected,
          ),
        );
        return filters;
      }, concurrency: Concurrency.dropLatest);

  Call<Template?> selectTemplate(String templateIdOrSlug) =>
      mutate(selectTemplateMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null || current.templates.isEmpty) return null;
        final fallback =
            current.selectedTemplate ??
            current.visibleTemplates.firstOrNull ??
            current.templates.first;
        final template = current.templates.firstWhere(
          (template) =>
              template.id == templateIdOrSlug ||
              template.slug == templateIdOrSlug,
          orElse: () => fallback,
        );
        ref.state = AsyncData(current.copyWith(selectedTemplate: template));
        return template;
      }, concurrency: Concurrency.dropLatest);

  Call<String?> prefetchTemplate(String templateIdOrSlug) =>
      mutate(prefetchMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return null;
        final key = templateIdOrSlug;
        if (current.prefetchedTemplateRefs.contains(key)) return key;

        ref.state = AsyncData(current.copyWith(isPrefetching: true));
        await Future<void>.delayed(const Duration(milliseconds: 160));

        final latest = ref.watch(this).valueOrNull;
        if (latest == null) return null;

        ref.state = AsyncData(
          latest.copyWith(
            isPrefetching: false,
            prefetchedTemplateRefs: <String>{
              ...latest.prefetchedTemplateRefs,
              key,
            },
          ),
        );
        return key;
      }, concurrency: Concurrency.restart);
}

final designStyleViewModel = DesignStyleViewModel();

SealShape _defaultShape(AppExperienceGates gates, Set<String> filters) {
  if (filters.contains('digital') || gates.emphasizeInternationalFlows) {
    return SealShape.square;
  }
  return SealShape.round;
}

List<Template> _filterTemplates({
  required List<Template> templates,
  required List<Font> fonts,
  required ScriptFamily script,
  required SealShape shape,
  required Set<String> filters,
  required AppExperienceGates gates,
}) {
  final filtered = templates.where((template) {
    if (template.shape != shape) return false;
    final font = _fontForTemplate(template, fonts);
    if (!_hasFontSupport(template, font)) return false;
    if (!_matchesScript(template, font, script)) return false;
    if (!_matchesPersona(template, gates, filters)) return false;
    return true;
  }).toList();

  filtered.sort((a, b) {
    final scoreA = _scoreTemplate(a, fonts, gates, filters);
    final scoreB = _scoreTemplate(b, fonts, gates, filters);
    return scoreB.compareTo(scoreA);
  });
  return filtered;
}

bool _matchesPersona(
  Template template,
  AppExperienceGates gates,
  Set<String> filters,
) {
  final requiresOfficial =
      gates.enableRegistrabilityCheck || filters.contains('official');
  if (requiresOfficial &&
      template.constraints.registrability?.jpJitsuinAllowed != true) {
    return false;
  }
  return true;
}

bool _matchesScript(Template template, Font? font, ScriptFamily script) {
  switch (script) {
    case ScriptFamily.kanji:
      return template.writing != WritingStyle.custom;
    case ScriptFamily.kana:
      final glyphs = font?.glyphCoverage ?? const <String>[];
      return glyphs.contains('kana') ||
          template.writing == WritingStyle.gyosho ||
          template.writing == WritingStyle.kaisho;
    case ScriptFamily.roman:
      final glyphs = font?.glyphCoverage ?? const <String>[];
      return glyphs.contains('latin') ||
          template.tags.contains('international') ||
          template.writing == WritingStyle.koentai;
  }
}

double _scoreTemplate(
  Template template,
  List<Font> fonts,
  AppExperienceGates gates,
  Set<String> filters,
) {
  var score = 1 + (template.sort / 100);
  final font = _fontForTemplate(template, fonts);
  if (font?.glyphCoverage.contains('latin') == true &&
      gates.emphasizeInternationalFlows) {
    score += 0.8;
  }
  if (filters.contains('official') &&
      template.constraints.registrability?.jpJitsuinAllowed == true) {
    score += 0.8;
  }
  if (template.writing == WritingStyle.tensho && gates.prefersJapanese) {
    score += 0.5;
  }
  if (font?.designClass == FontDesignClass.seal) {
    score += 0.2;
  }
  return score + Random(template.hashCode).nextDouble() * 0.05;
}

Font? _fontForTemplate(Template template, List<Font> fonts) {
  if (fonts.isEmpty) return null;
  final ref = template.defaults?.fontRef;
  if (ref != null) {
    final found = fonts.firstWhere(
      (font) => font.id == ref || font.family == ref,
      orElse: () => fonts.first,
    );
    return found;
  }
  return fonts.firstWhere(
    (font) => font.writing == template.writing,
    orElse: () => fonts.first,
  );
}

bool _hasFontSupport(Template template, Font? font) {
  if (template.defaults?.fontRef == null) return true;
  if (font == null) return false;
  return font.id == template.defaults?.fontRef ||
      font.family == template.defaults?.fontRef;
}

List<Font> _seedFonts(AppExperienceGates gates) {
  final now = DateTime.now();
  return [
    Font(
      id: 'tensho-pro',
      family: gates.prefersEnglish ? 'Tensho Pro' : '篆書プロ',
      writing: WritingStyle.tensho,
      license: const FontLicense(type: FontLicenseType.commercial),
      glyphCoverage: const ['kanji', 'kana'],
      metrics: const FontMetrics(
        weightRange: RangeConstraint(min: 0.32, max: 0.82),
      ),
      previewUrl:
          'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=400&q=60',
      sampleText: gates.prefersEnglish ? 'SATO' : '佐藤',
      designClass: FontDesignClass.seal,
      isPublic: true,
      sort: 10,
      createdAt: now.subtract(const Duration(days: 200)),
    ),
    Font(
      id: 'kaisho-modern',
      family: gates.prefersEnglish ? 'Kaisho Modern' : '楷書モダン',
      writing: WritingStyle.kaisho,
      license: const FontLicense(type: FontLicenseType.commercial),
      glyphCoverage: const ['kanji', 'kana', 'latin'],
      metrics: const FontMetrics(
        weightRange: RangeConstraint(min: 0.28, max: 0.7),
      ),
      previewUrl:
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=400&q=60',
      sampleText: gates.prefersEnglish ? 'Alex Sato' : '佐藤太郎',
      designClass: FontDesignClass.serif,
      isPublic: true,
      sort: 20,
      createdAt: now.subtract(const Duration(days: 180)),
    ),
    Font(
      id: 'koentai-a',
      family: gates.prefersEnglish ? 'Koentai A' : '古印A',
      writing: WritingStyle.koentai,
      license: const FontLicense(type: FontLicenseType.commercial),
      glyphCoverage: const ['kanji', 'latin'],
      metrics: const FontMetrics(
        weightRange: RangeConstraint(min: 0.36, max: 0.78),
      ),
      previewUrl:
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=400&q=60',
      sampleText: gates.prefersEnglish ? 'Invoice' : '領収印',
      designClass: FontDesignClass.engraved,
      isPublic: true,
      sort: 30,
      createdAt: now.subtract(const Duration(days: 160)),
    ),
  ];
}

List<Template> _seedTemplates(AppExperienceGates gates, List<Font> fonts) {
  final now = DateTime.now();
  final prefersEnglish = gates.prefersEnglish;

  return [
    Template(
      id: 'tensho-classic',
      name: prefersEnglish ? 'Tensho classic' : '篆書クラシック',
      slug: 'tensho-classic',
      description: prefersEnglish
          ? 'Deep red outline with balanced margin for official seals.'
          : '朱肉映えする余白バランスの篆書テンプレ。',
      tags: const ['official', 'balanced'],
      shape: SealShape.round,
      writing: WritingStyle.tensho,
      defaults: const TemplateDefaults(
        sizeMm: 15,
        stroke: TemplateStrokeDefaults(weight: 0.52),
        layout: TemplateLayoutDefaults(grid: 'balanced', margin: 1.4),
        fontRef: 'tensho-pro',
      ),
      constraints: const TemplateConstraints(
        sizeMm: SizeConstraint(min: 12, max: 18, step: 0.5),
        strokeWeight: RangeConstraint(min: 0.35, max: 0.78),
        registrability: RegistrabilityHint(jpJitsuinAllowed: true),
      ),
      previewUrl:
          'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=600&q=60',
      exampleImages: const [],
      recommendations: const TemplateRecommendations(
        defaultSizeMm: 15,
        materialRefs: ['akamatsu'],
        productRefs: ['round-classic'],
      ),
      isPublic: true,
      sort: 10,
      version: '1.0.0',
      isDeprecated: false,
      createdAt: now.subtract(const Duration(days: 60)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    Template(
      id: 'modern-square',
      name: prefersEnglish ? 'Modern square' : 'モダン角印',
      slug: 'modern-square',
      description: prefersEnglish
          ? 'Square layout with gentle contrast for bilingual names.'
          : 'ローマ字でも映える角印レイアウト。',
      tags: const ['international', 'square'],
      shape: SealShape.square,
      writing: WritingStyle.kaisho,
      defaults: const TemplateDefaults(
        sizeMm: 18,
        stroke: TemplateStrokeDefaults(weight: 0.46),
        layout: TemplateLayoutDefaults(
          grid: 'grid',
          margin: 1.1,
          centerBias: 0.12,
        ),
        fontRef: 'kaisho-modern',
      ),
      constraints: const TemplateConstraints(
        sizeMm: SizeConstraint(min: 15, max: 21, step: 0.5),
        strokeWeight: RangeConstraint(min: 0.3, max: 0.62),
        registrability: RegistrabilityHint(
          jpJitsuinAllowed: false,
          bankInAllowed: true,
        ),
      ),
      previewUrl:
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=600&q=60',
      exampleImages: const [],
      recommendations: const TemplateRecommendations(
        defaultSizeMm: 18,
        materialRefs: ['beech'],
        productRefs: ['square-modern'],
      ),
      isPublic: true,
      sort: 20,
      version: '1.1.0',
      isDeprecated: false,
      createdAt: now.subtract(const Duration(days: 45)),
      updatedAt: now.subtract(const Duration(days: 4)),
    ),
    Template(
      id: 'engraved-bold',
      name: prefersEnglish ? 'Engraved bold' : '深彫りボールド',
      slug: 'engraved-bold',
      description: prefersEnglish
          ? 'Thicker strokes for soft materials, easy to align.'
          : 'やわらかい素材でも潰れにくい太めストローク。',
      tags: const ['bold', 'easy'],
      shape: SealShape.round,
      writing: WritingStyle.koentai,
      defaults: const TemplateDefaults(
        sizeMm: 16,
        stroke: TemplateStrokeDefaults(weight: 0.64, contrast: 0.1),
        layout: TemplateLayoutDefaults(grid: 'centered', margin: 1.2),
        fontRef: 'koentai-a',
      ),
      constraints: const TemplateConstraints(
        sizeMm: SizeConstraint(min: 13, max: 19, step: 0.5),
        strokeWeight: RangeConstraint(min: 0.46, max: 0.75),
        margin: RangeConstraint(min: 0.8, max: 1.6),
      ),
      previewUrl:
          'https://images.unsplash.com/photo-1523419400520-223c6fc33afc?auto=format&fit=crop&w=600&q=60',
      exampleImages: const [],
      recommendations: const TemplateRecommendations(
        defaultSizeMm: 16,
        materialRefs: ['sakura'],
      ),
      isPublic: true,
      sort: 30,
      version: '1.0.1',
      isDeprecated: false,
      createdAt: now.subtract(const Duration(days: 70)),
      updatedAt: now.subtract(const Duration(days: 7)),
    ),
    Template(
      id: 'reisho-balanced',
      name: prefersEnglish ? 'Reisho balance' : '隷書バランス',
      slug: 'reisho-balanced',
      description: prefersEnglish
          ? 'Soft edges with wider kana support and subtle contrast.'
          : 'かな交じりでも読みやすい隷書ベース。',
      tags: const ['kana', 'friendly'],
      shape: gates.isJapanRegion ? SealShape.round : SealShape.square,
      writing: WritingStyle.reisho,
      defaults: TemplateDefaults(
        sizeMm: gates.isJapanRegion ? 15 : 17,
        stroke: const TemplateStrokeDefaults(weight: 0.48, contrast: 0.06),
        layout: const TemplateLayoutDefaults(grid: 'loose', margin: 1.3),
        fontRef: 'kaisho-modern',
      ),
      constraints: TemplateConstraints(
        sizeMm: const SizeConstraint(min: 14, max: 19, step: 0.5),
        strokeWeight: const RangeConstraint(min: 0.32, max: 0.64),
        margin: const RangeConstraint(min: 1.0, max: 1.6),
        registrability: gates.enableRegistrabilityCheck
            ? const RegistrabilityHint(jpJitsuinAllowed: true)
            : null,
      ),
      previewUrl:
          'https://images.unsplash.com/photo-1508602639530-96c859f6b2f5?auto=format&fit=crop&w=600&q=60',
      exampleImages: const [],
      recommendations: const TemplateRecommendations(
        defaultSizeMm: 16,
        materialRefs: ['hinoki'],
      ),
      isPublic: true,
      sort: 25,
      version: '1.0.2',
      isDeprecated: false,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now.subtract(const Duration(days: 3)),
    ),
  ];
}
