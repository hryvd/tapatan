import 'package:flutter/material.dart';

import '../services/account_backend_service.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
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
    showToast(context, 'Account management rules saved');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Glass(
            kind: GlassKind.strong,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(T.rSheet)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grabber handle
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: T.white(.3),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: T.op(T.cyan600, .2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: T.op(T.cyan400, .3),
                            width: .5,
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.shieldCheck,
                          color: T.cyan300,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Backend & Rules',
                              style: T.text(16, w: T.w700),
                            ),
                            Text(
                              '$_savedAccountCount persistent account(s) stored in database',
                              style: T.caption,
                            ),
                          ],
                        ),
                      ),
                      GlassIconBtn(
                        icon: LucideIcons.x,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: _loading
                      ? const SizedBox(
                          height: 180,
                          child: Center(
                            child:
                                CircularProgressIndicator(color: T.cyan400),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Remote Node Backend Sync Toggle
                              Toggle(
                                on: _useRemote,
                                onChanged: (v) =>
                                    setState(() => _useRemote = v),
                                label: 'Sync with Remote Node Backend',
                                hint:
                                    'Mirror local persistent DB with tapatan_backend REST API',
                              ),
                              if (_useRemote) ...[
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Field(
                                        label: 'Backend REST URL',
                                        controller: _urlCtrl,
                                        mono: true,
                                        hint: 'http://192.168.1.100:4180',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 20),
                                      child: Btn(
                                        variant: BtnVariant.glass,
                                        onTap: _testing ? null : _testBackend,
                                        disabled: _testing,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        child: Text(
                                          _testing ? 'Testing...' : 'Test',
                                          style: T.btn.copyWith(
                                            color: T.cyan300,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_statusMsg != null) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 4, bottom: 8),
                                    child: Text(
                                      _statusMsg!,
                                      style: T.text(
                                        11.5,
                                        w: T.w600,
                                        color: _statusError
                                            ? T.red400
                                            : T.emerald400,
                                      ),
                                    ),
                                  ),
                                ],
                              ],

                              const SizedBox(height: 12),
                              Text(
                                'CONFIGURABLE ACCOUNT RULES',
                                style: T.mono(
                                  10.5,
                                  w: T.w700,
                                  color: T.white(.45),
                                  ls: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Default starting balance field
                              Field(
                                label: 'Default Starting Balance (PHP)',
                                controller: _balanceCtrl,
                                keyboardType: TextInputType.number,
                                hint: '5000',
                                suffix: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    'PHP',
                                    style: T.mono(12,
                                        w: T.w700, color: T.cyan300),
                                  ),
                                ),
                              ),

                              Toggle(
                                on: _requirePinOnLogin,
                                onChanged: (v) =>
                                    setState(() => _requirePinOnLogin = v),
                                label: 'Require PIN on Email Sign-In',
                                hint:
                                    'Verify salted SHA-256 PIN hash when logging into stored accounts',
                              ),
                              Toggle(
                                on: _strictCardBinding,
                                onChanged: (v) =>
                                    setState(() => _strictCardBinding = v),
                                label: 'Strict Card-to-Account Binding',
                                hint:
                                    'NFC tap sign-in resolves strictly to bound database account',
                              ),
                              Toggle(
                                on: _allowCardRebind,
                                onChanged: (v) =>
                                    setState(() => _allowCardRebind = v),
                                label: 'Allow Card Rebind on New Signup',
                                hint:
                                    'Allow re-provisioning a Tapat JCOP4 card to a new account',
                              ),
                              Toggle(
                                on: _syncCardHolderName,
                                onChanged: (v) =>
                                    setState(() => _syncCardHolderName = v),
                                label: 'Sync Card Holder Name with Account',
                                hint:
                                    "Always display the authenticated user's real name on cards",
                              ),

                              const SizedBox(height: 20),
                              Btn.text(
                                'Save Account Configuration',
                                variant: BtnVariant.primary,
                                width: double.infinity,
                                onTap: _saveConfig,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
