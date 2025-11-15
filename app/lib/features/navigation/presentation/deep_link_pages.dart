import 'package:app/features/guides/presentation/guide_detail_screen.dart';
import 'package:app/features/guides/presentation/guides_list_screen.dart';
import 'package:app/features/profile/presentation/profile_addresses_screen.dart';
import 'package:app/features/profile/presentation/profile_export_screen.dart';
import 'package:app/features/profile/presentation/profile_legal_screen.dart';
import 'package:app/features/profile/presentation/profile_linked_accounts_screen.dart';
import 'package:app/features/profile/presentation/profile_locale_screen.dart';
import 'package:app/features/profile/presentation/profile_notifications_screen.dart';
import 'package:app/features/profile/presentation/profile_payments_screen.dart';
import 'package:app/features/profile/presentation/profile_support_screen.dart';
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

/// プロフィール配下
class ProfileSectionPage extends StatelessWidget {
  const ProfileSectionPage({required this.sectionSegments, super.key});

  final List<String> sectionSegments;

  @override
  Widget build(BuildContext context) {
    final title = sectionSegments.join(' / ');
    if (sectionSegments.isEmpty) {
      return _ProfileSectionFallback(title: title);
    }
    final primary = sectionSegments.first;
    switch (primary) {
      case 'addresses':
        return const ProfileAddressesScreen();
      case 'payments':
        return const ProfilePaymentsScreen();
      case 'notifications':
        return const ProfileNotificationsScreen();
      case 'locale':
        return const ProfileLocaleScreen();
      case 'legal':
        return const ProfileLegalScreen();
      case 'support':
        return const ProfileSupportScreen();
      case 'linked-accounts':
        return const ProfileLinkedAccountsScreen();
      case 'export':
        return const ProfileExportScreen();
      default:
        return _ProfileSectionFallback(title: title);
    }
  }
}

class _ProfileSectionFallback extends StatelessWidget {
  const _ProfileSectionFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
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
    if (sectionSegments.isEmpty) {
      return const GuidesListScreen();
    }
    final slug = sectionSegments.isEmpty ? '' : sectionSegments.last;
    final category = sectionSegments.length > 1 ? sectionSegments.first : null;
    return GuideDetailScreen(slug: slug, categoryHint: category);
  }
}
