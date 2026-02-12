class User {
  final String id;
  final String phone;
  final String? firstName;
  final String? lastName;
  final String role;
  final String? email;
  final String? avatarUrl;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.phone,
    this.firstName,
    this.lastName,
    required this.role,
    this.email,
    this.avatarUrl,
    this.createdAt,
  });

  String get fullName {
    if (firstName == null && lastName == null) return phone;
    return '${firstName ?? ''} ${lastName ?? ''}'.trim();
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      firstName: json['firstName'],
      lastName: json['lastName'],
      role: json['role'] ?? 'RIDER',
      email: json['email'],
      avatarUrl: json['avatarUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
        'email': email,
        'avatarUrl': avatarUrl,
      };
}

class RiderProfile {
  final String id;
  final String userId;
  final User? user;
  final String status; // PENDING_DOCUMENTS, PENDING_APPROVAL, APPROVED, SUSPENDED
  final bool isOnline;
  final Vehicle? vehicle;
  final List<RiderDocument> documents;
  final InsuranceInfo? insurance;
  final double? latitude;
  final double? longitude;
  final double totalEarnings;
  final int totalTrips;
  final double rating;
  final DateTime? createdAt;

  RiderProfile({
    required this.id,
    required this.userId,
    this.user,
    required this.status,
    this.isOnline = false,
    this.vehicle,
    this.documents = const [],
    this.insurance,
    this.latitude,
    this.longitude,
    this.totalEarnings = 0,
    this.totalTrips = 0,
    this.rating = 0,
    this.createdAt,
  });

  bool get isApproved => status == 'APPROVED';
  bool get needsDocuments => status == 'PENDING_DOCUMENTS';
  bool get pendingApproval => status == 'PENDING_APPROVAL';

  factory RiderProfile.fromJson(Map<String, dynamic> json) {
    return RiderProfile(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      status: json['status'] ?? 'PENDING_DOCUMENTS',
      isOnline: json['isOnline'] ?? false,
      vehicle:
          json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
      documents: (json['documents'] as List?)
              ?.map((d) => RiderDocument.fromJson(d))
              .toList() ??
          [],
      insurance: json['insurance'] != null
          ? InsuranceInfo.fromJson(json['insurance'])
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0,
      totalTrips: json['totalTrips'] ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }
}

class Vehicle {
  final String id;
  final String make;
  final String model;
  final int year;
  final String color;
  final String plateNumber;
  final String? engineSize;

  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.plateNumber,
    this.engineSize,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] ?? '',
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      year: json['year'] ?? 0,
      color: json['color'] ?? '',
      plateNumber: json['plateNumber'] ?? '',
      engineSize: json['engineSize'],
    );
  }

  Map<String, dynamic> toJson() => {
        'make': make,
        'model': model,
        'year': year,
        'color': color,
        'plateNumber': plateNumber,
        'engineSize': engineSize,
      };
}

class RiderDocument {
  final String id;
  final String type; // NRC, SELFIE, DRIVERS_LICENCE, INSURANCE
  final String status; // PENDING, APPROVED, REJECTED
  final String? url;
  final String? rejectionReason;

  RiderDocument({
    required this.id,
    required this.type,
    required this.status,
    this.url,
    this.rejectionReason,
  });

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  factory RiderDocument.fromJson(Map<String, dynamic> json) {
    return RiderDocument(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? 'PENDING',
      url: json['url'],
      rejectionReason: json['rejectionReason'],
    );
  }
}

class InsuranceInfo {
  final String id;
  final String insurerName;
  final String policyNumber;
  final DateTime expiryDate;
  final String? documentUrl;
  final String status;

  InsuranceInfo({
    required this.id,
    required this.insurerName,
    required this.policyNumber,
    required this.expiryDate,
    this.documentUrl,
    required this.status,
  });

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;
  bool get isExpired => daysUntilExpiry < 0;
  bool get isExpiringSoon => daysUntilExpiry <= 7 && daysUntilExpiry >= 0;

  factory InsuranceInfo.fromJson(Map<String, dynamic> json) {
    return InsuranceInfo(
      id: json['id'] ?? '',
      insurerName: json['insurerName'] ?? '',
      policyNumber: json['policyNumber'] ?? '',
      expiryDate: DateTime.tryParse(json['expiryDate'] ?? '') ?? DateTime.now(),
      documentUrl: json['documentUrl'],
      status: json['status'] ?? 'PENDING',
    );
  }
}

class Trip {
  final String id;
  final String type; // RIDE, DELIVERY
  final String status;
  // REQUESTED, MATCHED, RIDER_ACCEPTED, RIDER_ARRIVED,
  // IN_PROGRESS, COMPLETED, CANCELLED
  final String? passengerId;
  final User? passenger;
  final String? riderId;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;
  final double? fareEstimateMin;
  final double? fareEstimateMax;
  final double? finalFare;
  final double? distance;
  final String? pickupPhotoUrl;
  final String? dropoffPhotoUrl;
  final String? deliveryNotes;
  final DateTime? createdAt;
  final DateTime? completedAt;

  Trip({
    required this.id,
    required this.type,
    required this.status,
    this.passengerId,
    this.passenger,
    this.riderId,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    this.fareEstimateMin,
    this.fareEstimateMax,
    this.finalFare,
    this.distance,
    this.pickupPhotoUrl,
    this.dropoffPhotoUrl,
    this.deliveryNotes,
    this.createdAt,
    this.completedAt,
  });

  bool get isDelivery => type == 'DELIVERY';
  bool get isRide => type == 'RIDE';

  String get fareRange {
    if (fareEstimateMin != null && fareEstimateMax != null) {
      return 'K${fareEstimateMin!.toStringAsFixed(0)} - K${fareEstimateMax!.toStringAsFixed(0)}';
    }
    if (finalFare != null) {
      return 'K${finalFare!.toStringAsFixed(0)}';
    }
    return 'Calculating...';
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? '',
      type: json['type'] ?? 'RIDE',
      status: json['status'] ?? 'REQUESTED',
      passengerId: json['passengerId'],
      passenger:
          json['passenger'] != null ? User.fromJson(json['passenger']) : null,
      riderId: json['riderId'],
      pickupLat: (json['pickupLat'] as num?)?.toDouble() ?? 0,
      pickupLng: (json['pickupLng'] as num?)?.toDouble() ?? 0,
      pickupAddress: json['pickupAddress'] ?? '',
      dropoffLat: (json['dropoffLat'] as num?)?.toDouble() ?? 0,
      dropoffLng: (json['dropoffLng'] as num?)?.toDouble() ?? 0,
      dropoffAddress: json['dropoffAddress'] ?? '',
      fareEstimateMin: (json['fareEstimateMin'] as num?)?.toDouble(),
      fareEstimateMax: (json['fareEstimateMax'] as num?)?.toDouble(),
      finalFare: (json['finalFare'] as num?)?.toDouble(),
      distance: (json['distance'] as num?)?.toDouble(),
      pickupPhotoUrl: json['pickupPhotoUrl'],
      dropoffPhotoUrl: json['dropoffPhotoUrl'],
      deliveryNotes: json['deliveryNotes'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
    );
  }
}

class TripOffer {
  final String tripId;
  final Trip trip;
  final int expiresInSeconds;
  final DateTime receivedAt;

  TripOffer({
    required this.tripId,
    required this.trip,
    this.expiresInSeconds = 15,
  }) : receivedAt = DateTime.now();

  factory TripOffer.fromJson(Map<String, dynamic> json) {
    return TripOffer(
      tripId: json['tripId'] ?? json['trip']?['id'] ?? '',
      trip: Trip.fromJson(json['trip'] ?? json),
      expiresInSeconds: json['expiresInSeconds'] ?? 15,
    );
  }
}
