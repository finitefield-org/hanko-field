import 'dart:math' as math;

import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/features/profile/application/profile_support_controller.dart';
import 'package:app/features/support_contact/application/support_contact_controller.dart';
import 'package:app/features/support_contact/domain/support_contact.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportContactScreen extends ConsumerStatefulWidget {
  const SupportContactScreen({super.key});

  @override
  ConsumerState<SupportContactScreen> createState() =>
      _SupportContactScreenState();
}

class _SupportContactScreenState extends ConsumerState<SupportContactScreen> {
  late final TextEditingController _subjectController;
  late final TextEditingController _orderIdController;
  late final TextEditingController _messageController;
  bool _subjectTouched = false;
  bool _messageTouched = false;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController();
    _orderIdController = TextEditingController();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _orderIdController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(supportContactControllerProvider);
    final controller = ref.read(supportContactControllerProvider.notifier);
    final navigation = ref.read(appNavigationControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supportContactTitle),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: l10n.supportContactHistoryTooltip,
            icon: const Icon(Icons.history),
            onPressed: () {
              navigation.push(ProfileSectionRoute(['support']));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _SupportContactError(
            message: error.toString(),
            onRetry: () => ref.invalidate(supportContactControllerProvider),
          ),
          data: (state) {
            _syncControllers(state);
            return _SupportContactForm(
              state: state,
              controller: controller,
              l10n: l10n,
              subjectController: _subjectController,
              orderIdController: _orderIdController,
              messageController: _messageController,
              subjectTouched: _subjectTouched,
              messageTouched: _messageTouched,
              onSubjectChanged: (value) {
                setState(() => _subjectTouched = true);
                controller.updateSubject(value);
              },
              onOrderIdChanged: controller.updateOrderId,
              onMessageChanged: (value) {
                setState(() => _messageTouched = true);
                controller.updateMessage(value);
              },
              onSubmit: () => _handleSubmit(state),
              onCancel: () => Navigator.of(context).maybePop(),
              onTemplateApplied: controller.applyTemplate,
              onAddAttachment: _handleAddAttachment,
              onRemoveAttachment: controller.removeAttachment,
              onRetryAttachment: controller.retryAttachment,
            );
          },
        ),
      ),
    );
  }

  void _syncControllers(SupportContactState state) {
    if (_subjectController.text != state.subject) {
      _subjectController.value = TextEditingValue(
        text: state.subject,
        selection: TextSelection.collapsed(offset: state.subject.length),
      );
    }
    if (_orderIdController.text != state.orderId) {
      _orderIdController.value = TextEditingValue(
        text: state.orderId,
        selection: TextSelection.collapsed(offset: state.orderId.length),
      );
    }
    if (_messageController.text != state.message) {
      _messageController.value = TextEditingValue(
        text: state.message,
        selection: TextSelection.collapsed(offset: state.message.length),
      );
    }
  }

  Future<void> _handleSubmit(SupportContactState state) async {
    setState(() {
      _subjectTouched = true;
      _messageTouched = true;
    });
    final controller = ref.read(supportContactControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!state.canSubmit) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.supportContactValidationError)),
        );
      return;
    }
    try {
      final ticket = await controller.submit();
      ref.invalidate(profileSupportControllerProvider);
      if (!mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(l10n.supportContactSubmitSuccessTitle),
            content: Text(
              l10n.supportContactSubmitSuccessBody(ticket.reference),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  ref
                      .read(appNavigationControllerProvider)
                      .push(ProfileSectionRoute(['support']));
                },
                child: Text(l10n.supportContactHistoryButton),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.supportContactSubmitDialogDismiss),
              ),
            ],
          );
        },
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.supportContactSubmitError)));
    }
  }

  Future<void> _handleAddAttachment(SupportContactState state) async {
    final controller = ref.read(supportContactControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<_AttachmentSample>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) =>
          _AttachmentPickerSheet(l10n: AppLocalizations.of(sheetContext)),
    );
    if (!mounted || selected == null) {
      return;
    }
    final payload = SupportContactAttachmentPayload(
      fileName: selected.fileName,
      mimeType: selected.mimeType,
      sizeBytes: selected.sizeBytes,
    );
    final messenger = ScaffoldMessenger.of(context);
    if (state.attachments.length >= state.bootstrap.maxAttachments) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.supportContactAttachmentLimitReached)),
        );
      return;
    }
    final projectedBytes = state.attachmentBytesUsed + payload.sizeBytes;
    if (projectedBytes > state.bootstrap.maxTotalBytes) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.supportContactAttachmentSizeExceeded)),
        );
      return;
    }
    await controller.addAttachment(payload);
  }
}

class _SupportContactForm extends StatelessWidget {
  const _SupportContactForm({
    required this.state,
    required this.controller,
    required this.l10n,
    required this.subjectController,
    required this.orderIdController,
    required this.messageController,
    required this.subjectTouched,
    required this.messageTouched,
    required this.onSubjectChanged,
    required this.onOrderIdChanged,
    required this.onMessageChanged,
    required this.onSubmit,
    required this.onCancel,
    required this.onTemplateApplied,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
    required this.onRetryAttachment,
  });

  final SupportContactState state;
  final SupportContactController controller;
  final AppLocalizations l10n;
  final TextEditingController subjectController;
  final TextEditingController orderIdController;
  final TextEditingController messageController;
  final bool subjectTouched;
  final bool messageTouched;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<String> onOrderIdChanged;
  final ValueChanged<String> onMessageChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final ValueChanged<String> onTemplateApplied;
  final Future<void> Function(SupportContactState) onAddAttachment;
  final ValueChanged<String> onRemoveAttachment;
  final ValueChanged<String> onRetryAttachment;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (state.isSubmitting)
          const SliverToBoxAdapter(
            child: LinearProgressIndicator(minHeight: 2),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceL,
            AppTokens.spaceL,
            AppTokens.spaceL,
            AppTokens.spaceXL,
          ),
          sliver: SliverList.list(
            children: [
              Text(
                l10n.supportContactSubtitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppTokens.spaceL),
              _TopicSelector(
                topics: state.bootstrap.topics,
                selectedTopicId: state.selectedTopicId,
                onSelected: controller.selectTopic,
                l10n: l10n,
              ),
              const SizedBox(height: AppTokens.spaceL),
              _buildSubjectField(context),
              const SizedBox(height: AppTokens.spaceL),
              _buildOrderIdField(context),
              const SizedBox(height: AppTokens.spaceL),
              _buildMessageField(context),
              if (state.bootstrap.templates.isNotEmpty) ...[
                const SizedBox(height: AppTokens.spaceL),
                _TemplateChips(
                  templates: state.bootstrap.templates,
                  l10n: l10n,
                  onTemplateApplied: onTemplateApplied,
                ),
              ],
              const SizedBox(height: AppTokens.spaceXL),
              _AttachmentSection(
                state: state,
                l10n: l10n,
                onAddAttachment: () {
                  onAddAttachment(state);
                },
                onRemoveAttachment: onRemoveAttachment,
                onRetryAttachment: onRetryAttachment,
              ),
              const SizedBox(height: AppTokens.spaceXL),
              _ActionButtons(
                submitLabel: l10n.supportContactSubmitLabel,
                cancelLabel: l10n.supportContactCancelLabel,
                onSubmit: onSubmit,
                onCancel: onCancel,
                enabled: state.canSubmit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectField(BuildContext context) {
    final errorText = subjectTouched && subjectController.text.trim().isEmpty
        ? l10n.supportContactSubjectError
        : null;
    return TextField(
      controller: subjectController,
      onChanged: onSubjectChanged,
      decoration: InputDecoration(
        labelText: l10n.supportContactSubjectLabel,
        hintText: l10n.supportContactSubjectPlaceholder,
        errorText: errorText,
      ),
    );
  }

  Widget _buildOrderIdField(BuildContext context) {
    return TextField(
      controller: orderIdController,
      onChanged: onOrderIdChanged,
      decoration: InputDecoration(
        labelText: l10n.supportContactOrderIdLabel,
        helperText: l10n.supportContactOrderIdHelper,
      ),
    );
  }

  Widget _buildMessageField(BuildContext context) {
    final isValid =
        messageController.text.trim().length >= kSupportContactMinMessageLength;
    final errorText = messageTouched && !isValid
        ? l10n.supportContactMessageError(kSupportContactMinMessageLength)
        : null;
    return TextField(
      controller: messageController,
      maxLines: 6,
      minLines: 4,
      onChanged: onMessageChanged,
      decoration: InputDecoration(
        labelText: l10n.supportContactMessageLabel,
        helperText: l10n.supportContactMessageHelper,
        errorText: errorText,
      ),
    );
  }
}

class _TopicSelector extends StatelessWidget {
  const _TopicSelector({
    required this.topics,
    required this.selectedTopicId,
    required this.onSelected,
    required this.l10n,
  });

  final List<SupportContactTopic> topics;
  final String? selectedTopicId;
  final ValueChanged<String?> onSelected;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.supportContactTopicLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.spaceS),
        Text(
          l10n.supportContactTopicHelper,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTokens.spaceS),
        Wrap(
          spacing: AppTokens.spaceS,
          runSpacing: AppTokens.spaceS,
          children: [
            for (final topic in topics)
              ChoiceChip(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic.title),
                    Text(
                      topic.description,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                selected: topic.id == selectedTopicId,
                onSelected: (_) => onSelected(topic.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _TemplateChips extends StatelessWidget {
  const _TemplateChips({
    required this.templates,
    required this.l10n,
    required this.onTemplateApplied,
  });

  final List<SupportContactTemplate> templates;
  final AppLocalizations l10n;
  final ValueChanged<String> onTemplateApplied;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.supportContactTemplatesTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.spaceS),
        Text(
          l10n.supportContactTemplatesSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTokens.spaceS),
        Wrap(
          spacing: AppTokens.spaceS,
          runSpacing: AppTokens.spaceS,
          children: [
            for (final template in templates)
              InputChip(
                label: Text(template.label),
                onPressed: () => onTemplateApplied(template.body),
              ),
          ],
        ),
      ],
    );
  }
}

class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({
    required this.state,
    required this.l10n,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
    required this.onRetryAttachment,
  });

  final SupportContactState state;
  final AppLocalizations l10n;
  final VoidCallback onAddAttachment;
  final ValueChanged<String> onRemoveAttachment;
  final ValueChanged<String> onRetryAttachment;

  @override
  Widget build(BuildContext context) {
    final summary = l10n.supportContactAttachmentSummary(
      state.attachments.length,
      state.bootstrap.maxAttachments,
      _formatBytes(state.attachmentBytesUsed),
      _formatBytes(state.bootstrap.maxTotalBytes),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.attach_file_outlined),
          title: Text(l10n.supportContactAttachmentsTitle),
          subtitle: Text(summary),
          trailing: IconButton(
            tooltip: l10n.supportContactAddAttachmentTooltip,
            icon: const Icon(Icons.add_circle_outline),
            onPressed:
                state.attachments.length >= state.bootstrap.maxAttachments
                ? null
                : state.attachmentBytesUsed >= state.bootstrap.maxTotalBytes
                ? null
                : onAddAttachment,
          ),
        ),
        for (final attachment in state.attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceS),
            child: Card(
              child: ListTile(
                leading: Icon(_attachmentIcon(attachment.mimeType)),
                title: Text(attachment.fileName),
                subtitle: Text(
                  '${_attachmentStatusLabel(attachment, l10n)} · ${_formatBytes(attachment.sizeBytes)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (attachment.status == ContactAttachmentStatus.failed)
                      IconButton(
                        tooltip: l10n.supportContactAttachmentRetry,
                        icon: const Icon(Icons.refresh),
                        onPressed: () => onRetryAttachment(attachment.localId),
                      )
                    else if (attachment.status !=
                        ContactAttachmentStatus.uploaded)
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          value: attachment.progress == 0
                              ? null
                              : attachment.progress,
                        ),
                      ),
                    IconButton(
                      tooltip: l10n.supportContactAttachmentRemove,
                      icon: const Icon(Icons.close),
                      onPressed: () => onRemoveAttachment(attachment.localId),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.submitLabel,
    required this.cancelLabel,
    required this.onSubmit,
    required this.onCancel,
    required this.enabled,
  });

  final String submitLabel;
  final String cancelLabel;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonal(
          onPressed: enabled ? onSubmit : null,
          child: Text(submitLabel),
        ),
        TextButton(onPressed: onCancel, child: Text(cancelLabel)),
      ],
    );
  }
}

class _SupportContactError extends StatelessWidget {
  const _SupportContactError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceM),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.supportContactRetryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPickerSheet extends StatelessWidget {
  const _AttachmentPickerSheet({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.supportContactAttachmentPickerTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.spaceS),
          Text(
            l10n.supportContactAttachmentPickerSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.spaceL),
          for (final sample in _attachmentSamples)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_attachmentIcon(sample.mimeType)),
              title: Text(sample.label),
              subtitle: Text(_formatBytes(sample.sizeBytes)),
              onTap: () => Navigator.of(context).pop(sample),
            ),
        ],
      ),
    );
  }
}

class _AttachmentSample {
  const _AttachmentSample({
    required this.label,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String label;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
}

const List<_AttachmentSample> _attachmentSamples = [
  _AttachmentSample(
    label: 'Screenshot (PNG)',
    fileName: 'support-screenshot.png',
    mimeType: 'image/png',
    sizeBytes: 420 * 1024,
  ),
  _AttachmentSample(
    label: 'Proof feedback (PDF)',
    fileName: 'proof-feedback.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 1 * 1024 * 1024,
  ),
  _AttachmentSample(
    label: 'Purchase order (DOCX)',
    fileName: 'purchase-order.docx',
    mimeType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    sizeBytes: 780 * 1024,
  ),
];

String _formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const units = ['B', 'KB', 'MB', 'GB'];
  final exponent = math.min(
    (math.log(bytes) / math.log(1024)).floor(),
    units.length - 1,
  );
  final value = bytes / math.pow(1024, exponent);
  final fractionDigits = value >= 10 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[exponent]}';
}

IconData _attachmentIcon(String mimeType) {
  if (mimeType.contains('image')) {
    return Icons.image_outlined;
  }
  if (mimeType.contains('pdf')) {
    return Icons.picture_as_pdf_outlined;
  }
  if (mimeType.contains('word') || mimeType.contains('doc')) {
    return Icons.description_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

String _attachmentStatusLabel(
  ContactAttachmentDraft attachment,
  AppLocalizations l10n,
) {
  switch (attachment.status) {
    case ContactAttachmentStatus.requestingSlot:
      return l10n.supportContactAttachmentStatusPending;
    case ContactAttachmentStatus.uploading:
      return l10n.supportContactAttachmentStatusUploading;
    case ContactAttachmentStatus.verifying:
      return l10n.supportContactAttachmentStatusVerifying;
    case ContactAttachmentStatus.uploaded:
      return l10n.supportContactAttachmentStatusUploaded;
    case ContactAttachmentStatus.failed:
      return l10n.supportContactAttachmentStatusFailed;
  }
}
