import 'package:flutter/material.dart';

import '../../widgets/info_card.dart';

class SecurityCenterScreen extends StatelessWidget {
  final String email;

  const SecurityCenterScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Security Center',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const InfoCard(
            title: 'Zero-Trust posture',
            value: 'Every transfer is re-evaluated before execution',
            subtitle: 'Risk-based, contextual security',
          ),
          const SizedBox(height: 12),
          InfoCard(
            title: 'Signed in as',
            value: email,
            subtitle: 'Session stored locally for demo',
          ),
          const SizedBox(height: 12),
          const InfoCard(
            title: 'Device trust',
            value: 'Demo value = 70 / 100',
            subtitle: 'Replace with real mobile device attestation later',
          ),
        ],
      ),
    );
  }
}
