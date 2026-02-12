import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../config/api.dart';
import '../models/user.dart';
import 'auth_service.dart';

class TripService extends ChangeNotifier {
  final Dio _dio = ApiConfig.createDio();

  AuthService? _auth;
  Trip? _activeTrip;
  List<Trip> _tripHistory = [];
  bool _isLoading = false;
  String? _error;

  Trip? get activeTrip => _activeTrip;
  List<Trip> get tripHistory => _tripHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveTrip => _activeTrip != null;

  void updateAuth(AuthService auth) {
    _auth = auth;
  }

  /// Set active trip from socket event or API response.
  void setActiveTrip(Trip? trip) {
    _activeTrip = trip;
    notifyListeners();
  }

  /// Fetch current active trip if any.
  Future<void> fetchActiveTrip() async {
    try {
      final response = await _dio.get('/trips/active');
      if (response.data != null && response.data['id'] != null) {
        _activeTrip = Trip.fromJson(response.data);
      } else {
        _activeTrip = null;
      }
      notifyListeners();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _activeTrip = null;
        notifyListeners();
      }
    }
  }

  /// Accept a trip offer.
  Future<bool> acceptTrip(String tripId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.post('/trips/$tripId/accept');
      _activeTrip = Trip.fromJson(response.data);
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

  /// Reject a trip offer.
  Future<bool> rejectTrip(String tripId) async {
    try {
      await _dio.post('/trips/$tripId/reject');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Mark arrived at pickup.
  Future<bool> markArrived() async {
    if (_activeTrip == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final response =
          await _dio.post('/trips/${_activeTrip!.id}/arrived');
      _activeTrip = Trip.fromJson(response.data);
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

  /// Start the trip.
  Future<bool> startTrip() async {
    if (_activeTrip == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final response =
          await _dio.post('/trips/${_activeTrip!.id}/start');
      _activeTrip = Trip.fromJson(response.data);
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

  /// Complete the trip.
  Future<bool> completeTrip() async {
    if (_activeTrip == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final response =
          await _dio.post('/trips/${_activeTrip!.id}/complete');
      _activeTrip = null;
      _isLoading = false;
      notifyListeners();
      // Refresh history
      fetchTripHistory();
      return true;
    } on DioException catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Upload delivery photo (pickup or dropoff).
  Future<bool> uploadDeliveryPhoto({
    required String photoType, // 'pickup' or 'dropoff'
    required File file,
  }) async {
    if (_activeTrip == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final formData = FormData.fromMap({
        'type': photoType,
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await _dio.post(
        '/trips/${_activeTrip!.id}/photo',
        data: formData,
      );

      _activeTrip = Trip.fromJson(response.data);
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

  /// Fetch trip history.
  Future<void> fetchTripHistory({int page = 1, int limit = 20}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.get('/trips/history', queryParameters: {
        'page': page,
        'limit': limit,
      });

      final List data = response.data['trips'] ?? response.data ?? [];
      _tripHistory = data.map((t) => Trip.fromJson(t)).toList();
      _isLoading = false;
      notifyListeners();
    } on DioException catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancel active trip.
  Future<bool> cancelTrip(String reason) async {
    if (_activeTrip == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _dio.post('/trips/${_activeTrip!.id}/cancel', data: {
        'reason': reason,
      });
      _activeTrip = null;
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
    return 'Something went wrong. Please try again.';
  }
}
