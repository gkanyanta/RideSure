class User {
  final String id;
  final String phone;
  final String? name;
  final String role;
  final String? riderId;
  final String? riderStatus;

  User({
    required this.id,
    required this.phone,
    this.name,
    required this.role,
    this.riderId,
    this.riderStatus,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'],
      role: json['role'] ?? 'RIDER',
      riderId: json['riderId'],
      riderStatus: json['riderStatus'],
    );
  }
}

class RiderProfile {
  final String id;
  final String userId;
  final Map<String, dynamic>? user;
  final String status;
  final bool isOnline;
  final Vehicle? vehicle;
  final List<RiderDocument> documents;
  final int totalTrips;
  final double avgRating;
  final double? currentLat;
  final double? currentLng;
  final String? rejectionReason;

  RiderProfile({
    required this.id,
    required this.userId,
    this.user,
    required this.status,
    this.isOnline = false,
    this.vehicle,
    this.documents = const [],
    this.totalTrips = 0,
    this.avgRating = 0,
    this.currentLat,
    this.currentLng,
    this.rejectionReason,
  });

  bool get isApproved => status == 'APPROVED';
  bool get needsDocuments => status == 'PENDING_DOCUMENTS';
  bool get pendingApproval => status == 'PENDING_APPROVAL';
  bool get isSuspended => status == 'SUSPENDED';
  String get userName => user?['name'] ?? user?['phone'] ?? 'Rider';
  String get userPhone => user?['phone'] ?? '';

  RiderDocument? get insuranceDoc {
    try {
      return documents.firstWhere((d) => d.type == 'INSURANCE_CERTIFICATE');
    } catch (_) {
      return null;
    }
  }

  factory RiderProfile.fromJson(Map<String, dynamic> json) {
    return RiderProfile(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      user: json['user'],
      status: json['status'] ?? 'PENDING_DOCUMENTS',
      isOnline: json['isOnline'] ?? false,
      vehicle: json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
      documents: (json['documents'] as List?)
              ?.map((d) => RiderDocument.fromJson(d))
              .toList() ??
          [],
      totalTrips: json['totalTrips'] ?? 0,
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
      currentLat: (json['currentLat'] as num?)?.toDouble(),
      currentLng: (json['currentLng'] as num?)?.toDouble(),
      rejectionReason: json['rejectionReason'],
    );
  }
}

class Vehicle {
  final String id;
  final String? make;
  final String model;
  final String? color;
  final String plateNumber;

  Vehicle({
    required this.id,
    this.make,
    required this.model,
    this.color,
    required this.plateNumber,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] ?? '',
      make: json['make'],
      model: json['model'] ?? '',
      color: json['color'],
      plateNumber: json['plateNumber'] ?? '',
    );
  }
}

class RiderDocument {
  final String id;
  final String type;
  final String status;
  final String? insurerName;
  final String? policyNumber;
  final DateTime? expiryDate;
  final String? rejectionReason;

  RiderDocument({
    required this.id,
    required this.type,
    required this.status,
    this.insurerName,
    this.policyNumber,
    this.expiryDate,
    this.rejectionReason,
  });

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  int get daysUntilExpiry =>
      expiryDate?.difference(DateTime.now()).inDays ?? 999;
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isExpiringSoon => daysUntilExpiry <= 7 && daysUntilExpiry >= 0;

  factory RiderDocument.fromJson(Map<String, dynamic> json) {
    return RiderDocument(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? 'PENDING',
      insurerName: json['insurerName'],
      policyNumber: json['policyNumber'],
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'])
          : null,
      rejectionReason: json['rejectionReason'],
    );
  }
}

class TripOffer {
  final String tripId;
  final Trip trip;
  final int expiresInSeconds;

  TripOffer({
    required this.tripId,
    required this.trip,
    this.expiresInSeconds = 15,
  });

  factory TripOffer.fromJson(Map<String, dynamic> json) {
    // Backend sends flat offer data: { tripId, type, passengerName, pickupAddress, ... }
    // Map it into a Trip-compatible shape
    final tripId = json['tripId'] ?? json['id'] ?? '';

    final tripData = json['trip'] is Map<String, dynamic>
        ? json['trip'] as Map<String, dynamic>
        : <String, dynamic>{
            'id': tripId,
            'type': json['type'],
            'status': 'OFFERED',
            'pickupAddress': json['pickupAddress'] ?? '',
            'pickupLandmark': json['pickupLandmark'],
            'destinationAddress': json['destinationAddress'] ?? '',
            'pickupLat': json['pickupLat'] ?? 0,
            'pickupLng': json['pickupLng'] ?? 0,
            'destinationLat': json['destinationLat'] ?? 0,
            'destinationLng': json['destinationLng'] ?? 0,
            'estimatedFareLow': json['estimatedFareLow'],
            'estimatedFareHigh': json['estimatedFareHigh'],
            'estimatedDistance': json['estimatedDistance'],
            'packageType': json['packageType'],
            'packageNotes': json['packageNotes'],
            'passenger': json['passengerName'] != null
                ? {'name': json['passengerName']}
                : json['passenger'],
          };

    return TripOffer(
      tripId: tripId,
      trip: Trip.fromJson(tripData),
      expiresInSeconds: json['timeoutSec'] ?? json['expiresIn'] ?? json['timeout'] ?? 15,
    );
  }
}

class Trip {
  final String id;
  final String type;
  final String status;
  final String? passengerId;
  final Map<String, dynamic>? passenger;
  final String? riderId;
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
    this.createdAt,
    this.completedAt,
  });

  bool get isDelivery => type == 'DELIVERY';
  String get passengerName => passenger?['name'] ?? passenger?['phone'] ?? 'Passenger';

  String get fareRange {
    if (estimatedFareLow != null && estimatedFareHigh != null) {
      return 'K${estimatedFareLow!.toStringAsFixed(0)} - K${estimatedFareHigh!.toStringAsFixed(0)}';
    }
    if (actualFare != null) return 'K${actualFare!.toStringAsFixed(0)}';
    return 'Calculating...';
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? '',
      type: json['type'] ?? 'RIDE',
      status: json['status'] ?? 'REQUESTED',
      passengerId: json['passengerId'],
      passenger: json['passenger'],
      riderId: json['riderId'],
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
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
    );
  }
}
