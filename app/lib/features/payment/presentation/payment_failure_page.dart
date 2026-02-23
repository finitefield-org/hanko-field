import 'package:flutter/material.dart';

import '../../../app/theme/hf_theme.dart';

class PaymentFailurePage extends StatelessWidget {
  const PaymentFailurePage({super.key, required this.onBackToTop});

  final VoidCallback onBackToTop;

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
                    'お支払いが完了しませんでした',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'カード情報の確認や通信状態をご確認のうえ、再度お試しください。',
                    style: TextStyle(color: HfPalette.muted),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '決済を完了できませんでした',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8F2219),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text('注文内容は保存されています。準備ができたら購入画面から再度お手続きください。'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: onBackToTop,
                    child: const Text('購入画面に戻る'),
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
