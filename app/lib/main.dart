import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

import 'app/app.dart';
import 'features/my_seals/my_seals.dart';
import 'features/order/order.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      child: HankoApp(
        localSealDesignRepository: SqfliteLocalSealDesignRepository(),
        localOrderDraftRepository: SqfliteLocalOrderDraftRepository(),
      ),
    ),
  );
}
