import 'package:flutter/material.dart';
import '../utils/lucide_icons.dart';
import 'dart:async';

import '../services/nfc_service.dart';
import '../services/card_revocation_service.dart';

enum FlowStep { idle, amount, pin, otp, authenticating, writing, ready, success, error }

class NfcFlowScreen extends StatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onTransactionComplete;
  const NfcFlowScreen({super.key, this.onClose, this.onTransactionComplete});

  @override
  State<NfcFlowScreen> createState() => _NfcFlowScreenState();
}

class _NfcFlowScreenState extends State<NfcFlowScreen> with TickerProviderStateMixin {
  FlowStep _step = FlowStep.idle;
  String _amountStr = "";
  String _pinStr = "";
  String _otpStr = "";
  String _errorMsg = "";
  TokenPayload? _payload;
  
  static const int cardTimeoutSeconds = 5 * 60;
  int _timeoutSecsLeft = cardTimeoutSeconds;
  Timer? _timer;

  static const double microThreshold = 100.0;
  static const double mediumThreshold = 500.0;
  static const double highThreshold = 1000.0;

  final String _generatedOtp = "123456"; // Mock OTP for demo

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timeoutSecsLeft = cardTimeoutSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeoutSecsLeft <= 1) {
          timer.cancel();
          _step = FlowStep.idle;
          _payload = null;
        } else {
          _timeoutSecsLeft--;
        }
      });
    });
  }

  double get _amount => double.tryParse(_amountStr) ?? 0;

  String _authLevel() {
    if (_amount < microThreshold) return "micro";
    if (_amount < mediumThreshold) return "low";
    if (_amount < highThreshold) return "medium";
    return "high";
  }

  void _handleStart() async {
    bool revoked = await CardRevocationService.isRevoked("demo-card-1");
    if (revoked) {
      setState(() {
        _errorMsg = "This card has been revoked. Please contact support.";
        _step = FlowStep.error;
      });
      return;
    }
    setState(() {
      _amountStr = "";
      _pinStr = "";
      _otpStr = "";
      _step = FlowStep.amount;
    });
  }

  void _handleAmountNext() {
    if (_amount <= 0) return;
    String level = _authLevel();
    if (level == "micro" || level == "low") {
      _startWriteFlow();
    } else {
      setState(() => _step = FlowStep.pin);
    }
  }

  void _handlePinNext() {
    if (_pinStr.length < 4) return;
    String level = _authLevel();
    if (level == "high") {
      setState(() => _step = FlowStep.otp);
    } else {
      _startWriteFlow();
    }
  }

  void _handleOtpNext() {
    if (_otpStr != _generatedOtp) {
      setState(() => _errorMsg = "Incorrect OTP. Check your email.");
      return;
    }
    _startWriteFlow();
  }

  Future<void> _startWriteFlow() async {
    setState(() {
      _step = FlowStep.authenticating;
      _errorMsg = "";
    });
    
    await Future.delayed(const Duration(milliseconds: 900));
    
    if (!mounted) return;
    
    TokenPayload newPayload = NfcService.buildTokenPayload("demo-card-1", _amount > 0 ? _amount : null);
    
    setState(() {
      _payload = newPayload;
      _step = FlowStep.writing;
    });

    final result = await NfcService.writeTokenToNfc(newPayload);
    
    if (!mounted) return;
    
    if (result['success'] == true) {
      await CardRevocationService.incrementUseCount("demo-card-1");
      await CardRevocationService.recordLastTap("demo-card-1");
      setState(() {
        _step = FlowStep.ready;
      });
      _startTimer();
    } else {
      setState(() {
        _errorMsg = result['error'] ?? "NFC write failed.";
        _step = FlowStep.error;
      });
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _step = FlowStep.idle;
      _payload = null;
      _amountStr = "";
      _pinStr = "";
      _otpStr = "";
      _errorMsg = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF18181B), // Shadcn Card Color
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("NFC Pay Flow", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () {
                  if (widget.onClose != null) {
                    widget.onClose!();
                  } else {
                    Navigator.pop(context);
                  }
                },
              )
            ],
          ),
          const Text("Real NFC · Privacy-preserving payment", style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 24),
          
          if (_step == FlowStep.idle)
            _buildIdle()
          else if (_step == FlowStep.amount)
            _buildAmount()
          else if (_step == FlowStep.pin)
            _buildPin()
          else if (_step == FlowStep.otp)
            _buildOtp()
          else if (_step == FlowStep.authenticating || _step == FlowStep.writing)
            _buildLoading()
          else if (_step == FlowStep.ready)
            _buildReady()
          else if (_step == FlowStep.error)
            _buildError()
        ],
      ),
    );
  }

  Widget _buildIdle() {
    return Column(
      children: [
        GestureDetector(
          onTap: _handleStart,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0284C7)]),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.wifi, color: Colors.white),
                SizedBox(width: 8),
                Text("Start Payment Flow", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildAmount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.dollarSign, size: 14, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Text("TRANSACTION AMOUNT (₱)", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              TextField(
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "0.00",
                  hintStyle: TextStyle(color: Colors.white24),
                ),
                onChanged: (v) => setState(() => _amountStr = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _reset,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _amount > 0 ? _handleAmountNext : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _amount > 0 ? null : Colors.white.withOpacity(0.05),
                    gradient: _amount > 0 ? const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0284C7)]) : null,
                    borderRadius: BorderRadius.circular(16)
                  ),
                  alignment: Alignment.center,
                  child: const Text("Continue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildPin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.keyRound, size: 14, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Text("ENTER PIN" + (_amount >= highThreshold ? " (Step 1 of 2)" : ""), style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              TextField(
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "••••",
                  hintStyle: TextStyle(color: Colors.white24, letterSpacing: 8),
                ),
                onChanged: (v) => setState(() => _pinStr = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _reset,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _pinStr.length >= 4 ? _handlePinNext : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _pinStr.length >= 4 ? null : Colors.white.withOpacity(0.05),
                    gradient: _pinStr.length >= 4 ? const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0284C7)]) : null,
                    borderRadius: BorderRadius.circular(16)
                  ),
                  alignment: Alignment.center,
                  child: const Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
  
  Widget _buildOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.mail, size: 14, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Text("EMAIL OTP (Step 2 of 2)", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text("Demo OTP: $_generatedOtp", style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
              TextField(
                autofocus: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "000000",
                  hintStyle: TextStyle(color: Colors.white24, letterSpacing: 8),
                ),
                onChanged: (v) => setState(() { _otpStr = v; _errorMsg = ""; }),
              ),
              if (_errorMsg.isNotEmpty)
                Text(_errorMsg, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _reset,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _otpStr.length >= 6 ? _handleOtpNext : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _otpStr.length >= 6 ? null : Colors.white.withOpacity(0.05),
                    gradient: _otpStr.length >= 6 ? const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0284C7)]) : null,
                    borderRadius: BorderRadius.circular(16)
                  ),
                  alignment: Alignment.center,
                  child: const Text("Verify", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Color(0xFF38BDF8)),
          const SizedBox(height: 16),
          Text(_step == FlowStep.authenticating ? "Authenticating..." : "Hold phone to NFC tag...", style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReady() {
    int mins = _timeoutSecsLeft ~/ 60;
    int secs = _timeoutSecsLeft % 60;
    String timeoutStr = "$mins:${secs.toString().padLeft(2, '0')}";
    double timeoutPct = _timeoutSecsLeft / cardTimeoutSeconds;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0x3310B981), Color(0x2606B6D4)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x5910B981)),
          ),
          child: Column(
            children: [
              const Icon(LucideIcons.badgeCheck, color: Color(0xFF34D399), size: 40),
              const SizedBox(height: 12),
              const Text("NFC Tag Armed — Tap at POS", style: TextStyle(color: Color(0xFF34D399), fontSize: 16, fontWeight: FontWeight.bold)),
              if (_payload != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_payload!.token, style: const TextStyle(color: Color(0xFF67E8F9), fontFamily: 'monospace', fontSize: 11)),
                )
              ]
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.timer, color: Color(0xFFFBBF24), size: 14),
                const SizedBox(width: 4),
                Text("Expires in $timeoutStr", style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
              ],
            ),
            const Text("Tap POS before timeout", style: TextStyle(color: Colors.white30, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: timeoutPct,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation<Color>(
            timeoutPct > 0.5 ? const Color(0xFF34D399) : 
            timeoutPct > 0.2 ? const Color(0xFFFBBF24) : 
            const Color(0xFFEF4444)
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {
            setState(() {
              _step = FlowStep.success;
            });
            _timer?.cancel();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
            alignment: Alignment.center,
            child: const Text("[Dev] Simulate POS tap →", style: TextStyle(color: Colors.white54)),
          ),
        )
      ],
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0x1FEF4444),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x4DEF4444)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertTriangle, color: Color(0xFFF87171), size: 20),
              const SizedBox(width: 8),
              Text(_errorMsg.isNotEmpty ? _errorMsg : "NFC write failed", style: const TextStyle(color: Color(0xFFF87171), fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _reset,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0284C7)]),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text("Try Again", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }
}
