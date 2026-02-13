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
      final response = await _dio.get('/riders/profile');
      _profile = RiderProfile.fromJson(response.data);
      _isLoading = false;
      notifyListeners();
    } on DioException catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get profile as a raw map (used by profile screen).
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await _dio.get('/riders/profile');
      _profile = RiderProfile.fromJson(response.data);
      notifyListeners();
      return response.data;
    } catch (e) {
      return null;
    }
  }

  /// Toggle online/offline status.
  Future<bool> toggleOnlineStatus() async {
    if (_profile == null || !_profile!.isApproved) return false;

    _isToggling = true;
    notifyListeners();

    try {
      final newStatus = !_profile!.isOnline;
      final response = await _dio.put('/riders/online', data: {
        'online': newStatus,
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
      await _dio.put('/riders/location', data: {
        'lat': lat,
        'lng': lng,
      });
    } catch (_) {}
  }

  /// Upload a document (SELFIE, RIDER_LICENCE, INSURANCE_CERTIFICATE, BIKE_*).
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
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
        if (insurerName != null) 'insurerName': insurerName,
        if (policyNumber != null) 'policyNumber': policyNumber,
        if (expiryDate != null) 'expiryDate': expiryDate,
      });

      await _dio.post('/riders/documents/$type', data: formData);

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
    required String model,
    required String plateNumber,
    String? make,
    String? color,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _dio.post('/riders/vehicle', data: {
        'model': model,
        'plateNumber': plateNumber,
        if (make != null) 'make': make,
        if (color != null) 'color': color,
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

  /// Get insurance expiry warning.
  Future<Map<String, dynamic>?> getInsuranceWarning() async {
    try {
      final response = await _dio.get('/riders/insurance-warning');
      return response.data;
    } catch (_) {
      return null;
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
