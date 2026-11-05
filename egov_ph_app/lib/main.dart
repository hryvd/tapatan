import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/services/egov_api.dart';
import 'core/services/config_service.dart';
import 'features/auth/everify_transfer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.init();
  runApp(const ProviderScope(child: EGovApp()));
}

class EGovApp extends StatelessWidget {
  const EGovApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eGovPH Mock',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
        useMaterial3: true,
      ),
      home: const EGovHomeScreen(),
    );
  }
}

class EGovHomeScreen extends StatefulWidget {
  const EGovHomeScreen({super.key});

  @override
  State<EGovHomeScreen> createState() => _EGovHomeScreenState();
}

class _EGovHomeScreenState extends State<EGovHomeScreen> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    
    // Check initial URI
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint("Failed to get initial URI: $e");
    }

    // Listen for incoming URIs while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint("Deep link stream error: $err");
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'egovph') {
      if (uri.host == 'auth') {
        // Received auth request from bank app!
        final client = uri.queryParameters['client'] ?? 'Unknown';
        _showAuthDialog(client);
      } else if (uri.host == 'everify') {
        final amount = uri.queryParameters['amount'] ?? '0';
        final recipient = uri.queryParameters['recipient'] ?? 'Unknown';
        final approvalId = uri.queryParameters['approvalId'] ?? '';
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EverifyTransferScreen(
              amount: double.tryParse(amount) ?? 0,
              recipientName: recipient,
              approvalId: approvalId,
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAuthDialog(String clientName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Authorize $clientName?'),
        content: Text('$clientName is requesting access to your eGov identity and verifying via backend APIs.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _returnToBank(success: false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processAuthAndReturn();
            },
            child: const Text('Authorize'),
          ),
        ],
      ),
    );
  }

  Future<void> _processAuthAndReturn() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. SSO
      final ssoRes = await EGovSsoService.issueToken(
        exchangeCode: 'hackathon_auth_code_${DateTime.now().millisecondsSinceEpoch}',
        clientAppId: 'tapatan_bank',
        scopes: const ['SSO_AUTHENTICATION'],
      );
      if (!ssoRes.success) throw Exception(ssoRes.errorMessage);

      // 2. eVerify
      final verifyRes = await EVerifyService.verify(cardSerial: 'MOCK_SERIAL', nfcChallenge: 'MOCK_CHALLENGE');
      if (!verifyRes.success) throw Exception(verifyRes.errorMessage);

      // 3. Face Liveness
      final livenessRes = await FaceLivenessService.check(philsysNumber: '6347365049241571', sessionToken: 'session_xyz');
      if (!livenessRes.success) throw Exception(livenessRes.errorMessage);

      // 4. eGovAI
      final aiRes = await EGovAiService.analyzeRisk(
        philsysNumber: '6347365049241571',
        requestType: 'BANK_ACCOUNT_CREATION',
        context: {'amount': 0},
      );
      if (!aiRes.success) throw Exception(aiRes.errorMessage);

      // 5. eGovChain
      await EGovChainService.logEvent(
        eventType: 'EGovPH_Auth_Grant',
        actor: '6347365049241571',
        metadata: {'client': 'tapatan_bank'},
      );

      // Success! Return to bank
      if (mounted) Navigator.pop(context); // close loading
      final ssoToken = ssoRes.data['access_token'] ?? '';
      _returnToBank(success: true, ssoToken: ssoToken);

    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Error'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _returnToBank(success: false, error: error);
            },
            child: const Text('Return to Bank'),
          ),
        ],
      ),
    );
  }

  Future<void> _returnToBank({required bool success, String? ssoToken, String? error}) async {
    final uri = Uri(
      scheme: 'tapatan',
      host: 'auth-result',
      queryParameters: {
        'status': success ? 'success' : 'failed',
        if (ssoToken != null) 'ssoToken': ssoToken,
        if (error != null) 'error': error,
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint("Could not launch $uri");
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildBanner(),
              _buildGrid(),
              _buildBottomBanner(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF1E3A8A),
        shape: const CircleBorder(),
        child: const Icon(Icons.badge_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
              children: const [
                TextSpan(text: 'e', style: TextStyle(color: Color(0xFF1E3A8A))),
                TextSpan(text: 'GOV', style: TextStyle(color: Color(0xFFEF4444))),
                TextSpan(text: 'PH', style: TextStyle(color: Color(0xFF1E3A8A))),
              ],
            ),
          ),
          const Icon(Icons.notifications_active, color: Color(0xFF1E3A8A)),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 120,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('BAGONG PILIPINAS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red)),
                  Text('eGOVPH SERBISYO HUB', style: GoogleFonts.poppins(fontWeight: FontWeight.w900, color: const Color(0xFF1E3A8A))),
                  const SizedBox(height: 8),
                  Text('Avail Services ➔', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Container(
            width: 120,
            decoration: const BoxDecoration(
              color: Colors.blueGrey,
              borderRadius: BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            child: const Center(child: Icon(Icons.person, size: 64, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final items = [
      ('NGAs', Icons.account_balance),
      ('LGUs', Icons.location_city),
      ('Jobs', Icons.work),
      ('Tourism', Icons.beach_access),
      ('Travel', Icons.flight),
      ('OFW', Icons.luggage),
      ('Health', Icons.health_and_safety),
      ('Agriculture', Icons.agriculture),
      ('Sim Card', Icons.sim_card),
      ('Report', Icons.report_problem),
      ('Start-Up', Icons.rocket_launch),
      ('Show Less', Icons.expand_less),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(items[i].$2, color: const Color(0xFF1E3A8A)),
            ),
            const SizedBox(height: 8),
            Text(
              items[i].$1,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
            )
          ],
        );
      },
    );
  }

  Widget _buildBottomBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text('Lab For All Promo Placeholder', style: GoogleFonts.inter(color: Colors.grey)),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.home, 'Home', true),
          _navItem(Icons.article, 'News', false),
          const SizedBox(width: 40), // space for FAB
          _navItem(Icons.qr_code_scanner, 'Scan QR', false),
          _navItem(Icons.grid_view, 'Account', false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: active ? const Color(0xFF1E3A8A) : Colors.grey),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: active ? const Color(0xFF1E3A8A) : Colors.grey)),
      ],
    );
  }
}
