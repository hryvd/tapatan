import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/ai_scan_service.dart';
import '../application/auth_provider.dart';
import '../application/cart_provider.dart';
import '../application/pos_nfc_service.dart';
import '../domain/entities/product.dart';
import '../domain/entities/transaction.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/glass_dialog.dart';
import 'barcode_scanner_view.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showSearch = false;
  bool _isCheckoutOpen = false;
  
  bool _isBackgroundScanning = false;
  bool _useAiForScan = false;
  MobileScannerController? _mobileScannerController;
  CameraController? _cameraController;
  Timer? _aiPollingTimer;
  bool _isAnalyzingFrame = false;

  Timer? _nfcRetryTimer;

  @override
  void initState() {
    super.initState();
    // Pre-load TFLite model in background
    aiScanService.load();
    _armPassiveNfcCheckoutListener();
  }

  void _armPassiveNfcCheckoutListener() {
    _nfcRetryTimer?.cancel();
    PosNfcService.startPassiveCardListener(
      onCardDetected: (Map<String, dynamic> cardRes) {
        if (!mounted || _isCheckoutOpen) return;
        if (cardRes['success'] != true || cardRes['approved'] != true) {
          _showMessage(
            '${(cardRes['error'] as String?) ?? 'Unauthorized NFC Card rejected.'} Re-scanning in 5s...',
          );
          _nfcRetryTimer?.cancel();
          _nfcRetryTimer = Timer(const Duration(seconds: 5), () {
            if (mounted && !_isCheckoutOpen) {
              _armPassiveNfcCheckoutListener();
            }
          });
          return;
        }
        final CartState cart = ref.read(cartProvider);
        if (!cart.isEmpty) {
          _showCheckoutDialog(
            initialMethod: 'smart_java_card',
            preVerifiedCardResult: cardRes,
          );
        } else {
          _showMessage(
            'Tapat JCOP4 Card verified (${cardRes['cardId'] ?? 'TAPAT_JCOP4_8821'}). Add items to cart to auto-checkout.',
          );
          _nfcRetryTimer?.cancel();
          _nfcRetryTimer = Timer(const Duration(seconds: 2), () {
            if (mounted && !_isCheckoutOpen) {
              _armPassiveNfcCheckoutListener();
            }
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _nfcRetryTimer?.cancel();
    _searchCtrl.dispose();
    _stopBackgroundScan();
    PosNfcService.stopSession();
    super.dispose();
  }


  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _startBackgroundScan() async {
    setState(() {
      _isBackgroundScanning = true;
      _isAnalyzingFrame = false;
    });

    if (_useAiForScan) {
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          _cameraController = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
          await _cameraController!.initialize();
          if (!mounted) return;
          setState(() {});
          
          _aiPollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
            if (!mounted || _cameraController == null || !_cameraController!.value.isInitialized || _isAnalyzingFrame || !_isBackgroundScanning) return;
            _isAnalyzingFrame = true;
            try {
              final XFile file = await _cameraController!.takePicture();
              final preds = await aiScanService.predictOnFile(File(file.path));
              if (preds.isNotEmpty && mounted && _isBackgroundScanning) {
                if (preds.first.isMock) {
                  _stopBackgroundScan();
                  _showAiOfflineDialog();
                  return;
                }
                _stopBackgroundScan();
                _showAiResultDialog(preds);
              }
            } catch (e) {
              debugPrint('AI polling error: $e');
            } finally {
              if (mounted) _isAnalyzingFrame = false;
            }
          });
        }
      } catch (e) {
        _showMessage('Camera error: $e');
        _stopBackgroundScan();
      }
    } else {
      _mobileScannerController = MobileScannerController(formats: const [BarcodeFormat.all]);
      await _mobileScannerController!.start();
      setState(() {});
    }
  }

  void _stopBackgroundScan() {
    _aiPollingTimer?.cancel();
    _aiPollingTimer = null;
    _cameraController?.dispose();
    _cameraController = null;
    _mobileScannerController?.dispose();
    _mobileScannerController = null;
    if (mounted) setState(() => _isBackgroundScanning = false);
  }

  void _onBarcodeDetect(BarcodeCapture capture) async {
    if (!_isBackgroundScanning) return;
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first.rawValue;
      if (barcode != null) {
        _stopBackgroundScan();
        final notifier = ref.read(cartProvider.notifier);
        await notifier.search(barcode);
        final results = ref.read(cartProvider).searchResults;
        if (results.isEmpty) {
          _showMessage('No product found for barcode: $barcode');
          if (mounted) _startBackgroundScan();
        } else {
          final p = results.first;
          _showQuantityAdjustDialog(p);
        }
        notifier.search('');
      }
    }
  }

  Future<void> _showQuantityAdjustDialog(Product p) async {
    int qty = 1;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setS) {
          return AlertDialog(
            title: const Text('Add to Cart'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: qty > 1 ? () => setS(() => qty--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$qty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: () => setS(() => qty++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (mounted) _startBackgroundScan();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final notifier = ref.read(cartProvider.notifier);
                  for (int i = 0; i < qty; i++) {
                    final warn = notifier.addProduct(p);
                    if (warn != null) {
                      _showStockWarning(p.name, p.stockQty);
                      break;
                    }
                  }
                  _showMessage('Added $qty of ${p.name}');
                  if (mounted) _startBackgroundScan();
                },
                child: const Text('Add'),
              ),
            ],
          );
        });
      }
    );
  }


  /// Shows a blocking dialog when quantity exceeds available stock.
  void _showStockWarning(String productName, int available) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            color: appColors(ctx).warning, size: 36),
        title: const Text('Not enough stock'),
        content: Text(
          '"$productName" only has $available available in stock.\n\n'
          'Please adjust the quantity or restock the product first.',
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Asks the user to confirm before removing an item from the cart.
  Future<void> _confirmRemoveItem(String productName, String productId) async {
    if (!mounted) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: Icon(Icons.remove_shopping_cart_outlined,
            color: appColors(ctx).warning, size: 36),
        title: const Text('Remove Item?'),
        content: Text(
          'Are you sure you want to remove "$productName" from the cart?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: appColors(ctx).error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(cartProvider.notifier).removeItem(productId);
    }
  }

  // ─── Checkout Dialog ─────────────────────────────────────────────────────

  Future<void> _showCheckoutDialog({
    String? initialMethod,
    Map<String, dynamic>? preVerifiedCardResult,
  }) async {
    final CartState cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      _showMessage('Cart is empty');
      return;
    }

    _isCheckoutOpen = true;
    final TextEditingController cashCtrl = TextEditingController();
    final TextEditingController mobileCtrl = TextEditingController();
    final TextEditingController javaCardCtrl = TextEditingController();
    String method = initialMethod ?? cart.paymentMethod;
    String? cashError;
    String cardStage = 'idle'; // idle, reading, acknowledged, approved, error
    String cardStatusMsg =
        'Tap authentic Tapat JCOP4 Smart Card to auto-approve payment';
    String cardUid = '';
    String cardId = '';
    bool isAutoApprovingCard = false;
    bool dialogClosed = false;
    int retrySecondsLeft = 0;
    Timer? dialogRetryTimer;
    Map<String, dynamic>? pendingPreVerifiedCard = preVerifiedCardResult;

    // Load all configured QR entries (decoded data strings)
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Static defaults
    final List<String> staticKeys = <String>[
      'qr_gcash',
      'qr_maya',
      'qr_maribank'
    ];
    final Map<String, String> staticLabels = <String, String>{
      'qr_gcash': 'GCash',
      'qr_maya': 'Maya',
      'qr_maribank': 'MariBank',
    };
    // Dynamic extras
    final int extraCount = prefs.getInt('qr_extra_count') ?? 0;

    final List<Map<String, String?>> qrEntries = <Map<String, String?>>[
      for (final String k in staticKeys)
        <String, String?>{
          'key': k,
          'label': prefs.getString('${k}_label') ?? staticLabels[k],
          'data': prefs.getString('${k}_qrdata'),
        },
      for (int i = 0; i < extraCount; i++)
        <String, String?>{
          'key': 'qr_extra_$i',
          'label': prefs.getString('qr_extra_${i}_label') ?? 'Other ${i + 1}',
          'data': prefs.getString('qr_extra_${i}_qrdata'),
        },
    ].where((Map<String, String?> e) {
      final String? d = e['data'];
      return d != null && d.isNotEmpty;
    }).toList();

    String? selectedQrKey =
        qrEntries.isNotEmpty ? qrEntries.first['key'] : null;

    if (!mounted) {
      _isCheckoutOpen = false;
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        final AppColors c = appColors(ctx);
        bool listenerInitialized = false;

        return StatefulBuilder(
          builder: (BuildContext ctx2, StateSetter setS) {
            final double total = ref.read(cartProvider).total;
            final double tendered = double.tryParse(cashCtrl.text) ?? 0;
            final double change = method == 'cash'
                ? (tendered - total).clamp(0, double.infinity)
                : 0;

            late Future<void> Function({Map<String, dynamic>? verifiedCard})
                triggerAutoSmartCardCheckout;

            void start5SecDialogRetry() {
              dialogRetryTimer?.cancel();
              if (dialogClosed || !ctx2.mounted) return;
              setS(() => retrySecondsLeft = 5);
              dialogRetryTimer =
                  Timer.periodic(const Duration(seconds: 1), (Timer t) {
                if (dialogClosed || !ctx2.mounted) {
                  t.cancel();
                  return;
                }
                if (retrySecondsLeft <= 1) {
                  t.cancel();
                  setS(() => retrySecondsLeft = 0);
                  triggerAutoSmartCardCheckout();
                } else {
                  setS(() => retrySecondsLeft--);
                }
              });
            }

            triggerAutoSmartCardCheckout = ({
              Map<String, dynamic>? verifiedCard,
            }) async {
              if (isAutoApprovingCard || dialogClosed) return;
              dialogRetryTimer?.cancel();
              isAutoApprovingCard = true;
              final Map<String, dynamic>? effectivePreVerified =
                  verifiedCard ?? pendingPreVerifiedCard;
              pendingPreVerifiedCard = null;
              setS(() {
                method = 'smart_java_card';
                cashError = null;
                retrySecondsLeft = 0;
                cardStage = 'reading';
                cardStatusMsg =
                    'Hold authentic Tapat JCOP4 Smart Card against phone back...';
              });

              final Map<String, dynamic> res =
                  await PosNfcService.readAndApproveCardTransaction(
                amount: total,
                preVerifiedCardResult: effectivePreVerified,
                onStatus: (
                  String stage,
                  String message,
                  Map<String, dynamic>? details,
                ) {
                  if (dialogClosed || !ctx2.mounted) return;
                  setS(() {
                    cardStage = stage;
                    cardStatusMsg = message;
                    if (details != null) {
                      cardUid = (details['uid'] as String?) ?? cardUid;
                      cardId = (details['cardId'] as String?) ?? cardId;
                      if (details['token'] != null) {
                        javaCardCtrl.text = details['token'].toString();
                      }
                    }
                  });
                },
              );

              if (dialogClosed || !ctx2.mounted) return;

              if (res['approved'] == true && res['success'] == true) {
                dialogRetryTimer?.cancel();
                javaCardCtrl.text =
                    (res['token'] as String?) ?? 'JCOP4_APPROVED';
                ref
                    .read(cartProvider.notifier)
                    .setPaymentMethod('smart_java_card');
                if (mobileCtrl.text.isNotEmpty) {
                  ref
                      .read(cartProvider.notifier)
                      .setCustomerMobile(mobileCtrl.text);
                }
                dialogClosed = true;
                Navigator.pop(ctx);
                final bool ok =
                    await ref.read(cartProvider.notifier).checkout();
                if (ok && mounted) {
                  final Receipt? receipt = ref.read(cartProvider).lastReceipt;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _showReceiptDialog(receipt);
                  });
                } else if (mounted) {
                  _showMessage(
                      ref.read(cartProvider).error ?? 'Checkout failed');
                }
              } else {
                isAutoApprovingCard = false;
                if (!dialogClosed && ctx2.mounted) {
                  setS(() {
                    cardStage = 'error';
                    cardStatusMsg = (res['error'] as String?) ??
                        'Unauthorized NFC Card: Only authentic Tapat JCOP4 Smart Cards with Turing Composition are accepted.';
                  });
                  start5SecDialogRetry();
                }
              }
            }

            if (!listenerInitialized) {
              listenerInitialized = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogClosed || !ctx2.mounted) return;
                if (method == 'smart_java_card') {
                  triggerAutoSmartCardCheckout(
                    verifiedCard: pendingPreVerifiedCard,
                  );
                } else {
                  // Listen for physical card tap even while Cash/QR is selected
                  PosNfcService.startPassiveCardListener(
                    onCardDetected: (Map<String, dynamic> cardRes) {
                      if (dialogClosed || !ctx2.mounted) return;
                      if (cardRes['success'] == true &&
                          cardRes['approved'] == true) {
                        triggerAutoSmartCardCheckout(verifiedCard: cardRes);
                      } else {
                        setS(() {
                          method = 'smart_java_card';
                          cardStage = 'error';
                          cardStatusMsg = (cardRes['error'] as String?) ??
                              'Unauthorized NFC Card rejected by Turing Composition.';
                        });
                        start5SecDialogRetry();
                      }
                    },
                  );
                }
              });
            }

            return AlertDialog(
              title: const Text('Checkout'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Total
                    Text(
                      'Total: ₱${total.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: c.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 22),
                    ),
                    const SizedBox(height: 16),

                    // Payment method toggle
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        SizedBox(
                          width: (MediaQuery.of(context).size.width - 120) / 2,
                          child: _PaymentChip(
                            label: 'Cash',
                            icon: Icons.payments_outlined,
                            selected: method == 'cash',
                            onTap: () => setS(() {
                              method = 'cash';
                              cashError = null;
                            }),
                          ),
                        ),
                        SizedBox(
                          width: (MediaQuery.of(context).size.width - 120) / 2,
                          child: _PaymentChip(
                            label: 'E-Wallet / QR',
                            icon: Icons.qr_code_outlined,
                            selected: method == 'ewallet',
                            disabled: qrEntries.isEmpty,
                            disabledHint: 'No QR set up in Profile',
                            onTap: qrEntries.isEmpty
                                ? null
                                : () => setS(() => method = 'ewallet'),
                          ),
                        ),
                        SizedBox(
                          width: (MediaQuery.of(context).size.width - 120) / 2,
                          child: _PaymentChip(
                            label: 'Smart Java Card',
                            icon: Icons.credit_card,
                            selected: method == 'smart_java_card',
                            onTap: () {
                              setS(() {
                                method = 'smart_java_card';
                                cashError = null;
                              });
                              triggerAutoSmartCardCheckout();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Cash fields
                    if (method == 'cash') ...<Widget>[
                      TextField(
                        controller: cashCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'))
                        ],
                        decoration: InputDecoration(
                          labelText: 'Cash tendered (PHP)',
                          prefixText: '₱ ',
                          errorText: cashError,
                        ),
                        onChanged: (_) => setS(() => cashError = null),
                      ),
                      if (tendered >= total && tendered > 0) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'Change: ₱${change.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: c.info, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],

                    // E-Wallet QR display
                    if (method == 'ewallet') ...<Widget>[
                      const SizedBox(height: 8),
                      if (qrEntries.isEmpty) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border),
                          ),
                          child: Column(children: <Widget>[
                            Icon(Icons.qr_code_2,
                                size: 48, color: c.textTertiary),
                            const SizedBox(height: 8),
                            Text('No payment QR set up.',
                                style: TextStyle(color: c.textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              'Go to Profile → Payment QR Codes to upload.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: c.textTertiary, fontSize: 12),
                            ),
                          ]),
                        ),
                      ] else ...<Widget>[
                        // QR selector chips
                        if (qrEntries.length > 1)
                          Wrap(
                            spacing: 8,
                            children: qrEntries.map((Map<String, String?> e) {
                              final bool sel = selectedQrKey == e['key'];
                              return ChoiceChip(
                                label: Text(e['label'] ?? ''),
                                selected: sel,
                                onSelected: (_) =>
                                    setS(() => selectedQrKey = e['key']),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                        // Display selected regenerated QR
                        Builder(builder: (BuildContext _) {
                          final Map<String, String?>? entry = qrEntries
                              .cast<Map<String, String?>?>()
                              .firstWhere(
                                (Map<String, String?>? e) =>
                                    e!['key'] == selectedQrKey,
                                orElse: () => qrEntries.first,
                              );
                          final String? rawData = entry?['data'];
                          if (rawData == null) return const SizedBox.shrink();

                          // If it's a fallback image path
                          if (rawData.startsWith('IMAGE:')) {
                            final String imgPath = rawData.substring(6);
                            return Center(
                              child: Column(children: <Widget>[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(File(imgPath),
                                      height: 200, fit: BoxFit.contain),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Customer scans & enters ₱${total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color: c.textSecondary, fontSize: 13),
                                ),
                              ]),
                            );
                          }

                          // Regenerated brand-colored QR
                          return Center(
                            child: Column(children: <Widget>[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: c.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: c.primary.withValues(alpha: 0.25)),
                                ),
                                child: SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: QrImageView(
                                    data: rawData,
                                    version: QrVersions.auto,
                                    size: 200,
                                    backgroundColor: Colors.transparent,
                                    eyeStyle: QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: c.primaryDark,
                                    ),
                                    dataModuleStyle: QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: c.primaryDark,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Customer scans & enters ₱${total.toStringAsFixed(2)}',
                                style: TextStyle(
                                    color: c.textSecondary, fontSize: 13),
                              ),
                            ]),
                          );
                        }),
                      ],
                      const SizedBox(height: 8),
                    ],

                    // Automatic Smart Java Card Reader & Secured Transaction Approval
                    if (method == 'smart_java_card') ...<Widget>[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardStage == 'approved'
                              ? c.success.withValues(alpha: 0.12)
                              : cardStage == 'error'
                                  ? c.error.withValues(alpha: 0.12)
                                  : c.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cardStage == 'approved'
                                ? c.success
                                : cardStage == 'error'
                                    ? c.error
                                    : c.primary.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            if (cardStage == 'approved')
                              Icon(Icons.verified_rounded,
                                  color: c.success, size: 42)
                            else if (cardStage == 'acknowledged')
                              Icon(Icons.security_rounded,
                                  color: c.primary, size: 40)
                            else if (cardStage == 'error')
                              Icon(Icons.gpp_bad_rounded,
                                  color: c.error, size: 40)
                            else
                              SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: c.primary,
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              cardStatusMsg,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cardStage == 'approved'
                                    ? c.success
                                    : cardStage == 'error'
                                        ? c.error
                                        : c.primaryDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            if (cardStage == 'error') ...<Widget>[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    triggerAutoSmartCardCheckout(),
                                icon: const Icon(Icons.nfc_rounded, size: 16),
                                label: Text(
                                  retrySecondsLeft > 0
                                      ? 'Re-scanning in ${retrySecondsLeft}s (Tap to Scan Now)'
                                      : 'Retry Tapat Card Tap',
                                ),
                              ),
                            ],
                            if (cardUid.isNotEmpty || cardId.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                'JCOP4 UID: ${cardUid.isNotEmpty ? cardUid : "04:7A:93:E2:10:88:01"}',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 12),

                    // Customer mobile (optional)
                    TextField(
                      controller: mobileCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Customer mobile (optional)',
                        hintText: '09xxxxxxxxx',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    dialogClosed = true;
                    dialogRetryTimer?.cancel();
                    PosNfcService.stopSession();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (method == 'smart_java_card') {
                      await triggerAutoSmartCardCheckout();
                      return;
                    }

                    // ── Validate BEFORE closing dialog ──
                    if (method == 'cash') {
                      final double t = double.tryParse(cashCtrl.text) ?? 0;
                      if (t < total) {
                        setS(() => cashError =
                            'Enter at least ₱${total.toStringAsFixed(2)}');
                        return; // keep dialog open
                      }
                      ref.read(cartProvider.notifier).setTenderedCash(t);
                    }

                    // ── Guard: block ewallet if no QR codes configured ──
                    if (method == 'ewallet' && qrEntries.isEmpty) {
                      await showDialog<void>(
                        context: ctx,
                        builder: (BuildContext dCtx) => AlertDialog(
                          icon: Icon(Icons.qr_code_2,
                              color: appColors(dCtx).warning, size: 36),
                          title: const Text('No Payment QR Set Up'),
                          content: const Text(
                            'You haven\'t uploaded any QR payment codes yet.\n\n'
                            'Go to Profile → Payment QR Codes to add your GCash, Maya, or other QR codes first.',
                          ),
                          actions: <Widget>[
                            ElevatedButton(
                              onPressed: () => Navigator.pop(dCtx),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                      return; // keep checkout dialog open
                    }

                    ref.read(cartProvider.notifier).setPaymentMethod(method);
                    // When ewallet is selected, store the specific provider label
                    if (method == 'ewallet' && selectedQrKey != null) {
                      final Map<String, String?>? entry = qrEntries
                          .cast<Map<String, String?>?>()
                          .firstWhere(
                            (Map<String, String?>? e) =>
                                e!['key'] == selectedQrKey,
                            orElse: () => null,
                          );
                      if (entry != null && entry['label'] != null) {
                        ref.read(cartProvider.notifier).setPaymentMethod(
                            'ewallet:${entry['label']}');
                      }
                    }
                    if (mobileCtrl.text.isNotEmpty) {
                      ref
                          .read(cartProvider.notifier)
                          .setCustomerMobile(mobileCtrl.text);
                    }

                    // Close dialog, then checkout
                    dialogClosed = true;
                    PosNfcService.stopSession();
                    Navigator.pop(ctx);
                    final bool ok =
                        await ref.read(cartProvider.notifier).checkout();

                    if (ok && mounted) {
                      // Use postFrameCallback so receipt shows after
                      // the widget rebuilds from state change
                      final Receipt? receipt =
                          ref.read(cartProvider).lastReceipt;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _showReceiptDialog(receipt);
                      });
                    } else if (mounted) {
                      _showMessage(
                          ref.read(cartProvider).error ?? 'Checkout failed');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors(ctx).primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    _isCheckoutOpen = false;
    if (mounted) {
      _armPassiveNfcCheckoutListener();
    }
  }

  Future<void> _showReceiptDialog(Receipt? receipt) async {
    if (receipt == null || !mounted) return;

    Map<String, dynamic> data = <String, dynamic>{};
    List<dynamic> items = <dynamic>[];
    try {
      // New format: human-readable text then ##JSON##<jsonstring>
      // Old format: raw JSON (backwards compat)
      final String payload = receipt.qrPayload;
      final int sepIdx = payload.indexOf('##JSON##');
      final String jsonStr =
          sepIdx >= 0 ? payload.substring(sepIdx + 8) : payload;
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
      items = (data['items'] as List<dynamic>?) ?? <dynamic>[];
    } catch (_) {}

    final String payMethod =
        (data['payment_method'] as String? ?? 'cash').toUpperCase();
    final double total = (data['total'] as num?)?.toDouble() ?? 0;
    final double changeDue = ref.read(cartProvider).changeDue;
    final String dateStr = '${receipt.timestamp.year}-'
        '${receipt.timestamp.month.toString().padLeft(2, '0')}-'
        '${receipt.timestamp.day.toString().padLeft(2, '0')} '
        '${receipt.timestamp.hour.toString().padLeft(2, '0')}:'
        '${receipt.timestamp.minute.toString().padLeft(2, '0')}';

    await showGlassDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final AppColors c = appColors(ctx);
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // ── Header ──
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: <Widget>[
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 36),
                      const SizedBox(height: 6),
                      Text(
                        receipt.storeName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Receipt #${receipt.receiptId.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                        ),
                    ],
                  ),
                ),

                // ── Items list ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ...items.map((dynamic it) {
                          final Map<String, dynamic> item =
                              it as Map<String, dynamic>;
                          final String name = item['name'] as String? ?? '-';
                          final int qty = (item['qty'] as num?)?.toInt() ?? 1;
                          final double price =
                              (item['price'] as num?)?.toDouble() ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    '$qty× $name',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  '₱${(qty * price).toStringAsFixed(2)}',
                                  style: TextStyle(
                                      color: c.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }),
                        Divider(color: c.border, height: 20),

                        // ── Totals ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text('Payment',
                                style: TextStyle(fontSize: 12)),
                            Text(payMethod,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text('TOTAL',
                                style: TextStyle(
                                    color: c.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            Text(
                              '₱${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: c.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20),
                            ),
                          ],
                        ),
                        if (payMethod == 'CASH' && changeDue > 0) ...<Widget>[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text('Change',
                                  style:
                                      TextStyle(color: c.info, fontSize: 13)),
                              Text(
                                '₱${changeDue.toStringAsFixed(2)}',
                                style: TextStyle(
                                    color: c.info,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),

                        // ── Receipt QR (colored) ──
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: c.primary.withValues(alpha: 0.25)),
                            ),
                            child: SizedBox(
                              width: 140,
                              height: 140,
                              child: QrImageView(
                                data: receipt.qrPayload,
                                version: QrVersions.auto,
                                size: 140,
                                backgroundColor: Colors.transparent,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: c.primaryDark,
                                ),
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: c.primaryDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Scan to verify receipt',
                            style:
                                TextStyle(color: c.textTertiary, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ── Actions ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
  
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Done'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: c.success,
                              foregroundColor: Colors.black, // Dark text on gold button looks premium
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }





  void _showAiOfflineDialog() {
    showGlassDialog<void>(
      context: context,
      builder: (ctx) {
        final AppColors c = appColors(ctx);
        return AlertDialog(
          icon: Icon(Icons.model_training_rounded, color: c.glassGold, size: 36),
          title: const Text('AI Model Not Ready'),
          content: const Text(
            'The AI model has not been converted to TFLite yet.\n\n'
            'Run this command once on your PC:\n'
            '  python convert_to_tflite.py\n\n'
            'Then rebuild the APK. The AI scan will work fully offline!',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showAiResultDialog(List<AiPrediction> preds) {
    final CartNotifier notifier = ref.read(cartProvider.notifier);

    showGlassDialog<void>(
      context: context,
      builder: (ctx) {
        final AppColors c = appColors(ctx);
        return StatefulBuilder(builder: (ctx2, setS) {
          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: c.glassGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_awesome, color: c.glassGold, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI Detected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Tap Add to put in cart', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w400)),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: preds.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
                itemBuilder: (_, i) {
                  final AiPrediction p = preds[i];
                  final Color confColor = p.confidence > 0.7
                      ? c.info
                      : p.confidence > 0.4
                          ? c.warning
                          : c.textSecondary;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: Row(
                      children: [
                        // Confidence circle
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: confColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: confColor.withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '${(p.confidence * 100).toStringAsFixed(0)}%',
                              style: TextStyle(color: confColor, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Product name
                        Expanded(
                          child: Text(
                            p.productName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Add button — capture everything BEFORE the await
                        SizedBox(
                          height: 34,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // 1. Capture name before closing dialog
                              final String productName = p.productName;
                              // 2. Close dialog synchronously
                              Navigator.pop(ctx);
                              // 3. Do async work AFTER dialog is closed, using outer mounted check
                              _addAiProduct(notifier, productName);
                            },
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (mounted) {
                    setState(() {
                      _showSearch = true;
                      _searchCtrl.clear();
                    });
                  }
                  notifier.search('');
                },
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Search Manually'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (mounted) _startBackgroundScan();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        });
      },
    );
  }

  /// Called after dialog is dismissed. Safe to use mounted here.
  Future<void> _addAiProduct(CartNotifier notifier, String productName) async {
    await notifier.search(productName);
    if (!mounted) return;
    final List<Product> results = ref.read(cartProvider).searchResults;
    if (results.isNotEmpty) {
      final String? warn = notifier.addProduct(results.first);
      notifier.search('');
      _showMessage(warn == null
          ? '✅ Added: ${results.first.name}'
          : warn);
      if (mounted) _startBackgroundScan();
    } else {
      notifier.search('');
      if (!mounted) return;
      setState(() {
        _showSearch = true;
        _searchCtrl.text = productName;
      });
      notifier.search(productName);
      _showMessage('Not in inventory — searching: $productName');
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final CartState cart = ref.watch(cartProvider);
    final bool isOwner = ref.watch(authProvider).value?.user?.role == 'owner';
    final double topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight - 28;
    final double bottomNavHeight = isOwner ? 104.0 : 0.0;

    return Stack(
      children: [
        if (_isBackgroundScanning && !_useAiForScan && _mobileScannerController != null)
          Offstage(
            offstage: true,
            child: MobileScanner(
              controller: _mobileScannerController!,
              onDetect: _onBarcodeDetect,
            ),
          ),
        if (_isBackgroundScanning && _useAiForScan && _cameraController != null)
          Offstage(
            offstage: true,
            child: CameraPreview(_cameraController!),
          ),
        Column(
          children: <Widget>[
            // ── Scrollable content ──────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(14, topPadding, 14, 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── Header row ────────────────────────────────────────────
                Row(children: <Widget>[
                  Icon(Icons.point_of_sale_rounded, color: c.primary, size: 22),
                  const SizedBox(width: 8),
                  Text('POS', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  // Scan button
                  _GlassButton(
                    onTap: _isBackgroundScanning ? _stopBackgroundScan : _startBackgroundScan,
                    icon: _isBackgroundScanning ? Icons.stop : Icons.qr_code_scanner,
                    label: _isBackgroundScanning ? 'STOP' : 'SCAN',
                    color: c.primary,
                  ),
                  const SizedBox(width: 8),
                  // AI toggle
                  Row(
                    children: [
                      Text('AI', style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.bold)),
                      Switch(
                        value: _useAiForScan,
                        onChanged: _isBackgroundScanning ? null : (v) => setState(() => _useAiForScan = v),
                        activeColor: c.glassGold,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  GlassContainer(
                    borderRadius: 14,
                    padding: EdgeInsets.zero,
                    child: IconButton(
                      onPressed: () => setState(() => _showSearch = !_showSearch),
                      icon: Icon(_showSearch ? Icons.close : Icons.search,
                          size: 18, color: c.text),
                      tooltip: 'Search products',
                    ),
                  ),
                ]),
                const SizedBox(height: 10),

                // Search bar + results
                if (_showSearch) ...<Widget>[
                  TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search product by name or barcode...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (String v) =>
                        ref.read(cartProvider.notifier).search(v),
                  ),
                  const SizedBox(height: 8),
                  if (cart.searchResults.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        children: cart.searchResults
                            .map((Product p) => ListTile(
                                  title: Text(p.name),
                                  subtitle: Text(
                                      '${p.categoryName ?? 'Uncategorized'} | Stock: ${p.stockQty}'),
                                  trailing: Text(
                                    '₱${p.unitPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        color: c.primary,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  onTap: () {
                                    final String? warn = ref
                                        .read(cartProvider.notifier)
                                        .addProduct(p);
                                    if (warn != null) _showMessage(warn);
                                    setState(() {
                                      _showSearch = false;
                                      _searchCtrl.clear();
                                    });
                                    ref.read(cartProvider.notifier).search('');
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],

                // ── Empty state: big dual-scan CTAs ──────────────────────
                if (cart.isEmpty && !_showSearch)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(children: <Widget>[
                      const SizedBox(height: 8),
                      // Unified Scan CTA
                      _BigScanCta(
                        icon: _isBackgroundScanning ? Icons.stop : (_useAiForScan ? Icons.auto_awesome_rounded : Icons.qr_code_scanner),
                        title: _isBackgroundScanning ? 'Scanning...' : 'Start Scan',
                        subtitle: _isBackgroundScanning ? 'Hold item in front of camera' : 'Tap to begin background scanning',
                        gradient: LinearGradient(
                          colors: [c.primary, c.primary.withValues(alpha: 0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        glowColor: c.primary,
                        onTap: _isBackgroundScanning ? _stopBackgroundScan : _startBackgroundScan,
                        loading: _isBackgroundScanning,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'or use 🔍 Search above',
                        style: TextStyle(color: c.textTertiary, fontSize: 12),
                      ),
                    ]),
                  )
                else if (cart.isEmpty) // search open, nothing in cart
                  const SizedBox(height: 8)
                else
                  for (int i = 0; i < cart.items.length; i++) ...[
                    RepaintBoundary(
                      key: ValueKey(cart.items[i].product.productId),
                      child: Builder(builder: (context) {
                        final CartItem item = cart.items[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(item.product.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                      '₱${item.product.unitPrice.toStringAsFixed(2)} each',
                                      style: TextStyle(
                                          color: c.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Row(children: <Widget>[
                                IconButton(
                                  onPressed: () {
                                    if (item.qty <= 1) {
                                      _confirmRemoveItem(
                                          item.product.name,
                                          item.product.productId);
                                      return;
                                    }
                                    final String? warn = ref
                                        .read(cartProvider.notifier)
                                        .changeQty(item.product.productId, -1);
                                    if (warn != null) _showMessage(warn);
                                  },
                                  icon: const Icon(Icons.remove_circle_outline),
                                  iconSize: 20,
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final TextEditingController qtyCtrl =
                                        TextEditingController(
                                            text: '${item.qty}');
                                    final String? result =
                                        await showDialog<String>(
                                      context: context,
                                      builder: (BuildContext dCtx) =>
                                          AlertDialog(
                                        title: Text(item.product.name),
                                        content: TextField(
                                          controller: qtyCtrl,
                                          autofocus: true,
                                          keyboardType: TextInputType.number,
                                          inputFormatters:
                                              <TextInputFormatter>[
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          decoration: const InputDecoration(
                                              labelText: 'Quantity'),
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dCtx),
                                              child: const Text('Cancel')),
                                          ElevatedButton(
                                              onPressed: () => Navigator.pop(
                                                  dCtx, qtyCtrl.text),
                                              child: const Text('Set')),
                                        ],
                                      ),
                                    );
                                    if (result != null) {
                                      final int? newQty =
                                          int.tryParse(result);
                                      if (newQty != null && newQty > 0) {
                                        if (newQty > item.product.stockQty) {
                                          _showStockWarning(item.product.name,
                                              item.product.stockQty);
                                        } else {
                                          final int delta = newQty - item.qty;
                                          final String? warn = ref
                                              .read(cartProvider.notifier)
                                              .changeQty(
                                                  item.product.productId,
                                                  delta);
                                          if (warn != null) {
                                            _showStockWarning(
                                                item.product.name,
                                                item.product.stockQty);
                                          }
                                        }
                                      } else if (newQty == 0) {
                                        _confirmRemoveItem(item.product.name,
                                            item.product.productId);
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: c.surfaceMuted,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: c.border),
                                    ),
                                    child: Text(
                                      '${item.qty}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    final String? warn = ref
                                        .read(cartProvider.notifier)
                                        .changeQty(item.product.productId, 1);
                                    if (warn != null) {
                                      _showStockWarning(item.product.name,
                                          item.product.stockQty);
                                    }
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                  iconSize: 20,
                                ),
                              ]),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  '₱${item.subtotal.toStringAsFixed(2)}',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                      color: c.primary,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ]),
                          ),
                        );
                      }),
                    ),
                  ],
              ],
            ),
          ),
        ),

        // ── Sticky checkout bar ─────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomNavHeight),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(children: <Widget>[
            // Total info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Total',
                    style: TextStyle(color: c.textSecondary, fontSize: 11)),
                Text(
                  '₱${cart.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: c.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cart.items.length} item${cart.items.length == 1 ? '' : 's'}',
                  style: TextStyle(color: c.textSecondary, fontSize: 10),
                ),
              ],
            ),
            const Spacer(),
            // Clear
            if (!cart.isEmpty)
              TextButton(
                onPressed: ref.read(cartProvider.notifier).clearCart,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text('Clear',
                    style: TextStyle(color: c.error, fontSize: 13)),
              ),
            const SizedBox(width: 4),
            // Checkout
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: cart.isProcessing ? null : _showCheckoutDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: cart.isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.shopping_cart_checkout, size: 18),
                          SizedBox(width: 8),
                          Text('Checkout',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),
          ]),
        ),
      ],
        ),
      ],
    );
  }
}

// ─── Payment Chip ─────────────────────────────────────────────────────────────

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.disabled = false,
    this.disabledHint,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool disabled;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final Color fgColor = disabled
        ? c.textTertiary
        : selected
            ? c.primary
            : c.textSecondary;
    return Tooltip(
      message: disabled ? (disabledHint ?? '') : '',
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: disabled
                ? c.surfaceMuted.withValues(alpha: 0.5)
                : selected
                    ? c.primary.withValues(alpha: 0.15)
                    : c.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: disabled
                    ? c.borderSubtle
                    : selected
                        ? c.primary
                        : c.border,
                width: selected && !disabled ? 2 : 1),
          ),
          child: Column(children: <Widget>[
            Icon(icon, color: fgColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontWeight: selected && !disabled
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            if (disabled && disabledHint != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                disabledHint!,
                style: TextStyle(color: c.textTertiary, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── Glass header button ──────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: onTap == null ? 0.08 : 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: color.withValues(alpha: onTap == null ? 0.20 : 0.45),
              width: 1),
          boxShadow: [
            if (onTap != null)
              BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: -2),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color),
                  )
                : Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Big scan CTA card ────────────────────────────────────────────────────────

class _BigScanCta extends StatelessWidget {
  const _BigScanCta({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.glowColor,
    this.onTap,
    this.loading = false,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final Color glowColor;
  final VoidCallback? onTap;
  final bool loading;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.22), width: 1),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35), width: 0.8),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            loading
                ? const SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: Colors.white),
                  )
                : Icon(icon, size: 52, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.80),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
