import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secure_nfc_pay/providers/user_provider.dart';
import 'package:secure_nfc_pay/screens/camera_capture_overlay.dart';
import 'package:secure_nfc_pay/screens/face_liveness_screen.dart';
import 'package:secure_nfc_pay/screens/security_info_screen.dart';
import 'package:secure_nfc_pay/services/account_backend_service.dart';
import 'package:secure_nfc_pay/ui/card_face.dart' as ui_card;
import 'package:secure_nfc_pay/ui/tokens.dart';
import 'package:secure_nfc_pay/ui/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

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

  testWidgets('Glass stretches to full Expanded/ListView slot width and uniform row height', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: T.bg,
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const Glass(
                key: ValueKey('hero-glass'),
                kind: GlassKind.tint,
                padding: EdgeInsets.all(22),
                child: Column(
                  children: [
                    Text('Tap JCOP4 Card to Sign In'),
                    Text('Short'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Expanded(
                      child: Glass(
                        key: ValueKey('mini-1'),
                        padding: EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Text('A')],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Glass(
                        key: ValueKey('mini-2'),
                        padding: EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Text('Longer\nTwo Lines')],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Glass(
                    key: ValueKey('pill-loose'),
                    kind: GlassKind.pill,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('Account Rules'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Inner Container inside BackdropFilter must match outer Glass width (no StackFit.loose shrink-wrap)
    final heroOuterSize = tester.getSize(find.byKey(const ValueKey('hero-glass')));
    final heroInnerSize = tester.getSize(
      find.descendant(
        of: find.descendant(of: find.byKey(const ValueKey('hero-glass')), matching: find.byType(BackdropFilter)),
        matching: find.byType(Container),
      ).first,
    );
    expect(heroOuterSize.width, 350.0);
    expect(heroInnerSize.width, 350.0);

    final m1Outer = tester.getSize(find.byKey(const ValueKey('mini-1')));
    final m2Outer = tester.getSize(find.byKey(const ValueKey('mini-2')));
    final m1Inner = tester.getSize(
      find.descendant(
        of: find.descendant(of: find.byKey(const ValueKey('mini-1')), matching: find.byType(BackdropFilter)),
        matching: find.byType(Container),
      ).first,
    );
    expect(m1Outer.width, closeTo(171.0, 0.5));
    expect(m1Inner.width, closeTo(m1Outer.width, 0.1));
    expect(m1Outer.height, m2Outer.height);
    expect(m1Inner.height, m2Outer.height);

    // Loose pill must stay compact rather than expanding to full row width
    final pillSize = tester.getSize(find.byKey(const ValueKey('pill-loose')));
    expect(pillSize.width, lessThan(250.0));
  });

  testWidgets('SecurityInfoScreen renders Overview, NFC Key, and ML Model tabs without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SecurityInfoScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Security Center'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('NFC Key'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('JCOP4 J3R150 / Feitian A40CR'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ML Model'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Model Architecture'), findsOneWidget);
    expect(find.text('Output'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CameraCaptureOverlay and FaceLivenessScreen initialize safely without crash', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CameraCaptureOverlay(
          title: 'Scan Valid ID',
          subtitle: 'Position your government ID within the frame',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Scan Valid ID'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: FaceLivenessScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Face Liveness Check'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
