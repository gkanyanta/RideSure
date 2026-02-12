import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/user.dart';
import '../../services/trip_service.dart';
import '../../services/socket_service.dart';

/// Full-screen route for incoming job (used from routes).
class IncomingJobScreen extends StatelessWidget {
  const IncomingJobScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final offer = socket.currentOffer;

    if (offer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('No Active Offer')),
        body: const Center(child: Text('No incoming job offer.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: IncomingJobContent(
          offer: offer,
          onAccept: () => Navigator.pop(context),
          onReject: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

/// Bottom sheet variant shown as overlay on home screen.
class IncomingJobSheet extends StatelessWidget {
  final TripOffer offer;

  const IncomingJobSheet({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        child: IncomingJobContent(
          offer: offer,
          onAccept: () => Navigator.pop(context),
          onReject: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

/// Core content widget for incoming job.
class IncomingJobContent extends StatefulWidget {
  final TripOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingJobContent({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingJobContent> createState() => _IncomingJobContentState();
}

class _IncomingJobContentState extends State<IncomingJobContent> {
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.offer.expiresInSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    // Auto-reject on timeout
    final socket = context.read<SocketService>();
    socket.rejectTrip(widget.offer.tripId);
    widget.onReject();
  }

  Future<void> _acceptJob() async {
    _timer?.cancel();

    final socket = context.read<SocketService>();
    final tripService = context.read<TripService>();

    // Accept via socket for immediate response
    socket.acceptTrip(widget.offer.tripId);

    // Also accept via REST API for reliability
    await tripService.acceptTrip(widget.offer.tripId);

    widget.onAccept();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/active-trip',
        (route) => route.settings.name == '/home' || route.isFirst,
      );
    }
  }

  void _rejectJob() {
    _timer?.cancel();

    final socket = context.read<SocketService>();
    socket.rejectTrip(widget.offer.tripId);

    widget.onReject();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.offer.trip;
    final progress = _secondsLeft / widget.offer.expiresInSeconds;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation(
                    _secondsLeft <= 5
                        ? AppTheme.dangerRed
                        : AppTheme.primaryGreen,
                  ),
                ),
              ),
              Text(
                '$_secondsLeft',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _secondsLeft <= 5
                      ? AppTheme.dangerRed
                      : AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Trip type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: trip.isDelivery
                  ? AppTheme.warningOrange.withOpacity(0.1)
                  : AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trip.isDelivery ? 'DELIVERY' : 'RIDE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: trip.isDelivery
                    ? AppTheme.warningOrange
                    : AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fare range
          Text(
            trip.fareRange,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
          if (trip.distance != null)
            Text(
              '${trip.distance!.toStringAsFixed(1)} km',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          const SizedBox(height: 20),

          // Pickup
          _buildLocationRow(
            icon: Icons.radio_button_checked,
            color: AppTheme.accentGreen,
            label: 'PICKUP',
            address: trip.pickupAddress,
          ),
          Container(
            margin: const EdgeInsets.only(left: 11),
            height: 20,
            width: 2,
            color: Colors.grey[300],
          ),
          // Dropoff
          _buildLocationRow(
            icon: Icons.location_on,
            color: AppTheme.dangerRed,
            label: 'DROP-OFF',
            address: trip.dropoffAddress,
          ),

          if (trip.passenger != null) ...[
            const SizedBox(height: 16),
            Text(
              'Passenger: ${trip.passenger!.fullName}',
              style: const TextStyle(fontSize: 15),
            ),
          ],

          if (trip.deliveryNotes != null && trip.deliveryNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Note: ${trip.deliveryNotes}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _rejectJob,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerRed,
                      side: const BorderSide(color: AppTheme.dangerRed),
                    ),
                    child: const Text(
                      'REJECT',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _acceptJob,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                    child: const Text(
                      'ACCEPT',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                address,
                style: const TextStyle(fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
