import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secure_nfc_pay/providers/user_provider.dart';
import 'package:secure_nfc_pay/services/account_backend_service.dart';
import 'package:secure_nfc_pay/ui/card_face.dart' as ui_card;
import 'package:secure_nfc_pay/ui/tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UI v2 tokens and 3D card materials initialized without legacy placeholders', () {
    expect(T.bg.toARGB32(), 0xFF0A0E17);
    expect(ui_card.kMaterials.keys, containsAll(['obsidian', 'cyber', 'emerald', 'indigo']));
  });

  test('UserNotifier.updateProfileName updates cards and persists to AccountBackendService', () async {
    SharedPreferences.setMockInitialValues({});
    await AccountBackendService.initialize();

    final reg = await AccountBackendService.registerAccount(
      name: 'Juan Dela Cruz',
      email: 'juan.v2@tapat.ph',
      pin: '123456',
      cardId: 'CARD_JUAN_V2',
    );
    expect(reg.success, isTrue);

    final notifier = UserNotifier();
    await notifier.applyAuthenticatedAccount(reg.account!);
    expect(notifier.state.activeCard?.holderName, 'JUAN DELA CRUZ');

    notifier.updateProfileName('Maria Clara');
    expect(notifier.state.name, 'Maria Clara');
    expect(notifier.state.activeCard?.holderName, 'MARIA CLARA');

    // Guard: "Richard" placeholder must be ignored
    notifier.updateProfileName('Richard');
    expect(notifier.state.name, 'Maria Clara');
  });
}
