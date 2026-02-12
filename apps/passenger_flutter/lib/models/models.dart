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
  final String name;
  final String phone;
  final String? profilePhoto;
  final double rating;
  final int tripCount;
  final bool isVerified;
  final bool isInsured;
  final String? insuranceExpiry;
  final Vehicle? vehicle;

  Rider({
    required this.id,
    required this.name,
    required this.phone,
    this.profilePhoto,
    this.rating = 0.0,
    this.tripCount = 0,
    this.isVerified = false,
    this.isInsured = false,
    this.insuranceExpiry,
    this.vehicle,
  });

  factory Rider.fromJson(Map<String, dynamic> json) {
    return Rider(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? 'Unknown Rider',
      phone: json['phone'] ?? '',
      profilePhoto: json['profilePhoto'],
      rating: (json['rating'] ?? 0).toDouble(),
      tripCount: json['tripCount'] ?? json['trip_count'] ?? 0,
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      isInsured: json['isInsured'] ?? json['is_insured'] ?? false,
      insuranceExpiry: json['insuranceExpiry'] ?? json['insurance_expiry'],
      vehicle:
          json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'profilePhoto': profilePhoto,
        'rating': rating,
        'tripCount': tripCount,
        'isVerified': isVerified,
        'isInsured': isInsured,
        'insuranceExpiry': insuranceExpiry,
        'vehicle': vehicle?.toJson(),
      };
}

class Vehicle {
  final String? make;
  final String? model;
  final String? color;
  final String? plateNumber;
  final int? year;

  Vehicle({
    this.make,
    this.model,
    this.color,
    this.plateNumber,
    this.year,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      make: json['make'],
      model: json['model'],
      color: json['color'],
      plateNumber: json['plateNumber'] ?? json['plate_number'],
      year: json['year'],
    );
  }

  Map<String, dynamic> toJson() => {
        'make': make,
        'model': model,
        'color': color,
        'plateNumber': plateNumber,
        'year': year,
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

class TripLocation {
  final LatLng coordinates;
  final String? address;

  TripLocation({required this.coordinates, this.address});

  factory TripLocation.fromJson(Map<String, dynamic> json) {
    return TripLocation(
      coordinates: LatLng.fromJson(json['coordinates'] ?? json),
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() => {
        'coordinates': coordinates.toJson(),
        'address': address,
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
      minFare: (json['minFare'] ?? json['min_fare'] ?? 0).toDouble(),
      maxFare: (json['maxFare'] ?? json['max_fare'] ?? 0).toDouble(),
      estimatedDistance:
          (json['estimatedDistance'] ?? json['estimated_distance'] ?? 0)
              .toDouble(),
      estimatedDuration: json['estimatedDuration'] ??
          json['estimated_duration'] ??
          0,
      currency: json['currency'] ?? 'ZMW',
    );
  }

  String get displayRange => 'K${minFare.toStringAsFixed(2)} - K${maxFare.toStringAsFixed(2)}';
}

class Trip {
  final String id;
  final TripType type;
  final TripStatus status;
  final TripLocation pickup;
  final TripLocation destination;
  final Rider? rider;
  final double? fare;
  final FareEstimate? fareEstimate;
  final String? shareCode;
  final int? rating;
  final String? ratingComment;
  final DeliveryDetails? deliveryDetails;
  final DateTime? createdAt;
  final DateTime? completedAt;

  Trip({
    required this.id,
    required this.type,
    required this.status,
    required this.pickup,
    required this.destination,
    this.rider,
    this.fare,
    this.fareEstimate,
    this.shareCode,
    this.rating,
    this.ratingComment,
    this.deliveryDetails,
    this.createdAt,
    this.completedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? json['_id'] ?? '',
      type: _parseTripType(json['type']),
      status: _parseTripStatus(json['status']),
      pickup: TripLocation.fromJson(json['pickup']),
      destination: TripLocation.fromJson(json['destination']),
      rider: json['rider'] != null ? Rider.fromJson(json['rider']) : null,
      fare: json['fare'] != null ? (json['fare']).toDouble() : null,
      fareEstimate: json['fareEstimate'] != null
          ? FareEstimate.fromJson(json['fareEstimate'])
          : null,
      shareCode: json['shareCode'] ?? json['share_code'],
      rating: json['rating'],
      ratingComment: json['ratingComment'] ?? json['rating_comment'],
      deliveryDetails: json['deliveryDetails'] != null
          ? DeliveryDetails.fromJson(json['deliveryDetails'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
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
    double? fare,
    String? shareCode,
    int? rating,
    String? ratingComment,
  }) {
    return Trip(
      id: id,
      type: type,
      status: status ?? this.status,
      pickup: pickup,
      destination: destination,
      rider: rider ?? this.rider,
      fare: fare ?? this.fare,
      fareEstimate: fareEstimate,
      shareCode: shareCode ?? this.shareCode,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      deliveryDetails: deliveryDetails,
      createdAt: createdAt,
      completedAt: completedAt,
    );
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
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
        'packageType': packageType,
        'notes': notes,
      };
}
