// ignore_for_file: public_member_api_docs

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/security/storage_permission_client.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:archive/archive.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum ProfileExportSection { assets, orders, history }

extension ProfileExportSectionX on ProfileExportSection {
  String get key => switch (this) {
    ProfileExportSection.assets => 'assets',
    ProfileExportSection.orders => 'orders',
    ProfileExportSection.history => 'history',
  };
}

class ProfileExportRecord {
  const ProfileExportRecord({
    required this.filename,
    required this.path,
    required this.createdAt,
    required this.fileSizeMb,
    required this.sections,
  });

  final String filename;
  final String path;
  final DateTime createdAt;
  final double fileSizeMb;
  final List<ProfileExportSection> sections;

  String get label => '$filename.zip';
}

class ProfileExportState {
  const ProfileExportState({
    required this.includeAssets,
    required this.includeOrders,
    required this.includeHistory,
    required this.storageStatus,
    required this.isExporting,
    required this.progress,
    required this.history,
    required this.feedbackId,
    this.feedbackMessage,
  });

  final bool includeAssets;
  final bool includeOrders;
  final bool includeHistory;
  final StoragePermissionStatus storageStatus;
  final bool isExporting;
  final double progress;
  final List<ProfileExportRecord> history;
  final int feedbackId;
  final String? feedbackMessage;

  ProfileExportRecord? get lastExport => history.isEmpty ? null : history.first;

  ProfileExportState copyWith({
    bool? includeAssets,
    bool? includeOrders,
    bool? includeHistory,
    StoragePermissionStatus? storageStatus,
    bool? isExporting,
    double? progress,
    List<ProfileExportRecord>? history,
    int? feedbackId,
    String? feedbackMessage,
    bool clearFeedback = false,
  }) {
    return ProfileExportState(
      includeAssets: includeAssets ?? this.includeAssets,
      includeOrders: includeOrders ?? this.includeOrders,
      includeHistory: includeHistory ?? this.includeHistory,
      storageStatus: storageStatus ?? this.storageStatus,
      isExporting: isExporting ?? this.isExporting,
      progress: progress ?? this.progress,
      history: history ?? this.history,
      feedbackId: feedbackId ?? this.feedbackId,
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
    );
  }
}

class ProfileExportViewModel extends AsyncProvider<ProfileExportState> {
  ProfileExportViewModel() : super.args(null, autoDispose: false);

  late final toggleAssetsMut = mutation<bool>(#toggleAssets);
  late final toggleOrdersMut = mutation<bool>(#toggleOrders);
  late final toggleHistoryMut = mutation<bool>(#toggleHistory);
  late final ensurePermissionMut = mutation<StoragePermissionStatus>(
    #ensurePermission,
  );
  late final exportMut = mutation<ProfileExportRecord?>(#export);
  late final shareMut = mutation<void>(#share);

  late AppExperienceGates _gates;

  @override
  Future<ProfileExportState> build(
    Ref<AsyncValue<ProfileExportState>> ref,
  ) async {
    _gates = ref.watch(appExperienceGatesProvider);
    final permissionClient = ref.watch(storagePermissionClientProvider);
    final storageStatus = await permissionClient.status();

    return ProfileExportState(
      includeAssets: true,
      includeOrders: true,
      includeHistory: true,
      storageStatus: storageStatus,
      isExporting: false,
      progress: 0,
      history: const [],
      feedbackMessage: null,
      feedbackId: 0,
    );
  }

  Call<bool, AsyncValue<ProfileExportState>> toggleAssets(bool value) =>
      mutate(toggleAssetsMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return value;
        ref.state = AsyncData(current.copyWith(includeAssets: value));
        return value;
      }, concurrency: Concurrency.dropLatest);

  Call<bool, AsyncValue<ProfileExportState>> toggleOrders(bool value) =>
      mutate(toggleOrdersMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return value;
        ref.state = AsyncData(current.copyWith(includeOrders: value));
        return value;
      }, concurrency: Concurrency.dropLatest);

  Call<bool, AsyncValue<ProfileExportState>> toggleHistory(bool value) =>
      mutate(toggleHistoryMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return value;
        ref.state = AsyncData(current.copyWith(includeHistory: value));
        return value;
      }, concurrency: Concurrency.dropLatest);

  Call<StoragePermissionStatus, AsyncValue<ProfileExportState>>
  ensurePermission() => mutate(ensurePermissionMut, (ref) async {
    final client = ref.watch(storagePermissionClientProvider);
    final status = await client.request();
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      ref.state = AsyncData(current.copyWith(storageStatus: status));
    }
    return status;
  }, concurrency: Concurrency.dropLatest);

  Call<ProfileExportRecord?, AsyncValue<ProfileExportState>> export() =>
      mutate(exportMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return null;

        final permission = await ref.invoke(ensurePermission());
        if (!permission.isGranted) {
          _emitFeedback(
            ref,
            _gates.prefersEnglish
                ? 'Storage permission is required before exporting.'
                : 'エクスポートにはストレージ権限が必要です。',
          );
          return null;
        }

        var working = current.copyWith(
          isExporting: true,
          progress: 0.12,
          storageStatus: permission,
          clearFeedback: true,
        );
        ref.state = AsyncData(working);

        try {
          final bytes = await _buildArchive(working);
          working = working.copyWith(progress: 0.62);
          ref.state = AsyncData(working);

          final saved = await _saveArchive(bytes);
          final record = ProfileExportRecord(
            filename: saved.filename,
            path: saved.path,
            createdAt: DateTime.now(),
            fileSizeMb: saved.sizeMb,
            sections: _activeSections(working),
          );

          final updatedHistory = <ProfileExportRecord>[
            record,
            ...working.history,
          ];

          working = working.copyWith(
            isExporting: false,
            progress: 1.0,
            history: updatedHistory.take(8).toList(),
            feedbackMessage: _gates.prefersEnglish
                ? 'Export ready to download.'
                : 'エクスポートの準備ができました。',
            feedbackId: working.feedbackId + 1,
          );
          ref.state = AsyncData(working);

          try {
            await Share.shareXFiles(
              [XFile(record.path)],
              subject: _gates.prefersEnglish
                  ? 'Hanko Field data export'
                  : 'Hanko Field データ出力',
            );
          } catch (_) {
            _emitFeedback(
              ref,
              _gates.prefersEnglish
                  ? 'Export saved. Share sheet unavailable.'
                  : 'エクスポートは保存されましたが共有に失敗しました。',
            );
          }

          return record;
        } catch (error) {
          ref.state = AsyncData(
            working.copyWith(
              isExporting: false,
              progress: 0,
              feedbackMessage: _gates.prefersEnglish
                  ? 'Export failed. Please try again.'
                  : 'エクスポートに失敗しました。もう一度お試しください。',
              feedbackId: working.feedbackId + 1,
            ),
          );
          return null;
        }
      }, concurrency: Concurrency.restart);

  Call<void, AsyncValue<ProfileExportState>> share(
    ProfileExportRecord record,
  ) => mutate(shareMut, (ref) async {
    final file = File(record.path);
    if (!file.existsSync()) {
      _emitFeedback(
        ref,
        _gates.prefersEnglish
            ? 'Export file is missing. Please create a new export.'
            : '書き出しファイルが見つかりません。再度作成してください。',
      );
      return;
    }

    await Share.shareXFiles(
      [XFile(record.path)],
      subject: _gates.prefersEnglish
          ? 'Hanko Field data export'
          : 'Hanko Field データ出力',
    );
  }, concurrency: Concurrency.dropLatest);

  void _emitFeedback(Ref<AsyncValue<ProfileExportState>> ref, String message) {
    final current = ref.watch(this).valueOrNull;
    if (current == null) return;
    ref.state = AsyncData(
      current.copyWith(
        feedbackMessage: message,
        feedbackId: current.feedbackId + 1,
      ),
    );
  }

  List<ProfileExportSection> _activeSections(ProfileExportState state) {
    return [
      if (state.includeAssets) ProfileExportSection.assets,
      if (state.includeOrders) ProfileExportSection.orders,
      if (state.includeHistory) ProfileExportSection.history,
    ];
  }

  Future<Uint8List> _buildArchive(ProfileExportState state) async {
    final archive = Archive();
    final now = DateTime.now().toUtc();

    final manifest = <String, Object>{
      'generatedAt': now.toIso8601String(),
      'sections': _activeSections(state).map((section) => section.key).toList(),
      'app': 'Hanko Field',
      'format': 'zip',
    };

    _addJsonFile(archive, 'manifest.json', manifest);
    _addJsonFile(archive, 'profile.json', _buildProfilePayload(now));

    if (state.includeAssets) {
      _addJsonFile(archive, 'assets/designs.json', _buildAssetsPayload(now));
    }
    if (state.includeOrders) {
      _addJsonFile(archive, 'orders/orders.json', _buildOrdersPayload(now));
    }
    if (state.includeHistory) {
      _addJsonFile(archive, 'history/activity.json', _buildHistoryPayload(now));
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Unable to encode export archive.');
    }
    return Uint8List.fromList(encoded);
  }

  void _addJsonFile(Archive archive, String path, Object payload) {
    final bytes = utf8.encode(jsonEncode(payload));
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  Map<String, Object> _buildProfilePayload(DateTime now) {
    return {
      'generatedAt': now.toIso8601String(),
      'profile': {
        'displayName': 'Sample User',
        'email': 'user@example.com',
        'locale': _gates.prefersEnglish ? 'en' : 'ja',
        'persona': _gates.prefersEnglish ? 'global' : 'japan',
      },
    };
  }

  Map<String, Object> _buildAssetsPayload(DateTime now) {
    return {
      'generatedAt': now.toIso8601String(),
      'designs': [
        {'id': 'design_01', 'name': 'Classic Seal', 'updatedAt': '2024-08-01'},
        {'id': 'design_02', 'name': 'Modern Seal', 'updatedAt': '2024-09-12'},
      ],
    };
  }

  Map<String, Object> _buildOrdersPayload(DateTime now) {
    return {
      'generatedAt': now.toIso8601String(),
      'orders': [
        {
          'id': 'order_1201',
          'status': 'shipped',
          'total': 128.40,
          'currency': 'JPY',
        },
        {
          'id': 'order_1202',
          'status': 'processing',
          'total': 94.00,
          'currency': 'JPY',
        },
      ],
    };
  }

  Map<String, Object> _buildHistoryPayload(DateTime now) {
    return {
      'generatedAt': now.toIso8601String(),
      'events': [
        {
          'type': 'design_edit',
          'timestamp': now.subtract(const Duration(days: 2)).toIso8601String(),
          'detail': 'Updated seal layout',
        },
        {
          'type': 'export_request',
          'timestamp': now.subtract(const Duration(hours: 6)).toIso8601String(),
          'detail': 'Data export initiated',
        },
      ],
    };
  }

  Future<_SavedArchive> _saveArchive(Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final stamp = _timestamp(DateTime.now().toUtc());
    final filename = 'hanko-data-export-$stamp';
    final filePath = p.join(directory.path, '$filename.zip');
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return _SavedArchive(
      filename: filename,
      path: filePath,
      sizeMb: bytes.length / (1024 * 1024),
    );
  }

  String _timestamp(DateTime dateTime) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dateTime.year}${two(dateTime.month)}${two(dateTime.day)}_'
        '${two(dateTime.hour)}${two(dateTime.minute)}${two(dateTime.second)}';
  }
}

class _SavedArchive {
  const _SavedArchive({
    required this.filename,
    required this.path,
    required this.sizeMb,
  });

  final String filename;
  final String path;
  final double sizeMb;
}

final profileExportViewModel = ProfileExportViewModel();
