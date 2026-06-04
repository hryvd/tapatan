import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/lucide_icons.dart';
import '../providers/user_provider.dart';
import 'home_screen.dart';
import 'virtual_cards_screen.dart';
import 'analytics_screen.dart';
import 'profile_screen.dart';
import 'nfc_flow_screen.dart';
import 'nfc_unlock_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showNfcOverlay = false;
  bool _showNfcUnlock = false;

  static const _tabs = [
    {'label': 'Home', 'icon': LucideIcons.home},
    {'label': 'Cards', 'icon': LucideIcons.creditCard},
    {'label': 'Analytics', 'icon': LucideIcons.barChart2},
    {'label': 'Profile', 'icon': LucideIcons.user},
  ];

  void _openNfcOverlay() => setState(() => _showNfcOverlay = true);
  void _closeNfcOverlay() => setState(() => _showNfcOverlay = false);
  void _closeNfcUnlock() => setState(() => _showNfcUnlock = false);

  void _handleArmCard() {
    setState(() => _showNfcUnlock = true);
  }

  void _handleCardUnlocked() {
    ref.read(userProvider.notifier).armCard();
    setState(() => _showNfcUnlock = false);
  }

  void _handleTransactionComplete() {
    ref.read(userProvider.notifier).completeTransaction();
    setState(() => _showNfcOverlay = false);
  }

  Widget _currentScreen() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          onArmCard: _handleArmCard,
          onOpenOverlay: (type) {
            if (type == 'nfc') _openNfcOverlay();
          },
          onNavigateTab: (tab) {
            if (tab == 'cards') setState(() => _currentIndex = 1);
          },
        );
      case 1:
        return const VirtualCardsScreen();
      case 2:
        return const AnalyticsScreen();
      case 3:
        return ProfileScreen(
          onSignOut: () => Navigator.pushReplacementNamed(context, '/auth'),
          onNavigate: (tab) {
            if (tab == 'cards') setState(() => _currentIndex = 1);
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF020B18),
      body: Stack(
        children: [
          // Full-screen black-to-dark-navy gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF000000),
                    Color(0xFF020B18),
                    Color(0xFF031424),
                    Color(0xFF041E35),
                  ],
                  stops: [0.0, 0.35, 0.65, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Ambient glow — teal-blue
          Positioned(
            top: -80, left: -80,
            child: Container(
              width: 320, height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x220369A1),
              ),
            ),
          ),
          Positioned(
            top: 280, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1A0891B2),
              ),
            ),
          ),
          Positioned(
            bottom: 100, left: 20,
            child: Container(
              width: 200, height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1206B6D4),
              ),
            ),
          ),

          // Main content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: _currentScreen(),
            ),
          ),

          // Bottom nav bar — dark navy pill
          Positioned(
            bottom: 16, left: 16, right: 16,
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xCC020B18),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 32, offset: const Offset(0, 8)),
                  BoxShadow(color: const Color(0xFF0891B2).withOpacity(0.06), blurRadius: 0, spreadRadius: 1),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_tabs.length, (i) {
                    final tab = _tabs[i];
                    final isActive = _currentIndex == i;
                    final icon = tab['icon'] as IconData;
                    final label = tab['label'] as String;
                    return GestureDetector(
                      onTap: () => setState(() => _currentIndex = i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: isActive
                              ? const LinearGradient(
                                  colors: [Color(0x500369A1), Color(0x400891B2)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          border: isActive
                              ? Border.all(color: const Color(0xFF0891B2).withOpacity(0.4))
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color: isActive
                                  ? const Color(0xFF38BDF8)
                                  : Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                color: isActive
                                    ? const Color(0xFF38BDF8)
                                    : Colors.white.withOpacity(0.28),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

          // NFC Unlock Overlay
          if (_showNfcUnlock)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _showNfcUnlock ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: NfcUnlockScreen(
                  userName: user.name,
                  onUnlocked: _handleCardUnlocked,
                  onBack: _closeNfcUnlock,
                ),
              ),
            ),

          // NFC Pay Overlay
          if (_showNfcOverlay)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF031424), Color(0xFF020B18), Color(0xFF010612), Color(0xFF01040A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: NfcFlowScreen(
                  onClose: _closeNfcOverlay,
                  onTransactionComplete: _handleTransactionComplete,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
