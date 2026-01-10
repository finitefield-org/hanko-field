// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/core/routing/app_router.dart';
import 'package:app/core/routing/routes.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

final navigationControllerProvider = Provider<NavigationController>((ref) {
  return NavigationController(ref.container);
});

final deepLinkHandlerProvider = Provider<DeepLinkHandler>((ref) {
  final logger = Logger('DeepLinkHandler');
  final navigation = ref.watch(navigationControllerProvider);
  return DeepLinkHandler(navigation, logger);
});

class NavigationController {
  NavigationController(this._container);

  final ProviderContainer _container;

  Future<void> goToTab(AppTab tab) {
    return _container.invoke(appNavigationProvider.selectTab(tab));
  }

  Future<void> push(String location) {
    return _container.invoke(appNavigationProvider.push(location));
  }

  Future<void> go(String location) {
    return _container.invoke(appNavigationProvider.go(location));
  }

  void pop<T extends Object?>([T? result]) {
    unawaited(_container.invoke(appNavigationProvider.pop()));
  }

  String get currentLocation =>
      _container.read(appNavigationProvider).currentLocation;

  bool canPop() {
    final state = _container.read(appNavigationProvider);
    if (state.rootPages.length > 1) return true;
    final pages = state.pagesByTab[state.currentTab] ?? const <Object>[];
    return pages.length > 1;
  }
}

class DeepLinkHandler {
  DeepLinkHandler(this._navigation, this._logger);

  final NavigationController _navigation;
  final Logger _logger;

  Future<bool> open(Uri uri, {bool push = false}) async {
    final location = _normalize(uri);
    if (location == null) {
      _logger.warning('Ignored unsupported deep link: $uri');
      return false;
    }

    try {
      if (push) {
        await _navigation.push(location);
      } else {
        await _navigation.go(location);
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

class NavigationControllerScope extends InheritedWidget {
  const NavigationControllerScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final NavigationController controller;

  static NavigationController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<NavigationControllerScope>();
    assert(scope != null, 'NavigationControllerScope not found in context.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(NavigationControllerScope oldWidget) {
    return oldWidget.controller != controller;
  }
}

extension AppNavigationContext on BuildContext {
  NavigationController get navigation => NavigationControllerScope.of(this);

  Future<void> go(String location) => navigation.go(location);

  Future<void> push(String location) => navigation.push(location);

  void pop<T extends Object?>([T? result]) => navigation.pop(result);
}
