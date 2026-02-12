import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../config/api.dart';
import '../models/user.dart';
import 'auth_service.dart';

class RiderService extends ChangeNotifier {
  final Dio _dio = ApiConfig.createDio();

  AuthService? _auth;
  RiderProfile? _profile;
  bool _isLoading = false;
  bool _isToggling = false;
  String? _error;

  RiderProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isToggling => _isToggling;
  String? get error => _error;
  bool get isOnline => _profile?.isOnline ?? false;

  void updateAuth(AuthService auth) {
    _auth = auth;
  }

  /// Fetch rider profile from API.
  Future<void> fetchProfile() async {
    if (_auth?.token == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.get('/riders/me');
      _profile = RiderProfile.fromJson(response.data);
      _isLoading = false;
      notifyListeners();
    } on DioException catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle online/offline status.
  Future<bool> toggleOnlineStatus() async {
    if (_profile == null || !_profile!.isApproved) return false;

    _isToggling = true;
    notifyListeners();

    try {
      final newStatus = !_profile!.isOnline;
      final response = await _dio.patch('/riders/me/status', data: {
        'isOnline': newStatus,
      });

      _profile = RiderProfile.fromJson(response.data);
      _isToggling = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _extractError(e);
      _isToggling = false;
      notifyListeners();
      return false;
    }
  }

  /// Update rider location.
  Future<void> updateLocation(double lat, double lng) async {
    try {
      await _dio.patch('/riders/me/location', data: {
        'latitude': lat,
        'longitude': lng,
      });
    } catch (e) {
      print('Location update failed: $e');
    }
  }

  /// Upload a document (NRC, selfie, licence, insurance).
  Future<bool> uploadDocument({
    required String type,
    required File file,
    String? insurerName,
    String? policyNumber,
    String? expiryDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final formData = FormData.fromMap({
        'type': type,
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
        if (insurerName != null) 'insurerName': insurerName,
        if (policyNumber != null) 'policyNumber': policyNumber,
        if (expiryDate != null) 'expiryDate': expiryDate,
      });

      await _dio.post('/riders/me/documents', data: formData);

      // Refresh profile to get updated document list
      await fetchProfile();
      return true;
    } on DioException catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Submit vehicle information.
  Future<bool> submitVehicle({
    required String make,
    required String model,
    required int year,
    required String color,
    required String plateNumber,
    String? engineSize,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _dio.post('/riders/me/vehicle', data: {
        'make': make,
        'model': model,
        'year': year,
        'color': color,
        'plateNumber': plateNumber,
        if (engineSize != null) 'engineSize': engineSize,
      });

      await fetchProfile();
      return true;
    } on DioException catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get earnings summary.
  Future<Map<String, dynamic>?> getEarnings({
    String period = 'week',
  }) async {
    try {
      final response = await _dio.get('/riders/me/earnings', queryParameters: {
        'period': period,
      });
      return response.data;
    } catch (e) {
      return null;
    }
  }

  String _extractError(DioException e) {
    if (e.response?.data != null && e.response!.data is Map) {
      return e.response!.data['message'] ?? 'Something went wrong';
    }
    return 'Something went wrong. Please try again.';
  }
}
