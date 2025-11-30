// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app/core/network/network_config.dart';
import 'package:app/core/network/network_error.dart';
import 'package:app/core/network/response_parser.dart';
import 'package:app/security/secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

class NetworkClient {
  NetworkClient({
    required http.Client httpClient,
    required NetworkConfig config,
    required Connectivity connectivity,
    required TokenStorage tokenStorage,
    ResponseParser? parser,
    Logger? logger,
  }) : _httpClient = httpClient,
       _config = config,
       _connectivity = connectivity,
       _tokenStorage = tokenStorage,
       _parser = parser ?? const ResponseParser(),
       _logger = logger ?? Logger('NetworkClient');

  final http.Client _httpClient;
  final NetworkConfig _config;
  final Connectivity _connectivity;
  final TokenStorage _tokenStorage;
  final ResponseParser _parser;
  final Logger _logger;

  Future<NetworkResponse<T>> get<T>(
    String path, {
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
    Map<String, Object?>? extra,
    JsonDecoder<T>? decoder,
  }) {
    return _request(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      headers: headers,
      extra: extra,
      decoder: decoder,
    );
  }

  Future<NetworkResponse<T>> post<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
    Map<String, Object?>? extra,
    JsonDecoder<T>? decoder,
  }) {
    return _request(
      method: 'POST',
      path: path,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      extra: extra,
      decoder: decoder,
    );
  }

  Future<NetworkResponse<T>> put<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
    Map<String, Object?>? extra,
    JsonDecoder<T>? decoder,
  }) {
    return _request(
      method: 'PUT',
      path: path,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      extra: extra,
      decoder: decoder,
    );
  }

  Future<NetworkResponse<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
    Map<String, Object?>? extra,
    JsonDecoder<T>? decoder,
  }) {
    return _request(
      method: 'DELETE',
      path: path,
      data: data,
      queryParameters: queryParameters,
      headers: headers,
      extra: extra,
      decoder: decoder,
    );
  }

  Future<NetworkResponse<T>> _request<T>({
    required String method,
    required String path,
    Object? data,
    Map<String, Object?>? queryParameters,
    Map<String, Object?>? headers,
    Map<String, Object?>? extra,
    JsonDecoder<T>? decoder,
  }) async {
    final mergedExtra = extra ?? <String, Object?>{};
    final disableRetry = mergedExtra[networkDisableRetryExtraKey] == true;
    final uri = _buildUri(path, queryParameters);

    await _ensureOnline(uri);

    NetworkError? lastError;

    for (var attempt = 0; attempt <= _config.maxRetries; attempt++) {
      final stopwatch = Stopwatch()..start();
      try {
        final requestHeaders = await _buildHeaders(headers);
        final body = _encodeBody(data, requestHeaders);

        _logger.fine(
          '➡️ $method $uri headers=${_redactHeaders(requestHeaders)}',
        );

        final rawResponse = await _send(
          method: method,
          uri: uri,
          headers: requestHeaders,
          body: body,
          sendTimeout: _config.sendTimeout,
          receiveTimeout: _config.receiveTimeout,
        );

        stopwatch.stop();
        _logger.fine(
          '⬅️ ${rawResponse.statusCode} $method $uri '
          '(${stopwatch.elapsedMilliseconds}ms)',
        );

        if (_isSuccess(rawResponse.statusCode)) {
          final parsed = _parser.parse<T>(rawResponse, decoder: decoder);
          return NetworkResponse<T>(
            data: parsed,
            statusCode: rawResponse.statusCode,
            headers: rawResponse.headers,
            uri: rawResponse.uri,
          );
        }

        final error = NetworkError.http(
          statusCode: rawResponse.statusCode,
          message: 'Request failed with status ${rawResponse.statusCode}',
          data: rawResponse.data,
          uri: rawResponse.uri,
        );

        if (!disableRetry &&
            _shouldRetryStatus(rawResponse.statusCode, attempt)) {
          lastError = error;
          await Future<void>.delayed(_delayForAttempt(attempt + 1));
          continue;
        }

        throw error;
      } on TimeoutException {
        final error = NetworkError.timeout(uri: uri);
        if (!disableRetry && _shouldRetryTimeout(attempt)) {
          lastError = error;
          await Future<void>.delayed(_delayForAttempt(attempt + 1));
          continue;
        }
        throw error;
      } on NetworkError catch (error) {
        if (!disableRetry && _shouldRetryError(error, attempt)) {
          lastError = error;
          await Future<void>.delayed(_delayForAttempt(attempt + 1));
          continue;
        }
        rethrow;
      } on Exception catch (e, stack) {
        _logger.severe('Unexpected error during $method $uri', e, stack);
        final error = _mapExceptionToNetworkError(e, uri);
        if (!disableRetry && _shouldRetryError(error, attempt)) {
          lastError = error;
          await Future<void>.delayed(_delayForAttempt(attempt + 1));
          continue;
        }
        throw error;
      }
    }

    throw lastError ??
        NetworkError.unknown(message: 'Request failed', uri: uri);
  }

  Future<Map<String, String>> _buildHeaders(
    Map<String, Object?>? headers,
  ) async {
    final merged = <String, String>{
      'Accept': 'application/json',
      'User-Agent': _config.userAgent ?? '',
      'Accept-Language': _config.locale ?? '',
      ..._config.defaultHeaders,
    }..removeWhere((_, value) => value.isEmpty);

    if (headers != null) {
      headers.forEach((key, value) {
        if (value != null) merged[key] = value.toString();
      });
    }

    final hasAuthorization = merged.keys.any(
      (key) => key.toLowerCase() == 'authorization',
    );

    if (!hasAuthorization) {
      final token = await _tokenStorage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        merged['Authorization'] = 'Bearer $token';
      }
    }

    return merged;
  }

  (_EncodedBody?, String?) _encodeBody(
    Object? data,
    Map<String, String> headers,
  ) {
    if (data == null) {
      return (null, null);
    }

    if (data is String) {
      return (_EncodedBody(text: data), null);
    }

    if (data is List<int>) {
      return (_EncodedBody(bytes: data), null);
    }

    final jsonBody = jsonEncode(data);
    headers.putIfAbsent('Content-Type', () => 'application/json');
    return (_EncodedBody(text: jsonBody), 'application/json');
  }

  Future<NetworkRawResponse> _send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required (_EncodedBody?, String?) body,
    required Duration sendTimeout,
    required Duration receiveTimeout,
  }) async {
    final (encodedBody, _) = body;
    final request = http.Request(method, uri);
    request.headers.addAll(headers);
    if (encodedBody != null) {
      if (encodedBody.text != null) {
        request.body = encodedBody.text!;
      } else if (encodedBody.bytes != null) {
        request.bodyBytes = encodedBody.bytes!;
      }
    }

    final streamed = encodedBody != null && sendTimeout != Duration.zero
        ? await _httpClient.send(request).timeout(sendTimeout)
        : await _httpClient.send(request);

    final responseFuture = http.Response.fromStream(streamed);
    final response = receiveTimeout == Duration.zero
        ? await responseFuture
        : await responseFuture.timeout(receiveTimeout);
    final responseData = _decodeBody(response);

    return NetworkRawResponse(
      data: responseData,
      statusCode: response.statusCode,
      headers: Map<String, String>.from(response.headers),
      uri: response.request?.url ?? uri,
    );
  }

  Future<void> _ensureOnline(Uri uri) async {
    final dynamic connectivity = await _connectivity.checkConnectivity();

    final bool isOffline = switch (connectivity) {
      final List<ConnectivityResult> list =>
        list.isEmpty ||
            list.every((result) => result == ConnectivityResult.none),
      final ConnectivityResult single => single == ConnectivityResult.none,
      _ => true,
    };

    if (isOffline) throw NetworkError.offline(uri: uri);
  }

  NetworkError _mapExceptionToNetworkError(Exception exception, Uri uri) {
    if (exception is NetworkError) return exception;
    if (exception is SocketException) return NetworkError.offline(uri: uri);
    return NetworkError.unknown(message: exception.toString(), uri: uri);
  }

  bool _shouldRetryStatus(int statusCode, int attempt) {
    const retryableStatusCodes = <int>{408, 429, 500, 502, 503, 504};
    return attempt < _config.maxRetries &&
        retryableStatusCodes.contains(statusCode);
  }

  bool _shouldRetryTimeout(int attempt) {
    return attempt < _config.maxRetries;
  }

  bool _shouldRetryError(NetworkError error, int attempt) {
    if (attempt >= _config.maxRetries) return false;
    return switch (error.type) {
      NetworkErrorType.timeout ||
      NetworkErrorType.offline ||
      NetworkErrorType.server => true,
      _ => false,
    };
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  Duration _delayForAttempt(int attempt) {
    final jitter = Random().nextInt(150);
    final delayMs = min(
      _config.retryBaseDelay.inMilliseconds * pow(2, attempt - 1).toInt() +
          jitter,
      _config.retryMaxDelay.inMilliseconds,
    );
    return Duration(milliseconds: delayMs);
  }

  Uri _buildUri(String path, Map<String, Object?>? queryParameters) {
    final baseUri = Uri.parse(_config.baseUrl);
    final resolved = Uri.tryParse(path)?.hasScheme == true
        ? Uri.parse(path)
        : baseUri.resolve(path);
    if (queryParameters == null || queryParameters.isEmpty) {
      return resolved;
    }

    final qp = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value != null) qp[key] = value.toString();
    });

    return resolved.replace(
      queryParameters: {...resolved.queryParameters, ...qp},
    );
  }

  Object? _decodeBody(http.Response response) {
    if (response.body.isEmpty) return null;

    final contentType = response.headers['content-type'] ?? '';
    if (contentType.toLowerCase().contains('application/json')) {
      return jsonDecode(response.body) as Object?;
    }

    return response.body;
  }

  Map<String, Object?> _redactHeaders(Map<String, String> headers) {
    final sanitized = <String, Object?>{};
    headers.forEach((key, value) {
      final lowerKey = key.toLowerCase();
      if (_sensitiveHeaders.contains(lowerKey)) {
        sanitized[key] = '<redacted>';
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }
}

class NetworkResponse<T> {
  const NetworkResponse({
    required this.data,
    required this.statusCode,
    required this.headers,
    required this.uri,
  });

  final T data;
  final int statusCode;
  final Map<String, String> headers;
  final Uri uri;
}

class _EncodedBody {
  const _EncodedBody({this.text, this.bytes});

  final String? text;
  final List<int>? bytes;
}

const _sensitiveHeaders = <String>{
  'authorization',
  'cookie',
  'set-cookie',
  'x-api-key',
  'x-auth-token',
  'x-goog-iam-authorization-token',
  'x-goog-authuser',
};
