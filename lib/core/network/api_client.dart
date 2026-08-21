import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _httpClient = http.Client();
  final ValueNotifier<String> baseUrlNotifier = ValueNotifier<String>('');

  String? _customBaseUrl;

  /// Default URL from build configuration / environment
  String get defaultBaseUrl {
    String url = AppConstants.baseUrlLocal;
    if (defaultTargetPlatform == TargetPlatform.android &&
        (url.contains('localhost') || url.contains('127.0.0.1'))) {
      url = AppConstants.baseUrlAndroidEmulator;
    }
    return _cleanUrl(url);
  }

  /// Current active Base URL (custom saved URL takes precedence over default)
  String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    return defaultBaseUrl;
  }

  String _cleanUrl(String url) {
    String cleaned = url.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  /// Initialize and load saved Base URL from local storage
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(AppConstants.keyCustomBaseUrl);
      if (saved != null && saved.isNotEmpty) {
        _customBaseUrl = _cleanUrl(saved);
      } else {
        _customBaseUrl = null;
      }
    } catch (_) {
      _customBaseUrl = null;
    }
    baseUrlNotifier.value = baseUrl;
  }

  /// Update the Base URL dynamically at runtime
  Future<void> setBaseUrl(String newUrl) async {
    final cleaned = _cleanUrl(newUrl);
    _customBaseUrl = cleaned;
    baseUrlNotifier.value = cleaned;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyCustomBaseUrl, cleaned);
    } catch (_) {}
  }

  /// Reset to the default Base URL from build environment
  Future<void> resetToDefault() async {
    _customBaseUrl = null;
    baseUrlNotifier.value = defaultBaseUrl;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyCustomBaseUrl);
    } catch (_) {}
  }

  /// Test connectivity to a candidate URL before saving
  Future<bool> testUrl(String candidateUrl) async {
    try {
      final cleaned = _cleanUrl(candidateUrl);
      final uri = Uri.parse('$cleaned/health');
      final response =
          await _httpClient.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Check if the current backend is running and healthy
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response =
          await _httpClient.get(uri).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send GET request
  Future<http.Response> get(
    String endpoint, {
    String? token,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    return await _httpClient.get(uri, headers: headers).timeout(timeout);
  }

  /// Send standard POST request
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/event-stream',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    return await _httpClient
        .post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(timeout);
  }

  /// Send streaming POST request for SSE (Server-Sent Events)
  Future<http.StreamedResponse> sendStreamed(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final request = http.Request('POST', uri);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream, application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    });
    if (body != null) {
      request.body = jsonEncode(body);
    }

    return await _httpClient.send(request);
  }
}
