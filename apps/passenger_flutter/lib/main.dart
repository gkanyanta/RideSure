import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'services/auth_service.dart';
import 'services/trip_service.dart';
import 'services/socket_service.dart';
import 'services/location_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/booking/booking_screen.dart';
import 'screens/booking/location_search_screen.dart';
import 'screens/booking/delivery_details_screen.dart';
import 'screens/trip/searching_screen.dart';
import 'screens/trip/active_trip_screen.dart';
import 'screens/trip/trip_complete_screen.dart';
import 'screens/history/trip_history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RideSurePassengerApp());
}

class RideSurePassengerApp extends StatelessWidget {
  const RideSurePassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => TripService()),
        ChangeNotifierProvider(create: (_) => SocketService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: MaterialApp(
        title: 'RideSure',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/otp': (context) => const OtpScreen(),
          '/home': (context) => const HomeScreen(),
          '/location-search': (context) => const LocationSearchScreen(),
          '/booking': (context) => const BookingScreen(),
          '/delivery-details': (context) => const DeliveryDetailsScreen(),
          '/searching': (context) => const SearchingScreen(),
          '/active-trip': (context) => const ActiveTripScreen(),
          '/trip-complete': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            final trip = args is Map<String, dynamic> ? args : <String, dynamic>{};
            return TripCompleteScreen(trip: trip);
          },
          '/trip-history': (context) => const TripHistoryScreen(),
        },
      ),
    );
  }
}
