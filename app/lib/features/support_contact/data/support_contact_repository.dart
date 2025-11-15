import 'package:app/features/profile/domain/support_center.dart';
import 'package:app/features/support_contact/domain/support_contact.dart';

abstract class SupportContactRepository {
  Future<SupportContactBootstrap> loadBootstrap();

  Future<SignedAttachmentUpload> createAttachmentUpload(
    AttachmentUploadRequest request,
  );

  Future<void> uploadAttachmentBytes({
    required SignedAttachmentUpload upload,
    required int sizeBytes,
  });

  Future<SupportContactUploadedAttachment> finalizeAttachmentUpload({
    required SignedAttachmentUpload upload,
    required AttachmentUploadRequest request,
  });

  Future<SupportTicket> submitTicket(SupportContactSubmission submission);
}
