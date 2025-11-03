import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:app/core/domain/entities/design.dart';
import 'package:app/core/routing/app_state_notifier.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/design_creation/application/design_creation_controller.dart';
import 'package:app/features/design_creation/application/design_editor_controller.dart';
import 'package:app/features/design_creation/application/design_editor_state.dart';
import 'package:app/features/design_creation/application/design_share_controller.dart';
import 'package:app/features/design_creation/application/design_share_state.dart';
import 'package:app/features/design_creation/domain/design_creation_state.dart';
import 'package:app/features/design_creation/domain/design_share_templates.dart';
import 'package:app/features/design_creation/presentation/widgets/design_canvas_preview.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class DesignSharePage extends ConsumerStatefulWidget {
  const DesignSharePage({super.key});

  @override
  ConsumerState<DesignSharePage> createState() => _DesignSharePageState();
}

class _DesignSharePageState extends ConsumerState<DesignSharePage> {
  late final PageController _pageController;
  late final TextEditingController _captionController;
  late final Map<String, GlobalKey> _mockupKeys;
  bool _isSyncingCaption = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.78);
    _captionController = TextEditingController();
    _captionController.addListener(_handleCaptionChanged);
    _mockupKeys = {
      for (final template in kDesignShareTemplates)
        template.id: GlobalKey(debugLabel: 'share-mockup-${template.id}'),
    };
    ref.listen<DesignShareState>(
      designShareControllerProvider,
      _handleShareStateChanged,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _captionController
      ..removeListener(_handleCaptionChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shareState = ref.watch(designShareControllerProvider);
    final creationState = ref.watch(designCreationControllerProvider);
    final editorConfig = ref.watch(
      designEditorControllerProvider.select((value) => value.config),
    );

    if (!creationState.hasStyleSelection ||
        creationState.pendingInput == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.designShareTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => ref.read(appStateProvider.notifier).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spaceL),
            child: Text(
              l10n.designShareMissingSelection,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    const templates = kDesignShareTemplates;
    final template = templates.byId(shareState.selectedTemplateId);
    final designText = _resolveDesignText(creationState, l10n);
    final shape = creationState.selectedShape ?? DesignShape.round;
    final templateTitle = creationState.selectedTemplateTitle;

    _syncCaptionController(shareState);

    final hashtags = shareState.hashtagsForTemplate(template.id);
    final orderedHashtags = _orderedHashtags(template, hashtags);
    final captionFallback = l10n.designShareDefaultCaption(
      designText,
      _platformLabel(l10n, template.platform),
    );
    final hasError = shareState.errorMessage != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.designShareTitle),
        toolbarHeight: 88,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.designShareCloseTooltip,
          onPressed: () => ref.read(appStateProvider.notifier).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_outlined),
            tooltip: l10n.designShareCopyLinkTooltip,
            onPressed: () => _handleCopyLink(context, designText, l10n),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceL,
            vertical: AppTokens.spaceL,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.designShareSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTokens.spaceL),
              SizedBox(
                height: 360,
                child: PageView.builder(
                  controller: _pageController,
                  clipBehavior: Clip.none,
                  onPageChanged: (index) {
                    final selected = templates[index];
                    ref
                        .read(designShareControllerProvider.notifier)
                        .selectTemplate(selected.id);
                  },
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final itemTemplate = templates[index];
                    final itemBackground =
                        itemTemplate.backgrounds[shareState
                                    .selectedTemplateId ==
                                itemTemplate.id
                            ? shareState.selectedBackgroundIndex
                            : 0];
                    final key =
                        _mockupKeys[itemTemplate.id] ??
                        GlobalKey(debugLabel: itemTemplate.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceS,
                      ),
                      child: _MockupPreviewCard(
                        boundaryKey: key,
                        template: itemTemplate,
                        background: itemBackground,
                        config: editorConfig,
                        shape: shape,
                        designText: designText,
                        watermarkEnabled: shareState.watermarkEnabled,
                        watermarkLabel: l10n.designShareWatermarkLabel,
                        templateTitle: templateTitle,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppTokens.spaceS),
              _MockupPageIndicator(
                templates: templates,
                selectedTemplateId: shareState.selectedTemplateId,
              ),
              const SizedBox(height: AppTokens.spaceL),
              _PlatformSelector(
                templates: templates,
                selectedTemplateId: shareState.selectedTemplateId,
                onSelected: (templateId) {
                  ref
                      .read(designShareControllerProvider.notifier)
                      .selectTemplate(templateId);
                },
                labelBuilder: (platform) => _platformLabel(l10n, platform),
              ),
              const SizedBox(height: AppTokens.spaceM),
              _BackgroundSelector(
                template: template,
                selectedIndex: shareState.selectedBackgroundIndex,
                labelBuilder: (key) => _backgroundLabel(l10n, key),
                onSelected: (index) {
                  ref
                      .read(designShareControllerProvider.notifier)
                      .selectBackground(index);
                },
              ),
              const SizedBox(height: AppTokens.spaceM),
              SwitchListTile.adaptive(
                value: shareState.watermarkEnabled,
                title: Text(l10n.designShareWatermarkToggleTitle),
                subtitle: Text(l10n.designShareWatermarkToggleSubtitle),
                onChanged: (value) {
                  ref
                      .read(designShareControllerProvider.notifier)
                      .toggleWatermark(value);
                },
              ),
              SwitchListTile.adaptive(
                value: shareState.includeHashtags,
                title: Text(l10n.designShareHashtagToggleTitle),
                subtitle: Text(l10n.designShareHashtagToggleSubtitle),
                onChanged: (value) {
                  ref
                      .read(designShareControllerProvider.notifier)
                      .toggleIncludeHashtags(value);
                },
              ),
              const SizedBox(height: AppTokens.spaceM),
              Text(
                l10n.designShareCaptionLabel,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.spaceS),
              TextField(
                controller: _captionController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: l10n.designShareCaptionHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTokens.spaceM),
              Text(
                l10n.designShareSuggestionsLabel,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppTokens.spaceS),
              Wrap(
                spacing: AppTokens.spaceS,
                runSpacing: AppTokens.spaceS,
                children: [
                  for (final preset in template.copyPresets)
                    ActionChip(
                      avatar: Icon(
                        Icons.auto_awesome_outlined,
                        size: 18,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      label: Text(_presetLabel(l10n, preset)),
                      onPressed: () {
                        final suggestion = _presetText(
                          l10n,
                          preset,
                          designText,
                          templateTitle,
                        );
                        ref
                            .read(designShareControllerProvider.notifier)
                            .applyCaptionSuggestion(suggestion);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceM),
              if (shareState.includeHashtags) ...[
                Text(
                  l10n.designShareHashtagsLabel,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppTokens.spaceS),
              ],
              Wrap(
                spacing: AppTokens.spaceS,
                runSpacing: AppTokens.spaceS,
                children: [
                  for (final tag in template.defaultHashtags)
                    FilterChip(
                      label: Text(tag),
                      selected: hashtags.contains(tag),
                      onSelected: shareState.includeHashtags
                          ? (_) {
                              ref
                                  .read(designShareControllerProvider.notifier)
                                  .toggleHashtag(template.id, tag);
                            }
                          : null,
                    ),
                ],
              ),
              if (shareState.includeHashtags && orderedHashtags.isNotEmpty) ...[
                const SizedBox(height: AppTokens.spaceS),
                Text(
                  orderedHashtags.join(' '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.spaceL),
              Text(
                l10n.designShareQuickTargetsLabel,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.spaceS),
              Wrap(
                spacing: AppTokens.spaceS,
                runSpacing: AppTokens.spaceS,
                children: [
                  for (final option in _quickOptions)
                    ActionChip(
                      avatar: Icon(option.icon, size: 18),
                      label: Text(_quickOptionLabel(l10n, option)),
                      onPressed: () {
                        final targetIndex = templates.indexWhere(
                          (t) => t.id == option.templateId,
                        );
                        if (targetIndex != -1) {
                          ref
                              .read(designShareControllerProvider.notifier)
                              .selectTemplate(option.templateId);
                        }
                      },
                      backgroundColor:
                          option.templateId == shareState.selectedTemplateId
                          ? theme.colorScheme.secondaryContainer
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceL),
              if (hasError) ...[
                _ErrorBanner(message: shareState.errorMessage!),
                const SizedBox(height: AppTokens.spaceM),
              ],
              if (shareState.lastSharedAt != null) ...[
                _InfoBanner(
                  message: l10n.designShareLastShared(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(shareState.lastSharedAt!),
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay.fromDateTime(shareState.lastSharedAt!),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceM),
              ],
              FilledButton.tonalIcon(
                icon: shareState.isSharing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_outlined),
                label: Text(l10n.designShareShareButton),
                onPressed: shareState.isSharing
                    ? null
                    : () => _handleShare(
                        context,
                        template,
                        captionFallback,
                        orderedHashtags,
                        shareState,
                        l10n,
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          height: 72,
          selectedIndex: AppTab.values.indexOf(AppTab.creation),
          onDestinationSelected: (index) {
            final tab = AppTab.values[index];
            ref.read(appStateProvider.notifier).selectTab(tab);
          },
          destinations: [
            for (final tab in AppTab.values)
              NavigationDestination(icon: Icon(tab.icon), label: tab.label),
          ],
        ),
      ),
    );
  }

  void _handleShareStateChanged(
    DesignShareState? previous,
    DesignShareState next,
  ) {
    if (!mounted) {
      return;
    }
    const templates = kDesignShareTemplates;
    final targetIndex = templates.indexWhere(
      (template) => template.id == next.selectedTemplateId,
    );
    if (targetIndex == -1) {
      return;
    }
    final currentPage = _pageController.hasClients
        ? _pageController.page?.round()
        : null;
    if (currentPage == targetIndex) {
      return;
    }
    if (!_pageController.hasClients) {
      return;
    }
    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _handleCaptionChanged() {
    if (_isSyncingCaption) {
      return;
    }
    ref
        .read(designShareControllerProvider.notifier)
        .updateCaption(_captionController.text);
  }

  void _syncCaptionController(DesignShareState state) {
    final currentText = _captionController.text;
    if (currentText == state.captionDraft) {
      return;
    }
    _isSyncingCaption = true;
    _captionController
      ..text = state.captionDraft
      ..selection = TextSelection.collapsed(offset: state.captionDraft.length);
    _isSyncingCaption = false;
  }

  Future<void> _handleShare(
    BuildContext context,
    DesignShareTemplate template,
    String captionFallback,
    List<String> hashtags,
    DesignShareState shareState,
    AppLocalizations l10n,
  ) async {
    final controller = ref.read(designShareControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    controller.beginShare();
    try {
      final boundary =
          _mockupKeys[template.id]?.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Preview boundary not ready');
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Failed to encode mockup image');
      }
      final bytes = byteData.buffer.asUint8List();
      final caption = shareState.captionDraft.trim().isEmpty
          ? captionFallback
          : shareState.captionDraft.trim();
      final sanitizedHashtags = shareState.includeHashtags
          ? hashtags
                .where((tag) => tag.trim().isNotEmpty)
                .map((tag) => tag.startsWith('#') ? tag : '#$tag')
                .toList()
          : const <String>[];
      final message = sanitizedHashtags.isEmpty
          ? caption
          : '$caption\n${sanitizedHashtags.join(' ')}';
      final fileName = 'hanko-share-${template.id}.png';
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(bytes),
            name: fileName,
            mimeType: 'image/png',
          ),
        ],
        text: message,
        subject: l10n.designShareShareSubject(
          _platformLabel(l10n, template.platform),
        ),
      );
      controller.completeShare(DateTime.now());
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.designShareShareSuccess)),
      );
    } catch (error) {
      controller.failShare(l10n.designShareShareError);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.designShareShareError)),
      );
    }
  }

  Future<void> _handleCopyLink(
    BuildContext context,
    String designText,
    AppLocalizations l10n,
  ) async {
    final slug = _slugify(designText);
    final link = 'https://app.hanko-field.jp/share/$slug';
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: link));
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.designShareCopySuccess)),
    );
  }

  String _resolveDesignText(DesignCreationState state, AppLocalizations l10n) {
    return state.pendingInput?.kanji?.value ??
        state.pendingInput?.rawName ??
        state.nameDraft?.combined ??
        l10n.designEditorFallbackText;
  }

  List<String> _orderedHashtags(
    DesignShareTemplate template,
    Set<String> selected,
  ) {
    final ordered = <String>[];
    for (final tag in template.defaultHashtags) {
      if (selected.contains(tag)) {
        ordered.add(tag);
      }
    }
    for (final tag in selected) {
      if (!ordered.contains(tag)) {
        ordered.add(tag);
      }
    }
    return ordered;
  }

  String _platformLabel(AppLocalizations l10n, DesignSharePlatform platform) {
    return switch (platform) {
      DesignSharePlatform.instagram => l10n.designSharePlatformInstagram,
      DesignSharePlatform.x => l10n.designSharePlatformX,
      DesignSharePlatform.linkedin => l10n.designSharePlatformLinkedIn,
    };
  }

  String _backgroundLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'designShareBackgroundSunsetGlow':
        return l10n.designShareBackgroundSunsetGlow;
      case 'designShareBackgroundMorningMist':
        return l10n.designShareBackgroundMorningMist;
      case 'designShareBackgroundNeoNoir':
        return l10n.designShareBackgroundNeoNoir;
      case 'designShareBackgroundMidnight':
        return l10n.designShareBackgroundMidnight;
      case 'designShareBackgroundCyanGrid':
        return l10n.designShareBackgroundCyanGrid;
      case 'designShareBackgroundGraphite':
        return l10n.designShareBackgroundGraphite;
      case 'designShareBackgroundStudio':
        return l10n.designShareBackgroundStudio;
      case 'designShareBackgroundNavySlate':
        return l10n.designShareBackgroundNavySlate;
      case 'designShareBackgroundAquaFocus':
        return l10n.designShareBackgroundAquaFocus;
      default:
        return key;
    }
  }

  String _presetLabel(AppLocalizations l10n, DesignShareCopyPreset preset) {
    return switch (preset) {
      DesignShareCopyPreset.celebration =>
        l10n.designShareSuggestionCelebrationLabel,
      DesignShareCopyPreset.craft => l10n.designShareSuggestionCraftLabel,
      DesignShareCopyPreset.launch => l10n.designShareSuggestionLaunchLabel,
    };
  }

  String _presetText(
    AppLocalizations l10n,
    DesignShareCopyPreset preset,
    String designText,
    String? templateTitle,
  ) {
    return switch (preset) {
      DesignShareCopyPreset.celebration =>
        l10n.designShareSuggestionCelebrationText(designText),
      DesignShareCopyPreset.craft => () {
        final style = templateTitle?.trim() ?? '';
        if (style.isEmpty) {
          return l10n.designShareSuggestionCraftTextAlt(designText);
        }
        return l10n.designShareSuggestionCraftText(style, designText);
      }(),
      DesignShareCopyPreset.launch => l10n.designShareSuggestionLaunchText(
        designText,
      ),
    };
  }

  String _quickOptionLabel(AppLocalizations l10n, _QuickShareOption option) {
    return switch (option.platform) {
      DesignSharePlatform.instagram => l10n.designShareAssistInstagram,
      DesignSharePlatform.x => l10n.designShareAssistX,
      DesignSharePlatform.linkedin => l10n.designShareAssistLinkedIn,
    };
  }

  String _slugify(String input) {
    final lower = input.toLowerCase();
    final buffer = StringBuffer();
    for (final codeUnit in lower.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (RegExp(r'[a-z0-9]').hasMatch(char)) {
        buffer.write(char);
      } else if (buffer.length > 0 &&
          buffer.toString().codeUnitAt(buffer.length - 1) != 0x2D) {
        buffer.write('-');
      }
    }
    final slug = buffer.toString().replaceAll(RegExp('-{2,}'), '-');
    return slug.isEmpty
        ? 'design'
        : slug.trim().replaceAll(RegExp(r'^-|-?$'), '');
  }
}

class _MockupPreviewCard extends StatelessWidget {
  const _MockupPreviewCard({
    required this.boundaryKey,
    required this.template,
    required this.background,
    required this.config,
    required this.shape,
    required this.designText,
    required this.watermarkEnabled,
    required this.watermarkLabel,
    required this.templateTitle,
  });

  final GlobalKey boundaryKey;
  final DesignShareTemplate template;
  final DesignShareBackgroundVariant background;
  final DesignEditorConfig config;
  final DesignShape shape;
  final String designText;
  final bool watermarkEnabled;
  final String watermarkLabel;
  final String? templateTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: RepaintBoundary(
        key: boundaryKey,
        child: AspectRatio(
          aspectRatio: template.aspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: background.gradientColors,
                begin: background.begin,
                end: background.end,
              ),
            ),
            child: Stack(
              children: [
                if (watermarkEnabled)
                  Center(
                    child: Transform.rotate(
                      angle: -math.pi / 8,
                      child: Text(
                        watermarkLabel.toUpperCase(),
                        style:
                            theme.textTheme.headlineMedium?.copyWith(
                              color: background.onBackground.withValues(
                                alpha: 0.08,
                              ),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 8,
                            ) ??
                            TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 8,
                              color: background.onBackground.withValues(
                                alpha: 0.08,
                              ),
                            ),
                      ),
                    ),
                  ),
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(AppTokens.spaceL),
                    padding: const EdgeInsets.all(AppTokens.spaceL),
                    decoration: BoxDecoration(
                      color:
                          background.surfaceColor ??
                          theme.colorScheme.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(
                        background.surfaceBorderRadius,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              background.surfaceShadowColor ??
                              Colors.black.withValues(alpha: 0.12),
                          offset: const Offset(0, 16),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: DesignCanvasPreview(
                      config: config,
                      shape: shape,
                      primaryText: designText,
                      strokeColor: background.onBackground,
                      gridColor: background.onBackground.withValues(
                        alpha: 0.08,
                      ),
                      fillColor:
                          background.surfaceColor ?? theme.colorScheme.surface,
                      textStyle: theme.textTheme.displaySmall?.copyWith(
                        color: background.onBackground,
                      ),
                      drawContainer: false,
                    ),
                  ),
                ),
                Positioned(
                  top: AppTokens.spaceL,
                  left: AppTokens.spaceL,
                  child: Chip(
                    backgroundColor:
                        background.chipColor ?? template.accentColor,
                    label: Text(
                      _platformLabel(
                        AppLocalizations.of(context),
                        template.platform,
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (templateTitle != null && templateTitle!.isNotEmpty)
                  Positioned(
                    bottom: AppTokens.spaceL,
                    left: AppTokens.spaceL,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: background.onBackground.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.spaceM,
                          vertical: AppTokens.spaceXS,
                        ),
                        child: Text(
                          templateTitle!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: background.onBackground,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _platformLabel(AppLocalizations l10n, DesignSharePlatform platform) {
    return switch (platform) {
      DesignSharePlatform.instagram => l10n.designSharePlatformInstagram,
      DesignSharePlatform.x => l10n.designSharePlatformX,
      DesignSharePlatform.linkedin => l10n.designSharePlatformLinkedIn,
    };
  }
}

class _MockupPageIndicator extends StatelessWidget {
  const _MockupPageIndicator({
    required this.templates,
    required this.selectedTemplateId,
  });

  final List<DesignShareTemplate> templates;
  final String selectedTemplateId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final template in templates)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: template.id == selectedTemplateId ? 16 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: template.id == selectedTemplateId
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}

class _PlatformSelector extends StatelessWidget {
  const _PlatformSelector({
    required this.templates,
    required this.selectedTemplateId,
    required this.onSelected,
    required this.labelBuilder,
  });

  final List<DesignShareTemplate> templates;
  final String selectedTemplateId;
  final ValueChanged<String> onSelected;
  final String Function(DesignSharePlatform platform) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.spaceS,
      children: [
        for (final template in templates)
          ChoiceChip(
            label: Text(labelBuilder(template.platform)),
            selected: template.id == selectedTemplateId,
            onSelected: (_) => onSelected(template.id),
          ),
      ],
    );
  }
}

class _BackgroundSelector extends StatelessWidget {
  const _BackgroundSelector({
    required this.template,
    required this.selectedIndex,
    required this.labelBuilder,
    required this.onSelected,
  });

  final DesignShareTemplate template;
  final int selectedIndex;
  final String Function(String key) labelBuilder;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.spaceS,
      children: [
        for (final (index, background) in template.backgrounds.indexed)
          ChoiceChip(
            label: Text(labelBuilder(background.labelKey)),
            selected: index == selectedIndex,
            onSelected: (_) => onSelected(index),
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: AppTokens.radiusM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceM),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: AppTokens.spaceS),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: AppTokens.radiusM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceM),
        child: Row(
          children: [
            Icon(Icons.history, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: AppTokens.spaceS),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickShareOption {
  const _QuickShareOption({
    required this.platform,
    required this.templateId,
    required this.icon,
  });

  final DesignSharePlatform platform;
  final String templateId;
  final IconData icon;
}

const List<_QuickShareOption> _quickOptions = [
  _QuickShareOption(
    platform: DesignSharePlatform.instagram,
    templateId: 'instagram-square',
    icon: Icons.photo_camera_back_outlined,
  ),
  _QuickShareOption(
    platform: DesignSharePlatform.x,
    templateId: 'x-landscape',
    icon: Icons.bolt_outlined,
  ),
  _QuickShareOption(
    platform: DesignSharePlatform.linkedin,
    templateId: 'linkedin-portrait',
    icon: Icons.work_outline,
  ),
];
