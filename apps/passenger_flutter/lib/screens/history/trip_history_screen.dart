import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/trip_service.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final TripService _tripService = TripService();
  List<dynamic> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final trips = await _tripService.getMyTrips();
      setState(() { _trips = trips; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip History'),
        backgroundColor: const Color(0xFF1565C0),
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
                      final riderName = trip['rider']?['user']?['name'] ?? 'Unknown';

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDelivery ? Colors.orange[100] : Colors.blue[100],
                            child: Icon(
                              isDelivery ? Icons.delivery_dining : Icons.motorcycle,
                              color: isDelivery ? Colors.orange : const Color(0xFF1565C0),
                            ),
                          ),
                          title: Text(trip['destinationAddress'] ?? 'Unknown'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$riderName • ${DateFormat('MMM d, HH:mm').format(date)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _statusChip(trip['status']),
                                  const Spacer(),
                                  if (fare != null)
                                    Text('K${(fare as num).toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (trip['rating'] != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.star, size: 14, color: Colors.amber[700]),
                                    Text('${trip['rating']['score']}', style: const TextStyle(fontSize: 12)),
                                  ],
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
      case 'COMPLETED': color = Colors.green; break;
      case 'CANCELLED': color = Colors.red; break;
      case 'IN_PROGRESS': color = Colors.blue; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(status ?? '', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
