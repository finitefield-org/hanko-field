import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'hanko_surface_card.dart';

class HankoEmailSentNotice extends StatelessWidget {
  const HankoEmailSentNotice({
    super.key,
    required this.title,
    required this.message,
    required this.orderNoLabel,
    required this.emailLabel,
    this.orderNo,
    this.email,
  });

  final String title;
  final String message;
  final String orderNoLabel;
  final String emailLabel;
  final String? orderNo;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final detailRows = <Widget>[
      if (_hasText(orderNo))
        _EmailNoticeDetailRow(
          icon: Icons.inventory_2_outlined,
          label: orderNoLabel,
          value: orderNo!.trim(),
        ),
      if (_hasText(email))
        _EmailNoticeDetailRow(
          icon: Icons.mail_outline,
          label: emailLabel,
          value: email!.trim(),
        ),
    ];

    return HankoSurfaceCard(
      radius: HankoRadii.sm,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _EmailNoticeIcon(),
              const SizedBox(width: HankoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: HankoTextStyles.cardTitle),
                    const SizedBox(height: HankoSpacing.xs),
                    Text(message, style: HankoTextStyles.body),
                  ],
                ),
              ),
            ],
          ),
          if (detailRows.isNotEmpty) ...[
            const SizedBox(height: HankoSpacing.md),
            const Divider(height: 1, color: HankoColors.surfaceBorder),
            const SizedBox(height: HankoSpacing.md),
            ...detailRows,
          ],
        ],
      ),
    );
  }
}

class _EmailNoticeIcon extends StatelessWidget {
  const _EmailNoticeIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HankoColors.medallion,
        borderRadius: BorderRadius.circular(HankoRadii.sm),
        border: Border.all(color: HankoColors.surfaceBorder),
      ),
      child: const Icon(
        Icons.mark_email_read_outlined,
        color: HankoColors.gold,
      ),
    );
  }
}

class _EmailNoticeDetailRow extends StatelessWidget {
  const _EmailNoticeDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HankoSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: HankoColors.gold, size: 22),
          const SizedBox(width: HankoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: HankoTextStyles.compactBody.copyWith(
                    color: HankoColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(value, style: HankoTextStyles.label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
