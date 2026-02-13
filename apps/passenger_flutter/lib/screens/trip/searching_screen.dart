import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart' as models;
import '../../services/trip_service.dart';
import '../../services/socket_service.dart';

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _listenForSocketEvents();
  }

  void _listenForSocketEvents() {
    final socket = context.read<SocketService>();
    final tripService = context.read<TripService>();

    socket.listenForTripUpdates(
      onAccepted: (data) {
        if (data is Map<String, dynamic>) {
          // trip:accepted payload has { tripId, rider: {...} }
          // Update current trip with rider info and ACCEPTED status
          final riderData = data['rider'];
          if (tripService.currentTrip != null && riderData is Map<String, dynamic>) {
            final rider = models.Rider.fromJson(riderData);
            tripService.updateTripStatus(models.TripStatus.ACCEPTED, rider: rider);
          } else {
            tripService.updateTripFromSocket(data);
          }
        }
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/active-trip');
        }
      },
      onNoRiders: (data) {
        if (mounted) {
          _showNoRidersDialog();
        }
      },
      onCancelled: (data) {
        if (mounted) {
          tripService.clearCurrentTrip();
          Navigator.popUntil(
              context, (route) => route.settings.name == '/home');
        }
      },
    );

    // Emit trip:request to trigger backend matching
    final trip = tripService.currentTrip;
    if (trip != null && trip.id.isNotEmpty) {
      socket.emit('trip:request', {'tripId': trip.id});
    }
  }

  void _showNoRidersDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('No riders available'),
        content: const Text(
          'Sorry, there are no riders available in your area right now. Please try again in a few minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              final tripService = context.read<TripService>();
              tripService.clearCurrentTrip();
              Navigator.popUntil(
                  context, (route) => route.settings.name == '/home');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSearch() async {
    final tripService = context.read<TripService>();
    final trip = tripService.currentTrip;

    if (trip != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel search?'),
          content: const Text('Stop looking for a rider?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep searching'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.dangerColor,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        await tripService.cancelTrip(trip.id);
        if (mounted) {
          Navigator.popUntil(
              context, (route) => route.settings.name == '/home');
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    final socket = context.read<SocketService>();
    socket.removeAllTripListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _cancelSearch();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Pulsing animation
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse rings
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _opacityAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryColor,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Center icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.two_wheeler,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Text(
                'Looking for a rider...',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'We\'re finding the nearest available rider for you. This usually takes less than a minute.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // Cancel button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _cancelSearch,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerColor,
                      side: const BorderSide(color: AppTheme.dangerColor),
                    ),
                    child: const Text('Cancel Search'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
