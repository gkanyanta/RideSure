import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api.dart';

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  io.Socket? get socket => _socket;

  /// Connect to Socket.IO server with auth token
  Future<void> connect() async {
    if (_socket != null && _isConnected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      print('[Socket] No auth token found, cannot connect');
      return;
    }

    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      print('[Socket] Connected');
      _isConnected = true;
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      print('[Socket] Disconnected');
      _isConnected = false;
      notifyListeners();
    });

    _socket!.onConnectError((error) {
      print('[Socket] Connection error: $error');
      _isConnected = false;
      notifyListeners();
    });

    _socket!.onError((error) {
      print('[Socket] Error: $error');
    });

    _socket!.connect();
  }

  /// Listen for trip events
  void onTripEvent(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  /// Listen for all trip-related events
  void listenForTripUpdates({
    Function(dynamic)? onSearching,
    Function(dynamic)? onAccepted,
    Function(dynamic)? onNoRiders,
    Function(dynamic)? onArrived,
    Function(dynamic)? onInProgress,
    Function(dynamic)? onCompleted,
    Function(dynamic)? onCancelled,
    Function(dynamic)? onLocationUpdate,
  }) {
    if (onSearching != null) _socket?.on('trip:searching', onSearching);
    if (onAccepted != null) _socket?.on('trip:accepted', onAccepted);
    if (onNoRiders != null) _socket?.on('trip:no_riders', onNoRiders);
    if (onArrived != null) _socket?.on('trip:arrived', onArrived);
    if (onInProgress != null) _socket?.on('trip:in_progress', onInProgress);
    if (onCompleted != null) _socket?.on('trip:completed', onCompleted);
    if (onCancelled != null) _socket?.on('trip:cancelled', onCancelled);
    if (onLocationUpdate != null) {
      _socket?.on('rider:location', onLocationUpdate);
    }
  }

  /// Remove all trip listeners
  void removeAllTripListeners() {
    _socket?.off('trip:searching');
    _socket?.off('trip:accepted');
    _socket?.off('trip:no_riders');
    _socket?.off('trip:arrived');
    _socket?.off('trip:in_progress');
    _socket?.off('trip:completed');
    _socket?.off('trip:cancelled');
    _socket?.off('rider:location');
  }

  /// Emit an event
  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  /// Disconnect from server
  void disconnect() {
    removeAllTripListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
