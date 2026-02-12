import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/models.dart';

class TripService extends ChangeNotifier {
  Trip? _currentTrip;
  FareEstimate? _fareEstimate;
  List<Trip> _tripHistory = [];
  bool _isLoading = false;
  String? _error;

  Trip? get currentTrip => _currentTrip;
  FareEstimate? get fareEstimate => _fareEstimate;
  List<Trip> get tripHistory => _tripHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get fare estimate for a trip
  Future<FareEstimate?> getFareEstimate({
    required LatLng pickup,
    required LatLng destination,
    required TripType type,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiConfig.dio.post('/trips/estimate', data: {
        'pickup': pickup.toJson(),
        'destination': destination.toJson(),
        'type': type == TripType.DELIVERY ? 'DELIVERY' : 'RIDE',
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fareEstimate = FareEstimate.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
        return _fareEstimate;
      }

      _error = 'Could not get fare estimate';
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Request a new trip
  Future<Trip?> requestTrip({
    required TripLocation pickup,
    required TripLocation destination,
    required TripType type,
    DeliveryDetails? deliveryDetails,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = {
        'pickup': pickup.toJson(),
        'destination': destination.toJson(),
        'type': type == TripType.DELIVERY ? 'DELIVERY' : 'RIDE',
      };

      if (deliveryDetails != null) {
        data['deliveryDetails'] = deliveryDetails.toJson();
      }

      final response = await ApiConfig.dio.post('/trips', data: data);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _currentTrip = Trip.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
        return _currentTrip;
      }

      _error = 'Could not request trip';
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Get current active trip
  Future<Trip?> getCurrentTrip() async {
    try {
      final response = await ApiConfig.dio.get('/trips/current');

      if (response.statusCode == 200 && response.data != null) {
        _currentTrip = Trip.fromJson(response.data);
        notifyListeners();
        return _currentTrip;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get trip by ID
  Future<Trip?> getTripById(String tripId) async {
    try {
      final response = await ApiConfig.dio.get('/trips/$tripId');

      if (response.statusCode == 200) {
        return Trip.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Cancel a trip
  Future<bool> cancelTrip(String tripId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response =
          await ApiConfig.dio.post('/trips/$tripId/cancel');

      if (response.statusCode == 200) {
        _currentTrip = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }

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

  /// Rate a trip
  Future<bool> rateTrip(String tripId, int stars, {String? comment}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = <String, dynamic>{'rating': stars};
      if (comment != null && comment.isNotEmpty) {
        data['comment'] = comment;
      }

      final response =
          await ApiConfig.dio.post('/trips/$tripId/rate', data: data);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (_currentTrip != null && _currentTrip!.id == tripId) {
          _currentTrip =
              _currentTrip!.copyWith(rating: stars, ratingComment: comment);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }

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

  /// Send SOS alert
  Future<bool> sendSos(String tripId) async {
    try {
      final response = await ApiConfig.dio.post('/trips/$tripId/sos');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// Load trip history
  Future<void> loadTripHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiConfig.dio.get('/trips/history');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : (response.data['trips'] ?? []);
        _tripHistory = data.map((json) => Trip.fromJson(json)).toList();
      }
    } catch (e) {
      _error = _extractError(e);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Update current trip from socket event
  void updateTripFromSocket(Map<String, dynamic> data) {
    if (data.containsKey('status')) {
      final status = Trip.fromJson(data).status;
      if (_currentTrip != null) {
        _currentTrip = _currentTrip!.copyWith(
          status: status,
          rider: data['rider'] != null ? Rider.fromJson(data['rider']) : null,
          fare: data['fare'] != null ? (data['fare']).toDouble() : null,
          shareCode: data['shareCode'] ?? data['share_code'],
        );
      } else {
        _currentTrip = Trip.fromJson(data);
      }
      notifyListeners();
    }
  }

  void clearCurrentTrip() {
    _currentTrip = null;
    _fareEstimate = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _extractError(dynamic e) {
    try {
      final dioError = e as dynamic;
      if (dioError.response?.data != null) {
        final data = dioError.response.data;
        if (data is Map) {
          return data['message'] ?? data['error'] ?? 'An error occurred';
        }
      }
    } catch (_) {}
    return 'Connection error. Please try again.';
  }
}
