import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/fonts/app_fonts.dart';
import '../../../app/localization/app_locale_view_model.dart';
import '../../../app/widgets/app_site_chrome.dart';
import '../../order/domain/order_models.dart';

const _legalPageInk = Color(0xFF1B1C1A);
const _legalPageMuted = Color(0xFF6A645D);
const _legalPageAccent = Color(0xFF851217);
const _legalPageLine = Color(0xFFD8CCBC);
const _legalPageDivider = Color(0x1A8C716E);
const _legalPageNotes = Color(0xFFF5F3F0);

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({
    super.key,
    required this.locale,
    required this.onSelectLocale,
    required this.onBackToTop,
    required this.onOpenLegalNotice,
    required this.onOpenTerms,
    this.orderId,
    this.sessionId,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;
  final VoidCallback onBackToTop;
  final VoidCallback onOpenLegalNotice;
  final VoidCallback onOpenTerms;
  final String? orderId;
  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    final normalizedOrderId = orderId?.trim() ?? '';
    final normalizedSessionId = sessionId?.trim() ?? '';
    final hasOrderId = normalizedOrderId.isNotEmpty;
    final hasSessionId = normalizedSessionId.isNotEmpty;
    final contactUrl = inquiryUrlForLocale(locale);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            AppSiteHeader(
              locale: locale,
              onSelectLocale: onSelectLocale,
              onBrandTap: onBackToTop,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1152),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final isCompact = width < 640;
                            final horizontalPadding = isCompact ? 16.0 : 24.0;
                            final topPadding = isCompact ? 100.0 : 112.0;
                            final bottomPadding = isCompact ? 48.0 : 64.0;
                            final titleSize =
                                (isCompact ? width * 0.09 : width * 0.04)
                                    .clamp(
                                      isCompact ? 28.0 : 32.0,
                                      isCompact ? 40.0 : 52.0,
                                    )
                                    .toDouble();
                            final sectionTitleSize = (width * 0.02)
                                .clamp(17.0, 23.0)
                                .toDouble();
                            final sectionGap = isCompact ? 48.0 : 64.0;

                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                horizontalPadding,
                                topPadding,
                                horizontalPadding,
                                bottomPadding,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizedUiText(
                                      locale.code,
                                      ja: 'お支払いが完了しました',
                                      en: 'Payment completed',
                                    ),
                                    style: AppFonts.notoSerifJp(
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                      letterSpacing: 0.02,
                                      color: _legalPageInk,
                                    ),
                                  ),
                                  SizedBox(height: isCompact ? 32 : 48),
                                  _PaymentSection(
                                    index: '01',
                                    title: localizedUiText(
                                      locale.code,
                                      ja: '決済完了',
                                      en: 'Payment confirmed',
                                    ),
                                    titleSize: sectionTitleSize,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          localizedUiText(
                                            locale.code,
                                            ja: 'ご注文ありがとうございます。確認メール送信後、順次製作を開始します。',
                                            en: 'Thank you for your order. We will start production after the confirmation email is sent.',
                                          ),
                                          style: AppFonts.manrope(
                                            fontSize: 15,
                                            height: 1.8,
                                            color: _legalPageInk,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        _PaymentNoteGrid(
                                          isCompact: isCompact,
                                          notes: [
                                            (
                                              label: localizedUiText(
                                                locale.code,
                                                ja: '状態',
                                                en: 'Status',
                                              ),
                                              text: localizedUiText(
                                                locale.code,
                                                ja: '決済を受け付けました',
                                                en: 'Payment received',
                                              ),
                                            ),
                                            (
                                              label: localizedUiText(
                                                locale.code,
                                                ja: '製作開始',
                                                en: 'Production',
                                              ),
                                              text: localizedUiText(
                                                locale.code,
                                                ja: '確認メール送信後に製作を開始します。',
                                                en: 'We will begin production after the confirmation email is sent.',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: sectionGap),
                                  _PaymentSection(
                                    index: '02',
                                    title: localizedUiText(
                                      locale.code,
                                      ja: '注文情報',
                                      en: 'Order information',
                                    ),
                                    titleSize: sectionTitleSize,
                                    child: hasOrderId || hasSessionId
                                        ? _PaymentDefinitionList(
                                            isCompact: isCompact,
                                            rows: [
                                              if (hasOrderId)
                                                (
                                                  label: localizedUiText(
                                                    locale.code,
                                                    ja: '注文ID',
                                                    en: 'Order ID',
                                                  ),
                                                  value: normalizedOrderId,
                                                ),
                                              if (hasSessionId)
                                                (
                                                  label: localizedUiText(
                                                    locale.code,
                                                    ja: '決済セッションID',
                                                    en: 'Session ID',
                                                  ),
                                                  value: normalizedSessionId,
                                                ),
                                            ],
                                          )
                                        : Text(
                                            localizedUiText(
                                              locale.code,
                                              ja: '確認メールをご確認ください。',
                                              en: 'Please check your confirmation email.',
                                            ),
                                            style: AppFonts.manrope(
                                              fontSize: 15,
                                              height: 1.8,
                                              color: _legalPageInk,
                                            ),
                                          ),
                                  ),
                                  SizedBox(height: sectionGap),
                                  _PaymentSection(
                                    index: '03',
                                    title: localizedUiText(
                                      locale.code,
                                      ja: '次のステップ',
                                      en: 'Next steps',
                                    ),
                                    titleSize: sectionTitleSize,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          localizedUiText(
                                            locale.code,
                                            ja: 'ご不明点はお問い合わせフォームからご連絡ください。',
                                            en: 'If you have any questions, please contact us through the inquiry form.',
                                          ),
                                          style: AppFonts.manrope(
                                            fontSize: 15,
                                            height: 1.8,
                                            color: _legalPageInk,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _PaymentBulletList(
                                          items: [
                                            localizedUiText(
                                              locale.code,
                                              ja: '確認メールをご確認ください。',
                                              en: 'Check your confirmation email.',
                                            ),
                                            localizedUiText(
                                              locale.code,
                                              ja: '注文IDは問い合わせ時にお伝えください。',
                                              en: 'Keep your order ID for support.',
                                            ),
                                            localizedUiText(
                                              locale.code,
                                              ja: 'メールが届かない場合はお問い合わせください。',
                                              en: 'If the email does not arrive, contact us.',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Wrap(
                                          spacing: 16,
                                          runSpacing: 16,
                                          children: [
                                            _LegalActionButton(
                                              label: localizedUiText(
                                                locale.code,
                                                ja: 'トップへ戻る',
                                                en: 'Back to TOP',
                                              ),
                                              backgroundColor: _legalPageAccent,
                                              borderColor: _legalPageAccent,
                                              foregroundColor: Colors.white,
                                              onTap: onBackToTop,
                                            ),
                                            _LegalActionButton(
                                              label: localizedUiText(
                                                locale.code,
                                                ja: 'お問い合わせ',
                                                en: 'Contact us',
                                              ),
                                              backgroundColor: Colors.white,
                                              borderColor: _legalPageLine,
                                              foregroundColor: _legalPageInk,
                                              onTap: () => _openInquiryUrl(
                                                context,
                                                locale,
                                                contactUrl,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 56),
                    AppSiteFooter(
                      locale: locale,
                      onOpenLegalNotice: onOpenLegalNotice,
                      onOpenTerms: onOpenTerms,
                      onBrandTap: onBackToTop,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.index,
    required this.title,
    required this.titleSize,
    required this.child,
  });

  final String index;
  final String title;
  final double titleSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              index,
              style: AppFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.8,
                color: _legalPageAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppFonts.notoSerifJp(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: _legalPageInk,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class _PaymentNoteGrid extends StatelessWidget {
  const _PaymentNoteGrid({required this.isCompact, required this.notes});

  final bool isCompact;
  final List<({String label, String text})> notes;

  @override
  Widget build(BuildContext context) {
    final noteWidgets = notes
        .map((note) => _PaymentNote(label: note.label, text: note.text))
        .toList(growable: false);

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [noteWidgets[0], const SizedBox(height: 24), noteWidgets[1]],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: noteWidgets[0]),
        const SizedBox(width: 24),
        Expanded(child: noteWidgets[1]),
      ],
    );
  }
}

class _PaymentNote extends StatelessWidget {
  const _PaymentNote({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _legalPageNotes,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: _legalPageMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppFonts.manrope(
              fontSize: 15,
              height: 1.7,
              color: _legalPageInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDefinitionList extends StatelessWidget {
  const _PaymentDefinitionList({required this.isCompact, required this.rows});

  final bool isCompact;
  final List<({String label, String value})> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _legalPageDivider),
          bottom: BorderSide(color: _legalPageDivider),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _PaymentDefinitionRow(
              isCompact: isCompact,
              label: rows[index].label,
              value: rows[index].value,
            ),
            if (index != rows.length - 1)
              const Divider(height: 1, color: _legalPageDivider),
          ],
        ],
      ),
    );
  }
}

class _PaymentDefinitionRow extends StatelessWidget {
  const _PaymentDefinitionRow({
    required this.isCompact,
    required this.label,
    required this.value,
  });

  final bool isCompact;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: AppFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _legalPageMuted,
      ),
    );
    final valueWidget = Text(
      value,
      style: AppFonts.manrope(fontSize: 15, height: 1.7, color: _legalPageInk),
    );

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [labelWidget, const SizedBox(height: 7), valueWidget],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 176, child: labelWidget),
          const SizedBox(width: 12),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}

class _PaymentBulletList extends StatelessWidget {
  const _PaymentBulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _PaymentBulletItem(text: items[index]),
          if (index != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _PaymentBulletItem extends StatelessWidget {
  const _PaymentBulletItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: _legalPageInk,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppFonts.manrope(
              fontSize: 15,
              height: 1.7,
              color: _legalPageInk,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalActionButton extends StatelessWidget {
  const _LegalActionButton({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: Text(
              label,
              style: AppFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.1,
                color: foregroundColor,
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
