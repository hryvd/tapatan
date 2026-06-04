import 'package:flutter/material.dart';
import '../utils/lucide_icons.dart';
import 'dart:convert';
import 'dart:async';

import '../services/nfc_service.dart';
import '../services/card_revocation_service.dart';

class NfcUnlockScreen extends StatefulWidget {
  final String userName;
  final VoidCallback? onUnlocked;
  final VoidCallback? onBack;
  const NfcUnlockScreen({super.key, this.userName = "User", this.onUnlocked, this.onBack});

  @override
  State<NfcUnlockScreen> createState() => _NfcUnlockScreenState();
}

enum UnlockStep { idle, scanning, success, error, pinFallback, pinEntry }

class _NfcUnlockScreenState extends State<NfcUnlockScreen> with TickerProviderStateMixin {
  static const int maxNfcFailures = 3;

  UnlockStep _step = UnlockStep.idle;
  int _failureCount = 0;
  String _errorMsg = "";
  String _pinStr = "";
  String _pinError = "";
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: false);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Auto start scan on mount
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _startNfcScan();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startNfcScan() async {
    if (_step == UnlockStep.scanning) return;
    setState(() {
      _step = UnlockStep.scanning;
      _errorMsg = "";
    });

    final result = await NfcService.readTagFromNfc();

    if (!mounted) return;

    if (result['success'] == true && result['text'] != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(result['text']);
        final payload = TokenPayload.fromJson(decoded);

        bool revoked = await CardRevocationService.isRevoked(payload.cardId);
        if (revoked) {
          _handleScanFailure("This card has been remotely revoked. Contact support.");
          return;
        }
        
        if (!NfcService.isTokenValid(payload)) {
          _handleScanFailure("Token has expired. Please re-arm your card in the app.");
          return;
        }

            // Success!
        setState(() {
          _step = UnlockStep.success;
        });
        
        Future.delayed(const Duration(milliseconds: 1100), () {
          if (mounted) {
            if (widget.onUnlocked != null) {
              widget.onUnlocked!();
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          }
        });
      } catch (e) {
        _handleScanFailure("Tag format unrecognised. This doesn't look like a valid card.");
      }
    } else {
      _handleScanFailure(result['error'] ?? "Could not read card.");
    }
  }

  void _handleScanFailure(String msg) {
    int newCount = _failureCount + 1;
    setState(() {
      _failureCount = newCount;
      _errorMsg = msg;
      if (newCount >= maxNfcFailures) {
        _step = UnlockStep.pinFallback;
      } else {
        _step = UnlockStep.error;
      }
    });
  }

  void _handleRetry() {
    setState(() {
      _step = UnlockStep.idle;
      _errorMsg = "";
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _startNfcScan();
    });
  }

  void _handleUsePIN() {
    setState(() {
      _step = UnlockStep.pinEntry;
      _pinStr = "";
      _pinError = "";
    });
  }

  Future<void> _handlePINSubmit() async {
    bool hasPin = await CardRevocationService.hasCardPin();
    if (!hasPin) {
      // Demo auto-allow if no PIN set
      setState(() => _step = UnlockStep.success);
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      });
      return;
    }

    bool isValid = await CardRevocationService.verifyCardPin(_pinStr);
    if (isValid) {
      setState(() => _step = UnlockStep.success);
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      });
    } else {
      setState(() {
        _pinError = "Incorrect PIN. Try again.";
        _pinStr = "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color glowColor = const Color(0x230891B2); // default teal
    if (_step == UnlockStep.success) glowColor = const Color(0x1F10B981);
    else if (_step == UnlockStep.error || _step == UnlockStep.pinFallback) glowColor = const Color(0x19EF4444);
    else if (_step == UnlockStep.scanning) glowColor = const Color(0x1F06B6D4);

    return Scaffold(
      body: Stack(
        children: [
          // Background Glow
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glowColor,
                    blurRadius: 80,
                    spreadRadius: 40,
                  )
                ]
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Greeting
                  Column(
                    children: [
                      Text("Welcome back,", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(widget.userName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  
                  // Center Content
                  if (_step == UnlockStep.pinEntry)
                    _buildPinEntry()
                  else
                    _buildNfcVisual(),

                  // Bottom Action Buttons
                  _buildBottomActions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinEntry() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.keyRound, size: 36, color: Color(0xFF38BDF8)),
        const SizedBox(height: 12),
        const Text("Enter Card PIN", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text("NFC failed $maxNfcFailures times — use your backup PIN", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            autofocus: true,
            keyboardType: TextInputType.number,
            obscureText: true,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 8),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: "● ● ● ●",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
            ),
            onChanged: (val) {
              setState(() {
                _pinStr = val;
                _pinError = "";
              });
            },
          ),
        ),
        if (_pinError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_pinError, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _handlePINSubmit,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0284C7)]),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text("Unlock with PIN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _buildNfcVisual() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 160,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Phone Body
              Container(
                width: 100,
                height: 180,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0840), Color(0xFF080022)],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 2),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))],
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.shield,
                    size: 28,
                    color: _step == UnlockStep.success ? const Color(0xFF34D399) : 
                           (_step == UnlockStep.error || _step == UnlockStep.pinFallback) ? const Color(0xFFF87171) : 
                           const Color(0xFF38BDF8),
                  ),
                ),
              ),
              
              // Pulse (only when scanning)
              if (_step == UnlockStep.scanning)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Opacity(
                        opacity: 1.0 - ((_pulseAnimation.value - 0.8) / 1.0).clamp(0.0, 1.0),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0x8006B6D4), width: 2),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Floating Card
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                left: _step == UnlockStep.scanning ? 10 : 0,
                top: _step == UnlockStep.success ? 140 : 80,
                child: Transform.rotate(
                  angle: _step == UnlockStep.scanning ? -0.2 : -0.3,
                  child: Container(
                    width: 72,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0284C7)]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: const [BoxShadow(color: Color(0x800369A1), blurRadius: 12, offset: Offset(0, 4))],
                    ),
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0x99FFD700),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Status Text
        if (_step == UnlockStep.idle) ...[
          const Text("Hold NFC Card to Phone", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text("Bring your NFC card to the back of your phone", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13), textAlign: TextAlign.center),
        ] else if (_step == UnlockStep.scanning) ...[
          const Text("Hold card steady…", style: TextStyle(color: Color(0xFF67E8F9), fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text("Authenticating secure element", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13), textAlign: TextAlign.center),
        ] else if (_step == UnlockStep.success) ...[
          const Text("Card Authenticated", style: TextStyle(color: Color(0xFF34D399), fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text("Session unlocked — entering app…", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13), textAlign: TextAlign.center),
        ] else if (_step == UnlockStep.error || _step == UnlockStep.pinFallback) ...[
          Text(_step == UnlockStep.pinFallback ? "$maxNfcFailures Failures — Use PIN" : "Authentication Failed", style: const TextStyle(color: Color(0xFFF87171), fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(_errorMsg.isEmpty ? "Card not recognised." : _errorMsg, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12), textAlign: TextAlign.center),
          if (_step == UnlockStep.error) ...[
            const SizedBox(height: 4),
            Text("Attempt $_failureCount of $maxNfcFailures", style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11)),
          ]
        ],
        
        const SizedBox(height: 32),
        // Session Info Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _step == UnlockStep.success ? const Color(0x1410B981) : 
                   (_step == UnlockStep.error || _step == UnlockStep.pinFallback) ? const Color(0x0FEF4444) : 
                   (_step == UnlockStep.scanning) ? const Color(0x0F06B6D4) : 
                   Colors.white.withOpacity(0.05),
            border: Border.all(
              color: _step == UnlockStep.success ? const Color(0x6610B981) : 
                     (_step == UnlockStep.error || _step == UnlockStep.pinFallback) ? const Color(0x66EF4444) : 
                     (_step == UnlockStep.scanning) ? const Color(0x4D06B6D4) : 
                     Colors.white.withOpacity(0.10)
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("SESSION STATUS", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                  if (_step == UnlockStep.success) const Icon(LucideIcons.checkCircle, size: 14, color: Color(0xFF34D399))
                  else if (_step == UnlockStep.error || _step == UnlockStep.pinFallback) const Icon(LucideIcons.alertCircle, size: 14, color: Color(0xFFF87171))
                  else Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _step == UnlockStep.scanning ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.2))),
                ],
              ),
              const SizedBox(height: 12),
              _buildSessionRow("Card Status", 
                _step == UnlockStep.success ? "Authenticated ✓" :
                (_step == UnlockStep.error || _step == UnlockStep.pinFallback) ? "Failed ($_failureCount/$maxNfcFailures)" :
                _step == UnlockStep.scanning ? "Reading…" : "Pending",
                _step == UnlockStep.success ? const Color(0xFF34D399) :
                (_step == UnlockStep.error || _step == UnlockStep.pinFallback) ? const Color(0xFFF87171) :
                _step == UnlockStep.scanning ? const Color(0xFF06B6D4) : Colors.white.withOpacity(0.4)
              ),
              const SizedBox(height: 8),
              const _buildSessionRow("Mode", "Real NFC", Color(0xFF38BDF8)),
              const SizedBox(height: 8),
              _buildSessionRow("Fallback", 
                _step == UnlockStep.pinFallback ? "PIN Active" : "${maxNfcFailures - _failureCount} tries left", 
                _step == UnlockStep.pinFallback ? const Color(0xFFF87171) : Colors.white.withOpacity(0.3)
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildBottomActions() {
    if (_step == UnlockStep.idle) {
      return GestureDetector(
        onTap: _startNfcScan,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0284C7)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x660369A1), blurRadius: 20, offset: Offset(0, 8))],
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.wifi, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text("Start NFC Scan", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
    } else if (_step == UnlockStep.scanning) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0x1F06B6D4),
          border: Border.all(color: const Color(0x4006B6D4)),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Color(0xFF67E8F9), strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text("Waiting for NFC card…", style: TextStyle(color: Color(0xFF67E8F9), fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    } else if (_step == UnlockStep.error) {
      return Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _handleRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0284C7)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.wifi, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text("Retry", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _handleUsePIN,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.keyRound, color: Colors.white.withOpacity(0.5), size: 16),
                  const SizedBox(width: 6),
                  Text("PIN", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (_step == UnlockStep.pinFallback) {
      return GestureDetector(
        onTap: _handleUsePIN,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x4DEF4444), blurRadius: 20, offset: Offset(0, 8))],
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.keyRound, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text("Use Card PIN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
    } else if (_step == UnlockStep.success) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0x1F10B981),
          border: Border.all(color: const Color(0x4D10B981)),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.zap, color: Color(0xFF34D399), size: 18),
            SizedBox(width: 8),
            Text("Entering app…", style: TextStyle(color: Color(0xFF34D399), fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    return const SizedBox(height: 50); // placeholder
  }
}

class _buildSessionRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _buildSessionRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
