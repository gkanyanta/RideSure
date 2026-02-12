import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  final Dio _dio = ApiConfig.createDio();

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;
  String? _pendingPhone;

  User? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get pendingPhone => _pendingPhone;

  /// Load stored token on app start.
  Future<void> loadStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userJson = prefs.getString('auth_user');
    if (_token != null && _token!.isNotEmpty) {
      // Try to parse stored user
      if (userJson != null) {
        try {
          // Simple parse - in production you'd use dart:convert
          _user = null; // Will be fetched from profile
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  /// Request OTP for phone number.
  Future<bool> requestOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _dio.post('/auth/otp/request', data: {
        'phone': phone,
        'role': 'RIDER',
      });
      _pendingPhone = phone;
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify OTP and get JWT token.
  Future<bool> verifyOtp(String phone, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.post('/auth/otp/verify', data: {
        'phone': phone,
        'code': code,
        'role': 'RIDER',
      });

      final data = response.data;
      _token = data['token'] ?? data['accessToken'];
      if (data['user'] != null) {
        _user = User.fromJson(data['user']);
      }

      // Store token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);

      _isLoading = false;
      _pendingPhone = null;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout and clear stored data.
  Future<void> logout() async {
    _token = null;
    _user = null;
    _pendingPhone = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    notifyListeners();
  }

  /// Update user profile info.
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.patch('/users/me', data: {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (email != null) 'email': email,
      });

      if (response.data['user'] != null) {
        _user = User.fromJson(response.data['user']);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _extractError(DioException e) {
    if (e.response?.data != null && e.response!.data is Map) {
      return e.response!.data['message'] ?? 'Something went wrong';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Check your internet.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot connect to server. Check your internet.';
    }
    return 'Something went wrong. Please try again.';
  }
}
