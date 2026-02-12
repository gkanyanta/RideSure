import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/trip_service.dart';

class DeliveryDetailsScreen extends StatefulWidget {
  const DeliveryDetailsScreen({super.key});

  @override
  State<DeliveryDetailsScreen> createState() => _DeliveryDetailsScreenState();
}

class _DeliveryDetailsScreenState extends State<DeliveryDetailsScreen> {
  final _notesController = TextEditingController();
  String _selectedPackageType = 'Small Package';
  final _formKey = GlobalKey<FormState>();

  final List<Map<String, dynamic>> _packageTypes = [
    {
      'label': 'Small Package',
      'icon': Icons.inventory_2_outlined,
      'description': 'Documents, small items',
    },
    {
      'label': 'Medium Package',
      'icon': Icons.card_giftcard,
      'description': 'Groceries, electronics',
    },
    {
      'label': 'Large Package',
      'icon': Icons.luggage_outlined,
      'description': 'Large items, bags',
    },
    {
      'label': 'Food',
      'icon': Icons.restaurant_outlined,
      'description': 'Food and beverages',
    },
    {
      'label': 'Other',
      'icon': Icons.more_horiz,
      'description': 'Anything else',
    },
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelivery() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) return;

    final pickup = args['pickup'] as LatLng;
    final destination = args['destination'] as LatLng;
    final pickupAddress = args['pickupAddress'] as String?;
    final destinationAddress = args['destinationAddress'] as String?;

    final tripService = context.read<TripService>();
    final trip = await tripService.requestTrip(
      pickup: pickup,
      destination: destination,
      pickupAddress: pickupAddress ?? '',
      destinationAddress: destinationAddress ?? '',
      type: TripType.DELIVERY,
      packageType: _selectedPackageType,
      packageNotes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    if (trip != null && mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/searching',
        (route) => route.settings.name == '/home',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final fareEstimate = args?['fareEstimate'] as FareEstimate?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Details'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Package Type Selection
              Text(
                'What are you sending?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              ...(_packageTypes.map((type) {
                final isSelected = _selectedPackageType == type['label'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedPackageType = type['label']);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withOpacity(0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.dividerColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            type['icon'] as IconData,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type['label'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  type['description'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryColor,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              })),

              const SizedBox(height: 24),

              // Notes
              Text(
                'Special instructions (optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'E.g., Handle with care, call recipient on arrival...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                ),
              ),

              const SizedBox(height: 24),

              // Fare Estimate
              if (fareEstimate != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimated Fare',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        fareEstimate.displayRange,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // Confirm Button
              Consumer<TripService>(
                builder: (context, tripService, _) {
                  return SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed:
                          tripService.isLoading ? null : _confirmDelivery,
                      icon: tripService.isLoading
                          ? const SizedBox.shrink()
                          : const Icon(Icons.local_shipping),
                      label: tripService.isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Request Delivery',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  );
                },
              ),

              // Error
              Consumer<TripService>(
                builder: (context, tripService, _) {
                  if (tripService.error != null) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        tripService.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.dangerColor),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
