import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/trip_service.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();

  LatLng? _pickup;
  LatLng? _destination;
  TripType _tripType = TripType.RIDE;
  FareEstimate? _fareEstimate;
  bool _estimateLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _pickup == null) {
      _pickup = args['pickup'] as LatLng?;
      _destination = args['destination'] as LatLng?;
      _tripType = args['type'] as TripType? ?? TripType.RIDE;

      if (_pickup != null) {
        _pickupController.text =
            '${_pickup!.latitude.toStringAsFixed(4)}, ${_pickup!.longitude.toStringAsFixed(4)}';
      }
      if (_destination != null) {
        _destinationController.text =
            '${_destination!.latitude.toStringAsFixed(4)}, ${_destination!.longitude.toStringAsFixed(4)}';
      }

      // Auto-fetch estimate
      if (_pickup != null && _destination != null) {
        _fetchEstimate();
      }
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _fetchEstimate() async {
    if (_pickup == null || _destination == null) return;

    setState(() => _estimateLoading = true);

    final tripService = context.read<TripService>();
    final estimate = await tripService.getFareEstimate(
      pickup: _pickup!,
      destination: _destination!,
      type: _tripType,
    );

    if (mounted) {
      setState(() {
        _fareEstimate = estimate;
        _estimateLoading = false;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_pickup == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set pickup and destination')),
      );
      return;
    }

    if (_tripType == TripType.DELIVERY) {
      Navigator.pushNamed(
        context,
        '/delivery-details',
        arguments: {
          'pickup': _pickup,
          'destination': _destination,
          'pickupAddress': _pickupController.text,
          'destinationAddress': _destinationController.text,
          'fareEstimate': _fareEstimate,
        },
      );
      return;
    }

    // Request ride directly
    final tripService = context.read<TripService>();
    final trip = await tripService.requestTrip(
      pickup: TripLocation(
        coordinates: _pickup!,
        address: _pickupController.text,
      ),
      destination: TripLocation(
        coordinates: _destination!,
        address: _destinationController.text,
      ),
      type: _tripType,
    );

    if (trip != null && mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/searching',
        (route) => route.settings.name == '/home',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tripType == TripType.DELIVERY
            ? 'Book Delivery'
            : 'Book a Ride'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Trip Type Toggle
            Container(
              decoration: BoxDecoration(
                color: AppTheme.dividerColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeChip(
                      'Ride',
                      Icons.two_wheeler,
                      TripType.RIDE,
                    ),
                  ),
                  Expanded(
                    child: _buildTypeChip(
                      'Delivery',
                      Icons.local_shipping_outlined,
                      TripType.DELIVERY,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pickup & Destination
            _buildLocationCard(),
            const SizedBox(height: 24),

            // Fare Estimate
            _buildFareEstimateCard(),
            const SizedBox(height: 24),

            // Trip info
            if (_fareEstimate != null) ...[
              _buildInfoRow(
                Icons.straighten,
                'Estimated distance',
                '${_fareEstimate!.estimatedDistance.toStringAsFixed(1)} km',
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.timer_outlined,
                'Estimated time',
                '${_fareEstimate!.estimatedDuration} min',
              ),
              const SizedBox(height: 24),
            ],

            // Confirm Button
            Consumer<TripService>(
              builder: (context, tripService, _) {
                return SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: tripService.isLoading ? null : _confirmBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: tripService.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _tripType == TripType.DELIVERY
                                ? 'Continue to Details'
                                : 'Confirm Ride',
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                );
              },
            ),

            // Error
            Consumer<TripService>(
              builder: (context, tripService, _) {
                if (tripService.error != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      tripService.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.dangerColor),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, IconData icon, TripType type) {
    final isSelected = _tripType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _tripType = type);
        _fetchEstimate();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppTheme.successColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    color: AppTheme.dividerColor,
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppTheme.dangerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _pickupController,
                      decoration: const InputDecoration(
                        hintText: 'Pickup location',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                    const Divider(height: 1),
                    TextField(
                      controller: _destinationController,
                      decoration: const InputDecoration(
                        hintText: 'Destination',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareEstimateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Estimated Fare',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          if (_estimateLoading)
            const SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else if (_fareEstimate != null)
            Text(
              _fareEstimate!.displayRange,
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              'K15.00 - K18.00',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Final fare may vary based on route',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: AppTheme.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
