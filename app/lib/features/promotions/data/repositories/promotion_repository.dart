// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/features/promotions/data/models/promotion_models.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class PromotionRepository {
  static const fallback = Scope<PromotionRepository>.required(
    'promotion.repository',
  );

  Future<Promotion> getPublicPromotion(String code);

  Future<PromotionValidationResult> validate(
    String code, {
    String? currency,
    int? subtotal,
    SealShape? shape,
    double? sizeMm,
    String? productRef,
    String? materialRef,
  });
}
