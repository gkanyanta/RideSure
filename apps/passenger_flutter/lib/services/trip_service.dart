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

  /// Get fare estimate for a trip.
  /// Backend expects flat lat/lng fields, not nested objects.
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
        'pickupLat': pickup.latitude,
        'pickupLng': pickup.longitude,
        'destinationLat': destination.latitude,
        'destinationLng': destination.longitude,
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

  /// Request a new trip.
  /// Backend expects flat fields matching CreateTripDto.
  Future<Trip?> requestTrip({
    required LatLng pickup,
    required LatLng destination,
    required String pickupAddress,
    required String destinationAddress,
    required TripType type,
    String? pickupLandmark,
    String? destinationLandmark,
    String? packageType,
    String? packageNotes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = <String, dynamic>{
        'pickupLat': pickup.latitude,
        'pickupLng': pickup.longitude,
        'pickupAddress': pickupAddress,
        'destinationLat': destination.latitude,
        'destinationLng': destination.longitude,
        'destinationAddress': destinationAddress,
        'type': type == TripType.DELIVERY ? 'DELIVERY' : 'RIDE',
      };

      if (pickupLandmark != null) data['pickupLandmark'] = pickupLandmark;
      if (destinationLandmark != null) data['destinationLandmark'] = destinationLandmark;
      if (packageType != null) data['packageType'] = packageType;
      if (packageNotes != null) data['packageNotes'] = packageNotes;

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

  /// Get current active trip by fetching passenger's trips and finding active one.
  Future<Trip?> getCurrentTrip() async {
    try {
      final response = await ApiConfig.dio.get('/trips/my');

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data is List
            ? response.data
            : [];
        // Find the most recent active trip
        for (final tripJson in data) {
          final status = tripJson['status']?.toString().toUpperCase();
          if (status == 'REQUESTED' ||
              status == 'OFFERED' ||
              status == 'ACCEPTED' ||
              status == 'ARRIVED' ||
              status == 'IN_PROGRESS') {
            _currentTrip = Trip.fromJson(tripJson);
            notifyListeners();
            return _currentTrip;
          }
        }
        // Check for recently completed trip that needs rating
        for (final tripJson in data) {
          final status = tripJson['status']?.toString().toUpperCase();
          if (status == 'COMPLETED') {
            final trip = Trip.fromJson(tripJson);
            if (trip.ratingScore == null) {
              _currentTrip = trip;
              notifyListeners();
              return _currentTrip;
            }
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get trip by ID.
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

  /// Cancel a trip. Backend uses PATCH, not POST.
  Future<bool> cancelTrip(String tripId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiConfig.dio.patch('/trips/$tripId/cancel', data: {
        'reason': 'Cancelled by passenger',
      });

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

  /// Rate a trip. Backend expects 'score', not 'rating'.
  Future<bool> rateTrip(String tripId, int stars, {String? comment}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = <String, dynamic>{'score': stars};
      if (comment != null && comment.isNotEmpty) {
        data['comment'] = comment;
      }

      final response =
          await ApiConfig.dio.post('/trips/$tripId/rate', data: data);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (_currentTrip != null && _currentTrip!.id == tripId) {
          _currentTrip =
              _currentTrip!.copyWith(ratingScore: stars, ratingComment: comment);
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

  /// Send SOS alert.
  Future<bool> sendSos(String tripId, {String? description}) async {
    try {
      final response = await ApiConfig.dio.post('/trips/$tripId/sos', data: {
        'description': description ?? 'SOS triggered by passenger',
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// Load trip history. Backend endpoint is /trips/my for passengers.
  Future<void> loadTripHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiConfig.dio.get('/trips/my');

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

  /// Get raw trip list for history screen.
  Future<List<dynamic>> getMyTrips() async {
    try {
      final response = await ApiConfig.dio.get('/trips/my');
      return response.data is List ? response.data : [];
    } catch (e) {
      return [];
    }
  }

  /// Update current trip from socket event.
  void updateTripFromSocket(Map<String, dynamic> data) {
    if (data.containsKey('status') || data.containsKey('id')) {
      try {
        final trip = Trip.fromJson(data);
        if (_currentTrip != null) {
          _currentTrip = _currentTrip!.copyWith(
            status: trip.status,
            rider: trip.rider ?? _currentTrip!.rider,
            actualFare: trip.actualFare,
            shareCode: trip.shareCode ?? _currentTrip!.shareCode,
          );
        } else {
          _currentTrip = trip;
        }
        notifyListeners();
      } catch (_) {}
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
