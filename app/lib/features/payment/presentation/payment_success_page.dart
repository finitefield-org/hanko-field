import 'package:flutter/material.dart';

import '../../../app/theme/hf_theme.dart';

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({
    super.key,
    required this.onBackToTop,
    this.sessionId,
  });

  final VoidCallback onBackToTop;
  final String? sessionId;

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'Stone Signature',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      color: HfPalette.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'お支払いが完了しました',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ご注文ありがとうございます。確認メールを送信後、順次製作を開始します。',
                    style: TextStyle(color: HfPalette.muted),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '決済を受け付けました',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: HfPalette.accent2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('内容確認後、手彫り印鑑の製作に進みます。'),
                          if (sessionId != null &&
                              sessionId!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('決済セッションID: ${sessionId!.trim()}'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: onBackToTop,
                    child: const Text('トップへ戻る'),
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
