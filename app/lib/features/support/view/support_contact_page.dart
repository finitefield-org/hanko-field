// ignore_for_file: public_member_api_docs

import 'dart:io';
import 'dart:math';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/support/data/models/support_ticket_models.dart';
import 'package:app/features/support/view_model/support_contact_view_model.dart';
import 'package:app/security/storage_permission_client.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/buttons/app_button.dart';
import 'package:app/ui/forms/app_text_field.dart';
import 'package:app/ui/surfaces/app_card.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:path/path.dart' as path;

class SupportContactPage extends ConsumerStatefulWidget {
  const SupportContactPage({super.key});

  @override
  ConsumerState<SupportContactPage> createState() => _SupportContactPageState();
}

class _SupportContactPageState extends ConsumerState<SupportContactPage> {
  late final TextEditingController _subjectController;
  late final TextEditingController _messageController;
  late final TextEditingController _orderController;
  final Random _random = Random.secure();

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController();
    _messageController = TextEditingController();
    _orderController = TextEditingController();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final navigation = context.navigation;
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;

    final state = ref.watch(supportContactViewModel);
    final submitState = ref.watch(supportContactViewModel.submitMut);
    final isSubmitting = submitState is PendingMutationState;

    _syncController(_subjectController, state.subject);
    _syncController(_messageController, state.message);
    _syncController(_orderController, state.orderId);

    final templates = _templates(prefersEnglish);

    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            collapsedHeight: kToolbarHeight,
            backgroundColor: tokens.colors.surface,
            title: Text(prefersEnglish ? 'Contact support' : '問い合わせ'),
            leading: IconButton(
              tooltip: prefersEnglish ? 'Back' : '戻る',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => navigation.pop(),
            ),
            actions: [
              IconButton(
                tooltip: prefersEnglish ? 'History' : '履歴',
                icon: const Icon(Icons.history_rounded),
                onPressed: () => navigation.push(AppRoutePaths.profileSupport),
              ),
              SizedBox(width: tokens.spacing.sm),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.lg,
              tokens.spacing.md,
              tokens.spacing.lg,
              tokens.spacing.xxl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                if (state.lastSubmission != null) ...[
                  _ConfirmationCard(
                    submission: state.lastSubmission!,
                    prefersEnglish: prefersEnglish,
                  ),
                  SizedBox(height: tokens.spacing.lg),
                ],
                Text(
                  prefersEnglish
                      ? 'Tell us what you need and attach any helpful files.'
                      : '内容を入力し、必要であればファイルを添付してください。',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                SizedBox(height: tokens.spacing.lg),
                DropdownMenu<SupportTopic>(
                  initialSelection: state.topic,
                  expandedInsets: EdgeInsets.zero,
                  label: Text(prefersEnglish ? 'Topic' : 'カテゴリ'),
                  onSelected: (value) {
                    if (value == null) return;
                    ref.invoke(supportContactViewModel.updateTopic(value));
                  },
                  dropdownMenuEntries: SupportTopic.values
                      .map(
                        (topic) => DropdownMenuEntry(
                          value: topic,
                          label: _topicLabel(topic, prefersEnglish),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: tokens.spacing.lg),
                Text(
                  prefersEnglish ? 'Quick templates' : 'テンプレート',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.sm),
                Wrap(
                  spacing: tokens.spacing.sm,
                  runSpacing: tokens.spacing.sm,
                  children: [
                    for (final template in templates)
                      ActionChip(
                        label: Text(template.label),
                        onPressed: () => ref.invoke(
                          supportContactViewModel.applyTemplate(
                            template.topic,
                            template.subject,
                            template.message,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: tokens.spacing.lg),
                AppTextField(
                  label: prefersEnglish ? 'Subject' : '件名',
                  controller: _subjectController,
                  hintText: prefersEnglish
                      ? 'e.g. Need to update my shipping address'
                      : '例: 配送先を変更したい',
                  errorText: state.errors.subject,
                  onChanged: (value) =>
                      ref.invoke(supportContactViewModel.updateSubject(value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: prefersEnglish ? 'Message' : '本文',
                  controller: _messageController,
                  hintText: prefersEnglish
                      ? 'Include details such as order number, timeline, and request.'
                      : '注文番号や希望内容などを入力してください。',
                  maxLines: 6,
                  errorText: state.errors.message,
                  onChanged: (value) =>
                      ref.invoke(supportContactViewModel.updateMessage(value)),
                ),
                SizedBox(height: tokens.spacing.md),
                AppTextField(
                  label: prefersEnglish ? 'Order ID (optional)' : '注文ID (任意)',
                  controller: _orderController,
                  hintText: prefersEnglish
                      ? 'HF-2024-000123'
                      : 'HF-2024-000123',
                  errorText: state.errors.orderId,
                  onChanged: (value) =>
                      ref.invoke(supportContactViewModel.updateOrderId(value)),
                ),
                SizedBox(height: tokens.spacing.lg),
                _AttachmentCard(
                  attachments: state.attachments,
                  error: state.errors.attachments,
                  prefersEnglish: prefersEnglish,
                  onAdd: isSubmitting ? null : _pickAttachments,
                  onRemove: (id) =>
                      ref.invoke(supportContactViewModel.removeAttachment(id)),
                ),
                SizedBox(height: tokens.spacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: prefersEnglish ? 'Submit ticket' : '送信する',
                        variant: AppButtonVariant.secondary,
                        expand: true,
                        isLoading: isSubmitting,
                        leading: isSubmitting
                            ? null
                            : const Icon(Icons.send_rounded),
                        onPressed: state.canSubmit && !isSubmitting
                            ? _submit
                            : null,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.md),
                    TextButton(
                      onPressed: isSubmitting ? null : () => navigation.pop(),
                      child: Text(prefersEnglish ? 'Cancel' : 'キャンセル'),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttachments() async {
    final permission = await ref.container
        .read(storagePermissionClientProvider)
        .request();
    if (!permission.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.container.read(appExperienceGatesProvider).prefersEnglish
                ? 'Storage permission is required to attach files.'
                : 'ファイル添付にはストレージ権限が必要です。',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (!mounted || result == null) return;

    final attachments = <SupportAttachment>[];
    for (final file in result.files) {
      final bytes =
          file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) continue;

      final extension = (file.extension ?? path.extension(file.name))
          .replaceFirst('.', '')
          .toLowerCase();
      final mimeType = _mimeTypeForExtension(extension);

      attachments.add(
        SupportAttachment(
          id: createAttachmentId(_random),
          name: file.name,
          bytes: bytes,
          sizeBytes: bytes.length,
          mimeType: mimeType,
        ),
      );
    }

    if (attachments.isNotEmpty) {
      await ref.invoke(supportContactViewModel.addAttachments(attachments));
    }
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final submission = await ref.invoke(supportContactViewModel.submit());
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ref.container.read(appExperienceGatesProvider).prefersEnglish
                ? 'Ticket ${submission.ticketId} submitted.'
                : 'チケット ${submission.ticketId} を送信しました。',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.attachments,
    required this.error,
    required this.prefersEnglish,
    required this.onAdd,
    required this.onRemove,
  });

  final List<SupportAttachment> attachments;
  final String? error;
  final bool prefersEnglish;
  final VoidCallback? onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);

    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              prefersEnglish ? 'Attachments' : '添付ファイル',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              prefersEnglish ? 'Up to 3 files, 10 MB each.' : '最大3件、各10MBまで。',
            ),
            trailing: IconButton(
              tooltip: prefersEnglish ? 'Add attachment' : 'ファイルを追加',
              icon: const Icon(Icons.attach_file_rounded),
              onPressed: onAdd,
            ),
          ),
          if (error != null) ...[
            SizedBox(height: tokens.spacing.sm),
            AppValidationMessage(
              message: error!,
              state: AppValidationState.error,
            ),
          ],
          if (attachments.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.sm),
            for (final attachment in attachments)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.xs),
                child: _AttachmentRow(
                  attachment: attachment,
                  prefersEnglish: prefersEnglish,
                  onRemove: () => onRemove(attachment.id),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.attachment,
    required this.prefersEnglish,
    required this.onRemove,
  });

  final SupportAttachment attachment;
  final bool prefersEnglish;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.md,
        vertical: tokens.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.surface,
        borderRadius: BorderRadius.circular(tokens.radii.sm),
        border: Border.all(color: tokens.colors.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 20),
          SizedBox(width: tokens.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  _formatBytes(attachment.sizeBytes),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: prefersEnglish ? 'Remove' : '削除',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({
    required this.submission,
    required this.prefersEnglish,
  });

  final SupportTicketSubmission submission;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return AppCard(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: tokens.colors.success),
          SizedBox(width: tokens.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prefersEnglish ? 'Ticket submitted' : 'チケットを送信しました',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  prefersEnglish
                      ? 'We will reach out with updates. Your ticket ID is ${submission.ticketId}.'
                      : '更新があり次第ご連絡します。チケットID: ${submission.ticketId}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportTemplate {
  const _SupportTemplate({
    required this.label,
    required this.topic,
    required this.subject,
    required this.message,
  });

  final String label;
  final SupportTopic topic;
  final String subject;
  final String message;
}

List<_SupportTemplate> _templates(bool prefersEnglish) {
  if (prefersEnglish) {
    return const [
      _SupportTemplate(
        label: 'Update shipping',
        topic: SupportTopic.shipping,
        subject: 'Update my shipping address',
        message: 'Please update my shipping address for order ____.',
      ),
      _SupportTemplate(
        label: 'Payment help',
        topic: SupportTopic.payment,
        subject: 'Payment issue',
        message:
            'I encountered an issue while paying. Details: ____ (error message, card type).',
      ),
      _SupportTemplate(
        label: 'Order status',
        topic: SupportTopic.order,
        subject: 'Order status check',
        message:
            'Can you share the latest status for order ____? I need it by ____.',
      ),
      _SupportTemplate(
        label: 'Account access',
        topic: SupportTopic.account,
        subject: 'Account access request',
        message:
            'I cannot access my account. Please help reset or restore access.',
      ),
    ];
  }

  return const [
    _SupportTemplate(
      label: '配送先変更',
      topic: SupportTopic.shipping,
      subject: '配送先を変更したい',
      message: '注文 ____ の配送先を変更してください。',
    ),
    _SupportTemplate(
      label: '支払い相談',
      topic: SupportTopic.payment,
      subject: '支払いで問題が発生',
      message: '支払い時にエラーが出ました。詳細: ____',
    ),
    _SupportTemplate(
      label: '注文状況',
      topic: SupportTopic.order,
      subject: '注文状況を確認したい',
      message: '注文 ____ の進捗を教えてください。',
    ),
    _SupportTemplate(
      label: 'アカウント',
      topic: SupportTopic.account,
      subject: 'アカウントにログインできない',
      message: 'ログインできないため対応をお願いします。',
    ),
  ];
}

String _topicLabel(SupportTopic topic, bool prefersEnglish) {
  return switch (topic) {
    SupportTopic.order => prefersEnglish ? 'Order' : '注文',
    SupportTopic.shipping => prefersEnglish ? 'Shipping' : '配送',
    SupportTopic.payment => prefersEnglish ? 'Payment' : '支払い',
    SupportTopic.account => prefersEnglish ? 'Account' : 'アカウント',
    SupportTopic.app => prefersEnglish ? 'App' : 'アプリ',
    SupportTopic.other => prefersEnglish ? 'Other' : 'その他',
  };
}

String _mimeTypeForExtension(String extension) {
  final normalized = extension.toLowerCase();
  switch (normalized) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'heic':
      return 'image/heic';
    case 'webp':
      return 'image/webp';
    case 'svg':
      return 'image/svg+xml';
    case 'pdf':
      return 'application/pdf';
    case 'txt':
      return 'text/plain';
    default:
      return 'application/octet-stream';
  }
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
