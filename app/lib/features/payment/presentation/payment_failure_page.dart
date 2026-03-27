import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/localization/app_locale_view_model.dart';
import '../../../app/theme/hf_theme.dart';
import '../../../app/widgets/app_settings_button.dart';

class PaymentFailurePage extends StatelessWidget {
  const PaymentFailurePage({
    super.key,
    required this.locale,
    required this.onSelectLocale,
    required this.onBackToTop,
    this.orderId,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;
  final VoidCallback onBackToTop;
  final String? orderId;

  @override
  Widget build(BuildContext context) {
    final isEnglish = locale == AppLocale.en;
    final title = isEnglish ? 'Payment was not completed' : 'お支払いが完了しませんでした';
    final description = isEnglish
        ? 'Please check your card details and connection, then try again.'
        : 'カード情報の確認や通信状態をご確認のうえ、再度お試しください。';
    final cardTitle = isEnglish
        ? 'Unable to complete payment'
        : '決済を完了できませんでした';
    final cardBody = isEnglish
        ? 'Your order details are saved. Please try again from the purchase screen.'
        : '注文内容は保存されています。準備ができたら購入画面から再度お手続きください。';
    final orderLabel = isEnglish ? 'Order ID' : '注文ID';
    final nextStepsTitle = isEnglish ? 'Next steps' : '次のアクション';
    final nextStep1 = isEnglish
        ? 'Check your card details and network connection.'
        : 'カード情報と通信状態をご確認ください。';
    final nextStep2 = isEnglish
        ? 'Return to the purchase page and try again.'
        : '購入画面へ戻って、もう一度お試しください。';
    final nextStep3 = isEnglish
        ? 'If the issue repeats, contact us.'
        : '同じエラーが続く場合はお問い合わせください。';
    final backLabel = isEnglish ? 'Back to purchase' : '購入画面に戻る';
    final contactLabel = isEnglish ? 'Contact us' : 'お問い合わせ';
    final contactUrl = inquiryUrlForLocale(locale);
    final normalizedOrderId = orderId?.trim() ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          'Stone Signature',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.2,
                            color: HfPalette.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      AppSettingsButton(
                        selectedLocale: locale,
                        onSelectLocale: onSelectLocale,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(color: HfPalette.muted),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cardTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8F2219),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(cardBody),
                          if (normalizedOrderId.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SelectableText('$orderLabel: $normalizedOrderId'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nextStepsTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8F2219),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(nextStep1),
                          const SizedBox(height: 4),
                          Text(nextStep2),
                          const SizedBox(height: 4),
                          Text(nextStep3),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton(
                                onPressed: onBackToTop,
                                child: Text(backLabel),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _openInquiryUrl(
                                  context,
                                  locale,
                                  contactUrl,
                                ),
                                icon: const Icon(Icons.open_in_new),
                                label: Text(contactLabel),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openInquiryUrl(
  BuildContext context,
  AppLocale locale,
  String url,
) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_inquiryOpenFailedText(locale))));
    return;
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_inquiryOpenFailedText(locale))));
  }
}

String _inquiryOpenFailedText(AppLocale locale) {
  final isEnglish = locale == AppLocale.en;
  return isEnglish ? 'Could not open the contact page.' : 'お問い合わせページを開けませんでした。';
}
