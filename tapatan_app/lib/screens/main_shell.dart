import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_provider.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'analytics_screen.dart';
import 'home_screen.dart';
import 'nfc_flow_screen.dart';
import 'nfc_unlock_screen.dart';
import 'profile_screen.dart';
import 'sare_screen.dart';
import 'virtual_cards_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  bool _showNfcOverlay = false;
  bool _showNfcUnlock = false;

  void _openNfcOverlay() => setState(() => _showNfcOverlay = true);
  void _closeNfcOverlay() => setState(() => _showNfcOverlay = false);
  void _closeNfcUnlock() => setState(() => _showNfcUnlock = false);

  void _handleArmCard() {
    setState(() => _showNfcUnlock = true);
  }

  void _handleCardUnlocked() {
    ref.read(userProvider.notifier).armCard();
    setState(() => _showNfcUnlock = false);
    if (mounted) {
      showToast(context, 'JCOP4 card armed for 5 minutes');
    }
  }

  void _handleTransactionComplete(double amount) {
    final user = ref.read(userProvider);
    double paidAmount = amount;
    String merchantName = 'NFC POS Terminal';

    if (user.sarePendingOrder != null) {
      final order = user.sarePendingOrder!;
      paidAmount = order.totalAmount;
      merchantName = order.merchant;
      ref.read(userProvider.notifier).sendMoney(
            order.totalAmount,
            recipient: order.merchant,
            type: 'nfc',
          );
      ref.read(userProvider.notifier).clearSarEOrder();
    } else if (amount > 0) {
      ref.read(userProvider.notifier).sendMoney(
            amount,
            recipient: 'NFC POS Payment',
            type: 'nfc',
          );
    }
    ref.read(userProvider.notifier).completeTransaction();
    setState(() => _showNfcOverlay = false);

    if (mounted && paidAmount > 0) {
      showToast(
        context,
        'Approved · ₱${paidAmount.toStringAsFixed(2)} to $merchantName',
      );
    }
  }

  void _navigateToTabName(String tab) {
    switch (tab) {
      case 'home':
        setState(() => _currentIndex = 0);
        break;
      case 'cards':
        setState(() => _currentIndex = 1);
        break;
      case 'sare':
        setState(() => _currentIndex = 2);
        break;
      case 'analytics':
        setState(() => _currentIndex = 3);
        break;
      case 'profile':
        setState(() => _currentIndex = 4);
        break;
    }
  }

  Widget _currentScreen() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          onArmCard: _handleArmCard,
          onOpenOverlay: (type) {
            if (type == 'nfc') _openNfcOverlay();
          },
          onNavigateTab: _navigateToTabName,
        );
      case 1:
        return const VirtualCardsScreen();
      case 2:
        return SarEScreen(
          onNavigateHome: () => setState(() => _currentIndex = 0),
          onCheckoutWithCard: () => setState(() {
            _currentIndex = 0;
            _showNfcOverlay = true;
          }),
        );
      case 3:
        return const AnalyticsScreen();
      case 4:
        return ProfileScreen(
          onSignOut: () => Navigator.pushReplacementNamed(context, '/auth'),
          onNavigate: _navigateToTabName,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    return Scaffold(
      backgroundColor: T.bg,
      body: AppBackground(
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: FadeSlideIn(
                key: ValueKey('app$_currentIndex'),
                child: _currentScreen(),
              ),
            ),
            AppBottomNav.positioned(
              index: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
            ),
            if (_showNfcUnlock)
              Positioned.fill(
                child: NfcUnlockScreen(
                  userName: user.name,
                  cardId: user.cardId,
                  onUnlocked: _handleCardUnlocked,
                  onBack: _closeNfcUnlock,
                ),
              ),
            if (_showNfcOverlay)
              Positioned.fill(
                child: NfcFlowScreen(
                  onClose: _closeNfcOverlay,
                  onTransactionComplete: _handleTransactionComplete,
                  cardId: user.cardId,
                  pendingOrder: user.sarePendingOrder,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
