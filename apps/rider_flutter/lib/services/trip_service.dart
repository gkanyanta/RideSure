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

  /// Set active trip from socket event.
  void setActiveTrip(Trip? trip) {
    _activeTrip = trip;
    notifyListeners();
  }

  /// Set active trip from raw JSON (socket events).
  void setActiveTripFromJson(Map<String, dynamic> json) {
    _activeTrip = Trip.fromJson(json);
    notifyListeners();
  }

  /// Get trip details by ID.
  Future<Map<String, dynamic>?> getTripDetails(String tripId) async {
    try {
      final response = await _dio.get('/trips/$tripId');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  /// Update trip status (arrived, start, complete).
  Future<Map<String, dynamic>?> updateTripStatus(String tripId, String action) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.patch('/trips/$tripId/$action');
      final data = response.data as Map<String, dynamic>;

      if (action == 'complete') {
        _activeTrip = null;
      } else {
        _activeTrip = Trip.fromJson(data);
      }

      _isLoading = false;
      notifyListeners();
      return data;
    } on DioException catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Mark arrived at pickup.
  Future<bool> markArrived() async {
    if (_activeTrip == null) return false;
    final result = await updateTripStatus(_activeTrip!.id, 'arrived');
    return result != null;
  }

  /// Start the trip.
  Future<bool> startTrip() async {
    if (_activeTrip == null) return false;
    final result = await updateTripStatus(_activeTrip!.id, 'start');
    return result != null;
  }

  /// Complete the trip.
  Future<bool> completeTrip() async {
    if (_activeTrip == null) return false;
    final result = await updateTripStatus(_activeTrip!.id, 'complete');
    if (result != null) fetchTripHistory();
    return result != null;
  }

  /// Upload delivery photo (pickup or dropoff).
  Future<bool> uploadDeliveryPhoto(String tripId, String phase, String filePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
      });

      await _dio.post('/trips/$tripId/delivery-photo/$phase', data: formData);
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

  /// Fetch rider trip history.
  Future<void> fetchTripHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _dio.get('/trips/rider/my');
      final List data = response.data is List ? response.data : [];
      _tripHistory = data.map((t) => Trip.fromJson(t)).toList();
      _isLoading = false;
      notifyListeners();
    } on DioException catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get rider trips as raw list (used by trip history screen).
  Future<List<dynamic>> getRiderTrips() async {
    try {
      final response = await _dio.get('/trips/rider/my');
      return response.data is List ? response.data : [];
    } catch (_) {
      return [];
    }
  }

  /// Cancel active trip.
  Future<bool> cancelTrip(String reason) async {
    if (_activeTrip == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _dio.patch('/trips/${_activeTrip!.id}/cancel', data: {
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
