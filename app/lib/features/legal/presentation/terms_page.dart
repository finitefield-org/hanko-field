import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/fonts/app_fonts.dart';
import '../../../app/localization/app_locale_view_model.dart';
import '../../order/domain/order_models.dart';
import 'legal_page_shell.dart';

const _termsInk = Color(0xFF1B1C1A);

class TermsPage extends StatelessWidget {
  const TermsPage({
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
      title: localizedUiText(locale.code, ja: '利用規約', en: 'Terms of Service'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LegalSection(
            index: '01',
            title: localizedUiText(locale.code, ja: '適用範囲', en: 'Scope'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bodyParagraph(
                  localizedUiText(
                    locale.code,
                    ja: '本規約は、株式会社ファイナイトフィールド（以下「当社」）が運営するブランド「STONE SIGNATURE」（以下「本サービス」）の利用条件を定めるものです。',
                    en: 'These Terms set out the conditions for using the brand “STONE SIGNATURE” (the “Service”) operated by Finite Field, K.K. (the “Company”).',
                  ),
                ),
                _bodyParagraph(
                  localizedUiText(
                    locale.code,
                    ja: '本サービスを利用するお客様（以下「利用者」）は、注文手続を完了した時点で、本規約の全ての条項に同意したものとみなされます。',
                    en: 'Customers using the Service (the “Users”) are deemed to have agreed to all provisions of these Terms when they complete the order process.',
                  ),
                ),
                _bodyParagraph(
                  localizedUiText(
                    locale.code,
                    ja: '本サービスに関し、本規約以外に別途定める「特定商取引法に基づく表記」や案内等は、本規約の一部を構成するものとします。',
                    en: 'Any separate notices or guidance posted for the Service, including the “Legal Notice (Act on Specified Commercial Transactions),” form part of these Terms.',
                  ),
                ),
              ],
            ),
          ),
          LegalSection(
            index: '02',
            title: localizedUiText(
              locale.code,
              ja: '注文と契約の成立',
              en: 'Orders and Contract Formation',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bodyParagraph(
                  localizedUiText(
                    locale.code,
                    ja: '利用者が当サイトにて必要事項を入力し、注文手続を完了させた時点で、当社は注文を受付済みとして取り扱います。',
                    en: 'When a User enters the required information on the Site and completes the order process, we treat the order as received.',
                  ),
                ),
                LegalDefinitionList(
                  rows: [
                    LegalDefinitionRowData(
                      term: localizedUiText(
                        locale.code,
                        ja: '注文受付',
                        en: 'Order received',
                      ),
                      description: Text(
                        localizedUiText(
                          locale.code,
                          ja: '必要事項の入力と注文完了をもって、当社は注文を受付済みとして取り扱います。',
                          en: 'Once the required information has been entered and the order process is completed, we treat the order as received.',
                        ),
                      ),
                    ),
                    LegalDefinitionRowData(
                      term: localizedUiText(
                        locale.code,
                        ja: '契約成立',
                        en: 'Contract formation',
                      ),
                      description: Text(
                        localizedUiText(
                          locale.code,
                          ja: '当社が利用者からの支払いを確認し、注文確定の通知（メール等）を送信した時点で、売買契約が成立するものとします。',
                          en: 'A sales contract is formed when we confirm payment from the User and send an order confirmation notice (by email or similar means).',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _bodyParagraph(
                  localizedUiText(
                    locale.code,
                    ja: '当社は、以下の理由により注文をお断り、または契約を解除できるものとします。',
                    en: 'We may decline an order or terminate the contract for any of the following reasons:',
                  ),
                ),
                LegalBulletList(
                  items: [
                    Text(
                      localizedUiText(
                        locale.code,
                        ja: '入力内容に虚偽や不備がある場合',
                        en: 'The submitted information is false or incomplete',
                      ),
                    ),
                    Text(
                      localizedUiText(
                        locale.code,
                        ja: '転売目的、または不当な利益を得る目的と判断される場合',
                        en: 'The order is deemed to be for resale or to obtain unfair profit',
                      ),
                    ),
                    Text(
                      localizedUiText(
                        locale.code,
                        ja: '過去に利用規約違反があった場合',
                        en: 'The User has previously violated these Terms',
                      ),
                    ),
                    Text(
                      localizedUiText(
                        locale.code,
                        ja: 'その他、当社が不適切と判断した場合',
                        en: 'Any other reason we deem inappropriate',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          LegalSection(
            index: '03',
            title: localizedUiText(
              locale.code,
              ja: '料金、支払および関税',
              en: 'Fees, Payment, and Duties',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LegalDefinitionList(
                  rows: [
                    LegalDefinitionRowData(
                      term: localizedUiText(
                        locale.code,
                        ja: '販売価格',
                        en: 'Price',
                      ),
                      description: Text(
                        localizedUiText(
                          locale.code,
                          ja: '各商品ページに表示される価格に従います（消費税込み）。',
                          en: 'Prices displayed on each product page (tax included).',
                        ),
                      ),
                    ),
                    LegalDefinitionRowData(
                      term: localizedUiText(
                        locale.code,
                        ja: '追加料金',
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
                          ja: 'Stripe Checkout（クレジットカード、Apple Pay、Google Pay等）による前払いです。',
                          en: 'Payment is made in advance through Stripe Checkout (credit card, Apple Pay, Google Pay, and similar methods).',
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
                          ja: 'ご注文確定時（前払い）です。',
                          en: 'At the time the order is confirmed (prepayment).',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _bodyParagraph(
                  localizedUiText(
                    locale.code,
                    ja: '本商品は中国の提携工房より直送される個人輸入となります。日本国内および配送先の国において、受け取り時に関税、消費税、通関手数料等（以下「関税等」）が発生する場合、これらは全て利用者の負担となります。関税等の支払いを拒否したことによる受取辞退の場合、当社は代金の返金を行いません。',
                    en: 'This product is shipped directly from our partner workshop in China as a personal import. If customs duties, consumption tax, customs clearance fees, or similar charges (collectively, “Duties”) arise in Japan or in the destination country upon receipt, the User is solely responsible for those charges. If the User refuses to pay the Duties and declines delivery, we will not refund the purchase price.',
                  ),
                ),
              ],
            ),
          ),
          LegalSection(
            index: '04',
            title: localizedUiText(
              locale.code,
              ja: '製作と引渡し',
              en: 'Production and Delivery',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LegalNoteGrid(
                  notes: [
                    LegalNoteData(
                      label: localizedUiText(
                        locale.code,
                        ja: '製作拠点',
                        en: 'Production Origin',
                      ),
                      text: Text(
                        localizedUiText(
                          locale.code,
                          ja: '中国（当社提携工房にて一本ずつ製作）',
                          en: 'China (each item is produced by our partner workshop)',
                        ),
                      ),
                    ),
                    LegalNoteData(
                      label: localizedUiText(
                        locale.code,
                        ja: '目安納期',
                        en: 'Estimated Delivery',
                      ),
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
                _bodyParagraph(
                  localizedUiText(
                    locale.code,
                    ja: '本商品は完全受注生産です。支払いおよびデザイン確定（デザイン確認工程がある場合）の完了後、速やかに製作を開始します。',
                    en: 'Each item is made to order. Production begins promptly after payment and design confirmation (if a design review step is required) are completed.',
                  ),
                ),
                _bodyParagraph(
                  localizedUiText(
                    locale.code,
                    ja: '製作に通常 5〜10 営業日、発送後の配送に通常 7〜14 日程度を要します。ただし、以下の事由により遅延が生じる場合があります。',
                    en: 'Production usually takes 5-10 business days, and shipping usually takes 7-14 days after dispatch. However, delays may occur due to the following:',
                  ),
                ),
                LegalBulletList(
                  items: [
                    Text(
                      localizedUiText(
                        locale.code,
                        ja: '通関手続きの遅延',
                        en: 'Delays in customs procedures',
                      ),
                    ),
                    Text(
                      localizedUiText(
                        locale.code,
                        ja: '配送業者の都合、天候、国際情勢',
                        en: 'Shipping carrier issues, weather, or international conditions',
                      ),
                    ),
                    Text(
                      localizedUiText(
                        locale.code,
                        ja: '中国および日本の大型連休（春節等）',
                        en: 'Long holidays in China or Japan (including Lunar New Year)',
                      ),
                    ),
                  ],
                ),
                _bodyParagraph(
                  localizedUiText(
                    locale.code,
                    ja: '利用者の不在等により商品が発送元へ返送された場合、再発送にかかる費用は利用者の負担となります。',
                    en: 'If an item is returned to the sender due to the User’s absence or similar reasons, the cost of re-shipment shall be borne by the User.',
                  ),
                ),
              ],
            ),
          ),
          LegalSection(
            index: '05',
            title: localizedUiText(
              locale.code,
              ja: 'キャンセル・返品・交換',
              en: 'Cancellations, Returns, and Exchanges',
            ),
            child: LegalBulletList(
              items: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Customer-initiated refusal: ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: localizedUiText(
                          locale.code,
                          ja: '商品の性質上（オーダーメイド）、製作開始後のキャンセル、返品、交換は一切お受けできません。',
                          en: 'Because the product is custom-made, we cannot accept cancellations, returns, or exchanges after production has started.',
                        ),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Defective or incorrectly shipped items: ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: localizedUiText(
                          locale.code,
                          ja: 'お届けした商品に著しい破損、汚損、または当社の過失による彫刻内容の誤りがある場合に限り、商品到着後 7日以内にご連絡をいただいた上で、無償で再製作・再発送を行います。',
                          en: 'If the delivered item has significant damage, stains, or engraving errors caused by our fault, and you contact us within 7 days of receipt, we will remake and reship the item at no cost.',
                        ),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Stone characteristics: ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: localizedUiText(
                          locale.code,
                          ja: '石材特有の個体差（模様、色味、微細な質感の差異）は天然素材の特性であり、不良品の対象外となります。',
                          en: 'Natural variations in stone patterns, color, and fine texture are inherent to the material and are not considered defects.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          LegalSection(
            index: '06',
            title: localizedUiText(
              locale.code,
              ja: '禁止事項・知的財産権',
              en: 'Prohibited Conduct and Intellectual Property',
            ),
            child: LegalBulletList(
              items: [
                Text(
                  localizedUiText(
                    locale.code,
                    ja: '利用者は、本サイトの画像、文章、デザイン等の無断転載・転用を禁じられます。',
                    en: 'Users must not reproduce or reuse the Site’s images, text, designs, or other content without permission.',
                  ),
                ),
                Text(
                  localizedUiText(
                    locale.code,
                    ja: '提供される印影デザイン等の知的財産権は、当社または正当な権利者に帰属します。',
                    en: 'Intellectual property rights in the seal designs and related materials provided belong to the Company or the rightful rights holder.',
                  ),
                ),
              ],
            ),
          ),
          LegalSection(
            index: '07',
            title: localizedUiText(locale.code, ja: '免責事項', en: 'Disclaimer'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bodyParagraph(
                  localizedUiText(
                    locale.code,
                    ja: '当社は、天災、戦争、テロ、通信障害、システム保守、通関の差し止め、その他不可抗力により生じた損害や遅延について、一切の責任を負いません。',
                    en: 'The Company is not liable for damages or delays caused by natural disasters, war, terrorism, network failures, system maintenance, customs holds, or other force majeure events.',
                  ),
                ),
                _bodyParagraph(
                  localizedUiText(
                    locale.code,
                    ja: '本サービスにおける商品の使用、または使用不能から生じる損害についても、当社の過失が認められない限り責任を負いません。',
                    en: 'The Company is also not liable for damages arising from the use or inability to use the products in the Service, except where the Company is found negligent.',
                  ),
                ),
              ],
            ),
          ),
          LegalSection(
            index: '08',
            title: localizedUiText(
              locale.code,
              ja: '準拠法・裁判管轄・言語',
              en: 'Governing Law, Jurisdiction, and Language',
            ),
            child: LegalDefinitionList(
              rows: [
                LegalDefinitionRowData(
                  term: localizedUiText(
                    locale.code,
                    ja: '準拠法',
                    en: 'Governing law',
                  ),
                  description: Text(
                    localizedUiText(
                      locale.code,
                      ja: '本規約の解釈および適用は、日本法に準拠します。',
                      en: 'These Terms shall be governed by and construed in accordance with the laws of Japan.',
                    ),
                  ),
                ),
                LegalDefinitionRowData(
                  term: localizedUiText(
                    locale.code,
                    ja: '合意管轄',
                    en: 'Exclusive jurisdiction',
                  ),
                  description: Text(
                    localizedUiText(
                      locale.code,
                      ja: '本サービスに関して紛争が生じた場合、当社の本店所在地を管轄する地方裁判所を第一審の専属的合意管轄裁判所とします。',
                      en: 'Any dispute arising in connection with the Service shall be subject to the exclusive jurisdiction of the district court having jurisdiction over the location of our head office, as the court of first instance.',
                    ),
                  ),
                ),
                LegalDefinitionRowData(
                  term: localizedUiText(
                    locale.code,
                    ja: '準拠言語',
                    en: 'Controlling language',
                  ),
                  description: Text(
                    localizedUiText(
                      locale.code,
                      ja: '本規約に日本語以外の翻訳版が存在する場合でも、日本語による規約が優先されるものとします。',
                      en: 'If these Terms are available in any language other than Japanese, the Japanese version shall prevail.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          LegalSection(
            index: '09',
            title: localizedUiText(locale.code, ja: 'お問い合わせ', en: 'Contact'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bodyParagraph(
                  localizedUiText(
                    locale.code,
                    ja: 'ご不明点やご質問がございましたら、お問い合わせフォームよりご連絡ください。',
                    en: 'If you have any questions, please contact us through the inquiry form.',
                  ),
                ),
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

  Widget _bodyParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: AppFonts.manrope(fontSize: 15, height: 1.8, color: _termsInk),
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
