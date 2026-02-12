import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/trip_service.dart';

class SosButton extends StatelessWidget {
  final String tripId;
  const SosButton({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'sos',
      backgroundColor: Colors.red,
      onPressed: () => _showSosDialog(context),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sos, color: Colors.white, size: 22),
          Text('SOS', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showSosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergency SOS'),
          ],
        ),
        content: const Text(
          'This will alert our team and log an emergency incident for this trip. '
          'You will also be prompted to call emergency services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final tripService = context.read<TripService>();
                await tripService.sendSos(tripId, description: 'SOS triggered by passenger');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('SOS alert sent! Call 991 for police or 993 for ambulance.'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sending SOS: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('SEND SOS'),
          ),
        ],
      ),
    );
  }
}
