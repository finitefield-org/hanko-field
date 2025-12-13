// ignore_for_file: public_member_api_docs

import 'package:app/features/designs/data/models/design_models.dart';

String libraryDesignHeroTag(Design design) =>
    'library:design:${design.id ?? design.hash ?? 'unknown'}';
