import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'services/auth_service.dart';
import 'services/rider_service.dart';
import 'services/trip_service.dart';
import 'services/socket_service.dart';
import 'services/location_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/onboarding/documents_screen.dart';
import 'screens/onboarding/vehicle_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/trip/incoming_job_screen.dart';
import 'screens/trip/active_trip_screen.dart';
import 'screens/trip/trip_history_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RideSureRiderApp());
}

class RideSureRiderApp extends StatelessWidget {
  const RideSureRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProxyProvider<AuthService, RiderService>(
          create: (_) => RiderService(),
          update: (_, auth, rider) => rider!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthService, TripService>(
          create: (_) => TripService(),
          update: (_, auth, trip) => trip!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthService, SocketService>(
          create: (_) => SocketService(),
          update: (_, auth, socket) => socket!..updateAuth(auth),
        ),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: MaterialApp(
        title: 'RideSure Rider',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkGreenTheme,
        home: const AuthGate(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/otp': (context) => const OtpScreen(),
          '/documents': (context) => const DocumentsScreen(),
          '/vehicle': (context) => const VehicleScreen(),
          '/home': (context) => const HomeScreen(),
          '/incoming-job': (context) => const IncomingJobScreen(),
          '/active-trip': (context) => const ActiveTripScreen(),
          '/trip-history': (context) => const TripHistoryScreen(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}

/// Gate that checks auth state and routes accordingly.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthService>();
    await auth.loadStoredToken();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn) {
          return const LoginScreen();
        }

        // Fetch rider profile if needed
        final rider = context.read<RiderService>();
        if (rider.profile == null && !rider.isLoading) {
          rider.fetchProfile();
        }

        return Consumer<RiderService>(
          builder: (context, riderService, _) {
            if (riderService.isLoading || riderService.profile == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final status = riderService.profile!.status;

            if (status == 'PENDING_DOCUMENTS') {
              return const DocumentsScreen();
            }

            if (status == 'PENDING_APPROVAL') {
              return const _PendingApprovalScreen();
            }

            // APPROVED or ACTIVE
            return const HomeScreen();
          },
        );
      },
    );
  }
}

class _PendingApprovalScreen extends StatelessWidget {
  const _PendingApprovalScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approval')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Your account is under review',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'We are verifying your documents. This usually takes 24-48 hours. '
                'You will receive an SMS when your account is approved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<RiderService>().fetchProfile();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Status'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  context.read<AuthService>().logout();
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
