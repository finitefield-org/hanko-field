import 'dart:async';

import 'package:app/features/profile/domain/support_center.dart';
import 'package:app/features/support_contact/data/support_contact_repository.dart';
import 'package:app/features/support_contact/data/support_contact_repository_provider.dart';
import 'package:app/features/support_contact/domain/support_contact.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const int kSupportContactMinMessageLength = 24;

enum ContactAttachmentStatus {
  requestingSlot,
  uploading,
  verifying,
  uploaded,
  failed,
}

@immutable
class ContactAttachmentDraft {
  const ContactAttachmentDraft({
    required this.localId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.status,
    required this.progress,
    this.remoteAttachment,
    this.error,
  });

  final String localId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final ContactAttachmentStatus status;
  final double progress;
  final SupportContactUploadedAttachment? remoteAttachment;
  final Object? error;

  bool get isUploaded =>
      status == ContactAttachmentStatus.uploaded && remoteAttachment != null;

  ContactAttachmentDraft copyWith({
    ContactAttachmentStatus? status,
    double? progress,
    SupportContactUploadedAttachment? remoteAttachment,
    Object? error = _sentinel,
  }) {
    return ContactAttachmentDraft(
      localId: localId,
      fileName: fileName,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      remoteAttachment: remoteAttachment ?? this.remoteAttachment,
      error: identical(error, _sentinel) ? this.error : error,
    );
  }
}

@immutable
class SupportContactState {
  SupportContactState({
    required this.bootstrap,
    required this.subject,
    required this.message,
    required this.orderId,
    required this.selectedTopicId,
    required List<ContactAttachmentDraft> attachments,
    this.isSubmitting = false,
  }) : attachments = List.unmodifiable(attachments);

  final SupportContactBootstrap bootstrap;
  final String subject;
  final String message;
  final String orderId;
  final String? selectedTopicId;
  final List<ContactAttachmentDraft> attachments;
  final bool isSubmitting;

  SupportContactTopic? get selectedTopic {
    if (bootstrap.topics.isEmpty) {
      return null;
    }
    if (selectedTopicId == null) {
      return bootstrap.topics.first;
    }
    for (final topic in bootstrap.topics) {
      if (topic.id == selectedTopicId) {
        return topic;
      }
    }
    return bootstrap.topics.first;
  }

  int get attachmentBytesUsed {
    return attachments.fold(0, (sum, item) => sum + item.sizeBytes);
  }

  bool get hasUploadingAttachments => attachments.any((attachment) {
    return attachment.status == ContactAttachmentStatus.requestingSlot ||
        attachment.status == ContactAttachmentStatus.uploading ||
        attachment.status == ContactAttachmentStatus.verifying;
  });

  bool get hasFailedAttachments => attachments.any(
    (attachment) => attachment.status == ContactAttachmentStatus.failed,
  );

  bool get canSubmit {
    if (isSubmitting) {
      return false;
    }
    if (subject.trim().isEmpty) {
      return false;
    }
    if (message.trim().length < kSupportContactMinMessageLength) {
      return false;
    }
    if (hasUploadingAttachments || hasFailedAttachments) {
      return false;
    }
    return true;
  }

  SupportContactState copyWith({
    SupportContactBootstrap? bootstrap,
    String? subject,
    String? message,
    String? orderId,
    Object? selectedTopicId = _sentinel,
    List<ContactAttachmentDraft>? attachments,
    bool? isSubmitting,
  }) {
    return SupportContactState(
      bootstrap: bootstrap ?? this.bootstrap,
      subject: subject ?? this.subject,
      message: message ?? this.message,
      orderId: orderId ?? this.orderId,
      selectedTopicId: identical(selectedTopicId, _sentinel)
          ? this.selectedTopicId
          : selectedTopicId as String?,
      attachments: attachments ?? this.attachments,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class SupportContactController extends AsyncNotifier<SupportContactState> {
  SupportContactRepository get _repository =>
      ref.read(supportContactRepositoryProvider);

  @override
  FutureOr<SupportContactState> build() async {
    final bootstrap = await _repository.loadBootstrap();
    return SupportContactState(
      bootstrap: bootstrap,
      subject: '',
      message: '',
      orderId: '',
      selectedTopicId: bootstrap.topics.isEmpty
          ? null
          : bootstrap.topics.first.id,
      attachments: const [],
    );
  }

  void selectTopic(String? topicId) {
    final current = _requireState();
    if (current.selectedTopicId == topicId) {
      return;
    }
    state = AsyncData(current.copyWith(selectedTopicId: topicId));
  }

  void updateSubject(String value) {
    final current = _requireState();
    if (current.subject == value) {
      return;
    }
    state = AsyncData(current.copyWith(subject: value));
  }

  void updateOrderId(String value) {
    final current = _requireState();
    if (current.orderId == value) {
      return;
    }
    state = AsyncData(current.copyWith(orderId: value));
  }

  void updateMessage(String value) {
    final current = _requireState();
    if (current.message == value) {
      return;
    }
    state = AsyncData(current.copyWith(message: value));
  }

  void applyTemplate(String template) {
    final current = _requireState();
    final trimmed = current.message.trim();
    final nextValue = trimmed.isEmpty ? template : '$trimmed\n\n$template';
    state = AsyncData(current.copyWith(message: nextValue));
  }

  bool canAddAttachment(SupportContactAttachmentPayload payload) {
    final current = _requireState();
    if (current.attachments.length >= current.bootstrap.maxAttachments) {
      return false;
    }
    return current.attachmentBytesUsed + payload.sizeBytes <=
        current.bootstrap.maxTotalBytes;
  }

  Future<void> addAttachment(SupportContactAttachmentPayload payload) async {
    final current = _requireState();
    if (!canAddAttachment(payload)) {
      throw StateError('Attachment limits exceeded');
    }
    final localId = 'att-${DateTime.now().microsecondsSinceEpoch}';
    final pending = ContactAttachmentDraft(
      localId: localId,
      fileName: payload.fileName,
      mimeType: payload.mimeType,
      sizeBytes: payload.sizeBytes,
      status: ContactAttachmentStatus.requestingSlot,
      progress: 0,
    );
    state = AsyncData(
      current.copyWith(attachments: [...current.attachments, pending]),
    );
    unawaited(_performUpload(localId, payload));
  }

  Future<void> retryAttachment(String localId) async {
    final current = _requireState();
    final existing = current.attachments.firstWhere(
      (attachment) => attachment.localId == localId,
      orElse: () => throw StateError('Attachment missing'),
    );
    if (existing.status != ContactAttachmentStatus.failed) {
      return;
    }
    final payload = SupportContactAttachmentPayload(
      fileName: existing.fileName,
      mimeType: existing.mimeType,
      sizeBytes: existing.sizeBytes,
    );
    final patched = [
      for (final attachment in current.attachments)
        if (attachment.localId == localId)
          attachment.copyWith(
            status: ContactAttachmentStatus.requestingSlot,
            progress: 0,
            error: null,
            remoteAttachment: null,
          )
        else
          attachment,
    ];
    state = AsyncData(current.copyWith(attachments: patched));
    unawaited(_performUpload(localId, payload));
  }

  void removeAttachment(String localId) {
    final current = _requireState();
    final trimmed = [
      for (final attachment in current.attachments)
        if (attachment.localId != localId) attachment,
    ];
    if (trimmed.length == current.attachments.length) {
      return;
    }
    state = AsyncData(current.copyWith(attachments: trimmed));
  }

  Future<SupportTicket> submit() async {
    final current = _requireState();
    if (!current.canSubmit) {
      throw StateError('Form is not valid');
    }
    state = AsyncData(current.copyWith(isSubmitting: true));
    final attachments = current.attachments
        .where((attachment) => attachment.isUploaded)
        .map((attachment) => attachment.remoteAttachment!)
        .toList(growable: false);
    final submission = SupportContactSubmission(
      subject: current.subject.trim(),
      message: current.message.trim(),
      orderId: current.orderId.trim().isEmpty ? null : current.orderId.trim(),
      topicId: current.selectedTopicId,
      attachments: attachments,
    );
    try {
      final ticket = await _repository.submitTicket(submission);
      if (!ref.mounted) {
        return ticket;
      }
      state = AsyncData(
        current.copyWith(
          subject: '',
          message: '',
          orderId: '',
          attachments: const [],
          isSubmitting: false,
        ),
      );
      return ticket;
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(isSubmitting: false));
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _performUpload(
    String localId,
    SupportContactAttachmentPayload payload,
  ) async {
    final request = AttachmentUploadRequest(
      fileName: payload.fileName,
      mimeType: payload.mimeType,
      sizeBytes: payload.sizeBytes,
    );
    try {
      final slot = await _repository.createAttachmentUpload(request);
      _updateAttachment(localId, (attachment) {
        return attachment.copyWith(
          status: ContactAttachmentStatus.uploading,
          progress: 0.35,
          error: null,
        );
      });
      await _repository.uploadAttachmentBytes(
        upload: slot,
        sizeBytes: payload.sizeBytes,
      );
      _updateAttachment(localId, (attachment) {
        return attachment.copyWith(
          status: ContactAttachmentStatus.verifying,
          progress: 0.85,
        );
      });
      final uploaded = await _repository.finalizeAttachmentUpload(
        upload: slot,
        request: request,
      );
      _updateAttachment(localId, (attachment) {
        return attachment.copyWith(
          status: ContactAttachmentStatus.uploaded,
          progress: 1,
          remoteAttachment: uploaded,
        );
      });
    } catch (error) {
      _updateAttachment(localId, (attachment) {
        return attachment.copyWith(
          status: ContactAttachmentStatus.failed,
          progress: 0,
          error: error,
        );
      });
    }
  }

  void _updateAttachment(
    String localId,
    ContactAttachmentDraft Function(ContactAttachmentDraft) updater,
  ) {
    final current = _requireState();
    final patched = [
      for (final attachment in current.attachments)
        if (attachment.localId == localId) updater(attachment) else attachment,
    ];
    state = AsyncData(current.copyWith(attachments: patched));
  }

  SupportContactState _requireState() {
    final value = state.asData?.value;
    if (value == null) {
      throw StateError('Support contact state not ready');
    }
    return value;
  }
}

final supportContactControllerProvider =
    AsyncNotifierProvider<SupportContactController, SupportContactState>(
      SupportContactController.new,
    );

const Object _sentinel = Object();
