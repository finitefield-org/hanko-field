class SettingsContentBundle {
  const SettingsContentBundle({
    required this.about,
    required this.faq,
    required this.privacy,
    required this.terms,
  });

  final SettingsAboutContent about;
  final SettingsFaqContent faq;
  final SettingsLegalContent privacy;
  final SettingsLegalContent terms;

  static SettingsContentBundle forLanguage(String languageCode) {
    if (languageCode == 'ja') {
      return _jaContent;
    }
    return _enContent;
  }
}

class SettingsAboutContent {
  const SettingsAboutContent({
    required this.heading,
    required this.body,
    required this.points,
    required this.tagline,
  });

  final String heading;
  final String body;
  final List<SettingsTextSection> points;
  final String tagline;
}

class SettingsFaqContent {
  const SettingsFaqContent({required this.heading, required this.items});

  final String heading;
  final List<SettingsFaqItem> items;
}

class SettingsFaqItem {
  const SettingsFaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class SettingsLegalContent {
  const SettingsLegalContent({
    required this.updated,
    required this.intro,
    required this.officialLinkLabel,
    required this.officialUrl,
    required this.sections,
  });

  final String updated;
  final String intro;
  final String officialLinkLabel;
  final String officialUrl;
  final List<SettingsTextSection> sections;
}

class SettingsTextSection {
  const SettingsTextSection({required this.title, required this.body});

  final String title;
  final String body;
}

const _enContent = SettingsContentBundle(
  about: SettingsAboutContent(
    heading: 'Your seal, made from gemstone',
    body:
        'STONE SIGNATURE helps you choose a gemstone seal online, design the seal impression, and place an order from the app. Review the material and one-of-a-kind stone listings as you find the seal that fits you.',
    points: [
      SettingsTextSection(
        title: 'Custom design',
        body:
            'Turn your name into a kanji-based seal design with meaning, balance, and a personal sense of intention.',
      ),
      SettingsTextSection(
        title: 'Natural gemstones',
        body:
            'Choose the seal material while reviewing colors, patterns, and natural character unique to each stone.',
      ),
      SettingsTextSection(
        title: 'Handcrafted with care',
        body:
            'After payment and design confirmation, each custom seal is produced one by one by our partner workshop.',
      ),
    ],
    tagline: 'Your name. Your stone. Your signature.',
  ),
  faq: SettingsFaqContent(
    heading: 'Frequently asked questions',
    items: [
      SettingsFaqItem(
        question: 'How is kanji selected?',
        answer:
            'Kanji is suggested from your name, the desired meaning, and the balance of the seal design. You can review candidates before choosing the design direction.',
      ),
      SettingsFaqItem(
        question: 'Can I change my order after payment?',
        answer:
            'Because each seal is custom-made, changes may not be possible after production starts. Review the design, stone, shipping details, and terms before completing payment.',
      ),
      SettingsFaqItem(
        question: 'How long does production take?',
        answer:
            'Production usually takes 5-10 business days after payment and design confirmation. Shipping usually takes about 7-14 days after dispatch.',
      ),
      SettingsFaqItem(
        question: 'Do you ship internationally?',
        answer:
            'Orders are shipped from our partner workshop in China. Customs duties, import taxes, and clearance fees may be charged on receipt and are the customer\'s responsibility.',
      ),
      SettingsFaqItem(
        question: 'Are gemstones one of a kind?',
        answer:
            'Yes. Natural stones vary in color, pattern, and texture. These differences are part of the material and are not treated as defects.',
      ),
      SettingsFaqItem(
        question: 'How do I track my order?',
        answer:
            'Use Order Lookup with your order number and email address. Tracking details will appear there when shipment information is available.',
      ),
    ],
  ),
  privacy: SettingsLegalContent(
    updated: 'Last updated: May 16, 2025',
    intro:
        'This app displays the privacy policy in an app-friendly format and references the official web policy for the latest legal text.',
    officialLinkLabel: 'Official privacy policy',
    officialUrl: 'https://finitefield.org/en/privacy/',
    sections: [
      SettingsTextSection(
        title: 'Information we collect',
        body:
            'We collect information you provide directly, such as your name, email address, shipping details, and order details. Saved seal designs and preview images remain on this device until you delete them.',
      ),
      SettingsTextSection(
        title: 'How we use information',
        body:
            'We use information to provide the service, process orders, communicate important updates, and improve the app experience.',
      ),
      SettingsTextSection(
        title: 'Sharing information',
        body:
            'We do not sell personal information. We may share information with service providers needed for payment, production, delivery, support, legal compliance, or protection of rights.',
      ),
      SettingsTextSection(
        title: 'Retention and local storage',
        body:
            'Order-related information is retained as required for service operation and legal obligations. Local saved designs are stored only on this device and are not synced across devices in the MVP.',
      ),
      SettingsTextSection(
        title: 'Contact',
        body:
            'For privacy questions, use the contact guidance in Settings or the official privacy policy page.',
      ),
    ],
  ),
  terms: SettingsLegalContent(
    updated: 'Last updated: May 22, 2025',
    intro:
        'These terms summarize the conditions for using STONE SIGNATURE in the app. The official web terms remain the legal source of truth.',
    officialLinkLabel: 'Official terms of service',
    officialUrl: 'https://finitefield.org/terms',
    sections: [
      SettingsTextSection(
        title: 'Scope',
        body:
            'The service is operated by Finite Field, K.K. Customers are deemed to agree to the terms when they complete the order process.',
      ),
      SettingsTextSection(
        title: 'Orders and contract formation',
        body:
            'An order is treated as received when required information is entered and the order process is completed. A sales contract is formed when payment is confirmed and an order confirmation notice is sent.',
      ),
      SettingsTextSection(
        title: 'Fees, payment, and duties',
        body:
            'Prices are shown on each product page. Payment is made in advance through Stripe Checkout. Customs duties, import taxes, and clearance fees may apply and are the customer\'s responsibility.',
      ),
      SettingsTextSection(
        title: 'Production and delivery',
        body:
            'Each item is made to order by our partner workshop in China. Production usually takes 5-10 business days and shipping usually takes about 7-14 days after dispatch.',
      ),
      SettingsTextSection(
        title: 'Cancellations, returns, and exchanges',
        body:
            'Because custom seals are made to order, cancellations, returns, and exchanges are not accepted after production starts, except for significant damage or engraving errors caused by our fault.',
      ),
      SettingsTextSection(
        title: 'Governing law and language',
        body:
            'The terms are governed by the laws of Japan. If translated versions differ, the Japanese version prevails.',
      ),
    ],
  ),
);

const _jaContent = SettingsContentBundle(
  about: SettingsAboutContent(
    heading: '宝石でつくる、あなたの印鑑',
    body:
        'STONE SIGNATUREは、宝石を使った印鑑をオンラインで選び、印影をデザインして注文できるサービスです。素材や一点物の個体を確認しながら、自分に合った印鑑を見つけられます。',
    points: [
      SettingsTextSection(
        title: '印影デザイン',
        body: '名前から意味とバランスを考慮した漢字ベースの印影を作り、注文前に方向性を確認できます。',
      ),
      SettingsTextSection(
        title: '天然石',
        body: '天然石ならではの色や模様、個体差を見ながら、印鑑の素材を選べます。',
      ),
      SettingsTextSection(title: '一点ずつ製作', body: '支払いとデザイン確定後、提携工房で一本ずつ製作します。'),
    ],
    tagline: 'あなたの名前。あなたの石。あなたの印鑑。',
  ),
  faq: SettingsFaqContent(
    heading: 'よくある質問',
    items: [
      SettingsFaqItem(
        question: '漢字はどのように選ばれますか？',
        answer: '名前、込めたい意味、印影全体のバランスをもとに候補を提案します。候補を確認してからデザインの方向性を選べます。',
      ),
      SettingsFaqItem(
        question: '支払い後に注文内容を変更できますか？',
        answer: 'オーダーメイド商品のため、製作開始後の変更はできない場合があります。支払い前に印影、石、配送先、規約を確認してください。',
      ),
      SettingsFaqItem(
        question: '製作にはどのくらいかかりますか？',
        answer: '支払いとデザイン確定後、製作は通常5〜10営業日、発送後の配送は通常7〜14日程度です。',
      ),
      SettingsFaqItem(
        question: '海外配送はありますか？',
        answer: '商品は中国の提携工房から発送されます。受け取り時に関税、輸入消費税、通関手数料等が発生する場合があります。',
      ),
      SettingsFaqItem(
        question: '宝石は一点物ですか？',
        answer: 'はい。同じ種類の石でも色、模様、質感は少しずつ異なります。天然素材の個体差は不良品の対象外です。',
      ),
      SettingsFaqItem(
        question: '注文の追跡はどこで確認できますか？',
        answer: '注文番号とメールアドレスを使って注文照会から確認できます。発送情報がある場合は追跡情報も表示されます。',
      ),
    ],
  ),
  privacy: SettingsLegalContent(
    updated: '最終更新: 2025年5月16日',
    intro: 'このアプリでは、プライバシーポリシーをアプリ向けに要約して表示します。最新の法務本文は公式Webページを確認してください。',
    officialLinkLabel: '公式プライバシーポリシー',
    officialUrl: 'https://finitefield.org/privacy/',
    sections: [
      SettingsTextSection(
        title: '取得する情報',
        body:
            '氏名、メールアドレス、配送先、注文内容など、利用者が入力した情報を取得します。保存済み印影とプレビュー画像は、削除するまでこの端末に保存されます。',
      ),
      SettingsTextSection(
        title: '利用目的',
        body: 'サービス提供、注文処理、重要なお知らせ、問い合わせ対応、アプリ体験の改善のために情報を利用します。',
      ),
      SettingsTextSection(
        title: '第三者提供',
        body:
            '個人情報を販売することはありません。決済、製作、配送、サポート、法令対応、権利保護に必要な範囲でサービス提供者と共有する場合があります。',
      ),
      SettingsTextSection(
        title: '保存期間と端末内保存',
        body: '注文関連情報はサービス運営と法令上必要な期間保持します。MVPでは端末内の保存済み印影は端末間同期されません。',
      ),
      SettingsTextSection(
        title: 'お問い合わせ',
        body: 'プライバシーに関する質問は、Settings内の問い合わせ案内または公式プライバシーポリシーページからご連絡ください。',
      ),
    ],
  ),
  terms: SettingsLegalContent(
    updated: '最終更新: 2025年5月22日',
    intro:
        'この画面では、STONE SIGNATUREの利用条件をアプリ向けに要約して表示します。正式な法務本文は公式Webの利用規約を確認してください。',
    officialLinkLabel: '公式利用規約',
    officialUrl: 'https://finitefield.org/ja/terms',
    sections: [
      SettingsTextSection(
        title: '適用範囲',
        body:
            '本サービスは株式会社ファイナイトフィールドが運営します。利用者は注文手続を完了した時点で、利用規約に同意したものとみなされます。',
      ),
      SettingsTextSection(
        title: '注文と契約の成立',
        body: '必要事項の入力と注文完了により注文受付となります。当社が支払いを確認し、注文確定の通知を送信した時点で売買契約が成立します。',
      ),
      SettingsTextSection(
        title: '料金、支払および関税',
        body:
            '販売価格は各商品ページの表示に従います。支払いはStripe Checkoutによる前払いです。関税、輸入消費税、通関手数料等が発生する場合は利用者負担です。',
      ),
      SettingsTextSection(
        title: '製作と引渡し',
        body: '商品は中国の提携工房で受注生産されます。製作は通常5〜10営業日、発送後の配送は通常7〜14日程度です。',
      ),
      SettingsTextSection(
        title: 'キャンセル・返品・交換',
        body:
            'オーダーメイド商品のため、製作開始後のお客様都合によるキャンセル、返品、交換はできません。著しい破損や当社過失による彫刻内容の誤りは到着後7日以内にご連絡ください。',
      ),
      SettingsTextSection(
        title: '準拠法と言語',
        body: '本規約は日本法に準拠します。日本語以外の翻訳版がある場合でも、日本語による規約が優先されます。',
      ),
    ],
  ),
);
