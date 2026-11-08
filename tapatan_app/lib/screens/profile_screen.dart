import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_provider.dart';
import '../services/account_backend_service.dart';
import '../services/nfc_service.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';
import '../widgets/account_backend_settings_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback onSignOut;
  final Function(String)? onNavigate;

  const ProfileScreen({
    super.key,
    required this.onSignOut,
    this.onNavigate,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final Map<String, bool> _toggles = {
    'Biometric Auth': true,
    'Notifications': true,
    'NFC Debug Console': false,
  };

  bool _maskCardNumbers = true;
  bool _localBiometricCache = true;
  bool _anonTelemetry = false;
  bool _revoked = false;
  String? _customName;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  void _showEditNameSheet(BuildContext context, String currentName) {
    final nameCtrl = TextEditingController(text: currentName);
    showAppSheet(
      context,
      title: 'Edit Full Name',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your name will be displayed across virtual cards and account statements.',
            style: T.caption,
          ),
          const SizedBox(height: 16),
          Field(
            label: 'Full Name',
            controller: nameCtrl,
            hint: 'e.g. Maria Santos',
          ),
          const SizedBox(height: 12),
          Btn.text(
            'Save Changes',
            variant: BtnVariant.primary,
            width: double.infinity,
            onTap: () {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty && newName.toLowerCase() != 'richard') {
                setState(() => _customName = newName);
                ref.read(userProvider.notifier).updateProfileName(newName);
                Navigator.pop(context);
                showToast(context, 'Name updated & synced to cards');
              } else {
                showToast(context, 'Please enter a valid full name');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPinModal(BuildContext context, String email) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showAppSheet(
      context,
      title: 'Change PIN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update your 4-6 digit account & card authentication PIN.',
            style: T.caption,
          ),
          const SizedBox(height: 16),
          Field(
            label: 'Current PIN',
            obscure: true,
            mono: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            controller: currentCtrl,
            hint: '••••••',
          ),
          Field(
            label: 'New PIN',
            obscure: true,
            mono: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            controller: newCtrl,
            hint: '••••••',
          ),
          Field(
            label: 'Confirm New PIN',
            obscure: true,
            mono: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            controller: confirmCtrl,
            hint: '••••••',
          ),
          const SizedBox(height: 14),
          Btn.text(
            'Save PIN',
            variant: BtnVariant.primary,
            width: double.infinity,
            onTap: () async {
              if (newCtrl.text.trim().isEmpty || currentCtrl.text.trim().isEmpty) {
                showToast(context, 'Please enter both current and new PIN');
                return;
              }
              if (newCtrl.text.trim() != confirmCtrl.text.trim()) {
                showToast(context, 'New PINs do not match');
                return;
              }
              final res = await AccountBackendService.changePin(
                email: email,
                currentPin: currentCtrl.text.trim(),
                newPin: newCtrl.text.trim(),
              );
              if (!context.mounted) return;
              if (res.success) {
                Navigator.pop(context);
                showToast(context, 'Account PIN updated in database');
              } else {
                showToast(context, res.error ?? 'Failed to update PIN');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPersonalInfoModal(
      BuildContext context, UserState user, String effectiveName) {
    final isRevoked = _revoked || user.cardLifecycleState == 'terminated';
    final uid = user.jcopCardUid.isNotEmpty
        ? user.jcopCardUid
        : (user.cardId.isNotEmpty ? user.cardId : 'TPT-8821-J3R150');
    showAppSheet(
      context,
      title: 'Personal Information',
      child: Column(
        children: [
          _buildInfoTile('Full Name', effectiveName, LucideIcons.user, T.cyan400),
          _buildInfoTile(
            'Email',
            user.email.isNotEmpty ? user.email : 'user@tapat.ph',
            LucideIcons.mail,
            T.sky,
          ),
          _buildInfoTile(
            'Card Hardware UID',
            isRevoked ? '$uid (REVOKED)' : uid,
            LucideIcons.cpu,
            isRevoked ? T.red400 : T.indigo500,
            isMono: true,
          ),
          _buildInfoTile(
            'Account Status',
            'Individual · Tier 2 Verified',
            LucideIcons.shieldCheck,
            T.emerald400,
          ),
          _buildInfoTile(
            'Member Since',
            'June 2025',
            LucideIcons.calendar,
            T.amber500,
          ),
          const SizedBox(height: 16),
          Btn.text(
            'Close',
            variant: BtnVariant.glass,
            width: double.infinity,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showThesisMetricsSheet(BuildContext context) {
    showAppSheet(
      context,
      title: 'Thesis Security Metrics',
      child: Column(
        children: [
          _buildInfoTile(
            'CNN-LSTM Liveness Model',
            '99.82% Real-Face Accuracy',
            LucideIcons.brain,
            T.cyan400,
          ),
          _buildInfoTile(
            'STRIDE Threat Model',
            'Spoofing & Replay Mitigated',
            LucideIcons.shieldCheck,
            T.emerald400,
          ),
          _buildInfoTile(
            'NFC Contactless Latency',
            '82ms APDU execution roundtrip',
            LucideIcons.zap,
            T.amber500,
            isMono: true,
          ),
          _buildInfoTile(
            'Hardware Security Chip',
            'NXP JCOP4 J3R150 · CC EAL6+',
            LucideIcons.cpu,
            T.indigo500,
          ),
          _buildInfoTile(
            'Dynamic Session Cipher',
            'Turing PRNG + SHA-256 MAC',
            LucideIcons.keyRound,
            T.cyan300,
          ),
          const SizedBox(height: 16),
          Btn.text(
            'Close',
            variant: BtnVariant.glass,
            width: double.infinity,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showUpgradePremiumSheet(BuildContext context) {
    showAppSheet(
      context,
      title: 'Upgrade to tap@tan PRO',
      child: Column(
        children: [
          _buildInfoTile(
            'Unlimited Virtual Cards',
            'Issue dynamic virtual cards for each merchant',
            LucideIcons.creditCard,
            T.amber500,
          ),
          _buildInfoTile(
            'Multi-Card NFC Switching',
            'Route tap payments through any active card',
            LucideIcons.wifi,
            T.cyan400,
          ),
          _buildInfoTile(
            'Enhanced Zero-Knowledge Vault',
            'Custom hardware key derivation on JCOP4 applet',
            LucideIcons.cpu,
            T.indigo500,
          ),
          const SizedBox(height: 18),
          Btn.text(
            'Activate PRO (Included in Demo)',
            variant: BtnVariant.primary,
            width: double.infinity,
            onTap: () {
              Navigator.pop(context);
              showToast(context, 'tap@tan PRO activated');
            },
          ),
        ],
      ),
    );
  }

  void _showPrivacySheet(BuildContext context) {
    showAppSheet(
      context,
      title: 'Privacy Settings',
      child: StatefulBuilder(
        builder: (ctx, setModalState) => Column(
          children: [
            Toggle(
              label: 'Mask Virtual Card Numbers',
              hint: 'Hide digits on card details view',
              on: _maskCardNumbers,
              onChanged: (v) {
                setState(() => _maskCardNumbers = v);
                setModalState(() {});
              },
            ),
            Toggle(
              label: 'Local-Only Biometric Cache',
              hint: 'Store liveness templates exclusively in device secure storage',
              on: _localBiometricCache,
              onChanged: (v) {
                setState(() => _localBiometricCache = v);
                setModalState(() {});
              },
            ),
            Toggle(
              label: 'Anonymous Transaction Telemetry',
              hint: 'Zero-knowledge metrics for system health',
              on: _anonTelemetry,
              onChanged: (v) {
                setState(() => _anonTelemetry = v);
                setModalState(() {});
              },
            ),
            const SizedBox(height: 16),
            Btn.text(
              'Done',
              variant: BtnVariant.glass,
              width: double.infinity,
              onTap: () {
                Navigator.pop(ctx);
                showToast(context, 'Privacy preferences saved');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResyncCardSheet(BuildContext context, UserState user) {
    bool writing = false;
    String statusText = 'Hold your physical JCOP4 smart card flat against the phone\'s NFC antenna to write your verified account identity.';
    bool hasError = false;

    showAppSheet(
      context,
      title: 'Re-sync / Provision JCOP4 Card',
      child: StatefulBuilder(
        builder: (ctx, setModalState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Glass(
              kind: GlassKind.tint,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: T.op(hasError ? T.red500 : T.cyan500, .18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: T.op(hasError ? T.red400 : T.cyan300, .4),
                      ),
                    ),
                    child: Icon(
                      writing ? LucideIcons.wifi : LucideIcons.nfc,
                      size: 22,
                      color: hasError ? T.red400 : T.cyan300,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      statusText,
                      style: T.text(
                        12.5,
                        color: hasError ? T.red300 : T.white(.75),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Account: ${user.email.isNotEmpty ? user.email : 'Signed-in account'}\nAPDU: 80 E2 00 00 STORE DATA (TPT4 + TMAC)',
              style: T.mono(11, color: T.white(.45), height: 1.5),
            ),
            const SizedBox(height: 18),
            Btn.text(
              writing ? 'Scanning for JCOP4 Card…' : 'Start Card Provisioning',
              variant: BtnVariant.primary,
              width: double.infinity,
              disabled: writing,
              onTap: () async {
                setModalState(() {
                  writing = true;
                  hasError = false;
                  statusText =
                      'Listening for ISO 14443-4 JCOP4 J3R150 card… Hold card steady.';
                });
                final targetCardId = user.cardId.isNotEmpty
                    ? user.cardId
                    : NfcService.generateCardId();
                final res = await NfcService.writeCardIdentity(
                  targetCardId,
                  user.email,
                  name: user.name,
                );
                if (!ctx.mounted) return;
                if (res['success'] == true) {
                  final uid = (res['uid'] as String?) ?? user.jcopCardUid;
                  ref.read(userProvider.notifier).updateJcopCardInfo(
                        uid: uid,
                        cardId: targetCardId,
                        pinRetriesLeft: 5,
                        lifecycleState: 'ENROLLED',
                      );
                  if (mounted) setState(() => _revoked = false);
                  Navigator.pop(ctx);
                  showToast(
                    context,
                    'JCOP4 identity synced · UID: ${uid.isNotEmpty ? uid : 'Verified'}',
                  );
                } else {
                  setModalState(() {
                    writing = false;
                    hasError = true;
                    statusText = (res['error'] as String?) ??
                        'Provisioning interrupted or timed out.';
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRevokeSheet(BuildContext context, String uid) {
    showAppSheet(
      context,
      title: 'Revoke this card?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: T.text(13.5, color: T.white(.7)),
              children: [
                const TextSpan(text: 'UID '),
                TextSpan(
                  text: uid,
                  style: T.mono(13, w: T.w700, color: Colors.white),
                ),
                const TextSpan(
                  text:
                      ' will be added to the revocation list and can no longer authorize payments.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Btn.text(
                  'Cancel',
                  variant: BtnVariant.glass,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Btn.text(
                  'Revoke',
                  variant: BtnVariant.danger,
                  onTap: () {
                    setState(() => _revoked = true);
                    ref.read(userProvider.notifier).updateJcopCardInfo(
                          uid: uid,
                          lifecycleState: 'terminated',
                        );
                    Navigator.pop(context);
                    showToast(context, 'Card UID revoked');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNfcDebugSheet(BuildContext context) {
    final logs = [
      'SELECT AID: A0 00 00 05 59 10 10 -> 90 00 [OK]',
      'GET PROCESSING OPTIONS: 80 A8 00 00 -> 90 00 [OK]',
      'VERIFY PIN [MAC: SHA256-JCOP] -> 90 00 [VALID]',
      'READ RECORD: SFI 01 REC 01 -> 90 00 [OK]',
      'GENERATE AC: CRYPTOGRAM 4A 2B 9F ... -> 90 00',
    ];
    showAppSheet(
      context,
      title: 'NFC Debug Console',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.blk(.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: T.white(.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in logs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      line,
                      style: T.mono(11, color: T.cyan300),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Btn.text(
            'Clear Logs',
            variant: BtnVariant.glass,
            width: double.infinity,
            onTap: () {
              Navigator.pop(context);
              showToast(context, 'Debug logs cleared');
            },
          ),
        ],
      ),
    );
  }

  void _showHelpCenter(BuildContext context) {
    final faqs = [
      (
        'How does NFC payment work?',
        'Tap your NFC smart card to the back of your phone to write a secure token. Then tap your phone at any NFC-enabled POS terminal to complete the payment.'
      ),
      (
        'How do I arm my card?',
        'On the home screen, press "Enable Transaction" and follow the NFC unlock flow to arm your card for a single payment.'
      ),
      (
        'What happens after a payment?',
        'After each NFC payment, your card is automatically disarmed for security. You\'ll need to re-arm it for your next transaction.'
      ),
      (
        'How do I add a virtual card?',
        'Go to the Cards tab and tap "Add Card". Enter your card details and select your card finish.'
      ),
      (
        'Is my biometric data stored online?',
        'No. Face liveness checks and biometric hashes are strictly computed on-device with ML Kit and never transmitted over the network.'
      ),
    ];

    showAppSheet(
      context,
      title: 'Help Center & FAQ',
      tall: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final faq in faqs)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: T.white(.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: T.white(.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(faq.$1, style: T.text(13, w: T.w700)),
                  const SizedBox(height: 6),
                  Text(
                    faq.$2,
                    style: T.text(12, color: T.white(.5), height: 1.45),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Btn.text(
            'Close',
            variant: BtnVariant.glass,
            width: double.infinity,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isMono = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.white(.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.white(.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: T.op(color, .15),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: T.mono(10, w: T.w600, color: T.white(.4), ls: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: isMono
                      ? T.mono(13, w: T.w600)
                      : T.text(13.5, w: T.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool hasBorder) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: hasBorder
              ? Border(right: BorderSide(color: T.white(.1), width: .5))
              : null,
        ),
        child: Column(
          children: [
            Text(value, style: T.text(18, w: T.w800)),
            const SizedBox(height: 2),
            Text(label, style: T.caption),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final effectiveName = (_customName ?? user.name).trim().isNotEmpty
        ? (_customName ?? user.name).trim()
        : 'Tapat Member';
    final isRevoked = _revoked || user.cardLifecycleState == 'terminated';
    final uid = user.jcopCardUid.isNotEmpty
        ? user.jcopCardUid
        : (user.cardId.isNotEmpty ? user.cardId : 'TPT-8821-J3R150');

    final sections = [
      {
        'title': 'ACCOUNT',
        'items': [
          {
            'icon': LucideIcons.user,
            'label': 'Personal Information',
            'subtitle': 'Identity, verification tier & cardholder details',
            'color': T.cyan400,
            'action': () =>
                _showPersonalInfoModal(context, user, effectiveName),
          },
          {
            'icon': LucideIcons.creditCard,
            'label': 'Linked Banks & Cards',
            'subtitle': 'Manage virtual cards and bank payment sources',
            'color': T.sky,
            'badge': '${user.virtualCards.length}',
            'action': () => widget.onNavigate?.call('cards'),
          },
          {
            'icon': LucideIcons.settings,
            'label': 'Account Backend & Rules',
            'subtitle': 'Server URL, PIN policy, sync rules',
            'color': T.cyan300,
            'action': () => AccountBackendSettingsSheet.show(context),
          },
          {
            'icon': LucideIcons.star,
            'label': 'Upgrade to Premium',
            'subtitle': 'Unlock unlimited cards & custom NFC chip profiles',
            'color': T.amber500,
            'highlight': true,
            'action': () => _showUpgradePremiumSheet(context),
          },
        ],
      },
      {
        'title': 'HARDWARE & SECURITY',
        'items': [
          {
            'icon': LucideIcons.shieldCheck,
            'label': 'JCOP4 Applet Security Info',
            'subtitle': 'AID, Turing cipher, APDU table & card lock',
            'color': T.cyan400,
            'action': () => Navigator.pushNamed(context, '/security'),
          },
          {
            'icon': LucideIcons.brain,
            'label': 'Thesis Security Metrics',
            'subtitle': 'CNN-LSTM, STRIDE, NFC key specifications',
            'color': T.indigo500,
            'action': () => _showThesisMetricsSheet(context),
          },
          {
            'icon': LucideIcons.refreshCw,
            'label': 'Re-sync / Provision Card',
            'subtitle': 'Write account identity to the physical chip',
            'color': T.emerald400,
            'action': () => _showResyncCardSheet(context, user),
          },
          {
            'icon': LucideIcons.lock,
            'label': 'Change PIN',
            'subtitle': 'Update on-card OwnerPIN & database hash',
            'color': T.cyan400,
            'action': () => _showPinModal(context, user.email),
          },
          {
            'icon': LucideIcons.fingerprint,
            'label': 'Biometric Auth',
            'subtitle': 'Use Face / Touch unlock for quick authorization',
            'color': T.emerald,
            'toggle': true,
          },
          {
            'icon': LucideIcons.shield,
            'label': 'Privacy Settings',
            'subtitle': 'Card masking & telemetry preferences',
            'color': T.cyan500,
            'action': () => _showPrivacySheet(context),
          },
          {
            'icon': LucideIcons.info,
            'label': 'Security Info & Card Lock',
            'subtitle': 'Emergency freeze & tamper detection status',
            'color': T.red400,
            'action': () => Navigator.pushNamed(context, '/security'),
          },
          {
            'icon': LucideIcons.shieldAlert,
            'label': 'Report Lost Card / Revoke UID',
            'subtitle': 'Block compromised smart card hardware instantly',
            'color': T.red400,
            'danger': true,
            'action': () => _showRevokeSheet(context, uid),
          },
        ],
      },
      {
        'title': 'PREFERENCES',
        'items': [
          {
            'icon': LucideIcons.bell,
            'label': 'Notifications',
            'subtitle': 'Instant alerts for POS debits & card arming',
            'color': T.amber500,
            'toggle': true,
          },
          {
            'icon': LucideIcons.wifi,
            'label': 'NFC Debug Console',
            'subtitle': 'Inspect raw APDU trace and response codes',
            'color': T.cyan400,
            'toggle': true,
            'onToggle': (bool v) {
              if (v) _showNfcDebugSheet(context);
            },
          },
        ],
      },
      {
        'title': 'SUPPORT',
        'items': [
          {
            'icon': LucideIcons.helpCircle,
            'label': 'Help Center',
            'subtitle': 'Frequently asked questions & card usage guides',
            'color': T.cyan200,
            'action': () => _showHelpCenter(context),
          },
        ],
      },
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          T.screenPad,
          8,
          T.screenPad,
          T.navBottomPad,
        ),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Profile', style: T.h1),
          ),

          // Hero profile card
          Glass(
            kind: GlassKind.tint,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar with liquid gradient & initials
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: T.btnLiquidGradient,
                        border: Border.all(color: T.white(.4), width: .5),
                        boxShadow: T.btnShadow,
                      ),
                      child: Center(
                        child: Text(
                          _initials(effectiveName),
                          style: T.text(20, w: T.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Name & email & UID
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  effectiveName,
                                  style: T.text(17, w: T.w800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Badge2(
                                'PRO',
                                color: T.amber500,
                                textColor: T.amber300,
                                mono: false,
                                fontSize: 9,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email.isNotEmpty
                                ? user.email
                                : 'user@tapat.ph',
                            style: T.text(12, color: T.white(.6)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            uid,
                            style: T.mono(
                              10.5,
                              color: isRevoked ? T.red400 : T.cyan200,
                            ).copyWith(
                              decoration: isRevoked
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: T.red400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Edit button
                    PressScale(
                      onTap: () =>
                          _showEditNameSheet(context, effectiveName),
                      child: Glass(
                        kind: GlassKind.pill,
                        width: 36,
                        height: 36,
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Stats row
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: T.blk(.25),
                    border: Border.all(color: T.white(.08)),
                  ),
                  child: Row(
                    children: [
                      _buildStatItem(
                        'Cards',
                        '${user.virtualCards.length}',
                        true,
                      ),
                      _buildStatItem(
                        'Transactions',
                        '${user.transactions.length}',
                        true,
                      ),
                      _buildStatItem(
                        'NFC Pays',
                        '${user.nfcPayCount}',
                        false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Revoked banner
          if (isRevoked)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: T.op(T.red500, .15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: T.op(T.red400, .3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.shieldAlert,
                    size: 18,
                    color: T.red300,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This card UID is revoked. Payments are blocked until you re-provision.',
                      style: T.text(12, color: T.red300),
                    ),
                  ),
                ],
              ),
            ),

          // Menu sections
          for (final section in sections) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4, bottom: 6),
              child: Text(
                section['title'] as String,
                style: T.mono(
                  11,
                  w: T.w700,
                  color: T.white(.45),
                  ls: 1.2,
                ),
              ),
            ),
            Glass(
              kind: GlassKind.glass,
              margin: const EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0;
                      i < (section['items'] as List).length;
                      i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: .5,
                        color: T.white(.08),
                      ),
                    () {
                      final item =
                          (section['items'] as List<Map<String, dynamic>>)[i];
                      final icon = item['icon'] as IconData;
                      final label = item['label'] as String;
                      final subtitle = item['subtitle'] as String?;
                      final color = item['color'] as Color;
                      final isToggle = item['toggle'] == true;
                      final isDanger = item['danger'] == true;
                      final isHighlight = item['highlight'] == true;
                      final badge = item['badge'] as String?;
                      final action = item['action'] as VoidCallback?;
                      final onToggleCb =
                          item['onToggle'] as ValueChanged<bool>?;
                      final isOn = _toggles[label] ?? false;

                      return PressScale(
                        onTap: () {
                          if (isToggle) {
                            final next = !isOn;
                            setState(() => _toggles[label] = next);
                            onToggleCb?.call(next);
                          } else {
                            action?.call();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: isHighlight
                                ? T.op(T.amber500, .08)
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: T.op(color, .15),
                                ),
                                child: Icon(icon, size: 17, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: T.text(
                                        13.5,
                                        w: T.w600,
                                        color: isDanger
                                            ? T.red400
                                            : (isHighlight
                                                ? T.amber300
                                                : Colors.white),
                                      ),
                                    ),
                                    if (subtitle != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        style: T.caption,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (badge != null) ...[
                                const SizedBox(width: 8),
                                Badge2(
                                  badge,
                                  color: T.sky,
                                  textColor: T.cyan200,
                                ),
                              ],
                              if (isToggle) ...[
                                const SizedBox(width: 10),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 44,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(99),
                                    color: isOn ? T.emerald : T.white(.14),
                                    border: Border.all(
                                      color: isOn ? T.emerald400 : T.white(.2),
                                      width: .5,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      AnimatedPositioned(
                                        duration:
                                            const Duration(milliseconds: 160),
                                        top: 2,
                                        left: isOn ? 20 : 2,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: T.blk(.3),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (!isDanger) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  LucideIcons.chevronRight,
                                  size: 16,
                                  color: T.white(.35),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }(),
                  ],
                ],
              ),
            ),
          ],

          // Sign out button
          Btn.text(
            'Sign Out',
            variant: BtnVariant.glass,
            width: double.infinity,
            onTap: () async {
              await ref.read(userProvider.notifier).signOut();
              widget.onSignOut();
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Balance, cards and history are saved to your account.',
            style: T.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.checkCircle,
                size: 12,
                color: T.emerald400,
              ),
              const SizedBox(width: 6),
              Text(
                'Secured by end-to-end encryption · tap@tan v2.0.0',
                style: T.text(11, color: T.white(.35)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
