import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destinationFocus = FocusNode();
  final _geocodingService = GeocodingService();

  List<PlaceResult> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounce;

  // Which field is currently being edited
  bool _editingPickup = false;

  // Selected results with coordinates
  PlaceResult? _selectedPickup;
  PlaceResult? _selectedDestination;

  // Initial pickup from GPS
  String? _initialPickupAddress;
  double? _initialPickupLat;
  double? _initialPickupLng;

  @override
  void initState() {
    super.initState();
    _prefillCurrentLocation();
    // Auto-focus destination after frame builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _destinationFocus.requestFocus();
    });
  }

  void _prefillCurrentLocation() async {
    final locationService = context.read<LocationService>();
    final position = locationService.currentPosition;
    if (position != null) {
      _initialPickupLat = position.latitude;
      _initialPickupLng = position.longitude;

      // Reverse geocode to get address
      final address = await _geocodingService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _initialPickupAddress = address;
          _pickupController.text = address;
          _selectedPickup = PlaceResult(
            placeId: 'current_location',
            description: address,
            mainText: 'Current location',
            secondaryText: address,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await _geocodingService.searchPlaces(query);
    if (mounted) {
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _selectPlace(PlaceResult place) async {
    // Get coordinates for the selected place
    final detailed = await _geocodingService.getPlaceDetails(place);
    if (detailed == null || !mounted) return;

    setState(() {
      if (_editingPickup) {
        _selectedPickup = detailed;
        _pickupController.text = detailed.mainText;
        _suggestions = [];
        // Auto-focus destination
        _editingPickup = false;
        _destinationFocus.requestFocus();
      } else {
        _selectedDestination = detailed;
        _destinationController.text = detailed.mainText;
        _suggestions = [];
      }
    });

    // If both are selected, return result
    _tryReturnResult();
  }

  void _useCurrentLocation() async {
    final locationService = context.read<LocationService>();
    final position = await locationService.getCurrentLocation();
    if (position == null || !mounted) return;

    final address = await _geocodingService.reverseGeocode(
      position.latitude,
      position.longitude,
    );

    if (!mounted) return;

    setState(() {
      _selectedPickup = PlaceResult(
        placeId: 'current_location',
        description: address,
        mainText: 'Current location',
        secondaryText: address,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _pickupController.text = address;
      _suggestions = [];
      _editingPickup = false;
      _destinationFocus.requestFocus();
    });

    _tryReturnResult();
  }

  void _tryReturnResult() {
    if (_selectedPickup?.latitude != null &&
        _selectedDestination?.latitude != null) {
      Navigator.pop(context, {
        'pickupLatLng': _selectedPickup!.toLatLng(),
        'pickupAddress': _selectedPickup!.description,
        'destinationLatLng': _selectedDestination!.toLatLng(),
        'destinationAddress': _selectedDestination!.description,
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupController.dispose();
    _destinationController.dispose();
    _pickupFocus.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: const Text('Set locations'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: _buildInputFields(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildInputFields() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          // Route dots
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 36, color: AppTheme.dividerColor),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppTheme.dangerColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Text fields
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: _pickupController,
                  focusNode: _pickupFocus,
                  onTap: () => setState(() => _editingPickup = true),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Pickup location',
                    prefixIcon: const Icon(Icons.circle, size: 8,
                        color: AppTheme.successColor),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _destinationController,
                  focusNode: _destinationFocus,
                  onTap: () => setState(() => _editingPickup = false),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Where are you going?',
                    prefixIcon: const Icon(Icons.circle, size: 8,
                        color: AppTheme.dangerColor),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        const Divider(height: 1),
        // "Use current location" shortcut (shown when editing pickup)
        if (_editingPickup)
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.my_location,
                  color: AppTheme.primaryColor, size: 20),
            ),
            title: const Text('Use current location',
                style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              _initialPickupAddress ?? 'Detecting...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            onTap: _useCurrentLocation,
          ),

        // Loading indicator
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),

        // Suggestions list
        Expanded(
          child: ListView.separated(
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
            itemBuilder: (context, index) {
              final place = _suggestions[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_on_outlined,
                      color: AppTheme.textSecondary, size: 20),
                ),
                title: Text(
                  place.mainText,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  place.secondaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                onTap: () => _selectPlace(place),
              );
            },
          ),
        ),
      ],
    );
  }
}
