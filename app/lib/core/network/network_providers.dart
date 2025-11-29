// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:app/core/network/network_client.dart';
import 'package:app/core/network/network_config.dart';
import 'package:app/core/network/response_parser.dart';
import 'package:app/security/secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

const httpClientScope = Scope<http.Client>.required('network.httpClient');
const networkClientScope = Scope<NetworkClient>.required('network.client');
const responseParserScope = Scope<ResponseParser>.required(
  'network.responseParser',
);

final connectivityProvider = Provider<Connectivity>((_) => Connectivity());

final responseParserProvider = Provider<ResponseParser>((ref) {
  try {
    return ref.scope(responseParserScope);
  } on StateError {
    return const ResponseParser();
  }
});

final httpClientProvider = Provider<http.Client>((ref) {
  try {
    return ref.scope(httpClientScope);
  } on StateError {
    final config = ref.watch(networkConfigProvider);
    final ioClient = HttpClient();
    if (config.connectTimeout != Duration.zero) {
      ioClient.connectionTimeout = config.connectTimeout;
    }
    return IOClient(ioClient);
  }
});

final networkClientProvider = Provider<NetworkClient>((ref) {
  try {
    return ref.scope(networkClientScope);
  } on StateError {
    final config = ref.watch(networkConfigProvider);
    final client = ref.watch(httpClientProvider);
    final parser = ref.watch(responseParserProvider);
    final connectivity = ref.watch(connectivityProvider);
    final tokenStorage = ref.watch(tokenStorageProvider);
    final logger = Logger('NetworkClient');

    return NetworkClient(
      httpClient: client,
      config: config,
      connectivity: connectivity,
      tokenStorage: tokenStorage,
      parser: parser,
      logger: logger,
    );
  }
});
