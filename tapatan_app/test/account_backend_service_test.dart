import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secure_nfc_pay/providers/user_provider.dart';
import 'package:secure_nfc_pay/services/account_backend_service.dart';
import 'package:secure_nfc_pay/utils/lucide_icons.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Multi-account persistence across sign-outs, history retention, and zero Richard fallback',
    () async {
      SharedPreferences.setMockInitialValues({
        // Simulate stale Richard keys left over from older version
        'snfc_name': 'Richard',
        'snfc_email': 'richard@tapat.ph',
        'snfc_registered': true,
      });

      await AccountBackendService.initialize();

      // Stale Richard account must have been purged during migration
      expect(await AccountBackendService.listSavedAccounts(), isEmpty);

      // 1. Configure account rules (e.g. initialWalletBalance = 3000)
      await AccountBackendService.updateConfig(
        const AccountManagementConfig(initialWalletBalance: 3000.0),
      );

      // 2. Register Maria
      final regMaria = await AccountBackendService.registerAccount(
        name: 'Maria Santos',
        email: 'maria@tapat.ph',
        pin: '112233',
        cardId: 'CARD_MARIA_01',
        jcopCardUid: '04:11:22:33:44:55:66',
      );
      expect(regMaria.success, isTrue);
      expect(regMaria.account!.balance, 3000.0);
      expect(regMaria.account!.virtualCards.first.holderName, 'MARIA SANTOS');

      // 3. Record a payment transaction for Maria and sync
      final mariaState = UserState(
        name: regMaria.account!.name,
        email: regMaria.account!.email,
        balance: 2650.0,
        cardId: regMaria.account!.cardId,
        jcopCardUid: regMaria.account!.jcopCardUid,
        activeCardId: regMaria.account!.activeCardId,
        virtualCards: regMaria.account!.virtualCards,
        transactions: [
          TransactionData(
            id: 'tx-pay-1',
            name: 'Sar-E Store',
            amount: -350.0,
            icon: LucideIcons.wifi,
            color: const Color(0xFFF87171),
            time: 'Just now',
            type: 'nfc',
          ),
          ...regMaria.account!.transactions,
        ],
      );
      await AccountBackendService.syncAccountFromUserState(mariaState);

      // 4. Sign out of Maria's account
      await AccountBackendService.signOut();
      expect(await AccountBackendService.getActiveSessionAccount(), isNull);

      // 5. Register a second account (Juan) and sign out of Juan too
      final regJuan = await AccountBackendService.registerAccount(
        name: 'Juan Dela Cruz',
        email: 'juan@tapat.ph',
        pin: '998877',
        cardId: 'CARD_JUAN_02',
      );
      expect(regJuan.success, isTrue);
      expect(regJuan.account!.virtualCards.first.holderName, 'JUAN DELA CRUZ');
      await AccountBackendService.signOut();

      // 6. All accounts signed out -> sign back into known email maria@tapat.ph
      final reloginMaria = await AccountBackendService.loginWithEmailPin(
        email: 'maria@tapat.ph',
        pin: '112233',
      );
      expect(reloginMaria.success, isTrue);
      expect(reloginMaria.account!.name, 'Maria Santos');
      expect(reloginMaria.account!.balance, 2650.0);
      expect(reloginMaria.account!.transactions.length, 2);
      expect(reloginMaria.account!.transactions.first.name, 'Sar-E Store');
      expect(
        reloginMaria.account!.virtualCards.first.holderName,
        'MARIA SANTOS',
      );

      // 7. Sign out again and tap physical card even if EEPROM had legacy Richard fallback
      await AccountBackendService.signOut();
      final cardLogin = await AccountBackendService.loginWithCard(
        cardId: 'TAPAT_JCOP4_8821',
        uid: '04:11:22:33:44:55:66',
        ownerEmail: 'richard@tapat.ph',
        cardName: 'Richard',
      );
      expect(cardLogin.success, isTrue);
      expect(cardLogin.account!.name, 'Maria Santos');
      expect(cardLogin.account!.virtualCards.first.holderName, 'MARIA SANTOS');
    },
  );
}

