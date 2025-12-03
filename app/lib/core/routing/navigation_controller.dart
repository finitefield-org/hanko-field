// ignore_for_file: public_member_api_docs

import 'package:app/core/routing/app_router.dart';
import 'package:app/core/routing/routes.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

final navigationControllerProvider = Provider<NavigationController>((ref) {
  final router = ref.watch(appRouterProvider);
  return NavigationController(router);
});

final deepLinkHandlerProvider = Provider<DeepLinkHandler>((ref) {
  final logger = Logger('DeepLinkHandler');
  final router = ref.watch(appRouterProvider);
  return DeepLinkHandler(router, logger);
});

class NavigationController {
  NavigationController(this._router);

  final GoRouter _router;

  void goToTab(AppTab tab) {
    _router.go(tab.location);
  }

  Future<T?> push<T>(String location) {
    return _router.push<T>(location);
  }

  void go(String location) {
    _router.go(location);
  }

  void pop<T extends Object?>([T? result]) {
    _router.pop(result);
  }
}

class DeepLinkHandler {
  DeepLinkHandler(this._router, this._logger);

  final GoRouter _router;
  final Logger _logger;

  Future<bool> open(Uri uri, {bool push = false}) async {
    final location = _normalize(uri);
    if (location == null) {
      _logger.warning('Ignored unsupported deep link: $uri');
      return false;
    }

    try {
      if (push) {
        await _router.push(location);
      } else {
        _router.go(location);
      }
      return true;
    } catch (e, stack) {
      _logger.warning('Failed to open deep link $uri', e, stack);
      return false;
    }
  }

  String? _normalize(Uri uri) {
    if (uri.scheme == 'hanko' || uri.scheme.isEmpty) {
      return _toPath(uri);
    }

    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.contains('hanko.app')) {
      return _toPath(uri);
    }

    return null;
  }

  String _toPath(Uri uri) {
    final normalizedPath = uri.path.isEmpty ? AppRoutePaths.home : uri.path;
    final pathWithSlash = normalizedPath.startsWith('/')
        ? normalizedPath
        : '/$normalizedPath';

    final normalized = Uri(
      path: pathWithSlash,
      queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    );

    return normalized.toString();
  }
}
