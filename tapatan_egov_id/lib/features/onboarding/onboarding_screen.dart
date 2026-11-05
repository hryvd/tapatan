import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isScanning = false;

  void _startNfcScan() async {
    setState(() {
      _isScanning = true;
    });
    
    // Simulate NFC scan delay
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Navigate to Dashboard
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tapatan e-Gov ID'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isScanning ? Icons.wifi : Icons.security, 
              size: 100, 
              color: _isScanning ? Colors.green : Colors.blue,
            ),
            const SizedBox(height: 32),
            Text(
              _isScanning ? 'Reading NFC...' : 'Secure Your Digital Identity',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (!_isScanning)
              const Text(
                'Verify your identity using your Emirates ID\nor National ID via NFC.',
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 48),
            if (_isScanning)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _startNfcScan,
                child: const Text('Register with NFC'),
              ),
          ],
        ),
      ),
    );
  }
}
