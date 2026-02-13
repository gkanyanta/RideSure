import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/rider_service.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _imagePicker = ImagePicker();
  int _currentStep = 0;

  // Document files
  File? _selfieFile;
  File? _licenceFile;
  File? _insuranceFile;
  File? _bikeFrontFile;
  File? _bikeBackFile;
  File? _bikeLeftFile;
  File? _bikeRightFile;

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
        case 'SELFIE':
          _selfieFile = File(picked.path);
          break;
        case 'RIDER_LICENCE':
          _licenceFile = File(picked.path);
          break;
        case 'INSURANCE_CERTIFICATE':
          _insuranceFile = File(picked.path);
          break;
        case 'BIKE_FRONT':
          _bikeFrontFile = File(picked.path);
          break;
        case 'BIKE_BACK':
          _bikeBackFile = File(picked.path);
          break;
        case 'BIKE_LEFT':
          _bikeLeftFile = File(picked.path);
          break;
        case 'BIKE_RIGHT':
          _bikeRightFile = File(picked.path);
          break;
      }
    });
  }

  Future<void> _uploadDocument(String docType) async {
    File? file;
    switch (docType) {
      case 'SELFIE':
        file = _selfieFile;
        break;
      case 'RIDER_LICENCE':
        file = _licenceFile;
        break;
      case 'INSURANCE_CERTIFICATE':
        file = _insuranceFile;
        break;
      case 'BIKE_FRONT':
        file = _bikeFrontFile;
        break;
      case 'BIKE_BACK':
        file = _bikeBackFile;
        break;
      case 'BIKE_LEFT':
        file = _bikeLeftFile;
        break;
      case 'BIKE_RIGHT':
        file = _bikeRightFile;
        break;
    }

    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    // Validate insurance fields
    if (docType == 'INSURANCE_CERTIFICATE') {
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
          docType == 'INSURANCE_CERTIFICATE' ? _insurerNameController.text.trim() : null,
      policyNumber:
          docType == 'INSURANCE_CERTIFICATE' ? _policyNumberController.text.trim() : null,
      expiryDate: docType == 'INSURANCE_CERTIFICATE' && _insuranceExpiry != null
          ? _insuranceExpiry!.toIso8601String()
          : null,
    );

    setState(() {
      _uploading[docType] = false;
      if (success) _uploaded[docType] = true;
    });

    if (success) {
      // Check if all docs in current step are uploaded, auto-advance
      if (_isCurrentStepComplete()) {
        _autoAdvanceOrFinish();
      }
    } else if (mounted && rider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(rider.error!),
          backgroundColor: const Color(0xFFD32F2F),
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

  bool _isStepComplete(int step) {
    switch (step) {
      case 0:
        return _isDocUploaded('SELFIE');
      case 1:
        return _isDocUploaded('RIDER_LICENCE');
      case 2:
        return _isDocUploaded('INSURANCE_CERTIFICATE');
      case 3:
        return _isDocUploaded('BIKE_FRONT') &&
            _isDocUploaded('BIKE_BACK') &&
            _isDocUploaded('BIKE_LEFT') &&
            _isDocUploaded('BIKE_RIGHT');
      default:
        return false;
    }
  }

  bool _isCurrentStepComplete() => _isStepComplete(_currentStep);

  bool get _allStepsComplete =>
      _isStepComplete(0) && _isStepComplete(1) && _isStepComplete(2) && _isStepComplete(3);

  void _autoAdvanceOrFinish() {
    if (_allStepsComplete) {
      // All documents uploaded — navigate to vehicle screen
      Navigator.pushNamed(context, '/vehicle');
    } else if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
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
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete each step to start earning:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(4, (i) {
                    final complete = _isStepComplete(i);
                    final active = i == _currentStep;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _currentStep = i),
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                          decoration: BoxDecoration(
                            color: complete
                                ? const Color(0xFF4CAF50)
                                : active
                                    ? const Color(0xFF1B5E20)
                                    : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  'Step ${_currentStep + 1} of 4',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Step content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildCurrentStep(),
            ),
          ),

          // Bottom navigation
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildSelfieStep();
      case 1:
        return _buildLicenceStep();
      case 2:
        return _buildInsuranceStep();
      case 3:
        return _buildBikePhotosStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep--),
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isCurrentStepComplete()
                    ? () {
                        if (_currentStep < 3) {
                          setState(() => _currentStep++);
                        } else {
                          Navigator.pushNamed(context, '/vehicle');
                        }
                      }
                    : null,
                child: Text(
                  _currentStep < 3
                      ? 'Continue'
                      : _allStepsComplete
                          ? 'Add Vehicle Info'
                          : 'Continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 1: Selfie ──────────────────────────────────

  Widget _buildSelfieStep() {
    return _buildSingleDocStep(
      title: 'Selfie Photo',
      subtitle: 'Take a clear, front-facing photo of yourself. '
          'This will be used for identity verification.',
      icon: Icons.face,
      docType: 'SELFIE',
      file: _selfieFile,
    );
  }

  // ─── Step 2: Licence ─────────────────────────────────

  Widget _buildLicenceStep() {
    return _buildSingleDocStep(
      title: "Driver's Licence",
      subtitle: 'Upload a photo of your valid motorcycle driving licence. '
          'Make sure all details are clearly visible.',
      icon: Icons.card_membership,
      docType: 'RIDER_LICENCE',
      file: _licenceFile,
    );
  }

  // ─── Step 3: Insurance ────────────────────────────────

  Widget _buildInsuranceStep() {
    final isUploaded = _isDocUploaded('INSURANCE_CERTIFICATE');
    final isUploading = _uploading['INSURANCE_CERTIFICATE'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.security, color: Color(0xFF1B5E20), size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Insurance Certificate',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            if (isUploaded)
              const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 28),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Upload your third-party motor insurance certificate '
          'and fill in the details below.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),

        if (!isUploaded) ...[
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
                  color: _insuranceExpiry != null ? Colors.black : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Image preview
          if (_insuranceFile != null)
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
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
                  onPressed: () => _pickImage('INSURANCE_CERTIFICATE'),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: Text(_insuranceFile == null ? 'Select Image' : 'Change'),
                ),
              ),
              if (_insuranceFile != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        isUploading ? null : () => _uploadDocument('INSURANCE_CERTIFICATE'),
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
        ] else ...[
          const Card(
            color: Color(0xFFE8F5E9),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                  SizedBox(width: 12),
                  Text('Insurance certificate uploaded'),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Step 4: Bike Photos ──────────────────────────────

  Widget _buildBikePhotosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.two_wheeler, color: Color(0xFF1B5E20), size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Motorcycle Photos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Take clear photos of your motorcycle from all 4 sides. '
          'Make sure the plate number is visible in the back photo.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),

        // 2x2 grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
          children: [
            _buildBikePhotoCard('BIKE_FRONT', 'Front', Icons.arrow_upward, _bikeFrontFile),
            _buildBikePhotoCard('BIKE_BACK', 'Back', Icons.arrow_downward, _bikeBackFile),
            _buildBikePhotoCard('BIKE_LEFT', 'Left Side', Icons.arrow_back, _bikeLeftFile),
            _buildBikePhotoCard('BIKE_RIGHT', 'Right Side', Icons.arrow_forward, _bikeRightFile),
          ],
        ),
      ],
    );
  }

  Widget _buildBikePhotoCard(String docType, String label, IconData dirIcon, File? file) {
    final isUploaded = _isDocUploaded(docType);
    final isUploading = _uploading[docType] == true;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isUploaded ? null : () => _pickImage(docType),
        child: Column(
          children: [
            Expanded(
              child: file != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(file, fit: BoxFit.cover),
                        if (isUploaded)
                          Container(
                            color: Colors.black26,
                            child: const Center(
                              child: Icon(Icons.check_circle, color: Colors.white, size: 36),
                            ),
                          ),
                      ],
                    )
                  : isUploaded
                      ? Container(
                          color: const Color(0xFFE8F5E9),
                          child: const Center(
                            child: Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 36),
                          ),
                        )
                      : Container(
                          color: Colors.grey[100],
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(dirIcon, size: 32, color: Colors.grey[400]),
                                const SizedBox(height: 4),
                                Icon(Icons.add_a_photo, size: 24, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  if (file != null && !isUploaded)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isUploading ? null : () => _uploadDocument(docType),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          minimumSize: const Size(0, 28),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: isUploading
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Upload'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Shared single-doc step builder ──────────────────

  Widget _buildSingleDocStep({
    required String title,
    required String subtitle,
    required IconData icon,
    required String docType,
    required File? file,
  }) {
    final isUploaded = _isDocUploaded(docType);
    final isUploading = _uploading[docType] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF1B5E20), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            if (isUploaded)
              const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 28),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),

        if (isUploaded) ...[
          const Card(
            color: Color(0xFFE8F5E9),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                  SizedBox(width: 12),
                  Text('Document uploaded successfully'),
                ],
              ),
            ),
          ),
        ] else ...[
          // Image preview
          if (file != null)
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(file),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to select a photo',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

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
                    onPressed: isUploading ? null : () => _uploadDocument(docType),
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
    );
  }
}
