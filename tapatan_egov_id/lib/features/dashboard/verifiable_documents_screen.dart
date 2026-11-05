import 'package:flutter/material.dart';

class VerifiableDocumentsScreen extends StatelessWidget {
  const VerifiableDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifiable Documents'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'My Credentials',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildDocumentCard(
            context,
            title: 'National ID',
            status: 'Verified',
            icon: Icons.badge,
            color: Colors.blue,
          ),
          _buildDocumentCard(
            context,
            title: 'Driver\'s License',
            status: 'Verified',
            icon: Icons.directions_car,
            color: Colors.green,
          ),
          _buildDocumentCard(
            context,
            title: 'Vaccination Certificate',
            status: 'Pending',
            icon: Icons.medical_services,
            color: Colors.orange,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Add Document'),
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, {required String title, required String status, required IconData icon, required Color color}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Icon(
              status == 'Verified' ? Icons.check_circle : Icons.pending,
              size: 14,
              color: status == 'Verified' ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(status),
          ],
        ),
        trailing: const Icon(Icons.qr_code),
        onTap: () {
          // Show QR code for verification
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('$title QR'),
              content: const SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: Icon(Icons.qr_code_2, size: 150),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
