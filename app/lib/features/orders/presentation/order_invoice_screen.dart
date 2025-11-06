import 'dart:io';
import 'dart:typed_data';

import 'package:app/core/domain/entities/order.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_button.dart';
import 'package:app/core/ui/widgets/app_card.dart';
import 'package:app/core/ui/widgets/app_empty_state.dart';
import 'package:app/core/ui/widgets/app_skeleton.dart';
import 'package:app/features/orders/application/order_details_provider.dart';
import 'package:app/features/orders/application/order_invoice_provider.dart';
import 'package:app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderInvoiceScreen extends ConsumerStatefulWidget {
  const OrderInvoiceScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<OrderInvoiceScreen> createState() => _OrderInvoiceScreenState();
}

class _OrderInvoiceScreenState extends ConsumerState<OrderInvoiceScreen> {
  bool _isDownloading = false;
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orderAsync = ref.watch(orderDetailsProvider(widget.orderId));
    final invoiceAsync = ref.watch(orderInvoiceProvider(widget.orderId));
    final orderNumber = orderAsync.maybeWhen(
      data: (order) => order.orderNumber,
      orElse: () => widget.orderId,
    );

    final invoice = invoiceAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.orderInvoiceAppBarTitle(orderNumber)),
        actions: [
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined),
            tooltip: l10n.orderInvoiceShareTooltip,
            onPressed: invoice == null || !invoice.isDownloadReady || _isSharing
                ? null
                : () => _handleShare(context, invoice, l10n),
          ),
        ],
      ),
      body: RefreshIndicator(
        displacement: 72,
        onRefresh: _refreshInvoice,
        child: invoiceAsync.when(
          data: (value) =>
              _buildContent(context, value, orderAsync.asData?.value, l10n),
          loading: () => const _InvoiceLoadingView(),
          error: (error, stackTrace) => _InvoiceErrorView(
            message: l10n.orderInvoiceLoadError,
            onRetry: () {
              ref.invalidate(orderInvoiceProvider(widget.orderId));
            },
            retryLabel: l10n.orderInvoiceRetryLabel,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    OrderInvoice invoice,
    Order? order,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final headlineStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final amountText = _formatCurrency(
      context,
      invoice.amount,
      invoice.currency,
    );
    final taxChipLabel = _taxChipLabel(l10n, invoice);
    final statusChipLabel = _statusChipLabel(l10n, invoice.status);

    final dueDateText = invoice.dueDate == null
        ? l10n.orderInvoiceValueNotAvailable
        : DateFormat.yMMMd(l10n.localeName).format(invoice.dueDate!);
    final issuedText = DateFormat.yMMMd(
      l10n.localeName,
    ).format(invoice.createdAt);

    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (!invoice.isDownloadReady)
          _InvoicePendingBanner(
            onRefresh: _refreshInvoice,
            message: l10n.orderInvoicePendingMessage,
            actionLabel: l10n.orderInvoicePendingRefresh,
          ),
        if (!invoice.isDownloadReady) const SizedBox(height: AppTokens.spaceL),
        Text(
          l10n.orderInvoiceHeadline(order?.orderNumber ?? widget.orderId),
          style: headlineStyle,
        ),
        const SizedBox(height: AppTokens.spaceS),
        Text(
          l10n.orderInvoiceSubHeadline(amountText),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTokens.spaceM),
        Wrap(
          spacing: AppTokens.spaceS,
          runSpacing: AppTokens.spaceS,
          children: [
            _InfoChip(icon: Icons.description_outlined, label: statusChipLabel),
            _InfoChip(icon: Icons.receipt_long_outlined, label: taxChipLabel),
          ],
        ),
        const SizedBox(height: AppTokens.spaceL),
        _InvoicePreviewCard(
          invoice: invoice,
          onOpen: invoice.isDownloadReady
              ? () => _openPreview(invoice, l10n)
              : null,
        ),
        const SizedBox(height: AppTokens.spaceL),
        AppCard(
          variant: AppCardVariant.outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.orderInvoiceDetailsTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTokens.spaceM),
              _SummaryRow(
                label: l10n.orderInvoiceDetailsNumber,
                value: invoice.invoiceNumber,
              ),
              const SizedBox(height: AppTokens.spaceS),
              _SummaryRow(
                label: l10n.orderInvoiceDetailsIssuedOn,
                value: issuedText,
              ),
              const SizedBox(height: AppTokens.spaceS),
              _SummaryRow(
                label: l10n.orderInvoiceDetailsDueDate,
                value: dueDateText,
              ),
              const SizedBox(height: AppTokens.spaceS),
              _SummaryRow(
                label: l10n.orderInvoiceDetailsTotal,
                value: amountText,
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceL),
        if (invoice.lineItems.isNotEmpty)
          AppCard(
            variant: AppCardVariant.outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.orderInvoiceLineItemsTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceM),
                for (final (index, item) in invoice.lineItems.indexed) ...[
                  if (index > 0) const Divider(height: AppTokens.spaceL),
                  _LineItemRow(
                    label: item.description,
                    value: _formatCurrency(
                      context,
                      item.amount,
                      invoice.currency,
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppTokens.spaceXL),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: l10n.orderInvoiceDownloadAction,
                loading: _isDownloading,
                onPressed: invoice.isDownloadReady && !_isDownloading
                    ? () => _handleDownload(context, invoice, l10n)
                    : null,
                leadingIcon: const Icon(Icons.download_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceS),
        Align(
          alignment: Alignment.center,
          child: AppButton(
            label: l10n.orderInvoiceEmailAction,
            variant: AppButtonVariant.ghost,
            onPressed: () => _handleEmailRequest(context, l10n),
            leadingIcon: const Icon(Icons.alternate_email_outlined),
          ),
        ),
        const SizedBox(height: AppTokens.spaceXL),
      ],
    );
  }

  Future<void> _handleDownload(
    BuildContext context,
    OrderInvoice invoice,
    AppLocalizations l10n,
  ) async {
    if (!invoice.isDownloadReady || _isDownloading) {
      return;
    }
    setState(() {
      _isDownloading = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _fetchInvoiceBytes(invoice);
      final directory = await getApplicationDocumentsDirectory();
      final fileName = _fileNameFor(invoice);
      final path = '${directory.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orderInvoiceDownloadSuccess(path))),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orderInvoiceDownloadError)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _handleShare(
    BuildContext context,
    OrderInvoice invoice,
    AppLocalizations l10n,
  ) async {
    if (!invoice.isDownloadReady || _isSharing) {
      return;
    }
    setState(() {
      _isSharing = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _fetchInvoiceBytes(invoice);
      final fileName = _fileNameFor(invoice);
      final subject = l10n.orderInvoiceShareSubject(invoice.invoiceNumber);
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf')],
        subject: subject,
        text: l10n.orderInvoiceShareBody(invoice.invoiceNumber),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orderInvoiceShareError)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Future<void> _openPreview(OrderInvoice invoice, AppLocalizations l10n) async {
    if (!invoice.isDownloadReady) {
      return;
    }
    final url = Uri.tryParse(invoice.downloadUrl!);
    if (url == null) {
      return;
    }
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.orderInvoicePreviewError)),
      );
    }
  }

  Future<void> _handleEmailRequest(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.orderInvoiceEmailPlaceholder)),
    );
  }

  Future<void> _refreshInvoice() async {
    await Future.wait([
      ref.refresh(orderInvoiceProvider(widget.orderId).future),
      ref.refresh(orderDetailsProvider(widget.orderId).future),
    ]);
  }

  Future<Uint8List> _fetchInvoiceBytes(OrderInvoice invoice) async {
    if (invoice.downloadUrl == null) {
      throw StateError('Missing download URL for invoice ${invoice.id}');
    }
    final response = await http.get(Uri.parse(invoice.downloadUrl!));
    if (response.statusCode != 200) {
      throw HttpException(
        'Invoice download failed with status ${response.statusCode}',
      );
    }
    return response.bodyBytes;
  }

  String _fileNameFor(OrderInvoice invoice) {
    final base = invoice.invoiceNumber.isEmpty
        ? invoice.orderId
        : invoice.invoiceNumber;
    final sanitized = base.replaceAll(RegExp(r'[^\w\-]+'), '_');
    return '$sanitized.pdf';
  }

  String _statusChipLabel(AppLocalizations l10n, OrderInvoiceStatus status) {
    return switch (status) {
      OrderInvoiceStatus.draft => l10n.orderInvoiceStatusDraft,
      OrderInvoiceStatus.issued => l10n.orderInvoiceStatusIssued,
      OrderInvoiceStatus.sent => l10n.orderInvoiceStatusSent,
      OrderInvoiceStatus.paid => l10n.orderInvoiceStatusPaid,
      OrderInvoiceStatus.voided => l10n.orderInvoiceStatusVoided,
    };
  }

  String _taxChipLabel(AppLocalizations l10n, OrderInvoice invoice) {
    final override = invoice.metadata?['taxLabel'];
    if (override is String && override.trim().isNotEmpty) {
      return override;
    }
    return switch (invoice.taxStatus) {
      OrderInvoiceTaxStatus.inclusive => l10n.orderInvoiceTaxStatusInclusive,
      OrderInvoiceTaxStatus.exclusive => l10n.orderInvoiceTaxStatusExclusive,
      OrderInvoiceTaxStatus.exempt => l10n.orderInvoiceTaxStatusExempt,
    };
  }

  String _formatCurrency(BuildContext context, num amount, String currency) {
    final locale = Localizations.localeOf(context);
    final isJpy = currency == 'JPY';
    final symbol = isJpy
        ? '¥'
        : NumberFormat.simpleCurrency(name: currency).currencySymbol;
    final formatter = NumberFormat.currency(
      locale: locale.toLanguageTag(),
      symbol: symbol,
      decimalDigits: isJpy ? 0 : 2,
    );
    return formatter.format(amount);
  }
}

class _InvoicePreviewCard extends StatelessWidget {
  const _InvoicePreviewCard({required this.invoice, this.onOpen});

  final OrderInvoice invoice;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppTokens.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: AppTokens.radiusL,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: invoice.isDownloadReady
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 48),
                        const SizedBox(height: AppTokens.spaceS),
                        Text(
                          invoice.invoiceNumber,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppTokens.spaceXS),
                        Text(
                          l10n.orderInvoicePreviewLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.hourglass_bottom_outlined, size: 48),
                        const SizedBox(height: AppTokens.spaceS),
                        Text(
                          l10n.orderInvoicePreviewPending,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTokens.spaceXS),
                        Text(
                          l10n.orderInvoicePreviewPendingHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ),
          if (onOpen != null) ...[
            const SizedBox(height: AppTokens.spaceM),
            AppButton(
              label: l10n.orderInvoicePreviewOpen,
              variant: AppButtonVariant.secondary,
              onPressed: onOpen,
              leadingIcon: const Icon(Icons.open_in_new_outlined),
            ),
          ],
        ],
      ),
    );
  }
}

class _InvoicePendingBanner extends StatelessWidget {
  const _InvoicePendingBanner({
    required this.onRefresh,
    required this.message,
    required this.actionLabel,
  });

  final Future<void> Function() onRefresh;
  final String message;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      variant: AppCardVariant.filled,
      backgroundColor: scheme.surfaceContainerHighest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.autorenew, size: 24),
          const SizedBox(width: AppTokens.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppTokens.spaceS),
                TextButton(onPressed: onRefresh, child: Text(actionLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppTokens.spaceM),
        Text(
          value,
          style: emphasize
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )
              : theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        const SizedBox(width: AppTokens.spaceM),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceM,
        vertical: AppTokens.spaceXS,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppTokens.radiusL,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: AppTokens.spaceXS),
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}

class _InvoiceLoadingView extends StatelessWidget {
  const _InvoiceLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceL),
      children: const [
        AppSkeletonBlock(height: 28, width: 200),
        SizedBox(height: AppTokens.spaceS),
        AppSkeletonBlock(height: 16, width: 280),
        SizedBox(height: AppTokens.spaceL),
        AppSkeletonBlock(height: 220),
        SizedBox(height: AppTokens.spaceL),
        AppSkeletonBlock(height: 180),
        SizedBox(height: AppTokens.spaceL),
        AppSkeletonBlock(height: 180),
      ],
    );
  }
}

class _InvoiceErrorView extends StatelessWidget {
  const _InvoiceErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: AppTokens.spaceXXL),
        AppEmptyState(
          title: AppLocalizations.of(context).orderInvoiceErrorTitle,
          message: message,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          primaryAction: AppButton(
            label: retryLabel,
            variant: AppButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}
