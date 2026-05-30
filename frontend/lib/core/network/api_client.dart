import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import '../services/local_storage.dart';

class ApiClient {
  static String get baseUrl => EnvConfig.baseUrl;

  static Map<String, String> _getHeaders() {
    final token = LocalStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> _sendRequestWithRetry(
    String path,
    Future<http.Response> Function(Uri url) requestFn,
  ) async {
    Uri getUrl() => Uri.parse('$baseUrl$path');

    try {
      final url = getUrl();
      return await requestFn(url).timeout(const Duration(seconds: 10));
    } on SocketException catch (e) {
      debugPrint('Network SocketException on initial request: $e');
      final currentBaseUrl = EnvConfig.baseUrl;
      if (currentBaseUrl.contains('10.0.2.2') || currentBaseUrl.contains('localhost')) {
        EnvConfig.useProductionFallback();
        try {
          final retryUrl = getUrl();
          debugPrint('Retrying request with production backend: $retryUrl');
          return await requestFn(retryUrl).timeout(const Duration(seconds: 10));
        } catch (retryError) {
          debugPrint('Retry failed: $retryError');
        }
      }
      return http.Response(
        jsonEncode({
          'success': false,
          'message': 'Unable to connect to the server. Please verify your connection or local emulator server configuration.',
        }),
        503,
        headers: {'content-type': 'application/json'},
      );
    } on TimeoutException catch (e) {
      debugPrint('Network TimeoutException on initial request: $e');
      final currentBaseUrl = EnvConfig.baseUrl;
      if (currentBaseUrl.contains('10.0.2.2') || currentBaseUrl.contains('localhost')) {
        EnvConfig.useProductionFallback();
        try {
          final retryUrl = getUrl();
          debugPrint('Retrying request with production backend due to timeout: $retryUrl');
          return await requestFn(retryUrl).timeout(const Duration(seconds: 10));
        } catch (retryError) {
          debugPrint('Retry failed: $retryError');
        }
      }
      return http.Response(
        jsonEncode({
          'success': false,
          'message': 'Connection timed out. The server is taking too long to respond.',
        }),
        408,
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      debugPrint('Network error on initial request: $e');
      return http.Response(
        jsonEncode({
          'success': false,
          'message': 'An unexpected network error occurred: $e',
        }),
        500,
        headers: {'content-type': 'application/json'},
      );
    }
  }

  static http.Response _processResponse(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final body = response.body.trim();

    // Check if the response is an HTML page (like gateway error page)
    if (contentType.contains('text/html') ||
        body.startsWith('<!DOCTYPE html>') ||
        body.startsWith('<html>') ||
        body.startsWith('<html ')) {
      return http.Response(
        jsonEncode({
          'success': false,
          'message': 'Server returned an invalid response (HTML page). Code: ${response.statusCode}',
        }),
        response.statusCode,
        headers: {'content-type': 'application/json'},
      );
    }

    // Strict JSON parsing check
    try {
      jsonDecode(response.body);
    } on FormatException catch (e) {
      debugPrint('Invalid JSON response format: $e');
      return http.Response(
        jsonEncode({
          'success': false,
          'message': 'Failed to parse server response. Code: ${response.statusCode}',
        }),
        response.statusCode,
        headers: {'content-type': 'application/json'},
      );
    }

    return response;
  }

  static Future<http.Response> get(String path) async {
    final response = await _sendRequestWithRetry(path, (url) {
      return http.get(url, headers: _getHeaders());
    });
    return _processResponse(response);
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final response = await _sendRequestWithRetry(path, (url) {
      return http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
    });
    return _processResponse(response);
  }

  static Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final response = await _sendRequestWithRetry(path, (url) {
      return http.put(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
    });
    return _processResponse(response);
  }

  static Future<http.Response> delete(String path) async {
    final response = await _sendRequestWithRetry(path, (url) {
      return http.delete(url, headers: _getHeaders());
    });
    return _processResponse(response);
  }
}
