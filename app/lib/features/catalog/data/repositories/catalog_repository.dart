// ignore_for_file: public_member_api_docs

import 'package:app/core/model/enums.dart';
import 'package:app/core/model/value_objects.dart';
import 'package:app/features/catalog/data/models/catalog_models.dart';
import 'package:miniriverpod/miniriverpod.dart';

abstract class CatalogRepository {
  static const fallback = Scope<CatalogRepository>.required(
    'catalog.repository',
  );

  Future<Page<Template>> listTemplates({
    WritingStyle? writing,
    SealShape? shape,
    String? pageToken,
  });

  Future<Template> getTemplate(String templateIdOrSlug);

  Future<Page<Font>> listFonts({String? pageToken});

  Future<Font> getFont(String fontId);

  Future<Page<Material>> listMaterials({String? pageToken});

  Future<Material> getMaterial(String materialId);

  Future<Page<Product>> listProducts({
    SealShape? shape,
    double? sizeMm,
    String? materialRef,
    String? pageToken,
  });

  Future<Product> getProduct(String productId);
}
