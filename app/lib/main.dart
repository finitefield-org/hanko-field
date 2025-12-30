import 'package:app/bootstrap.dart';
import 'package:app/config/app_flavor.dart';

Future<void> main() => bootstrap(flavor: appFlavorFromEnvironment());
