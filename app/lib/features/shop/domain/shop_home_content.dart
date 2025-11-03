import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/routing/app_route_configuration.dart';
import 'package:app/core/routing/app_tab.dart';
import 'package:flutter/material.dart';

@immutable
class ShopHomeContext {
  const ShopHomeContext({required this.experience});

  final ExperienceGate experience;
}

@immutable
class ShopDestination {
  const ShopDestination({required this.route, this.overrideTab});

  final IndependentRoute route;
  final AppTab? overrideTab;
}

@immutable
class ShopCategory {
  const ShopCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.destination,
  });

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final ShopDestination destination;
}

@immutable
class ShopPromotion {
  const ShopPromotion({
    required this.id,
    required this.headline,
    required this.subheading,
    required this.imageUrl,
    required this.ctaLabel,
    required this.destination,
    this.badgeLabel,
  });

  final String id;
  final String headline;
  final String subheading;
  final String imageUrl;
  final String ctaLabel;
  final String? badgeLabel;
  final ShopDestination destination;
}

@immutable
class ShopMaterialRecommendation {
  const ShopMaterialRecommendation({
    required this.id,
    required this.name,
    required this.description,
    required this.origin,
    required this.hardness,
    required this.imageUrl,
    required this.priceLabel,
    required this.destination,
  });

  final String id;
  final String name;
  final String description;
  final String origin;
  final String hardness;
  final String imageUrl;
  final String priceLabel;
  final ShopDestination destination;
}

@immutable
class ShopGuideLink {
  const ShopGuideLink({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.destination,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final ShopDestination destination;
}

@immutable
class ShopHomeState {
  const ShopHomeState({
    required this.context,
    required this.categories,
    required this.promotions,
    required this.materials,
    required this.guides,
  });

  final ShopHomeContext context;
  final List<ShopCategory> categories;
  final List<ShopPromotion> promotions;
  final List<ShopMaterialRecommendation> materials;
  final List<ShopGuideLink> guides;
}
