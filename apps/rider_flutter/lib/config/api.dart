import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // Toggle this to switch between local dev and Render deployment
  static const bool useProduction = false;

  static const String _renderHost = 'ridesure-api.onrender.com';
  static const String _localHost = '10.0.2.2';

  static String get baseUrl => useProduction
      ? 'https://$_renderHost/api'
      : 'http://$_localHost:3000/api';
  static String get socketUrl => useProduction
      ? 'https://$_renderHost/ws'
      : 'http://$_localHost:3000/ws';

  static Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(AuthInterceptor());

    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    return dio;
  }
}

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired - could trigger logout here
      print('Auth token expired or invalid');
    }
    handler.next(err);
  }
}
