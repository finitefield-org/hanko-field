import 'package:flutter/material.dart';

import '../../../app/localization/app_locale_view_model.dart';
import '../../../app/theme/hf_theme.dart';
import '../../../app/widgets/app_settings_button.dart';

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({
    super.key,
    required this.locale,
    required this.onSelectLocale,
    required this.onBackToTop,
    this.sessionId,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;
  final VoidCallback onBackToTop;
  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    final isEnglish = locale == AppLocale.en;
    final title = isEnglish ? 'Payment completed' : 'お支払いが完了しました';
    final description = isEnglish
        ? 'Thank you. We will start crafting after confirmation email.'
        : 'ご注文ありがとうございます。確認メールを送信後、順次製作を開始します。';
    final cardTitle = isEnglish ? 'Payment accepted' : '決済を受け付けました';
    final cardBody = isEnglish
        ? 'We will proceed with your hand-carved seal.'
        : '内容確認後、手彫り印鑑の製作に進みます。';
    final sessionLabel = isEnglish ? 'Session ID' : '決済セッションID';
    final backLabel = isEnglish ? 'Back to top' : 'トップへ戻る';

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
                          if (sessionId != null &&
                              sessionId!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('$sessionLabel: ${sessionId!.trim()}'),
                          ],
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
