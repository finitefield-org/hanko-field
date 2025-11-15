import 'dart:async';
import 'dart:math';

import 'package:app/features/profile/data/support_center_repository.dart';
import 'package:app/features/profile/domain/support_center.dart';
import 'package:app/features/support_contact/data/support_contact_repository.dart';
import 'package:app/features/support_contact/domain/support_contact.dart';

class FakeSupportContactRepository implements SupportContactRepository {
  FakeSupportContactRepository({
    required SupportCenterRepository supportCenterRepository,
    Duration latency = const Duration(milliseconds: 280),
    DateTime Function()? now,
  }) : _supportCenterRepository = supportCenterRepository,
       _latency = latency,
       _now = now ?? DateTime.now,
       _random = Random();

  final SupportCenterRepository _supportCenterRepository;
  final Duration _latency;
  final DateTime Function() _now;
  final Random _random;
  int _uploadCounter = 0;

  @override
  Future<SupportContactBootstrap> loadBootstrap() async {
    await Future<void>.delayed(_latency);
    return SupportContactBootstrap(
      topics: _topics,
      templates: _templates,
      maxAttachments: 4,
      maxTotalBytes: 10 * 1024 * 1024,
    );
  }

  @override
  Future<SignedAttachmentUpload> createAttachmentUpload(
    AttachmentUploadRequest request,
  ) async {
    await Future<void>.delayed(_latency ~/ 2);
    final token = (++_uploadCounter).toRadixString(16);
    return SignedAttachmentUpload(
      uploadId: 'upload-$token',
      uploadUrl: Uri.parse(
        'https://uploads.hanko-field.com/support/$token?signature=demo',
      ),
      fileUrl: Uri.parse(
        'https://storage.hanko-field.com/support/$token/${request.fileName}',
      ),
      expiresAt: _now().add(const Duration(minutes: 20)),
    );
  }

  @override
  Future<void> uploadAttachmentBytes({
    required SignedAttachmentUpload upload,
    required int sizeBytes,
  }) async {
    final baseDelay = _latency + Duration(milliseconds: sizeBytes ~/ 4);
    await Future<void>.delayed(baseDelay);
    if (_random.nextInt(100) < 5) {
      throw StateError('Simulated upload failure for ${upload.uploadId}');
    }
  }

  @override
  Future<SupportContactUploadedAttachment> finalizeAttachmentUpload({
    required SignedAttachmentUpload upload,
    required AttachmentUploadRequest request,
  }) async {
    await Future<void>.delayed(_latency ~/ 2);
    return SupportContactUploadedAttachment(
      attachmentId: upload.uploadId,
      fileName: request.fileName,
      mimeType: request.mimeType,
      sizeBytes: request.sizeBytes,
      downloadUrl: upload.fileUrl,
    );
  }

  @override
  Future<SupportTicket> submitTicket(
    SupportContactSubmission submission,
  ) async {
    await Future<void>.delayed(_latency);
    final subject = submission.subject.isEmpty
        ? 'Support ticket'
        : submission.subject;
    return _supportCenterRepository.createTicket(subject: subject);
  }

  List<SupportContactTopic> get _topics => const [
    SupportContactTopic(
      id: 'orders',
      title: 'Orders & proofs',
      description: 'Proof approvals, revisions, and project changes.',
      estimatedSla: Duration(hours: 6),
    ),
    SupportContactTopic(
      id: 'shipping',
      title: 'Shipping & delivery',
      description: 'Tracking updates, reroutes, and customs paperwork.',
      estimatedSla: Duration(hours: 4),
    ),
    SupportContactTopic(
      id: 'billing',
      title: 'Billing & invoices',
      description: 'Payments, refunds, and finance contacts.',
      estimatedSla: Duration(hours: 24),
    ),
    SupportContactTopic(
      id: 'product',
      title: 'Product guidance',
      description: 'Material selection, engravings, and personalization.',
      estimatedSla: Duration(hours: 12),
    ),
  ];

  List<SupportContactTemplate> get _templates => const [
    SupportContactTemplate(
      id: 'proof',
      label: 'Request proof update',
      body:
          'Hi team, could you update the latest proof with the attached notes? I need confirmation before Friday.',
    ),
    SupportContactTemplate(
      id: 'shipping',
      label: 'Report shipping issue',
      body:
          'Tracking appears stuck after customs. Can you verify carrier handoff and provide next steps?',
    ),
    SupportContactTemplate(
      id: 'billing',
      label: 'Invoice request',
      body:
          'Please send a PDF invoice with company profile attached so we can close our month-end accounts.',
    ),
  ];
}
