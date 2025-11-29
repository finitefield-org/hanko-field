// ignore_for_file: public_member_api_docs

import 'package:app/core/network/network_error.dart';

typedef JsonDecoder<T> = T Function(Object? json);

class NetworkRawResponse {
  const NetworkRawResponse({
    required this.data,
    required this.statusCode,
    required this.headers,
    required this.uri,
  });

  final Object? data;
  final int statusCode;
  final Map<String, String> headers;
  final Uri uri;
}

class ResponseParser {
  const ResponseParser();

  T parse<T>(NetworkRawResponse response, {JsonDecoder<T>? decoder}) {
    final payload = response.data;

    if (decoder != null) {
      return decoder(payload);
    }

    if (payload == null && null is T) {
      return null as T;
    }

    if (payload is T) {
      return payload;
    }

    if (payload is Map && T == Map<String, dynamic>) {
      final map = Map<String, dynamic>.from(payload);
      return map as T;
    }

    if (payload is List && T == List<dynamic>) {
      final list = List<dynamic>.from(payload);
      return list as T;
    }

    throw NetworkError.serialization(
      message: 'Unable to parse response as $T (got ${payload.runtimeType})',
      statusCode: response.statusCode,
      uri: response.uri,
    );
  }
}
