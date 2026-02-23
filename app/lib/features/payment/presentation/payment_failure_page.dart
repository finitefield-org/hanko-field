import 'package:flutter/material.dart';

import '../../../app/localization/app_locale_view_model.dart';
import '../../../app/theme/hf_theme.dart';
import '../../../app/widgets/app_settings_button.dart';

class PaymentFailurePage extends StatelessWidget {
  const PaymentFailurePage({
    super.key,
    required this.locale,
    required this.onSelectLocale,
    required this.onBackToTop,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;
  final VoidCallback onBackToTop;

  @override
  Widget build(BuildContext context) {
    final isEnglish = locale == AppLocale.en;
    final title = isEnglish ? 'Payment was not completed' : 'お支払いが完了しませんでした';
    final description = isEnglish
        ? 'Please check card details and network, then try again.'
        : 'カード情報の確認や通信状態をご確認のうえ、再度お試しください。';
    final cardTitle = isEnglish
        ? 'Unable to complete payment'
        : '決済を完了できませんでした';
    final cardBody = isEnglish
        ? 'Your order details are saved. Please try again from the purchase screen.'
        : '注文内容は保存されています。準備ができたら購入画面から再度お手続きください。';
    final backLabel = isEnglish ? 'Back to purchase' : '購入画面に戻る';

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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: onBackToTop, child: Text(backLabel)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
