import 'package:flutter/material.dart';
import 'digital_signatures_screen.dart';
import 'verifiable_documents_screen.dart';
import 'recent_activity_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildFeatureCard(
            context,
            icon: Icons.assignment_turned_in,
            title: 'Digital Signatures',
            subtitle: 'Sign documents securely using your e-ID',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DigitalSignaturesScreen()));
            },
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.share,
            title: 'Verifiable Documents',
            subtitle: 'Request or share official government documents',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const VerifiableDocumentsScreen()));
            },
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.history,
            title: 'Recent Activity',
            subtitle: 'View your recent authentications and signed documents',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const RecentActivityScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: CircleAvatar(
          radius: 24,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
