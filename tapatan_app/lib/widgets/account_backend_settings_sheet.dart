import 'package:flutter/material.dart';

import '../services/account_backend_service.dart';
import '../utils/lucide_icons.dart';

/// Configurable modal bottom sheet for Bantay / tap@tan Account Management Backend
/// & Account Policy Rules. Accessible from both AuthScreen and ProfileScreen.
class AccountBackendSettingsSheet extends StatefulWidget {
  const AccountBackendSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AccountBackendSettingsSheet(),
    );
  }

  @override
  State<AccountBackendSettingsSheet> createState() =>
      _AccountBackendSettingsSheetState();
}

class _AccountBackendSettingsSheetState
    extends State<AccountBackendSettingsSheet> {
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _balanceCtrl = TextEditingController();

  bool _loading = true;
  bool _testing = false;
  String? _statusMsg;
  bool _statusError = false;

  bool _useRemote = false;
  bool _requirePinOnLogin = true;
  bool _strictCardBinding = true;
  bool _allowCardRebind = true;
  bool _syncCardHolderName = true;
  int _pinMinLen = 4;
  int _pinMaxLen = 6;
  int _savedAccountCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    final cfg = await AccountBackendService.getConfig();
    final saved = await AccountBackendService.listSavedAccounts();
    if (!mounted) return;
    setState(() {
      _urlCtrl.text = cfg.backendUrl;
      _balanceCtrl.text = cfg.initialWalletBalance.toStringAsFixed(0);
      _useRemote = cfg.useRemoteBackend;
      _requirePinOnLogin = cfg.requirePinOnEmailLogin;
      _strictCardBinding = cfg.strictCardToAccountBinding;
      _allowCardRebind = cfg.allowCardRebindOnSignup;
      _syncCardHolderName = cfg.syncCardHolderNameWithAccount;
      _pinMinLen = cfg.pinMinLength;
      _pinMaxLen = cfg.pinMaxLength;
      _savedAccountCount = saved.length;
      _loading = false;
    });
  }

  Future<void> _testBackend() async {
    setState(() {
      _testing = true;
      _statusMsg = null;
    });
    final res = await AccountBackendService.testRemoteConnection(_urlCtrl.text);
    if (!mounted) return;
    setState(() {
      _testing = false;
      if (res['success'] == true) {
        _statusError = false;
        final count = res['accountCount'] ?? 0;
        _statusMsg =
            'Connected to tapatan-account-backend ($count remote account(s)).';
      } else {
        _statusError = true;
        _statusMsg =
            (res['error'] ?? 'Failed to reach backend server.').toString();
      }
    });
  }

  Future<void> _saveConfig() async {
    final parsedBal =
        double.tryParse(_balanceCtrl.text.trim()) ?? 5000.0;
    final next = AccountManagementConfig(
      backendUrl: _urlCtrl.text.trim(),
      useRemoteBackend: _useRemote && _urlCtrl.text.trim().isNotEmpty,
      initialWalletBalance: parsedBal < 0 ? 0 : parsedBal,
      pinMinLength: _pinMinLen,
      pinMaxLength: _pinMaxLen,
      requirePinOnEmailLogin: _requirePinOnLogin,
      strictCardToAccountBinding: _strictCardBinding,
      allowCardRebindOnSignup: _allowCardRebind,
      syncCardHolderNameWithAccount: _syncCardHolderName,
    );
    await AccountBackendService.updateConfig(next);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Account management rules saved.'),
        backgroundColor: const Color(0xFF0369A1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF041E35), Color(0xFF020B18)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        child: _loading
            ? const SizedBox(
                height: 180,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0891B2).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.shieldCheck,
                            color: Color(0xFF38BDF8),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Account Management Backend',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '$_savedAccountCount persistent account(s) stored in database',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Remote HTTP Backend Sync toggle + URL
                    _buildToggleTile(
                      title: 'Sync with Remote Node Backend',
                      subtitle:
                          'Mirror local persistent DB with tapatan_backend REST API',
                      value: _useRemote,
                      onChanged: (v) => setState(() => _useRemote = v),
                    ),
                    if (_useRemote) ...[
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF0891B2).withValues(alpha: 0.35),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _urlCtrl,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13.5),
                                decoration: InputDecoration(
                                  hintText:
                                      'http://192.168.1.100:4180 (or 127.0.0.1:4180 / 10.0.2.2:4180)',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 12.5,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _testing ? null : _testBackend,
                              child: Text(
                                _testing ? 'Testing...' : 'Test',
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_statusMsg != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _statusMsg!,
                          style: TextStyle(
                            color: _statusError
                                ? const Color(0xFFF87171)
                                : const Color(0xFF34D399),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 16),
                    Text(
                      'CONFIGURABLE ACCOUNT RULES',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Starting Wallet Balance
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Default Starting Balance (PHP)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Initial wallet balance for newly created accounts',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 96,
                            child: TextField(
                              controller: _balanceCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                prefixText: '₱',
                                prefixStyle: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.w700,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.06),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildToggleTile(
                      title: 'Require PIN on Email Sign-In',
                      subtitle:
                          'Verify salted SHA-256 PIN hash when logging into stored accounts',
                      value: _requirePinOnLogin,
                      onChanged: (v) => setState(() => _requirePinOnLogin = v),
                    ),
                    const SizedBox(height: 8),

                    _buildToggleTile(
                      title: 'Strict Card-to-Account Binding',
                      subtitle:
                          'NFC tap sign-in resolves strictly to bound database account',
                      value: _strictCardBinding,
                      onChanged: (v) => setState(() => _strictCardBinding = v),
                    ),
                    const SizedBox(height: 8),

                    _buildToggleTile(
                      title: 'Allow Card Rebind on New Signup',
                      subtitle:
                          'Allow re-provisioning a Tapat JCOP4 card to a new account',
                      value: _allowCardRebind,
                      onChanged: (v) => setState(() => _allowCardRebind = v),
                    ),
                    const SizedBox(height: 8),

                    _buildToggleTile(
                      title: 'Sync Card Holder Name with Account',
                      subtitle:
                          'Always display the authenticated user\'s real name on cards',
                      value: _syncCardHolderName,
                      onChanged: (v) =>
                          setState(() => _syncCardHolderName = v),
                    ),
                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: _saveConfig,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0369A1), Color(0xFF0891B2)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Save Account Configuration',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch(
              value: value,
              activeThumbColor: const Color(0xFF38BDF8),
              activeTrackColor: const Color(0xFF0891B2).withValues(alpha: 0.5),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

