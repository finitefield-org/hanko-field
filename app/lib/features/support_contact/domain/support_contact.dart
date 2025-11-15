import 'package:flutter/foundation.dart';

@immutable
class SupportContactTopic {
  const SupportContactTopic({
    required this.id,
    required this.title,
    required this.description,
    this.estimatedSla,
  });

  final String id;
  final String title;
  final String description;
  final Duration? estimatedSla;
}

@immutable
class SupportContactTemplate {
  const SupportContactTemplate({
    required this.id,
    required this.label,
    required this.body,
  });

  final String id;
  final String label;
  final String body;
}

@immutable
class SupportContactBootstrap {
  SupportContactBootstrap({
    required List<SupportContactTopic> topics,
    required List<SupportContactTemplate> templates,
    required this.maxAttachments,
    required this.maxTotalBytes,
  }) : topics = List.unmodifiable(topics),
       templates = List.unmodifiable(templates);

  final List<SupportContactTopic> topics;
  final List<SupportContactTemplate> templates;
  final int maxAttachments;
  final int maxTotalBytes;
}

@immutable
class SupportContactAttachmentPayload {
  const SupportContactAttachmentPayload({
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String fileName;
  final String mimeType;
  final int sizeBytes;
}

@immutable
class AttachmentUploadRequest {
  const AttachmentUploadRequest({
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String fileName;
  final String mimeType;
  final int sizeBytes;

  AttachmentUploadRequest copyWith({
    String? fileName,
    String? mimeType,
    int? sizeBytes,
  }) {
    return AttachmentUploadRequest(
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }
}

@immutable
class SignedAttachmentUpload {
  const SignedAttachmentUpload({
    required this.uploadId,
    required this.uploadUrl,
    required this.fileUrl,
    required this.expiresAt,
  });

  final String uploadId;
  final Uri uploadUrl;
  final Uri fileUrl;
  final DateTime expiresAt;
}

@immutable
class SupportContactUploadedAttachment {
  const SupportContactUploadedAttachment({
    required this.attachmentId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  final String attachmentId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final Uri downloadUrl;
}

@immutable
class SupportContactSubmission {
  SupportContactSubmission({
    required this.subject,
    required this.message,
    this.orderId,
    this.topicId,
    required List<SupportContactUploadedAttachment> attachments,
  }) : attachments = List.unmodifiable(attachments);

  final String subject;
  final String message;
  final String? orderId;
  final String? topicId;
  final List<SupportContactUploadedAttachment> attachments;
}
