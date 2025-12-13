// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:app/core/model/enums.dart';
import 'package:app/features/designs/data/models/design_models.dart';
import 'package:app/features/designs/data/repositories/design_repository.dart';
import 'package:app/features/designs/view_model/design_editor_view_model.dart';
import 'package:app/features/designs/view_model/design_export_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

enum ExportScale { x1, x2, x4 }

extension ExportScaleX on ExportScale {
  double get multiplier => switch (this) {
    ExportScale.x1 => 1,
    ExportScale.x2 => 2,
    ExportScale.x4 => 4,
  };

  String label(bool prefersEnglish) => switch (this) {
    ExportScale.x1 => prefersEnglish ? '1×' : '1×',
    ExportScale.x2 => prefersEnglish ? '2×' : '2×',
    ExportScale.x4 => prefersEnglish ? '4×' : '4×',
  };
}

class ExportLinkPermissions {
  const ExportLinkPermissions({
    required this.watermark,
    required this.expiryEnabled,
    required this.expiryDays,
    required this.downloadAllowed,
  });

  final bool watermark;
  final bool expiryEnabled;
  final int expiryDays;
  final bool downloadAllowed;

  ExportLinkPermissions copyWith({
    bool? watermark,
    bool? expiryEnabled,
    int? expiryDays,
    bool? downloadAllowed,
  }) {
    return ExportLinkPermissions(
      watermark: watermark ?? this.watermark,
      expiryEnabled: expiryEnabled ?? this.expiryEnabled,
      expiryDays: expiryDays ?? this.expiryDays,
      downloadAllowed: downloadAllowed ?? this.downloadAllowed,
    );
  }
}

class ExportLinkRecord {
  const ExportLinkRecord({
    required this.url,
    required this.format,
    required this.scale,
    required this.permissions,
    required this.createdAt,
  });

  final String url;
  final ExportFormat format;
  final ExportScale scale;
  final ExportLinkPermissions permissions;
  final DateTime createdAt;

  String get shortCode {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final segments = uri.pathSegments;
    return segments.isEmpty ? url : segments.last;
  }
}

class LibraryDesignExportState {
  const LibraryDesignExportState({
    required this.design,
    required this.format,
    required this.scale,
    required this.permissions,
    required this.isGenerating,
    required this.isRevoking,
    required this.history,
    required this.feedbackId,
    this.activeLink,
    this.feedbackMessage,
  });

  final ExportableDesign design;
  final ExportFormat format;
  final ExportScale scale;
  final ExportLinkPermissions permissions;
  final bool isGenerating;
  final bool isRevoking;
  final List<ExportLinkRecord> history;
  final String? activeLink;
  final String? feedbackMessage;
  final int feedbackId;

  bool get isBusy => isGenerating || isRevoking;

  LibraryDesignExportState copyWith({
    ExportableDesign? design,
    ExportFormat? format,
    ExportScale? scale,
    ExportLinkPermissions? permissions,
    bool? isGenerating,
    bool? isRevoking,
    List<ExportLinkRecord>? history,
    String? activeLink,
    String? feedbackMessage,
    int? feedbackId,
    bool clearFeedback = false,
  }) {
    return LibraryDesignExportState(
      design: design ?? this.design,
      format: format ?? this.format,
      scale: scale ?? this.scale,
      permissions: permissions ?? this.permissions,
      isGenerating: isGenerating ?? this.isGenerating,
      isRevoking: isRevoking ?? this.isRevoking,
      history: history ?? this.history,
      activeLink: activeLink ?? this.activeLink,
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
      feedbackId: feedbackId ?? this.feedbackId,
    );
  }
}

class LibraryDesignExportViewModel
    extends AsyncProvider<LibraryDesignExportState> {
  LibraryDesignExportViewModel({required this.designId, this.designOverride})
    : super.args((designId, designOverride), autoDispose: true);

  final String designId;
  final Design? designOverride;

  late final setFormatMut = mutation<ExportFormat>(#setFormat);
  late final setScaleMut = mutation<ExportScale>(#setScale);
  late final toggleWatermarkMut = mutation<bool>(#toggleWatermark);
  late final toggleExpiryMut = mutation<bool>(#toggleExpiry);
  late final setExpiryDaysMut = mutation<int>(#setExpiryDays);
  late final toggleDownloadMut = mutation<bool>(#toggleDownload);
  late final generateLinkMut = mutation<String>(#generateLink);
  late final revokeAllMut = mutation<void>(#revokeAll);

  late AppExperienceGates _gates;
  final Random _rand = Random();

  @override
  Future<LibraryDesignExportState> build(Ref ref) async {
    _gates = ref.watch(appExperienceGatesProvider);

    final design = designOverride ?? await _fetchDesign(ref);
    final exportable = _toExportableDesign(design, _gates);

    return LibraryDesignExportState(
      design: exportable,
      format: ExportFormat.png,
      scale: ExportScale.x2,
      permissions: const ExportLinkPermissions(
        watermark: true,
        expiryEnabled: false,
        expiryDays: 14,
        downloadAllowed: true,
      ),
      isGenerating: false,
      isRevoking: false,
      history: const [],
      activeLink: null,
      feedbackMessage: null,
      feedbackId: 0,
    );
  }

  Future<Design> _fetchDesign(Ref ref) async {
    if (designId.trim().isEmpty) {
      throw ArgumentError.value(designId, 'designId', 'Design id is required.');
    }
    final repository = ref.watch(designRepositoryProvider);
    return repository.getDesign(designId);
  }

  Call<ExportFormat> setFormat(ExportFormat format) =>
      mutate(setFormatMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return format;
        ref.state = AsyncData(current.copyWith(format: format));
        return format;
      }, concurrency: Concurrency.dropLatest);

  Call<ExportScale> setScale(ExportScale scale) =>
      mutate(setScaleMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return scale;
        ref.state = AsyncData(current.copyWith(scale: scale));
        return scale;
      }, concurrency: Concurrency.dropLatest);

  Call<bool> toggleWatermark(bool enabled) =>
      mutate(toggleWatermarkMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;
        ref.state = AsyncData(
          current.copyWith(
            permissions: current.permissions.copyWith(watermark: enabled),
          ),
        );
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<bool> toggleExpiry(bool enabled) => mutate(toggleExpiryMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return enabled;
    ref.state = AsyncData(
      current.copyWith(
        permissions: current.permissions.copyWith(expiryEnabled: enabled),
      ),
    );
    return enabled;
  }, concurrency: Concurrency.dropLatest);

  Call<int> setExpiryDays(int days) => mutate(setExpiryDaysMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return days;
    final sanitized = days.clamp(1, 365);
    ref.state = AsyncData(
      current.copyWith(
        permissions: current.permissions.copyWith(expiryDays: sanitized),
      ),
    );
    return sanitized;
  }, concurrency: Concurrency.dropLatest);

  Call<bool> toggleDownloadAllowed(bool enabled) =>
      mutate(toggleDownloadMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return enabled;
        ref.state = AsyncData(
          current.copyWith(
            permissions: current.permissions.copyWith(downloadAllowed: enabled),
          ),
        );
        return enabled;
      }, concurrency: Concurrency.dropLatest);

  Call<String> generateLink() => mutate(generateLinkMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) throw StateError('Export state is not ready.');
    if (current.isBusy) return current.activeLink ?? '';

    ref.state = AsyncData(
      current.copyWith(isGenerating: true, clearFeedback: true),
    );
    await Future<void>.delayed(const Duration(milliseconds: 420));

    final working = ref.watch(this).valueOrNull ?? current;
    final token = _newToken();
    final url = _buildShareUrl(
      token,
      format: working.format,
      scale: working.scale,
    );
    final record = ExportLinkRecord(
      url: url,
      format: working.format,
      scale: working.scale,
      permissions: working.permissions,
      createdAt: DateTime.now(),
    );

    final feedback = _gates.prefersEnglish ? 'Link generated' : 'リンクを生成しました';
    ref.state = AsyncData(
      working.copyWith(
        isGenerating: false,
        activeLink: url,
        history: [record, ...working.history],
        feedbackMessage: feedback,
        feedbackId: working.feedbackId + 1,
      ),
    );
    return url;
  }, concurrency: Concurrency.dropLatest);

  Call<void> revokeAll() => mutate(revokeAllMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;
    if (current.isBusy) return;

    ref.state = AsyncData(
      current.copyWith(isRevoking: true, clearFeedback: true),
    );
    await Future<void>.delayed(const Duration(milliseconds: 420));

    final working = ref.watch(this).valueOrNull ?? current;
    final feedback = _gates.prefersEnglish
        ? 'All links revoked'
        : 'すべてのリンクを無効化しました';
    ref.state = AsyncData(
      working.copyWith(
        isRevoking: false,
        activeLink: null,
        history: const [],
        feedbackMessage: feedback,
        feedbackId: working.feedbackId + 1,
      ),
    );
  }, concurrency: Concurrency.dropLatest);

  String _newToken() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buf = StringBuffer();
    for (var i = 0; i < 10; i++) {
      buf.write(alphabet[_rand.nextInt(alphabet.length)]);
    }
    return buf.toString();
  }

  String _buildShareUrl(
    String token, {
    required ExportFormat format,
    required ExportScale scale,
  }) {
    final uri = Uri(
      scheme: 'https',
      host: 'hanko.field',
      path: '/share/$token',
      queryParameters: {
        'format': format.fileExtension,
        'scale': scale.multiplier.toStringAsFixed(0),
      },
    );
    return uri.toString();
  }
}

ExportableDesign _toExportableDesign(Design design, AppExperienceGates gates) {
  final name = design.input?.rawName.trim();
  final prefersEnglish = gates.prefersEnglish;
  final displayName = (name == null || name.isEmpty)
      ? (prefersEnglish ? 'Untitled' : '名称未設定')
      : name;

  final defaultLayout = design.shape == SealShape.square
      ? DesignCanvasLayout.grid
      : DesignCanvasLayout.balanced;
  final layout = switch (design.style.layout?.grid) {
    'grid' => DesignCanvasLayout.grid,
    'vertical' => DesignCanvasLayout.vertical,
    'arc' => DesignCanvasLayout.arc,
    _ => defaultLayout,
  };

  return ExportableDesign(
    displayName: displayName,
    shape: design.shape,
    sizeMm: design.size.mm,
    writingStyle: design.style.writing,
    layout: layout,
    strokeWeight: design.style.stroke?.weight ?? 2.4,
    margin: design.style.layout?.margin ?? 12,
    rotation: 0,
    templateName: design.style.templateRef,
  );
}
