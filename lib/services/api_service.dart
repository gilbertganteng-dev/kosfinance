import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? validationErrors;

  const ApiException(this.message, {this.statusCode, this.validationErrors});

  @override
  String toString() => message;
}

/// A single HTTP client for the Laravel API. Native tokens use secure storage.
/// Web uses localStorage via SharedPreferences because WebCrypto-backed secure
/// storage requires a secure browser context (HTTPS or localhost). Production
/// web deployments should use HTTPS and apply a strict CSP to reduce XSS risk.
class ApiService {
  ApiService._();

  static const Duration _timeout = Duration(seconds: 30);
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _tokenKey = 'kosfinance_sanctum_token';
  static String? _token;

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    _token = kIsWeb
        ? (await SharedPreferences.getInstance()).getString(_tokenKey)
        : await _secureStorage.read(key: _tokenKey);
    return _token;
  }

  static Future<void> setToken(String token) async {
    _token = token;
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).setString(_tokenKey, token);
    } else {
      await _secureStorage.write(key: _tokenKey, value: token);
    }
  }

  static Future<void> clearToken() async {
    _token = null;
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).remove(_tokenKey);
    } else {
      await _secureStorage.delete(key: _tokenKey);
    }
  }

  static Uri _uri(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$apiBaseUrl/$normalizedPath');
  }

  static Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (jsonBody) headers['Content-Type'] = 'application/json';
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String path) => _send(
        () async => http.get(_uri(path), headers: await _headers()).timeout(_timeout),
      );

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) => _send(
        () async => http
            .post(_uri(path), headers: await _headers(jsonBody: true), body: jsonEncode(body))
            .timeout(_timeout),
      );

  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) => _send(
        () async => http
            .put(_uri(path), headers: await _headers(jsonBody: true), body: jsonEncode(body))
            .timeout(_timeout),
      );

  static Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) => _send(
        () async => http
            .patch(_uri(path), headers: await _headers(jsonBody: true), body: jsonEncode(body))
            .timeout(_timeout),
      );

  static Future<Map<String, dynamic>> delete(String path) => _send(
        () async => http.delete(_uri(path), headers: await _headers()).timeout(_timeout),
      );

  static Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    Uint8List? fileBytes,
    required String fileField,
    String filename = 'upload.jpg',
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll(await _headers());
    request.fields.addAll(fields);
    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(fileField, fileBytes, filename: filename));
    }

    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  static Future<Uint8List> getBytes(String path) async {
    http.Response response;
    try {
      response = await http.get(_uri(path), headers: await _headers()).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('Server tidak merespons. Periksa koneksi dan server Laravel.');
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server ($apiBaseUrl).');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponseError(response);
    }
    return response.bodyBytes;
  }

  static Future<Map<String, dynamic>> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request();
    } on TimeoutException {
      throw const ApiException('Server tidak merespons. Periksa koneksi dan server Laravel.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server ($apiBaseUrl).');
    }
    return _decode(response);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _throwResponseError(response);
      }
      throw ApiException('Respons API bukan JSON yang valid (HTTP ${response.statusCode}).', statusCode: response.statusCode);
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Format respons API tidak sesuai kontrak Laravel.', statusCode: response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawErrors = decoded['errors'];
      throw ApiException(
        _messageFrom(decoded),
        statusCode: response.statusCode,
        validationErrors: rawErrors is Map<String, dynamic> ? rawErrors : null,
      );
    }
    return decoded;
  }

  static Never _throwResponseError(http.Response response) {
    String message = 'Permintaan gagal (HTTP ${response.statusCode}).';
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) message = _messageFrom(body);
    } catch (_) {
      // Do not expose HTML stack traces or server internals to the UI.
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  static String _messageFrom(Map<String, dynamic> body) {
    final message = body['message']?.toString();
    if (message != null && message.trim().isNotEmpty) return message;
    final errors = body['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String) return value;
      }
    }
    return 'Terjadi kesalahan pada server.';
  }
}
