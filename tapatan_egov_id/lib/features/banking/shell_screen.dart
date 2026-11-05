import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/banking_provider.dart';
import 'home/home_screen.dart';
import 'transfer/transfer_screen.dart';
import 'bills/bills_screen.dart';
import 'notifications/notifications_screen.dart';
import 'profile/profile_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});
  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    TransferScreen(),
    BillsScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(bankingProvider).pendingApprovalCount;

    return Scaffold(
      backgroundColor: const Color(0xFF080F1E),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A30),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Home', index: 0, current: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
                _NavItem(icon: Icons.send_rounded, label: 'Transfer', index: 1, current: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
                _NavItem(icon: Icons.receipt_long_rounded, label: 'Bills', index: 2, current: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
                _NavItem(icon: Icons.notifications_rounded, label: 'Approvals', index: 3, current: _currentIndex, badge: pendingCount, onTap: (i) => setState(() => _currentIndex = i)),
                _NavItem(icon: Icons.person_rounded, label: 'Profile', index: 4, current: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final int badge;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon, required this.label, required this.index,
    required this.current, required this.onTap, this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF003087).withValues(alpha: 0.3) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                    size: 22,
                    color: isActive ? const Color(0xFF60A5FA) : Colors.white.withValues(alpha: 0.4)),
                ),
                if (badge > 0)
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEF4444)),
                      child: Center(child: Text('$badge', style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label,
              style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF60A5FA) : Colors.white.withValues(alpha: 0.4),
              )),
          ],
        ),
      ),
    );
  }
}
