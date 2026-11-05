import 'package:flutter/material.dart';

class RecentActivityScreen extends StatelessWidget {
  const RecentActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Activity'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildActivityItem(
            title: 'Identity Verified (NFC)',
            description: 'Tapatan Authenticator App',
            date: 'Today, 11:45 AM',
            icon: Icons.nfc,
            color: Colors.blue,
          ),
          _buildActivityItem(
            title: 'Document Signed',
            description: 'Tax Declaration Form 2026',
            date: 'Today, 10:05 AM',
            icon: Icons.edit_document,
            color: Colors.green,
          ),
          _buildActivityItem(
            title: 'Credential Shared',
            description: 'Driver\'s License shared with Traffic Enforcer',
            date: 'Yesterday, 4:20 PM',
            icon: Icons.share,
            color: Colors.purple,
          ),
          _buildActivityItem(
            title: 'Login',
            description: 'New device login (iPhone 14)',
            date: 'Aug 15, 2026, 09:00 AM',
            icon: Icons.login,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({required String title, required String description, required String date, required IconData icon, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
