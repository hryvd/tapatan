import 'dart:async';

class AuthService {
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  Future<bool> authenticateWithBiometrics() async {
    // Simulate biometric auth delay
    await Future.delayed(const Duration(seconds: 1));
    _isAuthenticated = true;
    return true;
  }

  Future<void> login() async {
    // Simulate SSO login flow
    await Future.delayed(const Duration(seconds: 2));
    _isAuthenticated = true;
  }

  Future<void> logout() async {
    // Simulate logout flow
    await Future.delayed(const Duration(milliseconds: 500));
    _isAuthenticated = false;
  }
}
