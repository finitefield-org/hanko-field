// ignore_for_file: public_member_api_docs

const networkOfflineExtraKey = 'network.offline';
const networkDisableRetryExtraKey = 'network.disableRetry';

enum NetworkErrorType {
  unauthorized,
  forbidden,
  notFound,
  client,
  server,
  timeout,
  offline,
  cancel,
  serialization,
  unknown,
}

class NetworkError implements Exception {
  const NetworkError({
    required this.type,
    required this.message,
    this.statusCode,
    this.data,
    this.uri,
  });

  factory NetworkError.http({
    required int statusCode,
    required String message,
    Object? data,
    Uri? uri,
  }) {
    return NetworkError(
      type: _mapStatusToError(statusCode),
      message: message,
      statusCode: statusCode,
      data: data,
      uri: uri,
    );
  }

  factory NetworkError.timeout({Uri? uri}) {
    return NetworkError(
      type: NetworkErrorType.timeout,
      message: 'Request timed out',
      uri: uri,
    );
  }

  factory NetworkError.offline({Uri? uri}) {
    return NetworkError(
      type: NetworkErrorType.offline,
      message: 'No network connectivity',
      uri: uri,
    );
  }

  factory NetworkError.serialization({
    required String message,
    int? statusCode,
    Uri? uri,
  }) {
    return NetworkError(
      type: NetworkErrorType.serialization,
      message: message,
      statusCode: statusCode,
      uri: uri,
    );
  }

  factory NetworkError.unknown({
    required String message,
    Object? data,
    Uri? uri,
  }) {
    return NetworkError(
      type: NetworkErrorType.unknown,
      message: message,
      data: data,
      uri: uri,
    );
  }

  final NetworkErrorType type;
  final String message;
  final int? statusCode;
  final Object? data;
  final Uri? uri;

  static NetworkErrorType _mapStatusToError(int statusCode) {
    if (statusCode == 401) return NetworkErrorType.unauthorized;
    if (statusCode == 403) return NetworkErrorType.forbidden;
    if (statusCode == 404) return NetworkErrorType.notFound;
    if (statusCode >= 400 && statusCode < 500) return NetworkErrorType.client;
    if (statusCode >= 500) return NetworkErrorType.server;
    return NetworkErrorType.unknown;
  }

  @override
  String toString() {
    final status = statusCode ?? '-';
    return 'NetworkError($type, status: $status, message: $message)';
  }
}
