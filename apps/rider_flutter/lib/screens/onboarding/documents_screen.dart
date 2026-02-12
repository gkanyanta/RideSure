import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/rider_service.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _imagePicker = ImagePicker();

  // Document files
  File? _nrcFile;
  File? _selfieFile;
  File? _licenceFile;
  File? _insuranceFile;

  // Insurance fields
  final _insurerNameController = TextEditingController();
  final _policyNumberController = TextEditingController();
  DateTime? _insuranceExpiry;

  // Upload state per document
  final Map<String, bool> _uploading = {};
  final Map<String, bool> _uploaded = {};

  @override
  void dispose() {
    _insurerNameController.dispose();
    _policyNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String docType) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (picked == null) return;

    setState(() {
      switch (docType) {
        case 'NRC':
          _nrcFile = File(picked.path);
          break;
        case 'SELFIE':
          _selfieFile = File(picked.path);
          break;
        case 'DRIVERS_LICENCE':
          _licenceFile = File(picked.path);
          break;
        case 'INSURANCE':
          _insuranceFile = File(picked.path);
          break;
      }
    });
  }

  Future<void> _uploadDocument(String docType) async {
    File? file;
    switch (docType) {
      case 'NRC':
        file = _nrcFile;
        break;
      case 'SELFIE':
        file = _selfieFile;
        break;
      case 'DRIVERS_LICENCE':
        file = _licenceFile;
        break;
      case 'INSURANCE':
        file = _insuranceFile;
        break;
    }

    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    // Validate insurance fields
    if (docType == 'INSURANCE') {
      if (_insurerNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the insurer name')),
        );
        return;
      }
      if (_policyNumberController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the policy number')),
        );
        return;
      }
      if (_insuranceExpiry == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select the insurance expiry date')),
        );
        return;
      }
    }

    setState(() => _uploading[docType] = true);

    final rider = context.read<RiderService>();
    final success = await rider.uploadDocument(
      type: docType,
      file: file,
      insurerName:
          docType == 'INSURANCE' ? _insurerNameController.text.trim() : null,
      policyNumber:
          docType == 'INSURANCE' ? _policyNumberController.text.trim() : null,
      expiryDate: docType == 'INSURANCE' && _insuranceExpiry != null
          ? _insuranceExpiry!.toIso8601String()
          : null,
    );

    setState(() {
      _uploading[docType] = false;
      if (success) _uploaded[docType] = true;
    });

    if (!success && mounted && rider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(rider.error!),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  Future<void> _pickExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      setState(() => _insuranceExpiry = date);
    }
  }

  bool _isDocUploaded(String docType) {
    if (_uploaded[docType] == true) return true;
    final rider = context.read<RiderService>();
    if (rider.profile != null) {
      return rider.profile!.documents.any(
        (d) => d.type == docType && (d.isPending || d.isApproved),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Documents'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              context.read<AuthService>().logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To start earning, upload the following documents:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // NRC
            _buildDocumentCard(
              title: 'National Registration Card (NRC)',
              subtitle: 'Front side of your NRC',
              icon: Icons.badge,
              docType: 'NRC',
              file: _nrcFile,
            ),
            const SizedBox(height: 12),

            // Selfie
            _buildDocumentCard(
              title: 'Selfie Photo',
              subtitle: 'Clear photo of your face',
              icon: Icons.face,
              docType: 'SELFIE',
              file: _selfieFile,
            ),
            const SizedBox(height: 12),

            // Driver's Licence
            _buildDocumentCard(
              title: "Driver's Licence",
              subtitle: 'Valid motorcycle driving licence',
              icon: Icons.card_membership,
              docType: 'DRIVERS_LICENCE',
              file: _licenceFile,
            ),
            const SizedBox(height: 12),

            // Insurance
            _buildInsuranceCard(),

            const SizedBox(height: 24),

            // Navigate to vehicle form
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/vehicle');
                },
                icon: const Icon(Icons.two_wheeler),
                label: const Text('Add Vehicle Information'),
              ),
            ),
            const SizedBox(height: 12),

            // Refresh status
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<RiderService>().fetchProfile();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Status'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String docType,
    required File? file,
  }) {
    final isUploaded = _isDocUploaded(docType);
    final isUploading = _uploading[docType] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryGreen, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUploaded)
                  const Icon(Icons.check_circle, color: AppTheme.accentGreen),
              ],
            ),
            if (!isUploaded) ...[
              const SizedBox(height: 12),
              if (file != null)
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(file),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(docType),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: Text(file == null ? 'Select Image' : 'Change'),
                    ),
                  ),
                  if (file != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            isUploading ? null : () => _uploadDocument(docType),
                        child: isUploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Upload'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsuranceCard() {
    final isUploaded = _isDocUploaded('INSURANCE');
    final isUploading = _uploading['INSURANCE'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: AppTheme.primaryGreen, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Insurance Certificate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Third-party motor insurance',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUploaded)
                  const Icon(Icons.check_circle, color: AppTheme.accentGreen),
              ],
            ),
            if (!isUploaded) ...[
              const SizedBox(height: 16),

              // Insurer name
              TextFormField(
                controller: _insurerNameController,
                decoration: const InputDecoration(
                  labelText: 'Insurer Name',
                  hintText: 'e.g. ZSIC, Professional Insurance',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 12),

              // Policy number
              TextFormField(
                controller: _policyNumberController,
                decoration: const InputDecoration(
                  labelText: 'Policy Number',
                  hintText: 'e.g. POL-2025-12345',
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 12),

              // Expiry date picker
              InkWell(
                onTap: _pickExpiryDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expiry Date',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _insuranceExpiry != null
                        ? DateFormat('dd MMM yyyy').format(_insuranceExpiry!)
                        : 'Select expiry date',
                    style: TextStyle(
                      color: _insuranceExpiry != null
                          ? Colors.black
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Insurance document image
              if (_insuranceFile != null)
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(_insuranceFile!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage('INSURANCE'),
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: Text(_insuranceFile == null
                          ? 'Select Image'
                          : 'Change'),
                    ),
                  ),
                  if (_insuranceFile != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isUploading
                            ? null
                            : () => _uploadDocument('INSURANCE'),
                        child: isUploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Upload'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
