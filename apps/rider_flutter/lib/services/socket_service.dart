import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api.dart';
import '../models/user.dart';
import 'auth_service.dart';

class SocketService extends ChangeNotifier {
  AuthService? _auth;
  io.Socket? _socket;
  bool _isConnected = false;
  TripOffer? _currentOffer;

  bool get isConnected => _isConnected;
  TripOffer? get currentOffer => _currentOffer;

  // Callbacks that screens can register
  void Function(TripOffer offer)? onTripOffer;
  void Function(Trip trip)? onTripUpdate;
  void Function(String tripId)? onTripCancelled;

  void updateAuth(AuthService auth) {
    _auth = auth;
    if (auth.isLoggedIn && _socket == null) {
      connect();
    } else if (!auth.isLoggedIn && _socket != null) {
      disconnect();
    }
  }

  /// Connect to Socket.IO server.
  void connect() {
    if (_auth?.token == null) return;

    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': _auth!.token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket!.onConnect((_) {
      print('Socket connected');
      _isConnected = true;
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
      _isConnected = false;
      notifyListeners();
    });

    _socket!.onConnectError((data) {
      print('Socket connection error: $data');
      _isConnected = false;
      notifyListeners();
    });

    // Listen for trip offers
    _socket!.on('trip:offer', (data) {
      print('Received trip offer: $data');
      try {
        final offer = TripOffer.fromJson(data);
        _currentOffer = offer;
        notifyListeners();
        onTripOffer?.call(offer);
      } catch (e) {
        print('Error parsing trip offer: $e');
      }
    });

    // Listen for trip updates
    _socket!.on('trip:update', (data) {
      print('Trip update: $data');
      try {
        final trip = Trip.fromJson(data);
        onTripUpdate?.call(trip);
      } catch (e) {
        print('Error parsing trip update: $e');
      }
    });

    // Listen for trip cancellation
    _socket!.on('trip:cancelled', (data) {
      print('Trip cancelled: $data');
      _currentOffer = null;
      notifyListeners();
      final tripId = data is Map ? data['tripId'] : data.toString();
      onTripCancelled?.call(tripId);
    });

    // Listen for offer expired
    _socket!.on('trip:offer_expired', (data) {
      print('Trip offer expired');
      _currentOffer = null;
      notifyListeners();
    });

    _socket!.connect();
  }

  /// Disconnect from socket.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _currentOffer = null;
    notifyListeners();
  }

  /// Accept a trip via socket.
  void acceptTrip(String tripId) {
    _socket?.emit('trip:accept', {'tripId': tripId});
    _currentOffer = null;
    notifyListeners();
  }

  /// Reject a trip via socket.
  void rejectTrip(String tripId) {
    _socket?.emit('trip:reject', {'tripId': tripId});
    _currentOffer = null;
    notifyListeners();
  }

  /// Send location update via socket.
  void sendLocation(double lat, double lng) {
    _socket?.emit('location:update', {
      'latitude': lat,
      'longitude': lng,
    });
  }

  /// Clear current offer.
  void clearOffer() {
    _currentOffer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
