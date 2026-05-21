import 'dart:convert';
import 'dart:io';

import 'api_json.dart';

class HankoApiClient {
  HankoApiClient({required this.baseUri, HankoApiTransport? transport})
    : _transport = transport ?? HankoHttpApiTransport();

  final Uri baseUri;
  final HankoApiTransport _transport;

  Future<JsonMap> getJson(
    String path, {
    Map<String, String?> queryParameters = const {},
  }) {
    return _send('GET', path, queryParameters: queryParameters);
  }

  Future<JsonMap> postJson(String path, JsonMap body) {
    return _send('POST', path, body: body);
  }

  Future<JsonMap> _send(
    String method,
    String path, {
    JsonMap? body,
    Map<String, String?> queryParameters = const {},
  }) async {
    final response = await _transport.send(
      HankoApiRequest(
        method: method,
        uri: _buildUri(path, queryParameters),
        body: body,
        headers: const {
          HttpHeaders.acceptHeader: 'application/json',
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        },
      ),
    );

    final decoded = _decodeJsonObject(response.body, 'API response');
    if (response.isSuccess) {
      return decoded;
    }

    final error = decoded['error'];
    if (error is Map) {
      final errorJson = asJsonMap(error, 'API error');
      throw HankoApiException(
        statusCode: response.statusCode,
        code: readString(errorJson, 'code', defaultValue: 'api_error'),
        message: readString(errorJson, 'message', defaultValue: 'API error'),
        payload: decoded,
      );
    }

    throw HankoApiException(
      statusCode: response.statusCode,
      code: 'http_${response.statusCode}',
      message: 'API request failed with status ${response.statusCode}',
      payload: decoded,
    );
  }

  Uri _buildUri(String path, Map<String, String?> queryParameters) {
    final base = baseUri.toString().replaceFirst(RegExp(r'/$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final query = <String, String>{};
    for (final entry in queryParameters.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) {
        query[entry.key] = value;
      }
    }
    return Uri.parse(
      '$base$normalizedPath',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  JsonMap _decodeJsonObject(String body, String context) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return const {};
    }
    try {
      return asJsonMap(jsonDecode(trimmed), context);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('$context is not valid JSON: $error');
    }
  }
}

class HankoApiRequest {
  const HankoApiRequest({
    required this.method,
    required this.uri,
    this.body,
    this.headers = const {},
  });

  final String method;
  final Uri uri;
  final JsonMap? body;
  final Map<String, String> headers;
}

class HankoApiResponse {
  const HankoApiResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

abstract interface class HankoApiTransport {
  Future<HankoApiResponse> send(HankoApiRequest request);
}

class HankoHttpApiTransport implements HankoApiTransport {
  HankoHttpApiTransport({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Future<HankoApiResponse> send(HankoApiRequest request) async {
    final httpRequest = await _httpClient.openUrl(request.method, request.uri);
    for (final header in request.headers.entries) {
      httpRequest.headers.set(header.key, header.value);
    }

    final body = request.body;
    if (body != null) {
      httpRequest.add(utf8.encode(jsonEncode(body)));
    }

    final response = await httpRequest.close();
    return HankoApiResponse(
      statusCode: response.statusCode,
      body: await response.transform(utf8.decoder).join(),
    );
  }
}

class HankoApiException implements Exception {
  const HankoApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    required this.payload,
  });

  final int statusCode;
  final String code;
  final String message;
  final JsonMap payload;

  @override
  String toString() {
    return 'HankoApiException($statusCode, $code, $message)';
  }
}
