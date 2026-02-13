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
  String? _pickupAddress;
  String? _destinationAddress;
  final Set<Marker> _markers = {};

  models.FareEstimate? _fareEstimate;
  bool _estimateLoading = false;

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
        case models.TripStatus.REQUESTED:
        case models.TripStatus.OFFERED:
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

  void _openLocationSearch() async {
    final result = await Navigator.pushNamed(context, '/location-search');
    if (result is Map<String, dynamic> && mounted) {
      _handleLocationSelected(result);
    }
  }

  void _handleLocationSelected(Map<String, dynamic> result) {
    final pickupLL = result['pickupLatLng'] as models.LatLng?;
    final destLL = result['destinationLatLng'] as models.LatLng?;

    if (pickupLL == null || destLL == null) return;

    setState(() {
      _pickupLatLng = LatLng(pickupLL.latitude, pickupLL.longitude);
      _destinationLatLng = LatLng(destLL.latitude, destLL.longitude);
      _pickupAddress = result['pickupAddress'] as String?;
      _destinationAddress = result['destinationAddress'] as String?;

      _markers.clear();
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup', snippet: _pickupAddress),
      ));
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destinationLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow:
            InfoWindow(title: 'Destination', snippet: _destinationAddress),
      ));
    });

    // Fit camera to show both markers
    if (_mapController != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _pickupLatLng!.latitude < _destinationLatLng!.latitude
              ? _pickupLatLng!.latitude
              : _destinationLatLng!.latitude,
          _pickupLatLng!.longitude < _destinationLatLng!.longitude
              ? _pickupLatLng!.longitude
              : _destinationLatLng!.longitude,
        ),
        northeast: LatLng(
          _pickupLatLng!.latitude > _destinationLatLng!.latitude
              ? _pickupLatLng!.latitude
              : _destinationLatLng!.latitude,
          _pickupLatLng!.longitude > _destinationLatLng!.longitude
              ? _pickupLatLng!.longitude
              : _destinationLatLng!.longitude,
        ),
      );
      _mapController!
          .animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }

    // Fetch fare estimate
    _fetchFareEstimate();
  }

  Future<void> _fetchFareEstimate() async {
    if (_pickupLatLng == null || _destinationLatLng == null) return;

    setState(() => _estimateLoading = true);

    final tripService = context.read<TripService>();
    final estimate = await tripService.getFareEstimate(
      pickup: models.LatLng(
        latitude: _pickupLatLng!.latitude,
        longitude: _pickupLatLng!.longitude,
      ),
      destination: models.LatLng(
        latitude: _destinationLatLng!.latitude,
        longitude: _destinationLatLng!.longitude,
      ),
      type: models.TripType.RIDE,
    );

    if (mounted) {
      setState(() {
        _fareEstimate = estimate;
        _estimateLoading = false;
      });
    }
  }

  void _clearLocations() {
    setState(() {
      _pickupLatLng = null;
      _destinationLatLng = null;
      _pickupAddress = null;
      _destinationAddress = null;
      _fareEstimate = null;
      _markers.clear();
    });
  }

  void _navigateToBooking(models.TripType type) {
    if (_pickupLatLng == null || _destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set pickup and destination first'),
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
        'pickupAddress': _pickupAddress,
        'destinationAddress': _destinationAddress,
        'fareEstimate': _fareEstimate,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLocations =
        _pickupLatLng != null && _destinationLatLng != null;

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
                        onTap: _openLocationSearch,
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
                              Expanded(
                                child: Text(
                                  hasLocations
                                      ? _destinationAddress ??
                                          'Where are you going?'
                                      : 'Where are you going?',
                                  style: TextStyle(
                                    color: hasLocations
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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

          // Bottom Sheet
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
                  const SizedBox(height: 16),

                  // Location summary (when locations are set)
                  if (hasLocations) ...[
                    _buildLocationRow(
                      icon: Icons.circle,
                      iconColor: AppTheme.successColor,
                      text: _pickupAddress ?? 'Pickup',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Container(
                        width: 2,
                        height: 16,
                        color: AppTheme.dividerColor,
                      ),
                    ),
                    _buildLocationRow(
                      icon: Icons.circle,
                      iconColor: AppTheme.dangerColor,
                      text: _destinationAddress ?? 'Destination',
                    ),
                    const SizedBox(height: 16),

                    // Fare estimate
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_estimateLoading)
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          else ...[
                            const Icon(Icons.payments_outlined,
                                color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _fareEstimate?.displayRange ??
                                  'Estimating fare...',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
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
                            onPressed: hasLocations
                                ? () => _navigateToBooking(
                                    models.TripType.RIDE)
                                : _openLocationSearch,
                            icon: Icon(hasLocations
                                ? Icons.two_wheeler
                                : Icons.search),
                            label: Text(hasLocations
                                ? 'Request Ride'
                                : 'Where are you going?'),
                          ),
                        ),
                      ),
                      if (hasLocations) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: () => _navigateToBooking(
                                  models.TripType.DELIVERY),
                              icon: const Icon(
                                  Icons.local_shipping_outlined),
                              label: const Text('Delivery'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (hasLocations) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _clearLocations,
                      child: const Text('Clear'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // My Location FAB
          Positioned(
            right: 16,
            bottom: hasLocations ? 320 : 200,
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

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 10, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
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
