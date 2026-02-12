import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/rider_service.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _engineSizeController = TextEditingController();

  // Common motorcycle makes in Zambia
  final _commonMakes = [
    'Honda',
    'Yamaha',
    'Suzuki',
    'Bajaj',
    'TVS',
    'Boxer',
    'Lifan',
    'Haojue',
    'Sonlink',
    'Other',
  ];

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _engineSizeController.dispose();
    super.dispose();
  }

  Future<void> _submitVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    final rider = context.read<RiderService>();
    final success = await rider.submitVehicle(
      make: _makeController.text.trim(),
      model: _modelController.text.trim(),
      year: int.parse(_yearController.text.trim()),
      color: _colorController.text.trim(),
      plateNumber: _plateController.text.trim().toUpperCase(),
      engineSize: _engineSizeController.text.trim().isNotEmpty
          ? _engineSizeController.text.trim()
          : null,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle information saved!'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
      Navigator.pop(context);
    } else if (mounted && rider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(rider.error!),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Information')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tell us about your motorcycle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'This information helps passengers identify your bike.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Make dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Make / Brand',
                  prefixIcon: Icon(Icons.two_wheeler),
                ),
                items: _commonMakes
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  _makeController.text = val ?? '';
                },
                validator: (val) =>
                    val == null || val.isEmpty ? 'Select a make' : null,
              ),
              const SizedBox(height: 16),

              // Model
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'e.g. CG125, Pulsar 150',
                  prefixIcon: Icon(Icons.info_outline),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Enter the model' : null,
              ),
              const SizedBox(height: 16),

              // Year
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  labelText: 'Year',
                  hintText: 'e.g. 2023',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter the year';
                  final year = int.tryParse(val);
                  if (year == null || year < 2000 || year > 2030) {
                    return 'Enter a valid year';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Color
              TextFormField(
                controller: _colorController,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  hintText: 'e.g. Black, Red, Blue',
                  prefixIcon: Icon(Icons.palette),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Enter the color' : null,
              ),
              const SizedBox(height: 16),

              // Plate number
              TextFormField(
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Number Plate',
                  hintText: 'e.g. ABX 1234',
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Enter the plate number'
                    : null,
              ),
              const SizedBox(height: 16),

              // Engine size (optional)
              TextFormField(
                controller: _engineSizeController,
                decoration: const InputDecoration(
                  labelText: 'Engine Size (optional)',
                  hintText: 'e.g. 125cc, 150cc',
                  prefixIcon: Icon(Icons.speed),
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              Consumer<RiderService>(
                builder: (context, rider, _) {
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: rider.isLoading ? null : _submitVehicle,
                      icon: rider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save Vehicle Info'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
