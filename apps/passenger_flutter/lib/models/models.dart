class User {
  final String id;
  final String phone;
  final String? name;
  final String? email;
  final String role;
  final String? profilePhoto;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    this.role = 'PASSENGER',
    this.profilePhoto,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'],
      email: json['email'],
      role: json['role'] ?? 'PASSENGER',
      profilePhoto: json['profilePhoto'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'email': email,
        'role': role,
        'profilePhoto': profilePhoto,
      };
}

class Rider {
  final String id;
  final String? name;
  final String? phone;
  final String? profilePhoto;
  final double avgRating;
  final int totalTrips;
  final bool isOnline;
  final Vehicle? vehicle;
  final Map<String, dynamic>? user;

  Rider({
    required this.id,
    this.name,
    this.phone,
    this.profilePhoto,
    this.avgRating = 0.0,
    this.totalTrips = 0,
    this.isOnline = false,
    this.vehicle,
    this.user,
  });

  String get displayName => user?['name'] ?? name ?? 'Rider';
  String get displayPhone => user?['phone'] ?? phone ?? '';

  factory Rider.fromJson(Map<String, dynamic> json) {
    return Rider(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? json['user']?['name'],
      phone: json['phone'] ?? json['user']?['phone'],
      profilePhoto: json['profilePhoto'],
      avgRating: (json['avgRating'] ?? json['rating'] ?? 0).toDouble(),
      totalTrips: json['totalTrips'] ?? json['tripCount'] ?? 0,
      isOnline: json['isOnline'] ?? false,
      vehicle:
          json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
      user: json['user'] is Map<String, dynamic> ? json['user'] : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': displayName,
        'phone': displayPhone,
        'profilePhoto': profilePhoto,
        'avgRating': avgRating,
        'totalTrips': totalTrips,
        'vehicle': vehicle?.toJson(),
      };
}

class Vehicle {
  final String? make;
  final String? model;
  final String? color;
  final String? plateNumber;

  Vehicle({
    this.make,
    this.model,
    this.color,
    this.plateNumber,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      make: json['make'],
      model: json['model'],
      color: json['color'],
      plateNumber: json['plateNumber'] ?? json['plate_number'],
    );
  }

  Map<String, dynamic> toJson() => {
        'make': make,
        'model': model,
        'color': color,
        'plateNumber': plateNumber,
      };

  String get displayName {
    final parts = <String>[];
    if (color != null) parts.add(color!);
    if (make != null) parts.add(make!);
    if (model != null) parts.add(model!);
    return parts.isEmpty ? 'Unknown Vehicle' : parts.join(' ');
  }
}

enum TripType { RIDE, DELIVERY }

enum TripStatus {
  SEARCHING,
  REQUESTED,
  OFFERED,
  ACCEPTED,
  ARRIVED,
  IN_PROGRESS,
  COMPLETED,
  CANCELLED,
  NO_RIDERS,
}

class LatLng {
  final double latitude;
  final double longitude;

  LatLng({required this.latitude, required this.longitude});

  factory LatLng.fromJson(Map<String, dynamic> json) {
    return LatLng(
      latitude: (json['latitude'] ?? json['lat'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? json['lng'] ?? json['lon'] ?? 0)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };
}

class FareEstimate {
  final double minFare;
  final double maxFare;
  final double estimatedDistance;
  final int estimatedDuration;
  final String currency;

  FareEstimate({
    required this.minFare,
    required this.maxFare,
    this.estimatedDistance = 0,
    this.estimatedDuration = 0,
    this.currency = 'ZMW',
  });

  factory FareEstimate.fromJson(Map<String, dynamic> json) {
    return FareEstimate(
      minFare: (json['minFare'] ?? json['estimatedFareLow'] ?? json['min_fare'] ?? 0).toDouble(),
      maxFare: (json['maxFare'] ?? json['estimatedFareHigh'] ?? json['max_fare'] ?? 0).toDouble(),
      estimatedDistance:
          (json['estimatedDistance'] ?? json['distance'] ?? json['estimated_distance'] ?? 0)
              .toDouble(),
      estimatedDuration: json['estimatedDuration'] ??
          json['estimated_duration'] ??
          0,
      currency: json['currency'] ?? 'ZMW',
    );
  }

  String get displayRange => 'K${minFare.toStringAsFixed(2)} - K${maxFare.toStringAsFixed(2)}';
}

/// Trip model matching the backend flat JSON format.
class Trip {
  final String id;
  final TripType type;
  final TripStatus status;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final String? pickupLandmark;
  final double destinationLat;
  final double destinationLng;
  final String destinationAddress;
  final String? destinationLandmark;
  final double? estimatedDistance;
  final double? estimatedFareLow;
  final double? estimatedFareHigh;
  final double? actualFare;
  final String? packageType;
  final String? packageNotes;
  final String? shareCode;
  final String? cancelReason;
  final Rider? rider;
  final Map<String, dynamic>? passenger;
  final DateTime? createdAt;
  final DateTime? completedAt;
  // Rating data (from included ratings relation)
  final int? ratingScore;
  final String? ratingComment;

  Trip({
    required this.id,
    required this.type,
    required this.status,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    this.pickupLandmark,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
    this.destinationLandmark,
    this.estimatedDistance,
    this.estimatedFareLow,
    this.estimatedFareHigh,
    this.actualFare,
    this.packageType,
    this.packageNotes,
    this.shareCode,
    this.cancelReason,
    this.rider,
    this.passenger,
    this.createdAt,
    this.completedAt,
    this.ratingScore,
    this.ratingComment,
  });

  bool get isDelivery => type == TripType.DELIVERY;

  String get passengerName => passenger?['name'] ?? passenger?['phone'] ?? 'Passenger';
  String get riderName => rider?.displayName ?? 'Rider';

  String get fareRange {
    if (estimatedFareLow != null && estimatedFareHigh != null) {
      return 'K${estimatedFareLow!.toStringAsFixed(0)} - K${estimatedFareHigh!.toStringAsFixed(0)}';
    }
    if (actualFare != null) return 'K${actualFare!.toStringAsFixed(0)}';
    return 'Calculating...';
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    // Extract rating from nested ratings list if present
    int? ratingScore;
    String? ratingComment;
    if (json['ratings'] is List && (json['ratings'] as List).isNotEmpty) {
      final rating = (json['ratings'] as List).first;
      ratingScore = rating['score'];
      ratingComment = rating['comment'];
    }

    return Trip(
      id: json['id'] ?? json['_id'] ?? '',
      type: _parseTripType(json['type']),
      status: _parseTripStatus(json['status']),
      pickupLat: (json['pickupLat'] as num?)?.toDouble() ?? 0,
      pickupLng: (json['pickupLng'] as num?)?.toDouble() ?? 0,
      pickupAddress: json['pickupAddress'] ?? '',
      pickupLandmark: json['pickupLandmark'],
      destinationLat: (json['destinationLat'] as num?)?.toDouble() ?? 0,
      destinationLng: (json['destinationLng'] as num?)?.toDouble() ?? 0,
      destinationAddress: json['destinationAddress'] ?? '',
      destinationLandmark: json['destinationLandmark'],
      estimatedDistance: (json['estimatedDistance'] as num?)?.toDouble(),
      estimatedFareLow: (json['estimatedFareLow'] as num?)?.toDouble(),
      estimatedFareHigh: (json['estimatedFareHigh'] as num?)?.toDouble(),
      actualFare: (json['actualFare'] as num?)?.toDouble(),
      packageType: json['packageType'],
      packageNotes: json['packageNotes'],
      shareCode: json['shareCode'],
      cancelReason: json['cancelReason'],
      rider: json['rider'] != null ? Rider.fromJson(json['rider']) : null,
      passenger: json['passenger'] is Map<String, dynamic> ? json['passenger'] : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
      ratingScore: ratingScore,
      ratingComment: ratingComment,
    );
  }

  static TripType _parseTripType(String? type) {
    switch (type?.toUpperCase()) {
      case 'DELIVERY':
        return TripType.DELIVERY;
      default:
        return TripType.RIDE;
    }
  }

  static TripStatus _parseTripStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'SEARCHING':
        return TripStatus.SEARCHING;
      case 'REQUESTED':
        return TripStatus.REQUESTED;
      case 'OFFERED':
        return TripStatus.OFFERED;
      case 'ACCEPTED':
        return TripStatus.ACCEPTED;
      case 'ARRIVED':
        return TripStatus.ARRIVED;
      case 'IN_PROGRESS':
        return TripStatus.IN_PROGRESS;
      case 'COMPLETED':
        return TripStatus.COMPLETED;
      case 'CANCELLED':
        return TripStatus.CANCELLED;
      case 'NO_RIDERS':
        return TripStatus.NO_RIDERS;
      default:
        return TripStatus.SEARCHING;
    }
  }

  Trip copyWith({
    TripStatus? status,
    Rider? rider,
    double? actualFare,
    String? shareCode,
    int? ratingScore,
    String? ratingComment,
  }) {
    return Trip(
      id: id,
      type: type,
      status: status ?? this.status,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      pickupAddress: pickupAddress,
      pickupLandmark: pickupLandmark,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      destinationAddress: destinationAddress,
      destinationLandmark: destinationLandmark,
      estimatedDistance: estimatedDistance,
      estimatedFareLow: estimatedFareLow,
      estimatedFareHigh: estimatedFareHigh,
      actualFare: actualFare ?? this.actualFare,
      packageType: packageType,
      packageNotes: packageNotes,
      shareCode: shareCode ?? this.shareCode,
      cancelReason: cancelReason,
      rider: rider ?? this.rider,
      passenger: passenger,
      createdAt: createdAt,
      completedAt: completedAt,
      ratingScore: ratingScore ?? this.ratingScore,
      ratingComment: ratingComment ?? this.ratingComment,
    );
  }
}

class PlaceResult {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final double? latitude;
  final double? longitude;

  PlaceResult({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.latitude,
    this.longitude,
  });

  factory PlaceResult.fromAutocomplete(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] ?? {};
    return PlaceResult(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structured['main_text'] ?? json['description'] ?? '',
      secondaryText: structured['secondary_text'] ?? '',
    );
  }

  PlaceResult withCoordinates(double lat, double lng) {
    return PlaceResult(
      placeId: placeId,
      description: description,
      mainText: mainText,
      secondaryText: secondaryText,
      latitude: lat,
      longitude: lng,
    );
  }

  LatLng? toLatLng() {
    if (latitude != null && longitude != null) {
      return LatLng(latitude: latitude!, longitude: longitude!);
    }
    return null;
  }
}

class DeliveryDetails {
  final String packageType;
  final String? notes;

  DeliveryDetails({
    required this.packageType,
    this.notes,
  });

  factory DeliveryDetails.fromJson(Map<String, dynamic> json) {
    return DeliveryDetails(
      packageType: json['packageType'] ?? json['package_type'] ?? '',
      notes: json['notes'] ?? json['packageNotes'],
    );
  }

  Map<String, dynamic> toJson() => {
        'packageType': packageType,
        'notes': notes,
      };
}
