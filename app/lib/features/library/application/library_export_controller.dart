import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final libraryExportControllerProvider =
    NotifierProvider.family<
      LibraryExportController,
      LibraryExportState,
      String
    >(LibraryExportController.new, name: 'libraryExportControllerProvider');

class LibraryExportController extends Notifier<LibraryExportState> {
  LibraryExportController(this.designId);

  final String designId;

  static const List<int> scaleOptions = [1, 2, 4, 8];
  static const List<int> expiryOptionsInDays = [1, 7, 30];

  @override
  LibraryExportState build() {
    return LibraryExportState(designId: designId, scale: 2, expiryDays: 7);
  }

  void selectFormat(LibraryExportFormat format) {
    state = state.copyWith(format: format);
  }

  void selectScale(int value) {
    final normalized = scaleOptions.contains(value) ? value : 2;
    state = state.copyWith(scale: normalized);
  }

  void toggleWatermark(bool value) {
    state = state.copyWith(watermark: value);
  }

  void toggleLinkExpiry(bool value) {
    state = state.copyWith(linkExpires: value);
  }

  void toggleDownloads(bool value) {
    state = state.copyWith(allowDownloads: value);
  }

  void updateExpiryDays(int days) {
    final normalized = expiryOptionsInDays.contains(days) ? days : 7;
    state = state.copyWith(expiryDays: normalized);
  }

  Future<LibraryExportLink?> generateLink() async {
    if (state.isGenerating) {
      return state.activeLink;
    }
    state = state.copyWith(isGenerating: true, clearError: true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final now = DateTime.now();
      final expiresAt = state.linkExpires
          ? now.add(Duration(days: state.expiryDays))
          : null;
      final slug = _buildSlug(now);
      final link = LibraryExportLink(
        url: 'https://hanko.field/d/$slug',
        format: state.format,
        scale: state.scale,
        watermark: state.watermark,
        allowDownloads: state.allowDownloads,
        createdAt: now,
        expiresAt: expiresAt,
      );
      final history = [link, ...state.history];
      final limited = history.take(10).toList(growable: false);
      state = state.copyWith(
        isGenerating: false,
        activeLink: link,
        history: limited,
      );
      return link;
    } catch (_) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'Unable to generate link. Please try again.',
      );
      return null;
    }
  }

  Future<void> revokeLinks() async {
    if (state.isRevoking || !state.hasLinks) {
      return;
    }
    state = state.copyWith(isRevoking: true, clearError: true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      state = state.copyWith(
        isRevoking: false,
        activeLink: null,
        history: const [],
      );
    } catch (_) {
      state = state.copyWith(
        isRevoking: false,
        errorMessage: 'Failed to revoke links. Please try again.',
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _buildSlug(DateTime timestamp) {
    final sanitizedId = designId.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final suffix = timestamp.millisecondsSinceEpoch.toRadixString(36);
    final formatCode = state.format.name.toUpperCase();
    return [
      sanitizedId,
      formatCode,
      suffix,
    ].where((segment) => segment.isNotEmpty).join('-');
  }
}

enum LibraryExportFormat { png, svg, pdf }

@immutable
class LibraryExportLink {
  const LibraryExportLink({
    required this.url,
    required this.format,
    required this.scale,
    required this.watermark,
    required this.allowDownloads,
    required this.createdAt,
    this.expiresAt,
  });

  final String url;
  final LibraryExportFormat format;
  final int scale;
  final bool watermark;
  final bool allowDownloads;
  final DateTime createdAt;
  final DateTime? expiresAt;
}

@immutable
class LibraryExportState {
  const LibraryExportState({
    required this.designId,
    this.format = LibraryExportFormat.png,
    this.scale = 2,
    this.watermark = true,
    this.linkExpires = true,
    this.expiryDays = 7,
    this.allowDownloads = false,
    this.isGenerating = false,
    this.isRevoking = false,
    this.activeLink,
    this.history = const [],
    this.errorMessage,
  });

  final String designId;
  final LibraryExportFormat format;
  final int scale;
  final bool watermark;
  final bool linkExpires;
  final int expiryDays;
  final bool allowDownloads;
  final bool isGenerating;
  final bool isRevoking;
  final LibraryExportLink? activeLink;
  final List<LibraryExportLink> history;
  final String? errorMessage;

  bool get hasLinks => activeLink != null || history.isNotEmpty;

  LibraryExportState copyWith({
    LibraryExportFormat? format,
    int? scale,
    bool? watermark,
    bool? linkExpires,
    int? expiryDays,
    bool? allowDownloads,
    bool? isGenerating,
    bool? isRevoking,
    LibraryExportLink? activeLink,
    bool clearActiveLink = false,
    List<LibraryExportLink>? history,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LibraryExportState(
      designId: designId,
      format: format ?? this.format,
      scale: scale ?? this.scale,
      watermark: watermark ?? this.watermark,
      linkExpires: linkExpires ?? this.linkExpires,
      expiryDays: expiryDays ?? this.expiryDays,
      allowDownloads: allowDownloads ?? this.allowDownloads,
      isGenerating: isGenerating ?? this.isGenerating,
      isRevoking: isRevoking ?? this.isRevoking,
      activeLink: clearActiveLink ? null : activeLink ?? this.activeLink,
      history: history != null
          ? List<LibraryExportLink>.unmodifiable(history)
          : this.history,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
