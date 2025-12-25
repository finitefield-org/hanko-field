// ignore_for_file: public_member_api_docs

import 'dart:math';

import 'package:app/features/support/data/models/support_ticket_models.dart';
import 'package:app/features/support/data/repositories/support_api_repository.dart';
import 'package:app/features/support/data/repositories/support_repository.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

class SupportContactErrors {
  const SupportContactErrors({
    this.subject,
    this.message,
    this.orderId,
    this.attachments,
  });

  final String? subject;
  final String? message;
  final String? orderId;
  final String? attachments;

  bool get hasError =>
      subject != null ||
      message != null ||
      orderId != null ||
      attachments != null;
}

class SupportValidationException implements Exception {
  const SupportValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupportContactState {
  const SupportContactState({
    required this.topic,
    required this.subject,
    required this.message,
    required this.orderId,
    required this.attachments,
    required this.errors,
    required this.lastSubmission,
  });

  final SupportTopic topic;
  final String subject;
  final String message;
  final String orderId;
  final List<SupportAttachment> attachments;
  final SupportContactErrors errors;
  final SupportTicketSubmission? lastSubmission;

  bool get canSubmit =>
      subject.trim().isNotEmpty &&
      message.trim().isNotEmpty &&
      !errors.hasError;

  SupportContactState copyWith({
    SupportTopic? topic,
    String? subject,
    String? message,
    String? orderId,
    List<SupportAttachment>? attachments,
    SupportContactErrors? errors,
    SupportTicketSubmission? lastSubmission,
  }) {
    return SupportContactState(
      topic: topic ?? this.topic,
      subject: subject ?? this.subject,
      message: message ?? this.message,
      orderId: orderId ?? this.orderId,
      attachments: attachments ?? this.attachments,
      errors: errors ?? this.errors,
      lastSubmission: lastSubmission ?? this.lastSubmission,
    );
  }

  SupportContactState resetForm({SupportTicketSubmission? submission}) {
    return SupportContactState(
      topic: topic,
      subject: '',
      message: '',
      orderId: '',
      attachments: const [],
      errors: const SupportContactErrors(),
      lastSubmission: submission ?? lastSubmission,
    );
  }
}

final supportContactViewModel = SupportContactViewModel();

class SupportContactViewModel extends Provider<SupportContactState> {
  SupportContactViewModel() : super.args(null, autoDispose: true);

  static const int _maxAttachments = 3;
  static const int _maxAttachmentBytes = 10 * 1024 * 1024;

  late final updateMut = mutation<void>(#update);
  late final submitMut = mutation<SupportTicketSubmission>(#submit);

  @override
  SupportContactState build(Ref ref) {
    return const SupportContactState(
      topic: SupportTopic.order,
      subject: '',
      message: '',
      orderId: '',
      attachments: [],
      errors: SupportContactErrors(),
      lastSubmission: null,
    );
  }

  Call<void> updateTopic(SupportTopic topic) => _update(
    (ref, state) => state.copyWith(
      topic: topic,
      errors: _validate(ref, state.copyWith(topic: topic)),
    ),
  );

  Call<void> updateSubject(String value) => _update(
    (ref, state) => state.copyWith(
      subject: value,
      errors: _validate(ref, state.copyWith(subject: value)),
    ),
  );

  Call<void> updateMessage(String value) => _update(
    (ref, state) => state.copyWith(
      message: value,
      errors: _validate(ref, state.copyWith(message: value)),
    ),
  );

  Call<void> updateOrderId(String value) => _update(
    (ref, state) => state.copyWith(
      orderId: value,
      errors: _validate(ref, state.copyWith(orderId: value)),
    ),
  );

  Call<void> applyTemplate(
    SupportTopic topic,
    String subject,
    String message,
  ) => _update(
    (ref, state) => state.copyWith(
      topic: topic,
      subject: subject,
      message: message,
      errors: _validate(
        ref,
        state.copyWith(topic: topic, subject: subject, message: message),
      ),
    ),
  );

  Call<void> addAttachments(List<SupportAttachment> attachments) =>
      _update((ref, state) {
        final next = [...state.attachments, ...attachments];
        final overflowed = next.length > _maxAttachments;
        final limited = next.take(_maxAttachments).toList();
        var errors = _validate(ref, state.copyWith(attachments: limited));
        if (overflowed) {
          errors = SupportContactErrors(
            subject: errors.subject,
            message: errors.message,
            orderId: errors.orderId,
            attachments: _attachmentsLimitMessage(ref, max: _maxAttachments),
          );
        }
        return state.copyWith(attachments: limited, errors: errors);
      });

  Call<void> removeAttachment(String id) => _update((ref, state) {
    final next = state.attachments.where((item) => item.id != id).toList();
    return state.copyWith(
      attachments: next,
      errors: _validate(ref, state.copyWith(attachments: next)),
    );
  });

  Call<SupportTicketSubmission> submit() => mutate(submitMut, (ref) async {
    final current = ref.watch(this);
    final errors = _validate(ref, current);
    if (errors.hasError) {
      ref.state = current.copyWith(errors: errors);
      throw SupportValidationException(
        ref.watch(appExperienceGatesProvider).prefersEnglish
            ? 'Please fix the highlighted fields.'
            : '入力内容を確認してください。',
      );
    }

    final repository = ref.watch(supportRepositoryProvider);
    final submission = await repository.createTicket(
      SupportTicketDraft(
        topic: current.topic,
        subject: current.subject.trim(),
        message: current.message.trim(),
        orderId: current.orderId.trim(),
        attachments: current.attachments,
      ),
    );

    ref.state = current.resetForm(submission: submission);
    return submission;
  }, concurrency: Concurrency.restart);

  Call<void> _update(
    SupportContactState Function(Ref ref, SupportContactState state) update,
  ) {
    return mutate(updateMut, (ref) async {
      final current = ref.watch(this);
      ref.state = update(ref, current);
    }, concurrency: Concurrency.dropLatest);
  }

  SupportContactErrors _validate(Ref ref, SupportContactState state) {
    final prefersEnglish = ref.watch(appExperienceGatesProvider).prefersEnglish;
    final subject = state.subject.trim();
    final message = state.message.trim();
    final orderId = state.orderId.trim();

    String? subjectError;
    String? messageError;
    String? orderIdError;
    String? attachmentsError;

    if (subject.isEmpty) {
      subjectError = prefersEnglish ? 'Subject is required.' : '件名は必須です。';
    } else if (subject.length < 3) {
      subjectError = prefersEnglish
          ? 'Subject should be at least 3 characters.'
          : '件名は3文字以上で入力してください。';
    }

    if (message.isEmpty) {
      messageError = prefersEnglish ? 'Message is required.' : '本文は必須です。';
    } else if (message.length < 10) {
      messageError = prefersEnglish
          ? 'Message should be at least 10 characters.'
          : '本文は10文字以上で入力してください。';
    }

    if (orderId.isNotEmpty) {
      final match = RegExp(r'^[A-Za-z0-9-]+$').hasMatch(orderId);
      if (!match || orderId.length < 4) {
        orderIdError = prefersEnglish
            ? 'Enter a valid order ID.'
            : '正しい注文IDを入力してください。';
      }
    }

    if (state.attachments.length > _maxAttachments) {
      attachmentsError = _attachmentsLimitMessage(ref, max: _maxAttachments);
    }

    for (final attachment in state.attachments) {
      if (attachment.sizeBytes > _maxAttachmentBytes) {
        attachmentsError = prefersEnglish
            ? 'Each file must be under ${_formatBytes(_maxAttachmentBytes)}.'
            : '各ファイルは${_formatBytes(_maxAttachmentBytes)}以下です。';
        break;
      }
    }

    return SupportContactErrors(
      subject: subjectError,
      message: messageError,
      orderId: orderIdError,
      attachments: attachmentsError,
    );
  }
}

String createAttachmentId(Random random) {
  final seed = DateTime.now().microsecondsSinceEpoch;
  final rand = random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
  return '$seed-$rand';
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  double value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}

String _attachmentsLimitMessage(Ref ref, {required int max}) {
  final prefersEnglish = ref.watch(appExperienceGatesProvider).prefersEnglish;
  return prefersEnglish ? 'Up to $max attachments allowed.' : '添付は最大$max件までです。';
}
