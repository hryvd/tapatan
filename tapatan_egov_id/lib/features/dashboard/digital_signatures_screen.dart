import 'package:flutter/material.dart';

class DigitalSignaturesScreen extends StatelessWidget {
  const DigitalSignaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Signatures'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pending Signatures',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSignatureRequestCard(
            context,
            title: 'Tax Declaration Form 2026',
            requester: 'Bureau of Internal Revenue',
            date: 'Today, 10:00 AM',
          ),
          _buildSignatureRequestCard(
            context,
            title: 'Business Permit Renewal',
            requester: 'City Government',
            date: 'Yesterday, 2:30 PM',
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureRequestCard(BuildContext context, {required String title, required String requester, required String date}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Requested by: $requester', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Document digitally signed!')),
                    );
                  },
                  child: const Text('Sign Document'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
