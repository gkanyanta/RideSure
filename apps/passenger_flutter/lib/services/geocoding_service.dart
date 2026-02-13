import 'package:dio/dio.dart';
import '../models/models.dart';

class GeocodingService {
  static const String _apiKey = 'AIzaSyAtD_QQAobmxgzhhZv7o59OCvWVMiWQQsE';

  // Copperbelt region bias (Mufulira area)
  static const double _biasLat = -12.54;
  static const double _biasLng = 28.23;
  static const int _biasRadius = 50000; // 50km

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Search places using Google Places Autocomplete API.
  /// Returns predictions with placeId + description (no coordinates yet).
  Future<List<PlaceResult>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {
          'input': query,
          'key': _apiKey,
          'components': 'country:zm',
          'location': '$_biasLat,$_biasLng',
          'radius': _biasRadius,
        },
      );

      if (response.data['status'] == 'OK') {
        final predictions = response.data['predictions'] as List;
        return predictions
            .map((p) => PlaceResult.fromAutocomplete(p))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get place details (coordinates) for a selected place.
  Future<PlaceResult?> getPlaceDetails(PlaceResult place) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': place.placeId,
          'fields': 'geometry',
          'key': _apiKey,
        },
      );

      if (response.data['status'] == 'OK') {
        final location =
            response.data['result']['geometry']['location'];
        return place.withCoordinates(
          (location['lat'] as num).toDouble(),
          (location['lng'] as num).toDouble(),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Reverse geocode coordinates to a human-readable address.
  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': _apiKey,
        },
      );

      if (response.data['status'] == 'OK') {
        final results = response.data['results'] as List;
        if (results.isNotEmpty) {
          return results[0]['formatted_address'] ?? 'Unknown location';
        }
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }
}
