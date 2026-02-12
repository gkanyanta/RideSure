import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/trip_service.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<dynamic> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final tripService = context.read<TripService>();
    try {
      final trips = await tripService.getRiderTrips();
      if (mounted) {
        setState(() {
          _trips = trips;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip History'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? const Center(child: Text('No trips yet'))
              : RefreshIndicator(
                  onRefresh: _loadTrips,
                  child: ListView.builder(
                    itemCount: _trips.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final trip = _trips[index];
                      final isDelivery = trip['type'] == 'DELIVERY';
                      final date = DateTime.tryParse(trip['createdAt'] ?? '') ?? DateTime.now();
                      final fare = trip['actualFare'] ?? trip['estimatedFareHigh'];

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDelivery ? Colors.blue[100] : Colors.green[100],
                            child: Icon(
                              isDelivery ? Icons.delivery_dining : Icons.motorcycle,
                              color: isDelivery ? Colors.blue : const Color(0xFF1B5E20),
                            ),
                          ),
                          title: Text(trip['destinationAddress'] ?? 'Unknown destination'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${trip['passenger']?['name'] ?? 'Passenger'} • ${DateFormat('MMM d, HH:mm').format(date)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _statusChip(trip['status']),
                                  const Spacer(),
                                  if (fare != null)
                                    Text('K${(fare as num).toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _statusChip(String? status) {
    Color color;
    switch (status) {
      case 'COMPLETED':
        color = Colors.green;
        break;
      case 'CANCELLED':
        color = Colors.red;
        break;
      case 'IN_PROGRESS':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status ?? 'UNKNOWN', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
