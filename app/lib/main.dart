import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: HankoApp()));
}
