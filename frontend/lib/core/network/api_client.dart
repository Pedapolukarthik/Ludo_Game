import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import '../services/local_storage.dart';

class ApiClient {
  static final String baseUrl = EnvConfig.baseUrl;

  static Map<String, String> _getHeaders() {
    final token = LocalStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String path) async {
    final url = Uri.parse('$baseUrl$path');
    return await http.get(url, headers: _getHeaders());
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    return await http.post(
      url,
      headers: _getHeaders(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    return await http.put(
      url,
      headers: _getHeaders(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String path) async {
    final url = Uri.parse('$baseUrl$path');
    return await http.delete(url, headers: _getHeaders());
  }
}
