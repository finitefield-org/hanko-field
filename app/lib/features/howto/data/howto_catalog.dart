// ignore_for_file: public_member_api_docs

import 'package:app/features/howto/data/models/howto_models.dart';

const howtoVideosCatalog = <HowtoVideo>[
  HowtoVideo(
    id: 'getting-started',
    isFeatured: true,
    topicJa: 'はじめに',
    topicEn: 'Getting started',
    titleJa: '最初のデザインを作る',
    titleEn: 'Create your first design',
    summaryJa: '文字入力からプレビューまでの基本フローを紹介します。',
    summaryEn: 'Walk through the basic flow from text input to preview.',
    youtubeUrl: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
    durationLabel: '3:20',
  ),
  HowtoVideo(
    id: 'editor-basics',
    topicJa: 'デザイン',
    topicEn: 'Design',
    titleJa: 'エディタ操作の基本',
    titleEn: 'Editor basics',
    summaryJa: '配置・太さ・余白・回転などの調整ポイント。',
    summaryEn: 'Learn how to adjust position, weight, padding, and rotation.',
    youtubeUrl: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
    durationLabel: '4:05',
  ),
  HowtoVideo(
    id: 'ordering',
    topicJa: '注文',
    topicEn: 'Ordering',
    titleJa: '注文の流れ',
    titleEn: 'How ordering works',
    summaryJa: 'カートからチェックアウトまでのステップを確認します。',
    summaryEn: 'See the steps from cart to checkout.',
    youtubeUrl: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
    durationLabel: '2:45',
  ),
];
