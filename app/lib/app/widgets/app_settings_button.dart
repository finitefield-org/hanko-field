import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_locale_view_model.dart';
import '../theme/hf_theme.dart';

class AppSettingsButton extends StatelessWidget {
  const AppSettingsButton({
    super.key,
    required this.selectedLocale,
    required this.onSelectLocale,
  });

  final AppLocale selectedLocale;
  final ValueChanged<AppLocale> onSelectLocale;

  @override
  Widget build(BuildContext context) {
    final tooltip = selectedLocale == AppLocale.en ? 'Settings' : '設定';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HfPalette.line),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: () => _openSettingsSheet(context),
        icon: const Icon(Icons.settings_outlined, color: HfPalette.accent),
      ),
    );
  }

  void _openSettingsSheet(BuildContext context) {
    final isEnglish = selectedLocale == AppLocale.en;
    final title = isEnglish ? 'Settings' : '設定';
    final languageTitle = isEnglish ? 'Language' : '言語';
    final legalLabel = isEnglish ? 'Legal Notice' : '特定商取引法に基づく表記';
    final privacyLabel = isEnglish ? 'Privacy Policy' : 'プライバシーポリシー';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: HfPalette.bgPanel,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  languageTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: HfPalette.muted,
                  ),
                ),
                const SizedBox(height: 6),
                ...AppLocale.values.map((locale) {
                  final selected = locale == selectedLocale;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 0,
                    title: Text(locale.displayLabel),
                    trailing: selected
                        ? const Icon(Icons.check, color: HfPalette.accent)
                        : null,
                    onTap: () {
                      if (selected) {
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      onSelectLocale(locale);
                    },
                  );
                }),
                const Divider(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.receipt_long_outlined,
                    color: HfPalette.accent,
                  ),
                  title: Text(legalLabel),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openCommercialTransactions(context, selectedLocale);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: HfPalette.accent,
                  ),
                  title: Text(privacyLabel),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openPrivacyPolicy(context, selectedLocale);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCommercialTransactions(
    BuildContext context,
    AppLocale locale,
  ) async {
    final uri = Uri.parse(commercialTransactionsUrlForLocale(locale));
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      final message = locale == AppLocale.en
          ? 'Could not open the legal notice.'
          : '特定商取引法に基づく表記を開けませんでした。';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openPrivacyPolicy(
    BuildContext context,
    AppLocale locale,
  ) async {
    final uri = Uri.parse(privacyPolicyUrlForLocale(locale));
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      final message = locale == AppLocale.en
          ? 'Could not open privacy policy.'
          : 'プライバシーポリシーを開けませんでした。';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
