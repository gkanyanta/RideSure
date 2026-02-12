import 'package:flutter/material.dart';

class InsuranceWarningWidget extends StatelessWidget {
  final int daysRemaining;
  final String message;

  const InsuranceWarningWidget({
    super.key,
    required this.daysRemaining,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    IconData icon;

    if (daysRemaining <= 0) {
      bgColor = Colors.red;
      icon = Icons.error;
    } else if (daysRemaining <= 3) {
      bgColor = Colors.orange[800]!;
      icon = Icons.warning;
    } else {
      bgColor = Colors.amber[700]!;
      icon = Icons.info;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Insurance Alert',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          if (daysRemaining > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${daysRemaining}d',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }
}
