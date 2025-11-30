// ignore_for_file: public_member_api_docs

import 'dart:io';
import 'package:app/config/app_flavor.dart';
import 'package:app/firebase/firebase_providers.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:miniriverpod/miniriverpod.dart';

class NetworkConfig {
  const NetworkConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 10),
    this.userAgent,
    this.locale,
    this.defaultHeaders = const <String, String>{},
    this.maxRetries = 3,
    this.retryBaseDelay = const Duration(milliseconds: 300),
    this.retryMaxDelay = const Duration(seconds: 5),
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final String? userAgent;
  final String? locale;
  final Map<String, String> defaultHeaders;
  final int maxRetries;
  final Duration retryBaseDelay;
  final Duration retryMaxDelay;

  NetworkConfig copyWith({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    String? userAgent,
    String? locale,
    Map<String, String>? defaultHeaders,
    int? maxRetries,
    Duration? retryBaseDelay,
    Duration? retryMaxDelay,
  }) {
    return NetworkConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      userAgent: userAgent ?? this.userAgent,
      locale: locale ?? this.locale,
      defaultHeaders: defaultHeaders ?? this.defaultHeaders,
      maxRetries: maxRetries ?? this.maxRetries,
      retryBaseDelay: retryBaseDelay ?? this.retryBaseDelay,
      retryMaxDelay: retryMaxDelay ?? this.retryMaxDelay,
    );
  }
}

const networkConfigScope = Scope<NetworkConfig>.required('network.config');

final networkConfigProvider = Provider<NetworkConfig>((ref) {
  try {
    return ref.scope(networkConfigScope);
  } on StateError {
    final AppFlavor flavor = ref.watch(appFlavorProvider);
    final baseUrl = switch (flavor) {
      AppFlavor.dev => 'https://api-dev.hanko-field.app',
      AppFlavor.stg => 'https://api-stg.hanko-field.app',
      AppFlavor.prod => 'https://api.hanko-field.app',
    };

    final localeTag = ref.watch(appLocaleProvider).toLanguageTag();

    return NetworkConfig(
      baseUrl: baseUrl,
      userAgent: buildUserAgent(flavor),
      locale: localeTag,
    );
  }
});

String buildUserAgent(AppFlavor flavor) {
  final os = Platform.operatingSystem;
  final version = Platform.operatingSystemVersion;
  return 'HankoField/${flavor.name} ($os $version)';
}
