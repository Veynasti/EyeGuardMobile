import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService extends ChangeNotifier {
  static const String baseUrl = 'https://eye-guard-api.vercel.app';
  
  String? _token;
  String? get token => _token;

  ApiService() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    notifyListeners();
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    notifyListeners();
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('permissions_onboarding_completed');
    notifyListeners();
  }

  // General request wrapper for easy logging
  Future<http.Response> _sendRequest(
    String method,
    String path, {
    Map<String, String>? customHeaders,
    Object? body,
  }) async {
    final url = '$baseUrl$path';
    
    // Prepare headers
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    String? requestBodyStr;
    if (body != null) {
      requestBodyStr = jsonEncode(body);
    }

    http.Response response;
    
    if (method == 'POST') {
        response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: requestBodyStr,
        );
      } else if (method == 'GET') {
        response = await http.get(
          Uri.parse(url),
          headers: headers,
        );
      } else if (method == 'PATCH') {
        response = await http.patch(
          Uri.parse(url),
          headers: headers,
          body: requestBodyStr,
        );
      } else if (method == 'DELETE') {
        response = await http.delete(
          Uri.parse(url),
          headers: headers,
          body: requestBodyStr,
        );
      } else {
        throw Exception('Unsupported HTTP method: $method');
      }

      return response;
  }

  // Endpoints:
  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await _sendRequest('POST', '/api/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
    });
    return {
      'status': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otpCode) async {
    final response = await _sendRequest('POST', '/api/auth/verify-otp', body: {
      'email': email,
      'otp_code': otpCode,
    });
    return {
      'status': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _sendRequest('POST', '/api/auth/login', body: {
      'email': email,
      'password': password,
    });
    final Map<String, dynamic> responseBody = jsonDecode(response.body);
    if (response.statusCode == 200 && responseBody['token'] != null) {
      await _saveToken(responseBody['token']);
    }
    return {
      'status': response.statusCode,
      'body': responseBody,
    };
  }

  Future<Map<String, dynamic>> resendOtp(String email) async {
    final response = await _sendRequest('POST', '/api/auth/resend-otp', body: {
      'email': email,
    });
    return {
      'status': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _sendRequest('POST', '/api/auth/forgot-password', body: {
      'email': email,
    });
    return {
      'status': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  Future<Map<String, dynamic>> resetPassword(String email, String otpCode, String newPassword) async {
    final response = await _sendRequest('POST', '/api/auth/reset-password', body: {
      'email': email,
      'otp_code': otpCode,
      'new_password': newPassword,
    });
    return {
      'status': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  /// Kirim batch data sensor cahaya ke backend.
  /// Format [readings]: list of { 'lux': int, 'timestamp': ISO8601 String }
  /// Sesuai endpoint POST /api/light yang mengharapkan { "readings": [...] }
  Future<Map<String, dynamic>> syncLightReadings(
    List<Map<String, dynamic>> readings,
  ) async {
    final response = await _sendRequest('POST', '/api/light', body: {
      'readings': readings,
    });
    return {
      'status': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  /// Kirim data penggunaan aplikasi ke backend.
  /// Endpoint: POST /api/usage
  /// API hanya memproses: date, totalUsageMinutes, dan apps (packageName, appName, durationMinutes).
  Future<Map<String, dynamic>> syncUsageData({
    required String date,
    required int totalUsageMinutes,
    required List<Map<String, dynamic>> apps,
  }) async {
    final response = await _sendRequest('POST', '/api/usage', body: {
      'date': date,
      'totalUsageMinutes': totalUsageMinutes,
      'apps': apps,
    });
    return {
      'status': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  Future<Map<String, dynamic>> getStats({
    String period = 'day',
    String? date,
  }) async {
    String path = '/api/stats?period=$period';
    if (date != null) {
      path += '&date=$date';
    }
    final response = await _sendRequest('GET', path);
    return {
      'status': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  Future<Map<String, dynamic>> getLightStats({
    String? date,
  }) async {
    String path = '/api/stats/light';
    if (date != null) {
      path += '?date=$date';
    }
    final response = await _sendRequest('GET', path);
    return {
      'status': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  /// Mengambil data profil lengkap pengguna saat ini.
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _sendRequest('GET', '/api/profile/me');
    return {
      'status': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  /// Memperbarui nama dan/atau password pengguna.
  /// Jika [newPassword] diisi, [currentPassword] juga wajib diisi.
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? currentPassword,
    String? newPassword,
  }) async {
    final Map<String, dynamic> body = {};
    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
    }
    if (currentPassword != null && currentPassword.isNotEmpty) {
      body['currentPassword'] = currentPassword;
    }
    if (newPassword != null && newPassword.isNotEmpty) {
      body['newPassword'] = newPassword;
    }

    final response = await _sendRequest('PATCH', '/api/profile/me', body: body);
    return {
      'status': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  /// Menghapus akun pengguna dari database. Memerlukan konfirmasi password saat ini.
  Future<Map<String, dynamic>> deleteAccount(String password) async {
    final response = await _sendRequest('DELETE', '/api/profile/me', body: {
      'password': password,
    });
    return {
      'status': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }
}
