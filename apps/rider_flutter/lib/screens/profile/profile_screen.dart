import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/rider_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/insurance_warning.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _insuranceWarning;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final riderService = context.read<RiderService>();
    try {
      final profile = await riderService.getProfile();
      final warning = await riderService.getInsuranceWarning();
      if (mounted) {
        setState(() {
          _profile = profile;
          _insuranceWarning = warning;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Failed to load profile'))
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Insurance warning
                      if (_insuranceWarning != null && _insuranceWarning!['warning'] != null)
                        InsuranceWarningWidget(
                          daysRemaining: _insuranceWarning!['daysRemaining'] ?? 0,
                          message: _insuranceWarning!['warning'],
                        ),

                      // Profile card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const CircleAvatar(
                                radius: 40,
                                backgroundColor: Color(0xFF1B5E20),
                                child: Icon(Icons.person, size: 40, color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _profile!['user']?['name'] ?? 'Rider',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _profile!['user']?['phone'] ?? '',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              _statusBadge(_profile!['status'] ?? 'PENDING'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats
                      Row(
                        children: [
                          _statCard('Total Trips', '${_profile!['totalTrips'] ?? 0}', Icons.motorcycle),
                          const SizedBox(width: 12),
                          _statCard('Rating', '${(_profile!['avgRating'] ?? 0.0).toStringAsFixed(1)}', Icons.star),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Vehicle
                      if (_profile!['vehicle'] != null)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.two_wheeler, color: Color(0xFF1B5E20)),
                            title: Text(_profile!['vehicle']['model'] ?? ''),
                            subtitle: Text(
                              '${_profile!['vehicle']['color'] ?? ''} • ${_profile!['vehicle']['plateNumber'] ?? ''}',
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Documents status
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text('Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            ...(_profile!['documents'] as List? ?? []).map<Widget>((doc) {
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  doc['status'] == 'APPROVED' ? Icons.check_circle : Icons.pending,
                                  color: doc['status'] == 'APPROVED' ? Colors.green : Colors.orange,
                                ),
                                title: Text(_docTypeLabel(doc['type'])),
                                trailing: Text(doc['status'] ?? '', style: const TextStyle(fontSize: 12)),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Logout
                      OutlinedButton.icon(
                        onPressed: () async {
                          await context.read<AuthService>().logout();
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                          }
                        },
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF1B5E20), size: 28),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'APPROVED': color = Colors.green; break;
      case 'SUSPENDED': color = Colors.red; break;
      case 'PENDING_APPROVAL': color = Colors.orange; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  String _docTypeLabel(String? type) {
    switch (type) {
      case 'NRC': return 'National Registration Card';
      case 'SELFIE': return 'Selfie Photo';
      case 'RIDER_LICENCE': return "Rider's Licence";
      case 'INSURANCE_CERTIFICATE': return 'Insurance Certificate';
      default: return type ?? '';
    }
  }
}
