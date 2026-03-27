import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/localization/app_locale_view_model.dart';
import '../../../app/theme/hf_theme.dart';
import '../../../app/widgets/app_settings_button.dart';

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({
    super.key,
    required this.locale,
    required this.onSelectLocale,
    required this.onBackToTop,
    this.orderId,
    this.sessionId,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;
  final VoidCallback onBackToTop;
  final String? orderId;
  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    final isEnglish = locale == AppLocale.en;
    final title = isEnglish ? 'Payment completed' : 'お支払いが完了しました';
    final description = isEnglish
        ? 'Thank you for your order. We will start production after the confirmation email is sent.'
        : 'ご注文ありがとうございます。確認メールを送信後、順次製作を開始します。';
    final cardTitle = isEnglish ? 'Payment accepted' : '決済を受け付けました';
    final cardBody = isEnglish
        ? 'We will proceed with crafting your hand-carved seal after a review of the order details.'
        : '内容確認後、手彫り印鑑の製作に進みます。';
    final orderLabel = isEnglish ? 'Order ID' : '注文ID';
    final sessionLabel = isEnglish ? 'Session ID' : '決済セッションID';
    final nextStepsTitle = isEnglish ? 'Next steps' : '次のアクション';
    final nextStep1 = isEnglish
        ? 'Check your confirmation email.'
        : '確認メールをご確認ください。';
    final nextStep2 = isEnglish
        ? 'Keep your order ID for support.'
        : '注文IDは問い合わせ時にお伝えください。';
    final nextStep3 = isEnglish
        ? 'If the email does not arrive, contact us.'
        : 'メールが届かない場合はお問い合わせください。';
    final backLabel = isEnglish ? 'Back to top' : 'トップへ戻る';
    final contactLabel = isEnglish ? 'Contact us' : 'お問い合わせ';
    final contactUrl = inquiryUrlForLocale(locale);
    final normalizedOrderId = orderId?.trim() ?? '';
    final normalizedSessionId = sessionId?.trim() ?? '';

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
                              color: HfPalette.accent2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(cardBody),
                          if (normalizedOrderId.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SelectableText('$orderLabel: $normalizedOrderId'),
                          ],
                          if (normalizedSessionId.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            SelectableText(
                              '$sessionLabel: $normalizedSessionId',
                            ),
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
                              color: HfPalette.accent2,
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
