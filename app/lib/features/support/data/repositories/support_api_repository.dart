// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/core/network/network_client.dart';
import 'package:app/core/network/network_config.dart';
import 'package:app/core/network/network_providers.dart';
import 'package:app/features/support/data/models/support_ticket_models.dart';
import 'package:app/features/support/data/repositories/support_repository.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  try {
    return ref.scope(SupportRepository.fallback);
  } on StateError {
    return SupportApiRepository(ref);
  }
});

class SupportApiRepository implements SupportRepository {
  SupportApiRepository(this._ref) : _logger = Logger('SupportRepository');

  final Ref _ref;
  final Logger _logger;
  final Random _random = Random.secure();

  NetworkClient get _client => _ref.watch(networkClientProvider);
  http.Client get _httpClient => _ref.watch(httpClientProvider);
  NetworkConfig get _config => _ref.watch(networkConfigProvider);

  @override
  Future<SupportTicketSubmission> createTicket(SupportTicketDraft draft) async {
    final attachmentIds = <String>[];
    for (final attachment in draft.attachments) {
      attachmentIds.add(await _uploadAttachment(attachment));
    }

    final response = await _client.post<Object?>(
      '/support/tickets',
      headers: {'Idempotency-Key': _idempotencyKey()},
      data: {
        'topic': draft.topic.toJson(),
        'subject': draft.subject,
        'message': draft.message,
        if (draft.orderId.isNotEmpty) 'orderId': draft.orderId,
        if (attachmentIds.isNotEmpty) 'attachmentAssetIds': attachmentIds,
      },
      decoder: (json) => json,
    );

    final data = response.data;
    if (data is! Map) {
      throw StateError('Unexpected support ticket response: $data');
    }

    final map = Map<String, Object?>.from(data);
    final ticketId = (map['ticketId'] ?? map['id'] ?? map['ticket_id'])
        ?.toString();
    if (ticketId == null || ticketId.isEmpty) {
      throw StateError('Missing ticket id in response: $map');
    }

    return SupportTicketSubmission(
      ticketId: ticketId,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Future<String> _uploadAttachment(SupportAttachment attachment) async {
    final signed = await _client.post<Object?>(
      '/assets:signed-upload',
      headers: {'Idempotency-Key': _idempotencyKey()},
      data: {
        'kind': _assetKind(attachment),
        'purpose': 'support-attachment',
        'mimeType': attachment.mimeType,
      },
      decoder: (json) => json,
    );

    final data = signed.data;
    if (data is! Map) {
      throw StateError('Unexpected signed upload response: $data');
    }

    final map = Map<String, Object?>.from(data);
    final uploadUrl = map['uploadUrl']?.toString();
    final assetId = map['assetId']?.toString();
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw StateError('Missing uploadUrl in signed response: $map');
    }
    if (assetId == null || assetId.isEmpty) {
      throw StateError('Missing assetId in signed response: $map');
    }

    final request = http.Request('PUT', Uri.parse(uploadUrl));
    request.headers['Content-Type'] = attachment.mimeType;
    request.bodyBytes = attachment.bytes;

    final streamed = _config.sendTimeout == Duration.zero
        ? await _httpClient.send(request)
        : await _httpClient.send(request).timeout(_config.sendTimeout);
    final response = _config.receiveTimeout == Duration.zero
        ? await http.Response.fromStream(streamed)
        : await http.Response.fromStream(
            streamed,
          ).timeout(_config.receiveTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logger.warning(
        'Upload failed: ${response.statusCode} ${response.reasonPhrase}',
      );
      throw StateError('Attachment upload failed (${response.statusCode}).');
    }

    return assetId;
  }

  String _assetKind(SupportAttachment attachment) {
    final normalized = attachment.mimeType.toLowerCase();
    if (normalized.contains('pdf')) return 'pdf';
    if (normalized.contains('png')) return 'png';
    if (normalized.contains('jpeg') || normalized.contains('jpg')) return 'jpg';
    if (normalized.contains('heic')) return 'heic';
    if (normalized.contains('webp')) return 'webp';
    if (normalized.contains('svg')) return 'svg';
    return 'binary';
  }

  String _idempotencyKey() {
    final seed = DateTime.now().microsecondsSinceEpoch;
    final random = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$seed-$random';
  }
}
