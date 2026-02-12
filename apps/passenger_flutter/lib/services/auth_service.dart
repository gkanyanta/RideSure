import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api.dart';
import '../models/models.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _error;
  String? _pendingPhone;

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _currentUser != null;
  String? get pendingPhone => _pendingPhone;

  AuthService() {
    _loadStoredAuth();
  }

  Future<void> _loadStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    final userData = prefs.getString('user_data');

    if (_token != null && userData != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(userData));
        notifyListeners();
      } catch (e) {
        await _clearAuth();
      }
    }
  }

  Future<bool> requestOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiConfig.dio.post('/auth/otp/request', data: {
        'phone': phone,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        _pendingPhone = phone;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Failed to send OTP. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiConfig.dio.post('/auth/otp/verify', data: {
        'phone': phone,
        'code': code,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        _token = data['access_token'] ?? data['token'];
        _currentUser = User.fromJson(data['user']);

        await _storeAuth();
        _pendingPhone = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Invalid OTP code. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _clearAuth();
    notifyListeners();
  }

  Future<void> _storeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString('access_token', _token!);
    }
    if (_currentUser != null) {
      await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));
    }
  }

  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_data');
    _token = null;
    _currentUser = null;
    _pendingPhone = null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      try {
        final dioError = e as dynamic;
        if (dioError.response?.data != null) {
          final data = dioError.response.data;
          if (data is Map) {
            return data['message'] ?? data['error'] ?? 'An error occurred';
          }
        }
      } catch (_) {}
    }
    return 'Connection error. Please check your internet.';
  }
}
