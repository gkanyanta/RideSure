import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api.dart';
import '../../services/trip_service.dart';
import '../../services/socket_service.dart';

class ActiveTripScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const ActiveTripScreen({super.key, required this.trip});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  late Map<String, dynamic> trip;
  final TripService _tripService = TripService();
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    trip = Map.from(widget.trip);
  }

  String get status => trip['status'] ?? 'ACCEPTED';
  bool get isDelivery => trip['type'] == 'DELIVERY';

  Future<void> _updateStatus(String action) async {
    setState(() => _loading = true);
    try {
      final updated = await _tripService.updateTripStatus(trip['id'], action);
      if (updated != null) {
        setState(() => trip = updated);
        if (action == 'complete') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Trip completed! Earnings updated.')),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _takeDeliveryPhoto(String phase) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (photo == null) return;

    setState(() => _loading = true);
    try {
      await _tripService.uploadDeliveryPhoto(trip['id'], phase, photo.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${phase == 'pickup' ? 'Pickup' : 'Drop-off'} photo uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _launchNavigation() async {
    final destLat = trip['destinationLat'];
    final destLng = trip['destinationLng'];
    if (destLat == null || destLng == null) return;

    final uri = Uri.parse('google.navigation:q=$destLat,$destLng&mode=d');
    final fallback = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final passengerName = trip['passenger']?['name'] ?? 'Passenger';
    final pickup = trip['pickupAddress'] ?? '';
    final destination = trip['destinationAddress'] ?? '';
    final fareLow = trip['estimatedFareLow']?.toString() ?? '-';
    final fareHigh = trip['estimatedFareHigh']?.toString() ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: Text(isDelivery ? 'Active Delivery' : 'Active Ride'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status chip
                  Center(
                    child: Chip(
                      label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      backgroundColor: _statusColor(status),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Trip info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(passengerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _infoRow(Icons.circle, Colors.green, 'Pickup', pickup),
                          const SizedBox(height: 8),
                          _infoRow(Icons.location_on, Colors.red, 'Destination', destination),
                          const SizedBox(height: 8),
                          _infoRow(Icons.attach_money, Colors.amber, 'Fare', 'K$fareLow - K$fareHigh'),
                          if (isDelivery && trip['packageType'] != null) ...[
                            const SizedBox(height: 8),
                            _infoRow(Icons.inventory_2, Colors.blue, 'Package', trip['packageType']),
                          ],
                          if (trip['packageNotes'] != null && trip['packageNotes'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Text(trip['packageNotes'], style: TextStyle(color: Colors.grey[600])),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Navigation button
                  OutlinedButton.icon(
                    onPressed: _launchNavigation,
                    icon: const Icon(Icons.navigation),
                    label: const Text('Open Navigation'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Delivery photos
                  if (isDelivery && (status == 'ARRIVED' || status == 'IN_PROGRESS')) ...[
                    if (status == 'ARRIVED')
                      ElevatedButton.icon(
                        onPressed: () => _takeDeliveryPhoto('pickup'),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take Pickup Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    if (status == 'IN_PROGRESS')
                      ElevatedButton.icon(
                        onPressed: () => _takeDeliveryPhoto('dropoff'),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take Drop-off Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],

                  // Action buttons based on status
                  if (status == 'ACCEPTED')
                    ElevatedButton(
                      onPressed: () => _updateStatus('arrived'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('ARRIVED AT PICKUP', style: TextStyle(fontSize: 16)),
                    ),

                  if (status == 'ARRIVED')
                    ElevatedButton(
                      onPressed: () => _updateStatus('start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isDelivery ? 'START DELIVERY' : 'START RIDE',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),

                  if (status == 'IN_PROGRESS')
                    ElevatedButton(
                      onPressed: () => _updateStatus('complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isDelivery ? 'COMPLETE DELIVERY' : 'COMPLETE RIDE',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'ACCEPTED': return Colors.blue;
      case 'ARRIVED': return Colors.orange;
      case 'IN_PROGRESS': return const Color(0xFF1B5E20);
      case 'COMPLETED': return Colors.green;
      default: return Colors.grey;
    }
  }
}
