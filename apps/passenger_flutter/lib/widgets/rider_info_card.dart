import 'package:flutter/material.dart';
import '../models/models.dart';

class RiderInfoCard extends StatelessWidget {
  final Rider rider;
  const RiderInfoCard({super.key, required this.rider});

  @override
  Widget build(BuildContext context) {
    final name = rider.displayName;
    final rating = rider.avgRating;
    final totalTrips = rider.totalTrips;
    final vehicle = rider.vehicle;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFF1565C0),
                  child: Icon(Icons.person, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 2),
                          Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text('$totalTrips trips', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Verified badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Verified',
                          style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            if (vehicle != null) ...[
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.two_wheeler, size: 20, color: Color(0xFF1565C0)),
                  const SizedBox(width: 8),
                  Text('${vehicle.model ?? ''} • ${vehicle.plateNumber ?? ''}'),
                  if (vehicle.color != null) ...[
                    const SizedBox(width: 4),
                    Text('(${vehicle.color})', style: TextStyle(color: Colors.grey[600])),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
