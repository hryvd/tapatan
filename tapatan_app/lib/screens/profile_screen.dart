import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_provider.dart';
import '../services/account_backend_service.dart';
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
            'Update your 6-digit account & card authentication PIN.',
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
            hint: 'â€¢â€¢â€¢â€¢â€¢â€¢',
          ),
          Field(
            label: 'New PIN',
            obscure: true,
            mono: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            controller: newCtrl,
            hint: 'â€¢â€¢â€¢â€¢â€¢â€¢',
          ),
          Field(
            label: 'Confirm New PIN',
            obscure: true,
            mono: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            controller: confirmCtrl,
            hint: 'â€¢â€¢â€¢â€¢â€¢â€¢',
          ),
          const SizedBox(height: 14),
          Btn.text(
            'Save PIN',
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


  Widget _row(IconData icon, String label, VoidCallback onTap,
      {String? trailing, Color? color, bool last = false}) {
    final c = color ?? Colors.white;
    return PressScale(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Icon(icon, size: 19, color: color ?? T.white(0.65)),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: T.text(14.5, w: T.w600, color: c))),
                if (trailing != null)
                  Text(trailing, style: T.caption.copyWith(color: T.white(0.45))),
                if (color == null) ...[
                  const SizedBox(width: 6),
                  Icon(LucideIcons.chevronRight, size: 16, color: T.white(0.30)),
                ],
              ],
            ),
          ),
          if (!last) Divider(height: 1, thickness: 0.5, color: T.white(0.06)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final effectiveName = (_customName ?? user.name).trim().isNotEmpty
        ? (_customName ?? user.name).trim()
        : 'Tapat Member';

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          T.screenPad,
          16,
          T.screenPad,
          T.navBottomPad + MediaQuery.of(context).padding.bottom + 20,
        ),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: T.teal, shape: BoxShape.circle),
              child: Text(_initials(effectiveName),
                  style: T.text(30, w: T.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 14),
          Text(effectiveName,
              textAlign: TextAlign.center, style: T.text(20, w: T.w700)),
          if (user.email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(user.email,
                textAlign: TextAlign.center,
                style: T.caption.copyWith(color: T.white(0.55))),
          ],
          const SizedBox(height: 28),
          Glass(
            radius: 20,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(LucideIcons.user, 'Edit name',
                    () => _showEditNameSheet(context, effectiveName)),
                _row(LucideIcons.lock, 'Security PIN',
                    () => _showPinModal(context, user.email)),
                _row(LucideIcons.creditCard, 'Saved cards',
                    () => widget.onNavigate?.call('cards'),
                    trailing: '${user.virtualCards.length}'),
                _row(LucideIcons.settings, 'Account settings',
                    () => AccountBackendSettingsSheet.show(context),
                    last: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Glass(
            radius: 20,
            padding: EdgeInsets.zero,
            child: _row(LucideIcons.logOut, 'Sign out', () async {
              await ref.read(userProvider.notifier).signOut();
              widget.onSignOut();
            }, color: T.red400, last: true),
          ),
        ],
      ),
    );
  }
}
