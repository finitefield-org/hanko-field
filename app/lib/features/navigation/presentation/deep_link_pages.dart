import 'package:app/features/shop/presentation/material_detail_screen.dart';
import 'package:app/features/shop/presentation/product_addons_screen.dart';
import 'package:app/features/shop/presentation/product_detail_screen.dart';
import 'package:flutter/material.dart';

/// 作成フローステージ
class CreationStagePage extends StatelessWidget {
  const CreationStagePage({required this.stageSegments, super.key});

  final List<String> stageSegments;

  @override
  Widget build(BuildContext context) {
    final stage = stageSegments.join(' / ');
    return Scaffold(
      appBar: AppBar(title: Text('作成: $stage')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('作成ステージ', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(stageSegments.isEmpty ? '初期ステップを表示します。' : '現在のステップ: $stage'),
          ],
        ),
      ),
    );
  }
}

/// ショップ詳細
class ShopDetailPage extends StatelessWidget {
  const ShopDetailPage({
    required this.entity,
    required this.identifier,
    required this.subPage,
    super.key,
  });

  final String entity;
  final String identifier;
  final String subPage;

  @override
  Widget build(BuildContext context) {
    if (entity == 'materials') {
      return MaterialDetailScreen(materialId: identifier);
    }
    if (entity == 'products') {
      if (subPage == 'addons') {
        return ProductAddonsScreen(productId: identifier);
      }
      return ProductDetailScreen(productId: identifier);
    }

    final headline = switch (entity) {
      'products' => '商品詳細',
      _ => 'ショップ詳細',
    };
    return Scaffold(
      appBar: AppBar(title: Text('$headline #$identifier')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text('エンティティ: $entity'),
            Text('ID: $identifier'),
            if (subPage.isNotEmpty) Text('セクション: $subPage'),
          ],
        ),
      ),
    );
  }
}

/// 保存済み印影
class LibraryEntryPage extends StatelessWidget {
  const LibraryEntryPage({
    required this.designId,
    required this.subPage,
    super.key,
  });

  final String designId;
  final String subPage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('印影 $designId')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('マイ印鑑', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text('デザイン ID: $designId'),
            if (subPage.isNotEmpty) Text('セクション: $subPage'),
          ],
        ),
      ),
    );
  }
}

/// プロフィール配下
class ProfileSectionPage extends StatelessWidget {
  const ProfileSectionPage({required this.sectionSegments, super.key});

  final List<String> sectionSegments;

  @override
  Widget build(BuildContext context) {
    final title = sectionSegments.join(' / ');
    return Scaffold(
      appBar: AppBar(title: Text('プロフィール: $title')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('プロフィールセクション', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(title.isEmpty ? 'ルート設定' : '現在のパス: $title'),
          ],
        ),
      ),
    );
  }
}

/// ガイド一覧/詳細
class GuidesPage extends StatelessWidget {
  const GuidesPage({required this.sectionSegments, super.key});

  final List<String> sectionSegments;

  @override
  Widget build(BuildContext context) {
    final title = sectionSegments.isEmpty ? 'ガイド' : sectionSegments.join(' / ');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ガイドコンテンツ', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              sectionSegments.isEmpty
                  ? '文化・HowToガイドのエントリ一覧を表示します。'
                  : '選択中のセクション: $title',
            ),
            const SizedBox(height: 12),
            const Text('※ 本タスクではダミー表示です。'),
          ],
        ),
      ),
    );
  }
}
