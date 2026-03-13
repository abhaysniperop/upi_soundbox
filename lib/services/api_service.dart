import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

enum ApiErrorType {
  network,
  timeout,
  serverError,
  validationError,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final ApiErrorType type;
  final int? statusCode;
  final List<Map<String, dynamic>>? validationErrors;

  const ApiException({
    required this.message,
    required this.type,
    this.statusCode,
    this.validationErrors,
  });

  bool get isRetryable =>
      type == ApiErrorType.network ||
      type == ApiErrorType.timeout ||
      (type == ApiErrorType.serverError && (statusCode ?? 0) >= 500);

  @override
  String toString() => message;

  static ApiException fromHttpResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final errors = (body['errors'] as List?)
          ?.cast<Map<String, dynamic>>();
      final message = errors?.first['message'] as String? ??
          body['error'] as String? ??
          'Request failed (${response.statusCode})';
      return ApiException(
        message: message,
        type: response.statusCode >= 500
            ? ApiErrorType.serverError
            : ApiErrorType.validationError,
        statusCode: response.statusCode,
        validationErrors: errors,
      );
    } catch (_) {
      return ApiException(
        message: 'Request failed (${response.statusCode})',
        type: ApiErrorType.serverError,
        statusCode: response.statusCode,
      );
    }
  }

  static ApiException fromError(Object e) {
    if (e is ApiException) return e;
    if (e is TimeoutException || (e is SocketException && e.message.contains('timed out'))) {
      return const ApiException(
        message: 'Request timed out. Please retry.',
        type: ApiErrorType.timeout,
      );
    }
    if (e is SocketException) {
      return ApiException(
        message: 'No internet connection: ${e.message}',
        type: ApiErrorType.network,
      );
    }
    if (e is http.ClientException) {
      return ApiException(
        message: 'Network error: ${e.message}',
        type: ApiErrorType.network,
      );
    }
    return ApiException(
      message: e.toString(),
      type: ApiErrorType.unknown,
    );
  }
}

Future<T> withRetry<T>(
  Future<T> Function() fn, {
  int maxRetries = kMaxRetries,
  Duration delay = kRetryDelay,
  bool Function(ApiException)? shouldRetry,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn();
    } catch (e) {
      final apiEx = ApiException.fromError(e);
      final retryable = shouldRetry?.call(apiEx) ?? apiEx.isRetryable;
      attempt++;
      if (!retryable || attempt >= maxRetries) {
        throw apiEx;
      }
      debugPrint('[API] Retry $attempt/$maxRetries after error: ${apiEx.message}');
      await Future.delayed(delay * attempt);
    }
  }
}

class GeneratePayloadResult {
  final String vendor;
  final String transactionId;
  final Map<String, dynamic> payload;

  const GeneratePayloadResult({
    required this.vendor,
    required this.transactionId,
    required this.payload,
  });

  factory GeneratePayloadResult.fromJson(Map<String, dynamic> json) {
    return GeneratePayloadResult(
      vendor: json['vendor'] as String,
      transactionId: json['transactionId'] as String,
      payload: json['payload'] as Map<String, dynamic>,
    );
  }
}

class ProxyInjectResult {
  final bool success;
  final String targetIP;
  final int? statusCode;
  final dynamic response;
  final String? error;
  final String? code;

  const ProxyInjectResult({
    required this.success,
    required this.targetIP,
    this.statusCode,
    this.response,
    this.error,
    this.code,
  });

  factory ProxyInjectResult.fromJson(Map<String, dynamic> json) {
    return ProxyInjectResult(
      success: json['success'] as bool? ?? false,
      targetIP: json['targetIP'] as String? ?? '',
      statusCode: json['statusCode'] as int?,
      response: json['response'],
      error: json['error'] as String?,
      code: json['code'] as String?,
    );
  }
}

class PingResult {
  final bool isOnline;
  final double? uptime;
  final String? timestamp;
  final int latencyMs;

  const PingResult({
    required this.isOnline,
    this.uptime,
    this.timestamp,
    required this.latencyMs,
  });
}

class GeneratePayloadService {
  final String baseUrl;
  final http.Client _client;

  GeneratePayloadService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? kApiBase,
        _client = client ?? http.Client();

  Future<GeneratePayloadResult> call({
    required String vendor,
    required double amount,
    int retries = kMaxRetries,
  }) async {
    return withRetry(
      () => _execute(vendor: vendor, amount: amount),
      maxRetries: retries,
    );
  }

  Future<GeneratePayloadResult> _execute({
    required String vendor,
    required double amount,
  }) async {
    final uri = Uri.parse('$baseUrl/generate-payload').replace(
      queryParameters: {
        'vendor': vendor,
        'amount': amount.toStringAsFixed(2),
      },
    );

    debugPrint('[GeneratePayload] POST $uri');

    final response = await _client
        .post(uri)
        .timeout(kConnectTimeout);

    debugPrint('[GeneratePayload] ${response.statusCode}');

    if (response.statusCode != 200) {
      throw ApiException.fromHttpResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return GeneratePayloadResult.fromJson(json);
  }
}

class ProxyInjectService {
  final String baseUrl;
  final http.Client _client;

  ProxyInjectService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? kApiBase,
        _client = client ?? http.Client();

  Future<ProxyInjectResult> call({
    required String targetIP,
    required Map<String, dynamic> payload,
    int retries = kMaxRetries,
  }) async {
    return withRetry(
      () => _execute(targetIP: targetIP, payload: payload),
      maxRetries: retries,
      shouldRetry: (e) => e.type == ApiErrorType.timeout || e.type == ApiErrorType.network,
    );
  }

  Future<ProxyInjectResult> _execute({
    required String targetIP,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('$baseUrl/proxy-inject');

    debugPrint('[ProxyInject] POST $uri → target: $targetIP');

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'targetIP': targetIP, 'payload': payload}),
        )
        .timeout(kReceiveTimeout);

    debugPrint('[ProxyInject] ${response.statusCode}');

    if (response.statusCode == 400) {
      throw ApiException.fromHttpResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ProxyInjectResult.fromJson(json);
  }
}

class PingService {
  final String baseUrl;
  final http.Client _client;

  PingService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? kApiBase,
        _client = client ?? http.Client();

  Future<PingResult> call() async {
    final uri = Uri.parse('$baseUrl/ping');
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('[Ping] GET $uri');

      final response = await _client
          .get(uri)
          .timeout(kPingTimeout);

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      debugPrint('[Ping] ${response.statusCode} in ${latency}ms');

      if (response.statusCode != 200) {
        return PingResult(isOnline: false, latencyMs: latency);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PingResult(
        isOnline: json['success'] == true,
        uptime: (json['uptime'] as num?)?.toDouble(),
        timestamp: json['timestamp'] as String?,
        latencyMs: latency,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[Ping] error: $e');
      return PingResult(isOnline: false, latencyMs: stopwatch.elapsedMilliseconds);
    }
  }

  Stream<PingResult> watchEvery(Duration interval) async* {
    while (true) {
      yield await call();
      await Future.delayed(interval);
    }
  }
}
