import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/trip_service.dart';
import '../../services/socket_service.dart';
import '../../models/models.dart' as models;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  final Set<Marker> _markers = {};

  // Mufulira center
  static const LatLng _defaultCenter = LatLng(-12.5432, 28.2311);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _connectSocket();
    _checkActiveTrip();
  }

  void _initializeLocation() async {
    final locationService = context.read<LocationService>();
    await locationService.getCurrentLocation();

    if (locationService.currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(
            locationService.currentPosition!.latitude,
            locationService.currentPosition!.longitude,
          ),
        ),
      );
    }
  }

  void _connectSocket() {
    final socket = context.read<SocketService>();
    socket.connect();
  }

  void _checkActiveTrip() async {
    final tripService = context.read<TripService>();
    final trip = await tripService.getCurrentTrip();
    if (trip != null && mounted) {
      switch (trip.status) {
        case models.TripStatus.SEARCHING:
          Navigator.pushNamed(context, '/searching');
          break;
        case models.TripStatus.ACCEPTED:
        case models.TripStatus.ARRIVED:
        case models.TripStatus.IN_PROGRESS:
          Navigator.pushNamed(context, '/active-trip');
          break;
        case models.TripStatus.COMPLETED:
          if (trip.ratingScore == null) {
            Navigator.pushNamed(context, '/trip-complete', arguments: {
              'id': trip.id,
              'actualFare': trip.actualFare,
              'estimatedFareHigh': trip.estimatedFareHigh,
              'rider': trip.rider?.toJson(),
            });
          }
          break;
        default:
          break;
      }
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      if (_pickupLatLng == null) {
        _pickupLatLng = position;
        _markers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ));
      } else if (_destinationLatLng == null) {
        _destinationLatLng = position;
        _markers.add(Marker(
          markerId: const MarkerId('destination'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ));
      }
    });
  }

  void _clearMarkers() {
    setState(() {
      _pickupLatLng = null;
      _destinationLatLng = null;
      _markers.clear();
    });
  }

  void _navigateToBooking(models.TripType type) {
    if (_pickupLatLng == null || _destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Tap the map to set pickup and destination points first'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/booking',
      arguments: {
        'pickup': models.LatLng(
          latitude: _pickupLatLng!.latitude,
          longitude: _pickupLatLng!.longitude,
        ),
        'destination': models.LatLng(
          latitude: _destinationLatLng!.latitude,
          longitude: _destinationLatLng!.longitude,
        ),
        'type': type,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultCenter,
              zoom: 14.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTap,
          ),

          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Menu button
                    Builder(
                      builder: (context) => Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Search bar
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Could navigate to a search/address entry screen
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search,
                                  color: AppTheme.textSecondary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Where are you going?',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Instructions overlay
          if (_pickupLatLng == null || _destinationLatLng == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _pickupLatLng == null
                      ? 'Tap the map to set your PICKUP point'
                      : 'Now tap to set your DESTINATION',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // Bottom Action Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status indicators
                  if (_pickupLatLng != null || _destinationLatLng != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: _pickupLatLng != null
                              ? AppTheme.successColor
                              : AppTheme.dividerColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _pickupLatLng != null
                              ? 'Pickup set'
                              : 'Tap map for pickup',
                          style: TextStyle(
                            color: _pickupLatLng != null
                                ? AppTheme.successColor
                                : AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: _destinationLatLng != null
                              ? AppTheme.dangerColor
                              : AppTheme.dividerColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _destinationLatLng != null
                              ? 'Destination set'
                              : 'Tap map for destination',
                          style: TextStyle(
                            color: _destinationLatLng != null
                                ? AppTheme.dangerColor
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _navigateToBooking(models.TripType.RIDE),
                            icon: const Icon(Icons.two_wheeler),
                            label: const Text('Request Ride'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _navigateToBooking(models.TripType.DELIVERY),
                            icon: const Icon(Icons.local_shipping_outlined),
                            label: const Text('Delivery'),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_pickupLatLng != null || _destinationLatLng != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _clearMarkers,
                      child: const Text('Clear points'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // My Location FAB
          Positioned(
            right: 16,
            bottom: 240,
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              onPressed: _initializeLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final auth = context.watch<AuthService>();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: AppTheme.primaryColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 36,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.currentUser?.name ?? 'Passenger',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    auth.currentUser?.phone ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Trip History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/trip-history');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About RideSure'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'RideSure',
                  applicationVersion: '1.0.0',
                  children: [
                    const Text(
                      'Motorcycle ride-hailing service in Mufulira & Chililabombwe, Zambia.',
                    ),
                  ],
                );
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.dangerColor),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppTheme.dangerColor),
              ),
              onTap: () async {
                final auth = context.read<AuthService>();
                final socket = context.read<SocketService>();
                socket.disconnect();
                await auth.logout();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
