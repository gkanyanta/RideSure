import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/rider_service.dart';
import '../../services/trip_service.dart';
import '../../services/socket_service.dart';
import '../../services/location_service.dart';
import '../../widgets/insurance_warning.dart';
import '../trip/incoming_job_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  Future<void> _initialize() async {
    final socket = context.read<SocketService>();
    socket.onTripOffer = _handleTripOffer;
    socket.onTripUpdate = _handleTripUpdate;
    socket.onTripCancelled = _handleTripCancelled;

    if (!socket.isConnected) {
      socket.connect();
    }

    final location = context.read<LocationService>();
    await location.checkPermissions();

    _refreshData();
  }

  void _handleTripOffer(TripOffer offer) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IncomingJobSheet(offer: offer),
    );
  }

  void _handleTripUpdate(Trip trip) {
    if (!mounted) return;
    context.read<TripService>().setActiveTrip(trip);
  }

  void _handleTripCancelled(String tripId) {
    if (!mounted) return;
    final tripService = context.read<TripService>();
    if (tripService.activeTrip?.id == tripId) {
      tripService.setActiveTrip(null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip was cancelled by passenger')),
      );
    }
  }

  Future<void> _refreshData() async {
    final rider = context.read<RiderService>();
    await rider.fetchProfile();
  }

  Future<void> _toggleOnline() async {
    final rider = context.read<RiderService>();
    final location = context.read<LocationService>();
    final socket = context.read<SocketService>();

    if (!rider.isOnline) {
      final pos = await location.getCurrentPosition();
      if (pos == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot go online without location access'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final success = await rider.toggleOnlineStatus();
      if (success) {
        location.onLocationUpdate = (lat, lng) {
          rider.updateLocation(lat, lng);
          socket.sendLocation(lat, lng);
        };
        await location.startTracking();
      } else if (mounted && rider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(rider.error!), backgroundColor: Colors.red),
        );
      }
    } else {
      final success = await rider.toggleOnlineStatus();
      if (success) {
        location.stopTracking();
        location.onLocationUpdate = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RideSure Rider'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/trip-history'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Consumer2<RiderService, TripService>(
          builder: (context, rider, tripService, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Insurance warning
                if (rider.profile?.insuranceDoc != null &&
                    rider.profile!.insuranceDoc!.isExpiringSoon)
                  InsuranceWarningWidget(
                    daysRemaining: rider.profile!.insuranceDoc!.daysUntilExpiry,
                    message: rider.profile!.insuranceDoc!.isExpired
                        ? 'Insurance has EXPIRED!'
                        : 'Insurance expires in ${rider.profile!.insuranceDoc!.daysUntilExpiry} days',
                  ),

                // Online/Offline toggle
                _buildOnlineToggle(rider),
                const SizedBox(height: 16),

                // Connection status
                Consumer<SocketService>(
                  builder: (context, socket, _) {
                    return _buildStatusRow(
                      icon: socket.isConnected ? Icons.wifi : Icons.wifi_off,
                      label: socket.isConnected ? 'Connected to server' : 'Disconnected',
                      color: socket.isConnected ? Colors.green : Colors.red,
                    );
                  },
                ),
                const SizedBox(height: 8),

                Consumer<LocationService>(
                  builder: (context, location, _) {
                    return _buildStatusRow(
                      icon: location.isTracking ? Icons.my_location : Icons.location_off,
                      label: location.isTracking ? 'GPS active' : 'GPS inactive',
                      color: location.isTracking ? Colors.green : Colors.grey,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Active trip card
                if (tripService.hasActiveTrip)
                  _buildActiveTripCard(tripService.activeTrip!),

                // Stats + waiting
                if (!tripService.hasActiveTrip) ...[
                  _buildStatsCard(rider),
                  const SizedBox(height: 16),
                  _buildWaitingCard(rider),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOnlineToggle(RiderService rider) {
    final isOnline = rider.isOnline;
    return Card(
      color: isOnline ? const Color(0xFF1B5E20) : Colors.white,
      child: InkWell(
        onTap: rider.isToggling ? null : _toggleOnline,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (rider.isToggling)
                SizedBox(
                  height: 24, width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isOnline ? Colors.white : const Color(0xFF1B5E20),
                  ),
                )
              else
                Icon(
                  isOnline ? Icons.toggle_on : Icons.toggle_off,
                  size: 48,
                  color: isOnline ? Colors.white : Colors.grey,
                ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'YOU ARE ONLINE' : 'YOU ARE OFFLINE',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  Text(
                    isOnline ? 'Waiting for ride requests...' : 'Tap to go online and start earning',
                    style: TextStyle(
                      fontSize: 14,
                      color: isOnline ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow({required IconData icon, required String label, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }

  Widget _buildActiveTripCard(Trip trip) {
    return Card(
      color: const Color(0xFF2E7D32),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/active-trip', arguments: {
          'id': trip.id,
          'type': trip.type,
          'status': trip.status,
          'pickupAddress': trip.pickupAddress,
          'destinationAddress': trip.destinationAddress,
          'estimatedFareLow': trip.estimatedFareLow,
          'estimatedFareHigh': trip.estimatedFareHigh,
          'passenger': trip.passenger,
          'packageType': trip.packageType,
          'packageNotes': trip.packageNotes,
          'destinationLat': trip.destinationLat,
          'destinationLng': trip.destinationLng,
        }),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(trip.isDelivery ? Icons.inventory : Icons.person, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Active ${trip.isDelivery ? "Delivery" : "Ride"}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(trip.status.replaceAll('_', ' '),
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Passenger: ${trip.passengerName}',
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(height: 4),
              Text(trip.pickupAddress,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/active-trip', arguments: {
                    'id': trip.id, 'type': trip.type, 'status': trip.status,
                    'pickupAddress': trip.pickupAddress, 'destinationAddress': trip.destinationAddress,
                    'estimatedFareLow': trip.estimatedFareLow, 'estimatedFareHigh': trip.estimatedFareHigh,
                    'passenger': trip.passenger, 'destinationLat': trip.destinationLat,
                    'destinationLng': trip.destinationLng,
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B5E20),
                  ),
                  child: const Text('View Trip Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(RiderService rider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _statItem(Icons.route, 'Trips', '${rider.profile?.totalTrips ?? 0}')),
                Expanded(child: _statItem(Icons.star, 'Rating', '${rider.profile?.avgRating.toStringAsFixed(1) ?? "0.0"}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF1B5E20), size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildWaitingCard(RiderService rider) {
    if (!rider.isOnline) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.motorcycle, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('Go online to start receiving trips',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(
              height: 48, width: 48,
              child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1B5E20)),
            ),
            const SizedBox(height: 16),
            const Text('Waiting for ride requests...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Stay in Mufulira or Chililabombwe area\nfor best chances',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
