// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/core/model/enums.dart';
import 'package:app/features/designs/view_model/design_creation_view_model.dart';
import 'package:app/features/designs/view_model/design_editor_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:share_plus/share_plus.dart';

class ShareableDesign {
  const ShareableDesign({
    required this.displayName,
    required this.shape,
    required this.sizeMm,
    required this.writingStyle,
    this.templateName,
  });

  final String displayName;
  final SealShape shape;
  final double sizeMm;
  final WritingStyle writingStyle;
  final String? templateName;

  ShareableDesign copyWith({
    String? displayName,
    SealShape? shape,
    double? sizeMm,
    WritingStyle? writingStyle,
    String? templateName,
  }) {
    return ShareableDesign(
      displayName: displayName ?? this.displayName,
      shape: shape ?? this.shape,
      sizeMm: sizeMm ?? this.sizeMm,
      writingStyle: writingStyle ?? this.writingStyle,
      templateName: templateName ?? this.templateName,
    );
  }
}

enum ShareBackground { linen, studio, midnight }

extension ShareBackgroundX on ShareBackground {
  String label(bool prefersEnglish) {
    return switch (this) {
      ShareBackground.linen => prefersEnglish ? 'Linen beige' : '生成りリネン',
      ShareBackground.studio => prefersEnglish ? 'Studio grey' : 'スタジオグレー',
      ShareBackground.midnight =>
        prefersEnglish ? 'Midnight sakura' : 'ミッドナイト桜',
    };
  }
}

enum SocialPlatform { instagram, x, line, linkedin }

extension SocialPlatformX on SocialPlatform {
  String label(bool prefersEnglish) {
    return switch (this) {
      SocialPlatform.instagram => prefersEnglish ? 'Instagram' : 'インスタ',
      SocialPlatform.x => prefersEnglish ? 'X' : 'X',
      SocialPlatform.line => prefersEnglish ? 'LINE' : 'LINE',
      SocialPlatform.linkedin => prefersEnglish ? 'LinkedIn' : 'LinkedIn',
    };
  }

  String tagline(bool prefersEnglish) {
    return switch (this) {
      SocialPlatform.instagram =>
        prefersEnglish ? 'Feed-ready portrait' : 'フィード向け縦長',
      SocialPlatform.x => prefersEnglish ? 'Conversation friendly' : '会話に混ぜやすい',
      SocialPlatform.line => prefersEnglish ? 'Share to chats' : 'トークに貼り付け',
      SocialPlatform.linkedin =>
        prefersEnglish ? 'Professional highlight' : '実績として紹介',
    };
  }
}

class SocialMock {
  const SocialMock({
    required this.platform,
    required this.background,
    required this.overlayText,
    required this.hashtags,
    required this.watermarked,
    required this.sizeLabel,
    required this.aspectRatio,
    required this.impressionScore,
    required this.callout,
  });

  final SocialPlatform platform;
  final ShareBackground background;
  final String overlayText;
  final List<String> hashtags;
  final bool watermarked;
  final String sizeLabel;
  final double aspectRatio;
  final double impressionScore;
  final String callout;

  SocialMock copyWith({
    SocialPlatform? platform,
    ShareBackground? background,
    String? overlayText,
    List<String>? hashtags,
    bool? watermarked,
    String? sizeLabel,
    double? aspectRatio,
    double? impressionScore,
    String? callout,
  }) {
    return SocialMock(
      platform: platform ?? this.platform,
      background: background ?? this.background,
      overlayText: overlayText ?? this.overlayText,
      hashtags: hashtags ?? this.hashtags,
      watermarked: watermarked ?? this.watermarked,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      impressionScore: impressionScore ?? this.impressionScore,
      callout: callout ?? this.callout,
    );
  }
}

class DesignShareState {
  const DesignShareState({
    required this.design,
    required this.background,
    required this.overlayText,
    required this.watermarkEnabled,
    required this.includeHashtags,
    required this.isGenerating,
    required this.isSharing,
    required this.previews,
    required this.shareCopy,
    required this.shareLink,
    required this.generationSeed,
    required this.feedbackId,
    this.lastGeneratedAt,
    this.feedbackMessage,
  });

  final ShareableDesign design;
  final ShareBackground background;
  final String overlayText;
  final bool watermarkEnabled;
  final bool includeHashtags;
  final bool isGenerating;
  final bool isSharing;
  final List<SocialMock> previews;
  final String shareCopy;
  final String shareLink;
  final int generationSeed;
  final DateTime? lastGeneratedAt;
  final String? feedbackMessage;
  final int feedbackId;

  DesignShareState copyWith({
    ShareableDesign? design,
    ShareBackground? background,
    String? overlayText,
    bool? watermarkEnabled,
    bool? includeHashtags,
    bool? isGenerating,
    bool? isSharing,
    List<SocialMock>? previews,
    String? shareCopy,
    String? shareLink,
    int? generationSeed,
    DateTime? lastGeneratedAt,
    String? feedbackMessage,
    int? feedbackId,
  }) {
    return DesignShareState(
      design: design ?? this.design,
      background: background ?? this.background,
      overlayText: overlayText ?? this.overlayText,
      watermarkEnabled: watermarkEnabled ?? this.watermarkEnabled,
      includeHashtags: includeHashtags ?? this.includeHashtags,
      isGenerating: isGenerating ?? this.isGenerating,
      isSharing: isSharing ?? this.isSharing,
      previews: previews ?? this.previews,
      shareCopy: shareCopy ?? this.shareCopy,
      shareLink: shareLink ?? this.shareLink,
      generationSeed: generationSeed ?? this.generationSeed,
      lastGeneratedAt: lastGeneratedAt ?? this.lastGeneratedAt,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      feedbackId: feedbackId ?? this.feedbackId,
    );
  }
}

class DesignShareViewModel extends AsyncProvider<DesignShareState> {
  DesignShareViewModel() : super.args(null, autoDispose: false);

  late final selectBackgroundMut = mutation<ShareBackground>(#selectBackground);
  late final toggleWatermarkMut = mutation<bool>(#toggleWatermark);
  late final toggleHashtagsMut = mutation<bool>(#toggleHashtags);
  late final updateOverlayMut = mutation<String>(#updateOverlay);
  late final regenerateMut = mutation<bool>(#regenerate);
  late final shareMut = mutation<bool>(#share);

  late AppExperienceGates _gates;

  @override
  Future<DesignShareState> build(Ref ref) async {
    _gates = ref.watch(appExperienceGatesProvider);

    final creation = ref.watch(designCreationViewModel);
    final editor = ref.watch(designEditorViewModel);
    final design = _resolveDesign(creation, editor, _gates);
    final overlay = _defaultOverlay(design, _gates);
    final shareLink = _buildShareLink(design);
    final includeHashtags = true;
    final seed = DateTime.now().millisecondsSinceEpoch;

    ref.listen(designCreationViewModel, (next) {
      _syncFromSources(
        ref,
        creation: next,
        editor: ref.watch(designEditorViewModel),
      );
    });

    ref.listen(designEditorViewModel, (next) {
      _syncFromSources(
        ref,
        creation: ref.watch(designCreationViewModel),
        editor: next,
      );
    });

    final hashtags = _hashtags(_gates, includeHashtags: includeHashtags);
    final shareCopy = _buildShareCopy(
      design,
      overlayText: overlay,
      shareLink: shareLink,
      includeHashtags: includeHashtags,
      gates: _gates,
    );

    return DesignShareState(
      design: design,
      background: ShareBackground.linen,
      overlayText: overlay,
      watermarkEnabled: true,
      includeHashtags: includeHashtags,
      isGenerating: false,
      isSharing: false,
      previews: _buildMocks(
        design: design,
        background: ShareBackground.linen,
        overlayText: overlay,
        hashtags: hashtags,
        watermark: true,
        seed: seed,
        prefersEnglish: _gates.prefersEnglish,
      ),
      shareCopy: shareCopy,
      shareLink: shareLink,
      generationSeed: seed,
      lastGeneratedAt: DateTime.now(),
      feedbackMessage: null,
      feedbackId: 0,
    );
  }

  Call<ShareBackground> selectBackground(ShareBackground background) =>
      mutate(selectBackgroundMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return background;

        final hashtags = _hashtags(
          _gates,
          includeHashtags: current.includeHashtags,
        );
        ref.state = AsyncData(
          current.copyWith(
            background: background,
            previews: _buildMocks(
              design: current.design,
              background: background,
              overlayText: current.overlayText,
              hashtags: hashtags,
              watermark: current.watermarkEnabled,
              seed: current.generationSeed,
              prefersEnglish: _gates.prefersEnglish,
            ),
          ),
        );
        return background;
      }, concurrency: Concurrency.dropLatest);

  Call<bool> toggleWatermark(bool enabled) =>
      mutate(toggleWatermarkMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;

        ref.state = AsyncData(
          current.copyWith(
            watermarkEnabled: enabled,
            previews: current.previews
                .map((mock) => mock.copyWith(watermarked: enabled))
                .toList(),
          ),
        );
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<bool> toggleHashtags(bool enabled) =>
      mutate(toggleHashtagsMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;

        final hashtags = _hashtags(_gates, includeHashtags: enabled);
        ref.state = AsyncData(
          current.copyWith(
            includeHashtags: enabled,
            previews: current.previews
                .map((mock) => mock.copyWith(hashtags: hashtags))
                .toList(),
            shareCopy: _buildShareCopy(
              current.design,
              overlayText: current.overlayText,
              shareLink: current.shareLink,
              includeHashtags: enabled,
              gates: _gates,
            ),
          ),
        );
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<String> updateOverlay(String value) =>
      mutate(updateOverlayMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return value;

        final normalized = value.trim();
        ref.state = AsyncData(
          current.copyWith(
            overlayText: normalized,
            previews: current.previews
                .map((mock) => mock.copyWith(overlayText: normalized))
                .toList(),
            shareCopy: _buildShareCopy(
              current.design,
              overlayText: normalized.isEmpty
                  ? _defaultOverlay(current.design, _gates)
                  : normalized,
              shareLink: current.shareLink,
              includeHashtags: current.includeHashtags,
              gates: _gates,
            ),
          ),
        );
        return normalized;
      }, concurrency: Concurrency.dropLatest);

  Call<bool> regenerate() => mutate(regenerateMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return false;
    if (current.isGenerating) return false;

    ref.state = AsyncData(current.copyWith(isGenerating: true));
    await Future<void>.delayed(const Duration(milliseconds: 360));
    final seed = DateTime.now().millisecondsSinceEpoch;
    final hashtags = _hashtags(
      _gates,
      includeHashtags: current.includeHashtags,
    );
    final previews = _buildMocks(
      design: current.design,
      background: current.background,
      overlayText: current.overlayText,
      hashtags: hashtags,
      watermark: current.watermarkEnabled,
      seed: seed,
      prefersEnglish: _gates.prefersEnglish,
    );

    ref.state = AsyncData(
      current.copyWith(
        isGenerating: false,
        generationSeed: seed,
        lastGeneratedAt: DateTime.now(),
        previews: previews,
        feedbackMessage: _gates.prefersEnglish
            ? 'Refreshed social mockups'
            : 'ソーシャル向けモックを再生成しました',
        feedbackId: current.feedbackId + 1,
      ),
    );
    return true;
  }, concurrency: Concurrency.restart);

  Call<bool> share({required String target}) => mutate(shareMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return false;
    if (current.isSharing) return false;

    ref.state = AsyncData(
      current.copyWith(isSharing: true, feedbackMessage: null),
    );

    try {
      await Share.share(current.shareCopy, subject: current.design.displayName);
      ref.state = AsyncData(
        current.copyWith(
          isSharing: false,
          feedbackMessage: _gates.prefersEnglish
              ? 'Shared via $target'
              : '$targetで共有しました',
          feedbackId: current.feedbackId + 1,
        ),
      );
      return true;
    } catch (error) {
      ref.state = AsyncData(
        current.copyWith(
          isSharing: false,
          feedbackMessage: _gates.prefersEnglish
              ? 'Share failed: $error'
              : '共有に失敗しました: $error',
          feedbackId: current.feedbackId + 1,
        ),
      );
      return false;
    }
  }, concurrency: Concurrency.restart);

  void _syncFromSources(
    Ref ref, {
    required AsyncValue<DesignCreationState> creation,
    required AsyncValue<DesignEditorState> editor,
  }) {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;

    final design = _resolveDesign(creation, editor, _gates);
    final nextOverlay = current.overlayText.isEmpty
        ? _defaultOverlay(design, _gates)
        : current.overlayText;
    final shareLink = _buildShareLink(design);
    final hashtags = _hashtags(
      _gates,
      includeHashtags: current.includeHashtags,
    );

    ref.state = AsyncData(
      current.copyWith(
        design: design,
        overlayText: nextOverlay,
        shareLink: shareLink,
        shareCopy: _buildShareCopy(
          design,
          overlayText: nextOverlay,
          shareLink: shareLink,
          includeHashtags: current.includeHashtags,
          gates: _gates,
        ),
        previews: _buildMocks(
          design: design,
          background: current.background,
          overlayText: nextOverlay,
          hashtags: hashtags,
          watermark: current.watermarkEnabled,
          seed: current.generationSeed,
          prefersEnglish: _gates.prefersEnglish,
        ),
      ),
    );
  }
}

final designShareViewModel = DesignShareViewModel();

List<String> _hashtags(
  AppExperienceGates gates, {
  required bool includeHashtags,
}) {
  if (!includeHashtags) return const <String>[];
  return gates.prefersEnglish
      ? const ['#HankoField', '#sealdesign', '#madeinJapan']
      : const ['#ハンコフィールド', '#印影デザイン', '#朱肉'];
}

String _buildShareCopy(
  ShareableDesign design, {
  required String overlayText,
  required String shareLink,
  required bool includeHashtags,
  required AppExperienceGates gates,
}) {
  final hashtags = _hashtags(gates, includeHashtags: includeHashtags);
  final overlay = overlayText.trim().isEmpty
      ? _defaultOverlay(design, gates)
      : overlayText.trim();
  final intro = gates.prefersEnglish
      ? 'Sharing ${design.displayName} from Hanko Field'
      : 'Hanko Fieldで作成した${design.displayName}を共有';
  final templateLine = design.templateName == null
      ? null
      : gates.prefersEnglish
      ? 'Template: ${design.templateName}'
      : 'テンプレート: ${design.templateName}';

  return [
    intro,
    overlay,
    templateLine,
    'Link: $shareLink',
    if (hashtags.isNotEmpty) hashtags.join(' '),
  ].where((part) => part != null && part.trim().isNotEmpty).join('\n');
}

String _defaultOverlay(ShareableDesign design, AppExperienceGates gates) {
  final writing = _writingLabel(design.writingStyle, gates.prefersEnglish);
  final shape = design.shape == SealShape.square
      ? (gates.prefersEnglish ? 'Square seal' : '角印')
      : (gates.prefersEnglish ? 'Round seal' : '丸印');
  final size = '${design.sizeMm.toStringAsFixed(0)}mm';
  return gates.prefersEnglish
      ? '${design.displayName} • $writing • $shape • $size'
      : '${design.displayName}｜$writing｜$shape｜$size';
}

ShareableDesign _resolveDesign(
  AsyncValue<DesignCreationState> creation,
  AsyncValue<DesignEditorState> editor,
  AppExperienceGates gates,
) {
  final creationState = creation.valueOrNull;
  final editorState = editor.valueOrNull;

  final nameDraft = creationState?.nameDraft.fullName(
    prefersEnglish: gates.prefersEnglish,
  );
  final savedName = creationState?.savedInput?.rawName;
  final normalizedSaved = savedName?.trim();
  final displayName = (normalizedSaved != null && normalizedSaved.isNotEmpty)
      ? normalizedSaved
      : (nameDraft != null && nameDraft.isNotEmpty)
      ? nameDraft
      : (gates.prefersEnglish ? 'Hanko Field' : '印影');

  final shape =
      creationState?.selectedShape ?? editorState?.shape ?? SealShape.round;
  final writing =
      creationState?.selectedStyle?.writing ??
      creationState?.previewStyle ??
      editorState?.writingStyle ??
      WritingStyle.tensho;
  final sizeMm = editorState?.sizeMm ?? creationState?.selectedSize?.mm ?? 15.0;
  final templateName =
      creationState?.selectedTemplate?.name ??
      creationState?.selectedTemplate?.id ??
      editorState?.templateName;

  return ShareableDesign(
    displayName: displayName,
    shape: shape,
    sizeMm: sizeMm,
    writingStyle: writing,
    templateName: templateName,
  );
}

List<SocialMock> _buildMocks({
  required ShareableDesign design,
  required ShareBackground background,
  required String overlayText,
  required List<String> hashtags,
  required bool watermark,
  required int seed,
  required bool prefersEnglish,
}) {
  final random = Random(seed);
  final templates =
      <({SocialPlatform platform, String sizeLabel, double aspectRatio})>[
        (
          platform: SocialPlatform.instagram,
          sizeLabel: '1080 × 1350',
          aspectRatio: 4 / 5,
        ),
        (
          platform: SocialPlatform.x,
          sizeLabel: '1600 × 900',
          aspectRatio: 16 / 9,
        ),
        (
          platform: SocialPlatform.line,
          sizeLabel: '1200 × 1200',
          aspectRatio: 1,
        ),
        (
          platform: SocialPlatform.linkedin,
          sizeLabel: '1200 × 628',
          aspectRatio: 1.91 / 1,
        ),
      ];

  return templates.map((template) {
    final score = 0.64 + random.nextDouble() * 0.28;
    final callout = template.platform.tagline(prefersEnglish);
    return SocialMock(
      platform: template.platform,
      background: background,
      overlayText: overlayText,
      hashtags: hashtags,
      watermarked: watermark,
      sizeLabel: template.sizeLabel,
      aspectRatio: template.aspectRatio,
      impressionScore: double.parse(score.toStringAsFixed(2)),
      callout: callout,
    );
  }).toList();
}

String _buildShareLink(ShareableDesign design) {
  final slug = design.displayName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final safeSlug = slug.isEmpty ? 'design' : slug;
  final style = design.writingStyle.name;
  final size = design.sizeMm.toStringAsFixed(0);
  return 'https://hanko.field/share/$safeSlug?style=$style&size=${size}mm';
}

String _writingLabel(WritingStyle style, bool prefersEnglish) {
  return switch (style) {
    WritingStyle.tensho => prefersEnglish ? 'Tensho' : '篆書',
    WritingStyle.reisho => prefersEnglish ? 'Reisho' : '隷書',
    WritingStyle.kaisho => prefersEnglish ? 'Kaisho' : '楷書',
    WritingStyle.gyosho => prefersEnglish ? 'Gyosho' : '行書',
    WritingStyle.koentai => prefersEnglish ? 'Koentai' : '古印体',
    WritingStyle.custom => prefersEnglish ? 'Custom' : 'カスタム',
  };
}
