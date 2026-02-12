import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart' as models;

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  bool _permissionGranted = false;

  // Default center: Mufulira, Zambia
  static const double defaultLat = -12.5432;
  static const double defaultLng = 28.2311;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get permissionGranted => _permissionGranted;

  models.LatLng get currentLatLng {
    if (_currentPosition != null) {
      return models.LatLng(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );
    }
    return models.LatLng(latitude: defaultLat, longitude: defaultLng);
  }

  /// Check and request location permissions
  Future<bool> checkPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _error = 'Location services are disabled. Please enable them.';
        notifyListeners();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _error = 'Location permission denied.';
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _error =
            'Location permissions are permanently denied. Please enable them in settings.';
        notifyListeners();
        return false;
      }

      _permissionGranted = true;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error checking location permissions.';
      notifyListeners();
      return false;
    }
  }

  /// Get the current GPS location
  Future<Position?> getCurrentLocation() async {
    _isLoading = true;
    notifyListeners();

    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _error = null;
      _isLoading = false;
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      _error = 'Failed to get current location.';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Calculate distance between two points in meters
  double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
