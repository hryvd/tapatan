import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secure_nfc_pay/providers/user_provider.dart';
import 'package:secure_nfc_pay/screens/analytics_screen.dart';
import 'package:secure_nfc_pay/screens/auth_screen.dart';
import 'package:secure_nfc_pay/screens/camera_capture_overlay.dart';
import 'package:secure_nfc_pay/screens/face_liveness_screen.dart';
import 'package:secure_nfc_pay/screens/home_screen.dart';
import 'package:secure_nfc_pay/screens/nfc_flow_screen.dart';
import 'package:secure_nfc_pay/screens/security_info_screen.dart';
import 'package:secure_nfc_pay/services/account_backend_service.dart';
import 'package:secure_nfc_pay/ui/card_face.dart' as ui_card;
import 'package:secure_nfc_pay/ui/tokens.dart';
import 'package:secure_nfc_pay/ui/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AccountBackendService.initialize();
  });

  test('UI v3 tokens and 3D card materials initialized without glow or liquid gradients', () {
    expect(T.bg.toARGB32(), 0xFF0A0E17);
    expect(T.teal.toARGB32(), 0xFF0D9488);
    expect(T.glassShadow, isEmpty);
    expect(T.strongShadow, isEmpty);
    expect(T.tintShadow, isEmpty);
    expect(T.btnShadow, isEmpty);
    expect(T.lensShadow, isEmpty);
    expect(T.glow(T.teal), isEmpty);
    expect(T.surface.a, lessThan(1.0));
    expect(T.surfaceBorder, Colors.transparent);
    expect(T.glassBorder, Colors.transparent);
    expect(ui_card.kMaterials.keys, containsAll(['obsidian', 'cyber', 'emerald', 'indigo']));
  });

  testWidgets('AuthScreen shows updated landing copy, Tap to sign in, and 6-digit PIN without Confirm button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AccountBackendService.initialize();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AuthScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Your card is your password. Your wallet is your card.'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('I already have an account'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tap to sign in'), findsOneWidget);
    expect(find.text('Tap your card to sign in'), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, 'user@tapat.ph');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
    expect(find.byType(PinDots), findsOneWidget);
    expect(tester.widget<PinDots>(find.byType(PinDots)).max, 6);
    expect(tester.takeException(), isNull);
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

  testWidgets('AuthScreen opens directly to remembered NFC + 6-digit PIN page and links to Switch account page', (tester) async {
    await tester.runAsync(() async {
      final reg = await AccountBackendService.registerAccount(
        name: 'Elena Reyes',
        email: 'elena.quick@tapat.ph',
        pin: '654321',
        cardId: 'CARD_ELENA_Q',
      );
      expect(reg.success, isTrue);
      await AccountBackendService.signOut();
    });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          routes: {
            '/auth': (_) => const AuthScreen(),
            '/main': (_) => const Scaffold(body: Text('MAIN_SHELL')),
          },
          home: const AuthScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Dedicated direct activation view for remembered signed-up account
    expect(find.text('Elena Reyes'), findsOneWidget);
    expect(find.text('elena.quick@tapat.ph'), findsOneWidget);
    expect(find.text('Tap to sign in'), findsOneWidget);
    expect(find.text('Switch account'), findsOneWidget);
    expect(find.byType(PinDots), findsOneWidget);
    expect(tester.widget<PinDots>(find.byType(PinDots)).max, 6);
    expect(find.text('Email address'), findsNothing);
    expect(find.text('Confirm'), findsNothing);
    expect(tester.takeException(), isNull);

    // Separate Switch account page holds all saved accounts and Create Account / KYC
    await tester.tap(find.text('Switch account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('SAVED ACCOUNTS ON DEVICE'), findsOneWidget);
    expect(find.text('Create Account / KYC'), findsOneWidget);

    await tester.tap(find.textContaining('elena.quick@tapat.ph').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
    expect(tester.widget<PinDots>(find.byType(PinDots)).max, 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AuthScreen direct unlock activates automatically on 6th PIN digit', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          routes: {
            '/auth': (_) => const AuthScreen(),
            '/main': (_) => const Scaffold(body: Text('MAIN_SHELL')),
          },
          home: const AuthScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Elena Reyes'), findsOneWidget);
    for (final ch in ['6', '5', '4', '3', '2', '1']) {
      await tester.tap(
        find.descendant(of: find.byType(Numpad), matching: find.text(ch)),
      );
      await tester.pump();
    }
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('MAIN_SHELL'), findsOneWidget);
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

    // Translucent BackdropFilter blur without stroke/border, stretching to outer width
    expect(
      find.descendant(of: find.byType(Glass), matching: find.byType(BackdropFilter)),
      findsWidgets,
    );
    final glassContainers = tester.widgetList<Container>(
      find.descendant(of: find.byType(Glass), matching: find.byType(Container)),
    );
    for (final c in glassContainers) {
      final deco = c.decoration as BoxDecoration?;
      if (deco != null) {
        expect(deco.border, isNull);
        expect((deco.color?.a ?? 1.0), lessThan(1.0));
      }
    }

    final heroOuterSize = tester.getSize(find.byKey(const ValueKey('hero-glass')));
    final heroInnerSize = tester.getSize(
      find.descendant(
        of: find.byKey(const ValueKey('hero-glass')),
        matching: find.byType(Container),
      ).first,
    );
    expect(heroOuterSize.width, 350.0);
    expect(heroInnerSize.width, 350.0);

    final m1Outer = tester.getSize(find.byKey(const ValueKey('mini-1')));
    final m2Outer = tester.getSize(find.byKey(const ValueKey('mini-2')));
    final m1Inner = tester.getSize(
      find.descendant(
        of: find.byKey(const ValueKey('mini-1')),
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

  testWidgets('Btn always uses solid teal without gradients or shadows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: T.bg,
          body: Column(
            children: [
              Btn.text('Primary Action', onTap: () {}),
              Btn.text('Glass Variant', variant: BtnVariant.glass, onTap: () {}),
              Btn.text('Danger Variant', variant: BtnVariant.danger, onTap: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final containers = tester.widgetList<Container>(
      find.descendant(of: find.byType(Btn), matching: find.byType(Container)),
    );
    expect(containers.length, 3);
    for (final c in containers) {
      final deco = c.decoration as BoxDecoration;
      expect(deco.color, T.teal);
      expect(deco.gradient, isNull);
      expect(deco.boxShadow, isNull);
    }
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
    final scanRect = CameraCaptureOverlay.computeScanRect(
      const Size(390, 844),
      EdgeInsets.zero,
    );
    final overlayRect = tester.getRect(
      find.byKey(const ValueKey('id-scan-bottom-overlay')),
    );
    expect(overlayRect.top, greaterThanOrEqualTo(scanRect.bottom));
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

  testWidgets('HomeScreen shows Tap ready without Enrolled/TPT/KYC badges and Analytics shows clean empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AccountBackendService.initialize();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tap ready'), findsOneWidget);
    expect(find.text('Arm card for NFC payment'), findsNothing);
    expect(find.text('Enrolled'), findsNothing);
    expect(find.text('KYC Verified'), findsNothing);
    expect(find.text('TPT'), findsNothing);
    expect(tester.takeException(), isNull);

    // Active tap timer renders as amber rounded rectangle matching Disarm height & radius, borderless
    final homeContainer =
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    homeContainer.read(userProvider.notifier).armCard();
    await tester.pump();
    final disarmSize = tester.getSize(find.widgetWithText(Btn, 'Disarm'));
    final timerFinder = find.ancestor(
      of: find.text('5:00'),
      matching: find.byType(Glass),
    ).first;
    final timerWidget = tester.widget<Glass>(timerFinder);
    expect(timerWidget.radius, T.rBtn);
    expect(timerWidget.height, T.btnH);
    expect(tester.getSize(timerFinder).height, closeTo(disarmSize.height, 0.5));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AnalyticsScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('No activity yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Card3D delivers back-face Tap to reveal taps and horizontal stack swipes', (tester) async {
    var revealed = false;
    var swipedDir = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: T.bg,
          body: Center(
            child: ui_card.Card3D(
              gyro: false,
              flipped: true,
              onSwipeHorizontal: (dir) => swipedDir = dir,
              front: (_, _) => const SizedBox(key: ValueKey('front-face')),
              back: Center(
                child: GestureDetector(
                  onTap: () => revealed = true,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Tap to reveal'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Tap to reveal'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(revealed, isTrue);

    await tester.fling(find.byType(ui_card.Card3D), const Offset(-220, 0), 800);
    await tester.pump(const Duration(milliseconds: 300));
    expect(swipedDir, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NfcFlowScreen supports Card OR 6-digit PIN with no Confirm button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AccountBackendService.initialize();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: NfcFlowScreen(cardId: 'CARD_TEST_01'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Tap Card to Pay'), findsOneWidget);
    expect(find.text('Pay with PIN'), findsOneWidget);

    await tester.tap(find.text('₱150'));
    await tester.pump();
    await tester.tap(find.text('Pay with PIN'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Enter 6-digit PIN'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
    expect(tester.widget<PinDots>(find.byType(PinDots)).max, 6);
    expect(tester.takeException(), isNull);
  });
}
