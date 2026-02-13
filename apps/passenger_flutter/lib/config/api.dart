import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // Toggle this to switch between local dev and Render deployment
  static const bool useProduction = false;

  static const String _renderHost = 'ridesure-api.onrender.com';
  static const String _localHost = kIsWeb ? 'localhost' : '10.0.2.2';

  static String get baseUrl => useProduction
      ? 'https://$_renderHost/api'
      : 'http://$_localHost:3000/api';
  static String get socketUrl => useProduction
      ? 'https://$_renderHost/ws'
      : 'http://$_localHost:3000/ws';
  static String get shareBaseUrl => useProduction
      ? 'https://$_renderHost/api/trips/share'
      : 'http://$_localHost:3000/api/trips/share';

  static Dio? _dio;

  static Dio get dio {
    _dio ??= _createDio();
    return _dio!;
  }

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(JwtInterceptor());
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[API] $obj'),
    ));

    return dio;
  }
}

class JwtInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid - clear stored token
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('user_data');
    }
    handler.next(err);
  }
}
