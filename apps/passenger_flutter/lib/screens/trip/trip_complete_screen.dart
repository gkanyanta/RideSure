import 'package:flutter/material.dart';
import '../../services/trip_service.dart';

class TripCompleteScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const TripCompleteScreen({super.key, required this.trip});

  @override
  State<TripCompleteScreen> createState() => _TripCompleteScreenState();
}

class _TripCompleteScreenState extends State<TripCompleteScreen> {
  final TripService _tripService = TripService();
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final fare = widget.trip['actualFare'] ?? widget.trip['estimatedFareHigh'] ?? 0;
    final riderName = widget.trip['rider']?['user']?['name'] ?? 'Your rider';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Complete'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Trip Completed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Pay K${(fare as num).toStringAsFixed(2)} in cash',
                style: const TextStyle(fontSize: 20, color: Color(0xFF1565C0), fontWeight: FontWeight.w600)),
            const SizedBox(height: 32),

            // Rating
            if (!_submitted) ...[
              Text('Rate $riderName', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < _rating ? Icons.star : Icons.star_border,
                      size: 40,
                      color: Colors.amber,
                    ),
                    onPressed: () => setState(() => _rating = i + 1),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'Leave a comment (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _rating == 0 || _submitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Rating'),
                ),
              ),
            ] else ...[
              const Icon(Icons.thumb_up, size: 48, color: Colors.green),
              const SizedBox(height: 8),
              const Text('Thanks for your rating!', style: TextStyle(fontSize: 16)),
            ],

            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating() async {
    setState(() => _submitting = true);
    try {
      await _tripService.rateTrip(widget.trip['id'], _rating, _commentController.text);
      setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _submitting = false);
  }
}
