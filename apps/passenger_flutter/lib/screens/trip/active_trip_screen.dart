import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/trip_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/rider_info_card.dart';
import '../../widgets/sos_button.dart';

class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  GoogleMapController? _mapController;
  LatLng? _riderLocation;

  @override
  void initState() {
    super.initState();
    _listenForUpdates();
  }

  void _listenForUpdates() {
    final socket = context.read<SocketService>();
    final tripService = context.read<TripService>();

    socket.listenForTripUpdates(
      onArrived: (data) {
        if (data is Map<String, dynamic>) {
          tripService.updateTripFromSocket(data);
        }
        setState(() {});
      },
      onInProgress: (data) {
        if (data is Map<String, dynamic>) {
          tripService.updateTripFromSocket(data);
        }
        setState(() {});
      },
      onCompleted: (data) {
        if (data is Map<String, dynamic>) {
          tripService.updateTripFromSocket(data);
        }
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/trip-complete');
        }
      },
      onCancelled: (data) {
        if (data is Map<String, dynamic>) {
          tripService.updateTripFromSocket(data);
        }
        if (mounted) {
          tripService.clearCurrentTrip();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip was cancelled'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
          Navigator.popUntil(
              context, (route) => route.settings.name == '/home');
        }
      },
      onLocationUpdate: (data) {
        if (data is Map<String, dynamic>) {
          final lat = (data['latitude'] ?? data['lat'])?.toDouble();
          final lng =
              (data['longitude'] ?? data['lng'] ?? data['lon'])?.toDouble();
          if (lat != null && lng != null) {
            setState(() {
              _riderLocation = LatLng(lat, lng);
            });
          }
        }
      },
    );
  }

  @override
  void dispose() {
    final socket = context.read<SocketService>();
    socket.removeAllTripListeners();
    super.dispose();
  }

  String _statusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.ACCEPTED:
        return 'Rider is on the way';
      case TripStatus.ARRIVED:
        return 'Rider has arrived';
      case TripStatus.IN_PROGRESS:
        return 'Trip in progress';
      case TripStatus.COMPLETED:
        return 'Trip completed';
      case TripStatus.CANCELLED:
        return 'Trip cancelled';
      default:
        return 'Trip active';
    }
  }

  Color _statusColor(TripStatus status) {
    switch (status) {
      case TripStatus.ACCEPTED:
        return AppTheme.primaryColor;
      case TripStatus.ARRIVED:
        return AppTheme.warningColor;
      case TripStatus.IN_PROGRESS:
        return AppTheme.successColor;
      case TripStatus.COMPLETED:
        return AppTheme.successColor;
      case TripStatus.CANCELLED:
        return AppTheme.dangerColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _statusIcon(TripStatus status) {
    switch (status) {
      case TripStatus.ACCEPTED:
        return Icons.directions_bike;
      case TripStatus.ARRIVED:
        return Icons.place;
      case TripStatus.IN_PROGRESS:
        return Icons.navigation;
      case TripStatus.COMPLETED:
        return Icons.check_circle;
      case TripStatus.CANCELLED:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Set<Marker> _buildMarkers(Trip trip) {
    final markers = <Marker>{};

    markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(
        trip.pickup.coordinates.latitude,
        trip.pickup.coordinates.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(title: trip.pickup.address ?? 'Pickup'),
    ));

    markers.add(Marker(
      markerId: const MarkerId('destination'),
      position: LatLng(
        trip.destination.coordinates.latitude,
        trip.destination.coordinates.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow:
          InfoWindow(title: trip.destination.address ?? 'Destination'),
    ));

    if (_riderLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: _riderLocation!,
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Rider'),
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Consumer<TripService>(
        builder: (context, tripService, _) {
          final trip = tripService.currentTrip;

          if (trip == null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No active trip'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context, '/home', (route) => false),
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            body: Column(
              children: [
                // Map
                Expanded(
                  flex: 2,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            trip.pickup.coordinates.latitude,
                            trip.pickup.coordinates.longitude,
                          ),
                          zoom: 14.0,
                        ),
                        markers: _buildMarkers(trip),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                      ),

                      // Status Banner
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(trip.status),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _statusColor(trip.status)
                                      .withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _statusIcon(trip.status),
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _statusLabel(trip.status),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // SOS button
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 70,
                        right: 16,
                        child: SosButton(tripId: trip.id),
                      ),
                    ],
                  ),
                ),

                // Bottom info panel
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Handle
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.dividerColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Rider info card
                          if (trip.rider != null)
                            RiderInfoCard(rider: trip.rider!),

                          const SizedBox(height: 16),

                          // Trip details
                          _buildTripDetail(
                            Icons.circle,
                            AppTheme.successColor,
                            'Pickup',
                            trip.pickup.address ?? 'Pickup location',
                          ),
                          const SizedBox(height: 12),
                          _buildTripDetail(
                            Icons.circle,
                            AppTheme.dangerColor,
                            'Destination',
                            trip.destination.address ?? 'Destination',
                          ),

                          if (trip.type == TripType.DELIVERY &&
                              trip.deliveryDetails != null) ...[
                            const SizedBox(height: 12),
                            _buildTripDetail(
                              Icons.inventory_2_outlined,
                              AppTheme.warningColor,
                              'Package',
                              trip.deliveryDetails!.packageType,
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Share trip button
                          if (trip.shareCode != null) ...[
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/share-trip');
                              },
                              icon: const Icon(Icons.share),
                              label: const Text('Share Trip'),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Cancel (only if ACCEPTED)
                          if (trip.status == TripStatus.ACCEPTED)
                            TextButton(
                              onPressed: () => _cancelTrip(trip.id),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.dangerColor,
                              ),
                              child: const Text('Cancel Trip'),
                            ),

                          // Status progress
                          const SizedBox(height: 16),
                          _buildStatusProgress(trip.status),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTripDetail(
      IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusProgress(TripStatus current) {
    final statuses = [
      TripStatus.ACCEPTED,
      TripStatus.ARRIVED,
      TripStatus.IN_PROGRESS,
      TripStatus.COMPLETED,
    ];
    final currentIndex = statuses.indexOf(current);

    return Row(
      children: List.generate(statuses.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIndex = index ~/ 2;
          return Expanded(
            child: Container(
              height: 3,
              color: stepIndex < currentIndex
                  ? AppTheme.successColor
                  : AppTheme.dividerColor,
            ),
          );
        }

        // Status dot
        final stepIndex = index ~/ 2;
        final isActive = stepIndex <= currentIndex;
        final isCurrent = stepIndex == currentIndex;

        return Container(
          width: isCurrent ? 16 : 12,
          height: isCurrent ? 16 : 12,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.successColor : AppTheme.dividerColor,
            shape: BoxShape.circle,
            border: isCurrent
                ? Border.all(color: AppTheme.successColor, width: 3)
                : null,
          ),
        );
      }),
    );
  }

  Future<void> _cancelTrip(String tripId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel trip?'),
        content: const Text('Are you sure you want to cancel this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.dangerColor,
            ),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final tripService = context.read<TripService>();
      await tripService.cancelTrip(tripId);
      if (mounted) {
        Navigator.popUntil(context, (route) => route.settings.name == '/home');
      }
    }
  }
}
