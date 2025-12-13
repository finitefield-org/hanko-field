// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/core/routing/routes.dart';
import 'package:app/features/orders/data/models/order_invoice_models.dart';
import 'package:app/features/orders/view_model/order_invoice_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:app/ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

class OrderInvoicePage extends ConsumerStatefulWidget {
  const OrderInvoicePage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderInvoicePage> createState() => _OrderInvoicePageState();
}

class _OrderInvoicePageState extends ConsumerState<OrderInvoicePage> {
  PdfControllerPinch? _pdfController;
  Uint8List? _pdfBytes;

  @override
  void dispose() {
    _pdfController?.dispose();
    _pdfController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;
    final vm = OrderInvoiceViewModel(orderId: widget.orderId);
    final state = ref.watch(vm);
    final requestState = ref.watch(vm.requestInvoiceMut);

    final current = state.valueOrNull;
    final invoice = current?.invoice;
    final bytes = current?.pdfBytes;
    if (bytes != null) _ensurePdfController(bytes);

    final title = prefersEnglish ? 'Invoice' : '領収書';

    return Scaffold(
      backgroundColor: tokens.colors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: prefersEnglish ? 'Back' : '戻る',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              ref.container.read(navigationControllerProvider).pop(),
        ),
        title: Text(title),
        actions: [
          IconButton(
            tooltip: prefersEnglish ? 'Share' : '共有',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: bytes == null ? null : () => unawaited(_share(bytes)),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          displacement: tokens.spacing.xl,
          edgeOffset: tokens.spacing.md,
          onRefresh: _refresh,
          child: _buildBody(
            context: context,
            tokens: tokens,
            prefersEnglish: prefersEnglish,
            state: state,
            invoice: invoice,
            bytes: bytes,
            requestState: requestState,
          ),
        ),
      ),
    );
  }

  void _ensurePdfController(Uint8List bytes) {
    if (identical(_pdfBytes, bytes)) return;
    _pdfController?.dispose();
    _pdfController = PdfControllerPinch(document: PdfDocument.openData(bytes));
    _pdfBytes = bytes;
  }

  Future<void> _refresh() async {
    await ref.refreshValue(
      OrderInvoiceViewModel(orderId: widget.orderId),
      keepPrevious: true,
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required DesignTokens tokens,
    required bool prefersEnglish,
    required AsyncValue<OrderInvoiceViewState> state,
    required OrderInvoice? invoice,
    required Uint8List? bytes,
    required MutationState<void> requestState,
  }) {
    final loading = state is AsyncLoading<OrderInvoiceViewState>;
    final error = state is AsyncError<OrderInvoiceViewState>;
    final current = state.valueOrNull;

    if (loading && current == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: const AppListSkeleton(items: 5, itemHeight: 84),
      );
    }

    if (error && current == null) {
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: AppEmptyState(
          title: prefersEnglish ? 'Could not load invoice' : '領収書を読み込めませんでした',
          message: state.error.toString(),
          icon: Icons.error_outline,
          actionLabel: prefersEnglish ? 'Retry' : '再試行',
          onAction: () => unawaited(_refresh()),
        ),
      );
    }

    if (current == null || invoice == null) return const SizedBox.shrink();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.lg,
        tokens.spacing.lg,
        tokens.spacing.lg,
        tokens.spacing.xl,
      ),
      children: [
        _MetadataCard(
          invoice: invoice,
          orderNumber: current.order.orderNumber,
          currency: current.order.currency,
          total: current.order.totals.total,
          prefersEnglish: prefersEnglish,
        ),
        SizedBox(height: tokens.spacing.lg),
        _ChipsRow(invoice: invoice, prefersEnglish: prefersEnglish),
        SizedBox(height: tokens.spacing.lg),
        _PreviewCard(
          tokens: tokens,
          prefersEnglish: prefersEnglish,
          controller: _pdfController,
          bytes: bytes,
          onRequestInvoice: requestState is PendingMutationState
              ? null
              : () => unawaited(_requestInvoice(prefersEnglish)),
          onRefresh: () => unawaited(_refresh()),
          status: invoice.status,
        ),
        SizedBox(height: tokens.spacing.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.download_outlined),
                label: Text(prefersEnglish ? 'Download PDF' : 'PDFを保存'),
                onPressed: bytes == null
                    ? null
                    : () => unawaited(_download(bytes)),
              ),
            ),
            SizedBox(width: tokens.spacing.md),
            TextButton(
              onPressed: bytes == null ? null : () => unawaited(_share(bytes)),
              child: Text(prefersEnglish ? 'Send by email' : 'メールで送る'),
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.md),
        TextButton(
          onPressed: () => _contactSupport(),
          child: Text(prefersEnglish ? 'Contact support' : '問い合わせ'),
        ),
      ],
    );
  }

  Future<void> _requestInvoice(bool prefersEnglish) async {
    final messenger = ScaffoldMessenger.of(context);
    final vm = OrderInvoiceViewModel(orderId: widget.orderId);
    try {
      await ref.invoke(vm.requestInvoice());
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            prefersEnglish
                ? 'Invoice request sent (mock)'
                : '領収書のリクエストを送信しました（モック）',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            prefersEnglish ? 'Could not request invoice' : '領収書のリクエストに失敗しました',
          ),
        ),
      );
    }
  }

  Future<void> _download(Uint8List bytes) async {
    final messenger = ScaffoldMessenger.of(context);
    final gates = ref.container.read(appExperienceGatesProvider);
    final prefersEnglish = gates.prefersEnglish;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final invoicesDir = Directory(p.join(dir.path, 'invoices'));
      await invoicesDir.create(recursive: true);

      final invoiceNumber =
          ref.container
              .read(OrderInvoiceViewModel(orderId: widget.orderId))
              .valueOrNull
              ?.invoice
              .invoiceNumber ??
          'invoice';
      final safeName = invoiceNumber.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]+'),
        '_',
      );
      final filePath = p.join(invoicesDir.path, '$safeName.pdf');
      await File(filePath).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            prefersEnglish ? 'Saved to $filePath' : '保存しました: $filePath',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            prefersEnglish ? 'Could not save PDF' : 'PDFを保存できませんでした',
          ),
        ),
      );
    }
  }

  Future<void> _share(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final invoiceNumber =
        ref.container
            .read(OrderInvoiceViewModel(orderId: widget.orderId))
            .valueOrNull
            ?.invoice
            .invoiceNumber ??
        'invoice';
    final safeName = invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final path = p.join(tempDir.path, '$safeName.pdf');
    await File(path).writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/pdf', name: '$safeName.pdf')],
      subject: invoiceNumber,
      text: 'Hanko Field • $invoiceNumber',
    );
  }

  void _contactSupport() {
    unawaited(
      ref.container
          .read(navigationControllerProvider)
          .push<Object?>(AppRoutePaths.supportContact),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({
    required this.invoice,
    required this.orderNumber,
    required this.currency,
    required this.total,
    required this.prefersEnglish,
  });

  final OrderInvoice invoice;
  final String orderNumber;
  final String currency;
  final int total;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    return Card.filled(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invoice.invoiceNumber,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: tokens.spacing.xs),
            Text(
              prefersEnglish ? 'Order $orderNumber' : '注文番号：$orderNumber',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (invoice.issuedAt != null) ...[
              SizedBox(height: tokens.spacing.sm),
              Text(
                prefersEnglish
                    ? 'Issued: ${_formatDate(invoice.issuedAt!)}'
                    : '発行日：${_formatDate(invoice.issuedAt!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
            SizedBox(height: tokens.spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  prefersEnglish ? 'Total' : '合計',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  _formatMoney(total, currency: currency),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.invoice, required this.prefersEnglish});

  final OrderInvoice invoice;
  final bool prefersEnglish;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (invoice.status) {
      OrderInvoiceStatus.available => prefersEnglish ? 'Available' : '利用可能',
      OrderInvoiceStatus.pending => prefersEnglish ? 'Pending' : '準備中',
    };

    final taxLabel = switch (invoice.taxStatus) {
      OrderInvoiceTaxStatus.taxable => prefersEnglish ? 'Taxable' : '課税',
      OrderInvoiceTaxStatus.taxExempt => prefersEnglish ? 'Tax exempt' : '非課税',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        InputChip(label: Text(statusLabel)),
        InputChip(label: Text(taxLabel)),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.tokens,
    required this.prefersEnglish,
    required this.controller,
    required this.bytes,
    required this.onRequestInvoice,
    required this.onRefresh,
    required this.status,
  });

  final DesignTokens tokens;
  final bool prefersEnglish;
  final PdfControllerPinch? controller;
  final Uint8List? bytes;
  final VoidCallback? onRequestInvoice;
  final VoidCallback onRefresh;
  final OrderInvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    prefersEnglish ? 'Preview' : 'プレビュー',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: prefersEnglish ? 'Refresh' : '更新',
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.md),
            if (bytes == null || controller == null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(tokens.spacing.lg),
                decoration: BoxDecoration(
                  color: tokens.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(tokens.radii.md),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: tokens.colors.onSurface.withValues(alpha: 0.7),
                      size: 44,
                    ),
                    SizedBox(height: tokens.spacing.sm),
                    Text(
                      status == OrderInvoiceStatus.pending
                          ? (prefersEnglish
                                ? 'Invoice is being prepared.'
                                : '領収書を準備しています。')
                          : (prefersEnglish
                                ? 'Invoice preview is not available.'
                                : '領収書を表示できません。'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SizedBox(height: tokens.spacing.md),
                    if (status == OrderInvoiceStatus.pending)
                      FilledButton(
                        onPressed: onRequestInvoice,
                        child: Text(
                          prefersEnglish ? 'Request invoice' : '領収書をリクエスト',
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radii.md),
                child: SizedBox(
                  height: 460,
                  child: PdfViewPinch(
                    controller: controller!,
                    builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                      options: const DefaultBuilderOptions(),
                      documentLoaderBuilder: (_) => const Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                      pageLoaderBuilder: (_) => const Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                      errorBuilder: (_, error) => Center(
                        child: Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _formatMoney(int amount, {required String currency}) {
  final digits = amount.abs().toString();
  final formatted = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  final prefix = currency.toUpperCase() == 'JPY' ? '¥' : '$currency ';
  final sign = amount < 0 ? '-' : '';
  return '$sign$prefix$formatted';
}
