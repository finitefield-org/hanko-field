import 'dart:async';

import 'package:app/features/howto/data/howto_repository.dart';
import 'package:app/features/howto/domain/howto_tutorial.dart';

class FakeHowToRepository implements HowToRepository {
  const FakeHowToRepository();

  @override
  Future<HowToContentResult> fetchContent(HowToContentRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final normalized = request.localeTag.toLowerCase().startsWith('ja')
        ? 'ja'
        : 'en';
    final groups = _groupsForLocale(normalized);
    return HowToContentResult(
      groups: groups,
      localeTag: normalized,
      persona: request.persona,
      fetchedAt: DateTime.now(),
      fromCache: false,
    );
  }

  List<HowToTopicGroup> _groupsForLocale(String locale) {
    final isJa = locale == 'ja';
    return [
      HowToTopicGroup(
        topic: HowToTopic.onboarding,
        title: isJa ? '初回セットアップ' : 'Getting Started',
        description: isJa
            ? 'アプリの初期設定と漢字マッピングの流れを短い動画で確認できます。'
            : 'Short walkthroughs covering the initial app setup and kanji mapping.',
        tutorials: [
          HowToTutorial(
            id: 'howto-getting-started',
            topic: HowToTopic.onboarding,
            title: isJa ? '3 分で分かるアプリ導線' : '3-minute onboarding tour',
            summary: isJa
                ? 'ペルソナ選択からホームタブの活用まで、最初の 3 分で完了するセットアップ手順。'
                : 'Choose your persona, sync preferences, and understand the home tab in three minutes.',
            videoUrl:
                'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
            duration: const Duration(minutes: 3, seconds: 12),
            steps: [
              HowToStep(
                title: isJa ? 'ペルソナを選ぶ' : 'Pick your persona',
                description: isJa
                    ? '外国人/日本人モードを切り替えると、後続の案内が最適化されます。'
                    : 'Switch between international and domestic flows to tailor subsequent suggestions.',
                timestamp: const Duration(seconds: 20),
              ),
              HowToStep(
                title: isJa ? '通知と言語設定' : 'Notifications & language',
                description: isJa
                    ? '通知許可と preferred language を同時に設定。後でプロフィールから変更可能。'
                    : 'Enable notifications and choose your preferred language. You can adjust it later from profile.',
                timestamp: const Duration(minutes: 1, seconds: 15),
              ),
              HowToStep(
                title: isJa ? 'AI 漢字マップ' : 'AI kanji mapping primer',
                description: isJa
                    ? '氏名を入力すると AI が候補を提案。お気に入りに保存してライブラリで比較できます。'
                    : 'Enter your name to see AI kanji suggestions and save favorites into your library.',
                timestamp: const Duration(minutes: 2, seconds: 10),
              ),
            ],
            thumbnailUrl:
                'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=1200',
            caption: isJa
                ? '字幕 ON で各ステップの詳細とショートカットを確認しましょう。'
                : 'Enable captions to see shortcuts and deeper explanations per step.',
            resources: const ['guides/kanji-mapping-basics'],
            difficulty: HowToDifficultyLevel.beginner,
            featured: true,
            badge: isJa ? '人気' : 'Popular',
            relatedGuideSlug: 'kanji-mapping-basics',
          ),
          HowToTutorial(
            id: 'howto-persona-sync',
            topic: HowToTopic.onboarding,
            title: isJa ? 'ペルソナ連携とクラウド同期' : 'Sync persona & cloud data',
            summary: isJa
                ? '既存ユーザーでも 90 秒でクラウドと設定を同期。多拠点利用向け。'
                : 'Keep multiple devices in sync by linking persona and cloud settings in 90 seconds.',
            videoUrl:
                'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
            duration: const Duration(minutes: 2, seconds: 5),
            steps: [
              HowToStep(
                title: isJa ? 'QR でログイン' : 'Log in with QR',
                description: isJa
                    ? 'プロフィール > 連携アカウント から QR を表示し、新端末で読み取ります。'
                    : 'Open profile > linked accounts, show the QR code, and scan it from the new device.',
              ),
              HowToStep(
                title: isJa ? '環境の確認' : 'Confirm environment',
                description: isJa
                    ? 'dev/stg/prod のフレーバーを選び、同期対象をミスしないようにします。'
                    : 'Pick the matching dev/stg/prod flavor so you sync with the right environment.',
              ),
            ],
            thumbnailUrl:
                'https://images.unsplash.com/photo-1529333166437-7750a6dd5a70?w=1200',
            caption: isJa
                ? 'モバイルとデスクトップの双方で同じ字幕内容を表示します。'
                : 'Captions stay in sync across mobile and desktop layouts.',
            resources: const ['guides/material-care-guide'],
            difficulty: HowToDifficultyLevel.beginner,
          ),
        ],
      ),
      HowToTopicGroup(
        topic: HowToTopic.care,
        title: isJa ? 'メンテナンス' : 'Care & maintenance',
        description: isJa
            ? '素材別のお手入れと、失敗しやすい点を動画で学べます。'
            : 'Learn material-specific maintenance routines and common pitfalls.',
        tutorials: [
          HowToTutorial(
            id: 'howto-material-care',
            topic: HowToTopic.care,
            title: isJa ? '5 分で分かる印材ケア' : '5-minute seal care routine',
            summary: isJa
                ? '柘植・黒水牛・チタンをそれぞれ最適なリズムでケアする手順。'
                : 'Care routines for wood, horn, and titanium seals with quick reminders.',
            videoUrl:
                'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
            duration: const Duration(minutes: 5, seconds: 18),
            steps: [
              HowToStep(
                title: isJa ? '乾拭きの向き' : 'Dry wipe direction',
                description: isJa
                    ? '木材は木目に沿って拭き、角を丸めないよう優しく扱います。'
                    : 'Follow the wood grain when wiping and avoid rounding the edges.',
                timestamp: const Duration(seconds: 45),
              ),
              HowToStep(
                title: isJa ? '油分の補給' : 'Replenish oil',
                description: isJa
                    ? '黒水牛は月 1 回、綿棒でオイルを薄く塗布し、余分をティッシュで除去。'
                    : 'For horn materials, add a drop of oil monthly and blot the excess.',
                timestamp: const Duration(minutes: 2),
              ),
              HowToStep(
                title: isJa ? 'ケース保管' : 'Storage tips',
                description: isJa
                    ? '乾燥剤は 3 か月で交換。ケースは直射日光を避けて保管しましょう。'
                    : 'Replace desiccants every 3 months and keep the case out of direct sunlight.',
                timestamp: const Duration(minutes: 4),
              ),
            ],
            thumbnailUrl:
                'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1200',
            caption: isJa
                ? '字幕では道具リストと推奨サイクルを表示します。'
                : 'Captions list the recommended tools and cadence.',
            resources: const ['guides/material-care-guide'],
            difficulty: HowToDifficultyLevel.intermediate,
            relatedGuideSlug: 'material-care-guide',
          ),
          HowToTutorial(
            id: 'howto-ink-maintenance',
            topic: HowToTopic.care,
            title: isJa ? '朱肉を長持ちさせる方法' : 'Keep ink pads usable longer',
            summary: isJa
                ? '朱肉の裏返し保存や、海外持ち出し時の乾燥対策を解説。'
                : 'Store pads upside down and travel with moisture packs to stop drying.',
            videoUrl:
                'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
            duration: const Duration(minutes: 4, seconds: 2),
            steps: [
              HowToStep(
                title: isJa ? '裏返しで保管' : 'Store upside down',
                description: isJa
                    ? 'インク面を下にすると常に均等に湿り気が保たれます。'
                    : 'Keeping the ink surface face-down maintains saturation.',
              ),
              HowToStep(
                title: isJa ? '海外フライト対策' : 'Flight preparation',
                description: isJa
                    ? 'ジップバッグと湿度シートを追加し、気圧変化での漏れを防ぎます。'
                    : 'Add a zip bag plus humidity sheet to avoid leakage during flights.',
              ),
            ],
            thumbnailUrl:
                'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=1200',
            caption: isJa
                ? '世界各地で集めた tips を字幕で補足。'
                : 'Captions include global field notes.',
            resources: const ['guides/inkpad-guide'],
            difficulty: HowToDifficultyLevel.beginner,
            badge: isJa ? '新着' : 'New',
            relatedGuideSlug: 'inkpad-guide',
          ),
        ],
      ),
      HowToTopicGroup(
        topic: HowToTopic.shipping,
        title: isJa ? '発送とトラッキング' : 'Shipping & tracking',
        description: isJa
            ? '国際配送や再配達の依頼手順を録画しています。'
            : 'See how to prep packages, select carriers, and request redelivery.',
        tutorials: [
          HowToTutorial(
            id: 'howto-international-shipping',
            topic: HowToTopic.shipping,
            title: isJa ? '国際配送パッキングガイド' : 'International packing tips',
            summary: isJa
                ? '防水と耐衝撃を両立する梱包例。関税書類の入力例も紹介。'
                : 'Waterproof plus impact-safe packing with a customs form walkthrough.',
            videoUrl:
                'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
            duration: const Duration(minutes: 6, seconds: 10),
            steps: [
              HowToStep(
                title: isJa ? '二重梱包' : 'Double boxing',
                description: isJa
                    ? '緩衝材を印面側に 2 重で配置し、ズレ防止の和紙で固定。'
                    : 'Position padding on the stamp face twice and lock it with thin paper.',
              ),
              HowToStep(
                title: isJa ? 'HS コード' : 'HS codes',
                description: isJa
                    ? '8708.99 などのサンプルコードを字幕に表示。'
                    : 'Captions list common HS codes such as 8708.99.',
              ),
            ],
            thumbnailUrl:
                'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=1200',
            caption: isJa
                ? '字幕ボタンでインボイス定型文をコピーできます。'
                : 'Use captions to copy/paste invoice boilerplates.',
            resources: const ['guides/bank-registration-checklist'],
            difficulty: HowToDifficultyLevel.intermediate,
            relatedGuideSlug: 'bank-registration-checklist',
          ),
          HowToTutorial(
            id: 'howto-digital-export',
            topic: HowToTopic.digital,
            title: isJa ? 'デジタル印影の安全な共有' : 'Share digital seals securely',
            summary: isJa
                ? '透かしとアクセス期限を設定する 2 通りの方法を比較。'
                : 'Compare watermarking and expiring links when sharing your seal.',
            videoUrl:
                'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
            duration: const Duration(minutes: 3, seconds: 40),
            steps: [
              HowToStep(
                title: isJa ? 'ウォーターマーク適用' : 'Add a watermark',
                description: isJa
                    ? '共有 > 透かし でテンプレートを選択し、透過率を 60% に設定。'
                    : 'Go to Share > Watermark, choose a template, and set opacity to 60%.',
              ),
              HowToStep(
                title: isJa ? '期限付きリンク' : 'Generate expiring links',
                description: isJa
                    ? '7 日/30 日/無期限のプリセットから選び、閲覧のみモードを推奨。'
                    : 'Pick 7-day, 30-day, or no-expiry presets and keep links view-only.',
              ),
            ],
            thumbnailUrl:
                'https://images.unsplash.com/photo-1483478550801-ceba5fe50e8e?w=1200',
            caption: isJa
                ? '字幕に推奨のセキュリティ設定メモを表示。'
                : 'Captions remind you of the recommended security defaults.',
            resources: const ['guides/kanji-mapping-basics'],
            difficulty: HowToDifficultyLevel.advanced,
            badge: isJa ? '上級' : 'Advanced',
            relatedGuideSlug: 'kanji-mapping-basics',
          ),
        ],
      ),
    ];
  }
}
