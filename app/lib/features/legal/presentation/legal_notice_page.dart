import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/fonts/app_fonts.dart';
import '../../../app/localization/app_locale_view_model.dart';
import '../../order/domain/order_models.dart';
import 'legal_page_shell.dart';

const _legalNoticeInk = Color(0xFF1B1C1A);
const _legalNoticeAccent = Color(0xFF851217);

class LegalNoticePage extends StatelessWidget {
  const LegalNoticePage({
    super.key,
    required this.locale,
    required this.onSelectLocale,
    required this.onBack,
    required this.onOpenLegalNotice,
    required this.onOpenTerms,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;
  final VoidCallback onBack;
  final VoidCallback onOpenLegalNotice;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    return LegalPageScaffold(
      locale: locale,
      onSelectLocale: onSelectLocale,
      onBack: onBack,
      onOpenLegalNotice: onOpenLegalNotice,
      onOpenTerms: onOpenTerms,
      title: localizedUiText(
        locale.code,
        ja: '特定商取引法に基づく表記',
        en: 'Specified Commercial Transactions Act',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LegalSection(
            index: '01',
            title: localizedUiText(
              locale.code,
              ja: '販売業者・運営者情報',
              en: 'Seller and operator information',
            ),
            child: LegalDefinitionList(
              rows: [
                LegalDefinitionRowData(
                  term: localizedUiText(locale.code, ja: '販売業者', en: 'Seller'),
                  description: Text(
                    localizedUiText(
                      locale.code,
                      ja: '株式会社ファイナイトフィールド',
                      en: 'Finite Field, K.K.',
                    ),
                  ),
                ),
                LegalDefinitionRowData(
                  term: localizedUiText(
                    locale.code,
                    ja: '運営統括責任者',
                    en: 'Operations manager',
                  ),
                  description: Text(
                    localizedUiText(
                      locale.code,
                      ja: '代表取締役 一好 俊也',
                      en: 'Toshiya Kazuyoshi, Representative Director',
                    ),
                  ),
                ),
                LegalDefinitionRowData(
                  term: localizedUiText(locale.code, ja: '所在地', en: 'Address'),
                  description: Text(
                    localizedUiText(
                      locale.code,
                      ja: '〒879-0151 大分県宇佐市大字宮熊550番地',
                      en: '550 Oaza Miyaguma, Usa City, Oita 879-0151, Japan',
                    ),
                  ),
                ),
                LegalDefinitionRowData(
                  term: localizedUiText(locale.code, ja: '電話番号', en: 'Phone'),
                  description: Text(
                    localizedUiText(
                      locale.code,
                      ja: '050-3033-2975',
                      en: '+81-50-3033-2975',
                    ),
                  ),
                ),
                LegalDefinitionRowData(
                  term: localizedUiText(
                    locale.code,
                    ja: '受付時間',
                    en: 'Business hours',
                  ),
                  description: Text(
                    localizedUiText(
                      locale.code,
                      ja: '平日 10:00〜17:00（土日祝日を除く）',
                      en: 'Weekdays 10:00-17:00 (excluding weekends and public holidays)',
                    ),
                  ),
                ),
                LegalDefinitionRowData(
                  term: localizedUiText(
                    locale.code,
                    ja: 'メールアドレス',
                    en: 'Email',
                  ),
                  description: Text(
                    'dev@finitefield.org',
                    style:
                        AppFonts.manrope(
                          fontSize: 15,
                          height: 1.8,
                          color: _legalNoticeAccent,
                        ).copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: _legalNoticeAccent,
                        ),
                  ),
                ),
                LegalDefinitionRowData(
                  term: localizedUiText(
                    locale.code,
                    ja: 'サイトURL',
                    en: 'Website URL',
                  ),
                  description: Text(
                    'https://inkanfield.org',
                    style:
                        AppFonts.manrope(
                          fontSize: 15,
                          height: 1.8,
                          color: _legalNoticeAccent,
                        ).copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: _legalNoticeAccent,
                        ),
                  ),
                ),
              ],
            ),
          ),
          LegalSection(
            index: '02',
            title: localizedUiText(locale.code, ja: '販売条件', en: 'Sales terms'),
            child: LegalDefinitionList(
              rows: [
                LegalDefinitionRowData(
                  term: localizedUiText(locale.code, ja: '販売価格', en: 'Price'),
                  description: Text(
                    localizedUiText(
                      locale.code,
                      ja: '各商品ページに表示（消費税込み）',
                      en: 'Displayed on each product page (tax included)',
                    ),
                  ),
                ),
                LegalDefinitionRowData(
                  term: localizedUiText(
                    locale.code,
                    ja: '商品代金以外の必要料金',
                    en: 'Additional charges',
                  ),
                  description: Text(
                    localizedUiText(
                      locale.code,
                      ja: '送料（地域別）に加え、配送先や通関状況により関税・輸入消費税・通関手数料等が発生する場合があります。',
                      en: 'Shipping varies by destination. Depending on the destination and customs clearance status, customs duties, import consumption tax, brokerage fees, and similar charges may apply.',
                    ),
                  ),
                ),
                LegalDefinitionRowData(
                  term: localizedUiText(
                    locale.code,
                    ja: 'お支払い方法',
                    en: 'Payment method',
                  ),
                  description: Text(
                    localizedUiText(
                      locale.code,
                      ja: 'Stripe Checkout（クレジットカード、Apple Pay、Google Pay等）',
                      en: 'Stripe Checkout (credit card, Apple Pay, Google Pay, and similar methods)',
                    ),
                  ),
                ),
                LegalDefinitionRowData(
                  term: localizedUiText(
                    locale.code,
                    ja: '支払時期',
                    en: 'Payment timing',
                  ),
                  description: Text(
                    localizedUiText(
                      locale.code,
                      ja: 'ご注文確定時（前払い）',
                      en: 'At the time the order is confirmed (prepayment)',
                    ),
                  ),
                ),
              ],
            ),
          ),
          LegalSection(
            index: '03',
            title: localizedUiText(locale.code, ja: '商品の引渡し', en: 'Delivery'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LegalNoteGrid(
                  notes: [
                    LegalNoteData(
                      label: 'Production Origin',
                      text: Text(
                        localizedUiText(
                          locale.code,
                          ja: '中国（当社提携工房にて一本ずつ製作）',
                          en: 'China (each item is produced by our partner workshop)',
                        ),
                      ),
                    ),
                    LegalNoteData(
                      label: 'Estimated Delivery',
                      text: Text(
                        localizedUiText(
                          locale.code,
                          ja: '製作期間: 5〜10営業日 / 配送期間: 7〜14日程度',
                          en: 'Production period: 5-10 business days / Shipping period: about 7-14 days',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  localizedUiText(
                    locale.code,
                    ja: '本商品は完全受注生産です。製作開始後、通関手続きや配送状況、大型連休の影響により、お届けまで通常より時間がかかる場合があります。',
                    en: 'This product is made to order. After production begins, customs procedures, delivery conditions, and long holiday periods may extend the time required for delivery.',
                  ),
                  style: AppFonts.manrope(
                    fontSize: 15,
                    height: 1.8,
                    color: _legalNoticeInk,
                  ),
                ),
              ],
            ),
          ),
          LegalSection(
            index: '04',
            title: localizedUiText(
              locale.code,
              ja: '返品・交換・キャンセル',
              en: 'Returns, exchanges, and cancellations',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedUiText(
                    locale.code,
                    ja: '当ブランドの商品はすべてお客様一人ひとりに合わせたオーダーメイド品です。',
                    en: 'All products are custom-made for each individual customer.',
                  ),
                  style: AppFonts.manrope(
                    fontSize: 15,
                    height: 1.8,
                    color: _legalNoticeInk,
                  ),
                ),
                const SizedBox(height: 16),
                LegalBulletList(
                  items: [
                    Text(
                      localizedUiText(
                        locale.code,
                        ja: 'お客様都合による返品・交換はお受けできません。',
                        en: 'We cannot accept returns or exchanges for customer convenience.',
                      ),
                    ),
                    Text(
                      localizedUiText(
                        locale.code,
                        ja: '不良品・誤配送の場合、到着後7日以内にご連絡いただければ再製作いたします。',
                        en: 'If an item is defective or incorrectly delivered, please contact us within 7 days of receipt and we will remake it.',
                      ),
                    ),
                    Text(
                      localizedUiText(
                        locale.code,
                        ja: '石材の個体差は天然素材の特性であり、不良品の対象外となります。',
                        en: 'Natural variations in stone are inherent to the material and are not considered defects.',
                      ),
                    ),
                    Text(
                      localizedUiText(
                        locale.code,
                        ja: 'ご注文後、製作工程に入る前に限りキャンセルが可能です。至急お問い合わせフォームよりご連絡ください。',
                        en: 'Cancellation is possible only before production starts. Please contact us through the inquiry form as soon as possible.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          LegalSection(
            index: '05',
            title: localizedUiText(locale.code, ja: 'お問い合わせ', en: 'Contact'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedUiText(
                    locale.code,
                    ja: 'ご不明点やご質問がございましたら、お問い合わせフォームよりご連絡ください。',
                    en: 'If you have any questions, please contact us through the inquiry form.',
                  ),
                  style: AppFonts.manrope(
                    fontSize: 15,
                    height: 1.8,
                    color: _legalNoticeInk,
                  ),
                ),
                const SizedBox(height: 18),
                LegalActionButtons(
                  primaryLabel: localizedUiText(
                    locale.code,
                    ja: 'トップへ戻る',
                    en: 'Back to TOP',
                  ),
                  primaryOnPressed: onBack,
                  secondaryLabel: localizedUiText(
                    locale.code,
                    ja: 'お問い合わせ',
                    en: 'Contact us',
                  ),
                  secondaryOnPressed: () => _openContact(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openContact(BuildContext context) async {
    final uri = Uri.parse(inquiryUrlForLocale(locale));
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      final message = locale == AppLocale.en
          ? 'Could not open the inquiry form.'
          : 'お問い合わせフォームを開けませんでした。';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
