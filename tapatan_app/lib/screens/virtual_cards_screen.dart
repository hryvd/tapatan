import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/user_provider.dart';
import '../services/nfc_service.dart';
import '../ui/card_face.dart' as ui_card;
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';

class _CardMeta {
  final String kind; // 'virtual' | 'pass' | 'bank'
  final String material; // 'obsidian' | 'cyber' | 'chrome' | 'emerald' | 'indigo' | 'amber'
  final String? format; // 'qr' | 'barcode'
  final String? code;
  final String? bank;
  final String? acct;
  final double limit;

  const _CardMeta({
    this.kind = 'virtual',
    this.material = 'cyber',
    this.format,
    this.code,
    this.bank,
    this.acct,
    this.limit = 5000,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'material': material,
        if (format != null) 'format': format,
        if (code != null) 'code': code,
        if (bank != null) 'bank': bank,
        if (acct != null) 'acct': acct,
        'limit': limit,
      };

  factory _CardMeta.fromJson(Map<String, dynamic> j) => _CardMeta(
        kind: (j['kind'] ?? 'virtual').toString(),
        material: (j['material'] ?? 'cyber').toString(),
        format: j['format']?.toString(),
        code: j['code']?.toString(),
        bank: j['bank']?.toString(),
        acct: j['acct']?.toString(),
        limit: (j['limit'] as num?)?.toDouble() ?? 5000,
      );
}

class _ResolvedCard {
  final CardData raw;
  final ui_card.CardData ui;
  final String tag;
  final double limit;
  final String? acct;
  final bool isSyntheticPrimary;

  const _ResolvedCard({
    required this.raw,
    required this.ui,
    required this.tag,
    required this.limit,
    this.acct,
    this.isSyntheticPrimary = false,
  });
}

class VirtualCardsScreen extends ConsumerStatefulWidget {
  const VirtualCardsScreen({super.key});

  @override
  ConsumerState<VirtualCardsScreen> createState() => _VirtualCardsScreenState();
}

class _VirtualCardsScreenState extends ConsumerState<VirtualCardsScreen>
    with TickerProviderStateMixin {
  static const _metaPrefsKey = 'tapatan_v2_card_meta_v1';

  int _idx = 0;
  bool _flip = false;
  bool _xray = false;
  bool _drawerOpen = true;
  bool _syncing = false;
  String _syncStatus = '';
  int _tokenTick = 0;
  int _sigCounter = 42;
  int _pulseCount = 0;
  final Map<String, bool> _frozen = {};
  Map<String, _CardMeta> _meta = {};
  int _lastCardCount = -1;

  Timer? _tokenTimer;
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _xrayTraceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _loadMeta();
    _tokenTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _tokenTick++);
    });
  }

  @override
  void dispose() {
    _tokenTimer?.cancel();
    _pulseCtrl.dispose();
    _xrayTraceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_metaPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _meta = decoded.map(
          (k, v) => MapEntry(k, _CardMeta.fromJson(Map<String, dynamic>.from(v as Map))),
        );
      });
    } catch (_) {}
  }

  Future<void> _saveMeta(String id, _CardMeta m) async {
    _meta[id] = m;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _metaPrefsKey,
        jsonEncode(_meta.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } catch (_) {}
  }

  Future<void> _removeMeta(String id) async {
    if (_meta.remove(id) == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _metaPrefsKey,
        jsonEncode(_meta.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } catch (_) {}
  }

  String _peso(double amount) {
    final abs = amount.abs().toStringAsFixed(0);
    final intPart = abs.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return '₱$intPart';
  }

  List<_ResolvedCard> _buildCards(UserState user) {
    final stored = user.virtualCards;
    final list = <_ResolvedCard>[];

    for (final c in stored) {
      final m = _meta[c.id];
      final isPhysical = c.id == 'card-tapat-primary' ||
          c.provider.toLowerCase().contains('jcop4') ||
          c.provider.toLowerCase().contains('tapat physical');
      final kind = isPhysical
          ? 'virtual'
          : (m?.kind ??
              (c.type == 'qr' || c.type == 'barcode'
                  ? 'pass'
                  : c.type == 'bank'
                      ? 'bank'
                      : 'virtual'));
      final material = isPhysical
          ? 'obsidian'
          : (m?.material ??
              (c.type.toLowerCase() == 'mastercard'
                  ? 'indigo'
                  : kind == 'bank'
                      ? 'indigo'
                      : 'cyber'));
      final network = isPhysical
          ? 'ISO 14443-4'
          : kind == 'bank'
              ? 'Debit'
              : kind == 'pass'
                  ? ''
                  : (c.type.toLowerCase().contains('master')
                      ? 'Mastercard Tokenized'
                      : 'Visa Tokenized');
      final tag = isPhysical
          ? 'Physical · J3R150'
          : kind == 'pass'
              ? 'Pass · ${(m?.format ?? c.type) == 'barcode' ? 'Barcode' : 'QR'}'
              : kind == 'bank'
                  ? 'Bank · ATM account'
                  : 'Virtual · Tokenized';

      list.add(
        _ResolvedCard(
          raw: c,
          ui: ui_card.CardData(
            id: c.id,
            name: c.provider.isNotEmpty ? c.provider : 'Tapat Card',
            material: material,
            network: network,
            num: c.cardNumber.isNotEmpty ? c.cardNumber : '4532 •••• •••• 8821',
            kind: kind,
            physical: isPhysical,
            format: m?.format ?? (c.type == 'barcode' ? 'barcode' : 'qr'),
            code: m?.code ?? (kind == 'pass' ? c.cardNumber : null),
            bank: m?.bank ?? (kind == 'bank' ? c.provider : null),
          ),
          tag: tag,
          limit: m?.limit ?? (isPhysical ? 50000 : 5000),
          acct: m?.acct,
        ),
      );
    }

    if (list.isEmpty) {
      final tail = user.cardId.length >= 4
          ? user.cardId.substring(user.cardId.length - 4)
          : '8821';
      final holder = user.name.trim().isNotEmpty
          ? user.name.trim().toUpperCase()
          : 'TAPAT MEMBER';
      list.add(
        _ResolvedCard(
          raw: CardData(
            id: 'card-tapat-primary',
            provider: 'Tapat JCOP4 Card',
            cardNumber: '4532 •••• •••• $tail',
            holderName: holder,
            expiry: '12/29',
            cvv: '882',
            type: 'visa',
            colors: const [Color(0xFF0369A1), Color(0xFF0891B2)],
            balance: user.balance,
          ),
          ui: ui_card.CardData(
            id: 'card-tapat-primary',
            name: 'Tapat JCOP4 Card',
            material: 'obsidian',
            network: 'ISO 14443-4',
            num: '4532 •••• •••• $tail',
            kind: 'virtual',
            physical: true,
          ),
          tag: 'Physical · J3R150',
          limit: 50000,
          isSyntheticPrimary: true,
        ),
      );
    }

    return list;
  }

  void _stepCard(int delta, int count) {
    if (count <= 1) return;
    setState(() {
      _idx = (_idx + delta + count) % count;
      _flip = false;
      _xray = false;
    });
  }

  Future<void> _syncJcopCard() async {
    if (_syncing) return;
    final user = ref.read(userProvider);
    setState(() {
      _syncing = true;
      _syncStatus = 'Hold your Tapat JCOP4 Card steady against the phone…';
      _pulseCount++;
    });
    _pulseCtrl.forward(from: 0);

    final targetCardId =
        user.cardId.isNotEmpty ? user.cardId : NfcService.generateCardId();
    final result = await NfcService.writeCardIdentity(
      targetCardId,
      user.email,
      name: user.name,
    );
    if (!mounted) return;

    if (result['success'] == true) {
      final uid = (result['uid'] as String?) ?? '';
      ref.read(userProvider.notifier).updateJcopCardInfo(
            uid: uid.isNotEmpty ? uid : user.jcopCardUid,
            pinRetriesLeft: 5,
            lifecycleState: 'ENROLLED',
          );
      setState(() {
        _syncing = false;
        _sigCounter++;
        _syncStatus =
            'Bound to ${user.name.isNotEmpty ? user.name : 'Account'} · UID: ${uid.isNotEmpty ? uid : 'Verified'}';
      });
      showToast(context, 'JCOP4 hardware synced · APDU 0x9000');
    } else {
      final err = (result['error'] as String?) ?? 'JCOP4 tap timed out or failed';
      setState(() {
        _syncing = false;
        _syncStatus = err;
      });
      showToast(context, err);
    }
  }

  void _openAddCardSheet(UserState user) {
    showAppSheet(
      context,
      title: 'Add to wallet',
      tall: true,
      child: _AddCardStudio(
        defaultHolder: user.name.trim().isNotEmpty
            ? user.name.trim().toUpperCase()
            : 'TAPAT MEMBER',
        onAddCard: (card, meta) async {
          ref.read(userProvider.notifier).addVirtualCard(card);
          await _saveMeta(card.id, meta);
          if (mounted) {
            showToast(context, '${card.provider} added to wallet');
          }
        },
      ),
    );
  }

  String _lifecycleLabel(String state) {
    switch (state) {
      case 'op_ready':
        return 'PERSONALIZED · TPT4';
      case 'secured':
        return 'PIN_SET · SECURED';
      case 'ENROLLED':
        return 'PERSONALIZED / ENROLLED';
      case 'locked':
        return 'PIN_BLOCKED';
      case 'terminated':
        return 'TERMINATED';
      default:
        return 'ENROLLED · READY';
    }
  }

  Color _lifecycleColor(String state) {
    switch (state) {
      case 'op_ready':
      case 'ENROLLED':
        return T.emerald300;
      case 'secured':
        return T.amber300;
      case 'locked':
      case 'terminated':
        return T.red400;
      default:
        return T.cyan300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final cards = _buildCards(user);

    if (_lastCardCount != -1 && cards.length > _lastCardCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _idx = cards.length - 1;
          _flip = false;
          _xray = false;
        });
      });
    }
    _lastCardCount = cards.length;

    final safeIdx = _idx.clamp(0, cards.length - 1);
    final current = cards[safeIdx];
    final holder = user.name.trim().isNotEmpty
        ? user.name.trim().toUpperCase()
        : current.raw.holderName.trim().isNotEmpty &&
                current.raw.holderName.trim().toLowerCase() != 'richard'
            ? current.raw.holderName.trim().toUpperCase()
            : 'TAPAT MEMBER';
    final isFrozen = _frozen[current.ui.id] == true;
    final isActive =
        current.raw.id == user.activeCardId || (cards.length == 1 && current.isSyntheticPrimary);
    final uidText = user.jcopCardUid.isNotEmpty
        ? user.jcopCardUid
        : (user.cardId.isNotEmpty ? user.cardId : 'Not synced yet');

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          T.screenPad,
          10,
          T.screenPad,
          T.navBottomPad + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.tag,
                        style: T.text(12, color: T.white(.5)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        current.ui.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.text(22, w: T.w800, height: 1.15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    _RoundDockBtn(
                      icon: LucideIcons.plus,
                      primary: true,
                      onTap: () => _openAddCardSheet(user),
                    ),
                    const SizedBox(width: 6),
                    _RoundDockBtn(
                      icon: LucideIcons.chevronUp,
                      onTap: () => _stepCard(-1, cards.length),
                    ),
                    const SizedBox(width: 6),
                    _RoundDockBtn(
                      icon: LucideIcons.chevronDown,
                      onTap: () => _stepCard(1, cards.length),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── 3D Stage + Stacked Fan Deck ──────────────────────────────
            SizedBox(
              height: 270,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // Fan deck behind [2, 1]
                  for (final offset in [2, 1])
                    if (cards.length > offset)
                      Builder(
                        builder: (_) {
                          final bgCard = cards[(safeIdx + offset) % cards.length];
                          final scale = 1 - offset * 0.07;
                          final dy = -offset * 20.0;
                          final opacity = (0.75 - offset * 0.2).clamp(0.15, 0.85);
                          final m = Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateX(-18 * math.pi / 180)
                            ..scaleByDouble(scale, scale, 1.0, 1.0);
                          return Positioned(
                            top: 34 + dy,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: opacity * 0.65,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: m,
                                  child: SizedBox(
                                    width: 290,
                                    child: ui_card.CardFace(
                                      card: bgCard.ui,
                                      holder: holder,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                  // Ambient cyan/indigo glow beneath card
                  Positioned(
                    bottom: 12,
                    child: IgnorePointer(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          width: 210,
                          height: 24,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(999)),
                            gradient: RadialGradient(
                              colors: [
                                Color(0xAA06B6D4),
                                Color(0x556366F1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Foreground active 3D card (or X-Ray 3-layer stack)
                  if (_xray && current.ui.physical)
                    Positioned.fill(
                      child: GestureDetector(
                        onDoubleTap: () => setState(() => _xray = false),
                        child: Center(
                          child: SizedBox(
                            width: 290,
                            child: _XRayExplodedCard(
                              traceAnim: _xrayTraceCtrl,
                              pinRetriesLeft: user.pinRetriesLeft,
                              armed: user.cardArmed,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    ui_card.Card3D(
                      key: ValueKey('stage-${current.ui.id}'),
                      flipped: _flip,
                      onFlip: () => setState(() {
                        _xray = false;
                        _flip = !_flip;
                      }),
                      onSwipe: (dir) => _stepCard(dir, cards.length),
                      front: (tx, ty) => ui_card.CardFace(
                        card: current.ui,
                        holder: holder,
                        tiltX: tx,
                        tiltY: ty,
                        frozen: isFrozen,
                      ),
                      back: _CardBackFace(
                        resolved: current,
                        uid: uidText,
                        tokenTick: _tokenTick,
                        onCopyUid: () {
                          Clipboard.setData(ClipboardData(text: uidText));
                          showToast(context, 'Hardware UID copied');
                        },
                      ),
                    ),

                  // Sync pulse wave overlay
                  if (_pulseCount > 0)
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, _) {
                        if (!_pulseCtrl.isAnimating && _pulseCtrl.value == 1.0) {
                          return const SizedBox.shrink();
                        }
                        final v = Curves.easeOut.transform(_pulseCtrl.value);
                        return Positioned(
                          top: 46,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: (1 - v) * 0.85,
                              child: Transform.scale(
                                scale: 0.55 + v * 0.85,
                                child: Container(
                                  width: 192,
                                  height: 192,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: T.cyan300,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            // ── Dot Pagination ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < cards.length; i++)
                  GestureDetector(
                    onTap: () => setState(() {
                      _idx = i;
                      _flip = false;
                      _xray = false;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      width: i == safeIdx ? 20 : 6,
                      decoration: BoxDecoration(
                        color: i == safeIdx ? T.cyan300 : T.white(.25),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── 4-Button Control Dock ────────────────────────────────────
            Glass(
              radius: 26,
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  _DockAction(
                    icon: LucideIcons.rotateCw,
                    label: 'Flip 180°',
                    active: _flip,
                    onTap: () => setState(() {
                      _xray = false;
                      _flip = !_flip;
                    }),
                  ),
                  _DockAction(
                    icon: LucideIcons.layers,
                    label: 'X-Ray',
                    active: _xray,
                    onTap: () {
                      if (current.ui.physical) {
                        setState(() {
                          _flip = false;
                          _xray = !_xray;
                        });
                      } else {
                        showToast(
                          context,
                          'X-Ray is for the physical JCOP4 card',
                        );
                      }
                    },
                  ),
                  _DockAction(
                    icon: LucideIcons.zap,
                    label: _syncing ? 'Tap…' : 'Sync',
                    active: _syncing,
                    onTap: _syncJcopCard,
                  ),
                  _DockAction(
                    icon: LucideIcons.snowflake,
                    label: isFrozen ? 'Unfreeze' : 'Freeze',
                    active: isFrozen,
                    onTap: () {
                      setState(() => _frozen[current.ui.id] = !isFrozen);
                      showToast(
                        context,
                        isFrozen
                            ? '${current.ui.name} unfrozen'
                            : '${current.ui.name} frozen',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Telemetry / Card Info Drawer ─────────────────────────────
            if (current.ui.physical)
              Glass(
                radius: 26,
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _drawerOpen = !_drawerOpen),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: T.emerald400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Live JCOP4 Telemetry',
                                  style: T.text(14, w: T.w700),
                                ),
                              ],
                            ),
                            AnimatedRotation(
                              turns: _drawerOpen ? 0.5 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                LucideIcons.chevronDown,
                                size: 16,
                                color: T.white(.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_drawerOpen)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            _TelemetryRow(
                              k: 'Lifecycle State',
                              v: Text(
                                _lifecycleLabel(user.cardLifecycleState),
                                style: T.mono(
                                  12,
                                  color: _lifecycleColor(user.cardLifecycleState),
                                  w: T.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _TelemetryRow(
                              k: 'Hardware UID',
                              v: GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: uidText));
                                  showToast(context, 'Hardware UID copied');
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      uidText.length > 20
                                          ? '${uidText.substring(0, 20)}…'
                                          : uidText,
                                      style: T.mono(12),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      LucideIcons.copy,
                                      size: 14,
                                      color: T.cyan300,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _TelemetryRow(
                              k: 'PIN Retries',
                              v: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < 5; i++)
                                    Container(
                                      width: 16,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: (user.pinRetriesLeft < 0 ||
                                                i < user.pinRetriesLeft)
                                            ? (user.pinRetriesLeft == 0
                                                ? T.red400
                                                : T.cyan400)
                                            : T.white(.12),
                                        borderRadius: BorderRadius.circular(99),
                                        boxShadow: (user.pinRetriesLeft < 0 ||
                                                i < user.pinRetriesLeft)
                                            ? T.glow(T.cyan400, 8)
                                            : null,
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.pinRetriesLeft < 0
                                        ? '5/5'
                                        : '${user.pinRetriesLeft}/5',
                                    style: T.mono(12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            _TelemetryRow(
                              k: 'Last APDU SW',
                              v: Text(
                                '0x9000 · #$_sigCounter',
                                style: T.mono(12),
                              ),
                            ),
                            if (_syncStatus.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: T.white(.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: T.white(.08)),
                                ),
                                child: Text(
                                  _syncStatus,
                                  textAlign: TextAlign.center,
                                  style: T.text(11, color: T.cyan200),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Btn(
                              variant: BtnVariant.glass,
                              width: double.infinity,
                              onTap: _syncing ? null : _syncJcopCard,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.nfc,
                                    size: 16,
                                    color: _syncing ? T.cyan300 : Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _syncing
                                        ? 'Hold JCOP4 Card Against Phone…'
                                        : 'Tap to Verify & Sync Card',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              )
            else
              Glass(
                radius: 26,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _TelemetryRow(
                      k: 'Type',
                      v: Text(
                        current.ui.kind == 'pass'
                            ? ((current.ui.format ?? 'qr') == 'qr'
                                ? 'QR pass'
                                : 'Barcode pass')
                            : current.ui.kind == 'bank'
                                ? 'Bank / ATM account'
                                : current.ui.network,
                        style: T.text(12.5, w: T.w600),
                      ),
                    ),
                    if (current.ui.kind == 'bank' && current.acct != null) ...[
                      const SizedBox(height: 10),
                      _TelemetryRow(
                        k: 'Account',
                        v: Text(
                          '•••• ${current.acct!.length >= 4 ? current.acct!.substring(current.acct!.length - 4) : current.acct}',
                          style: T.mono(12),
                        ),
                      ),
                    ],
                    if (current.ui.kind == 'virtual') ...[
                      const SizedBox(height: 10),
                      _TelemetryRow(
                        k: 'Spending limit',
                        v: Text(_peso(current.limit), style: T.text(12.5, w: T.w600)),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _TelemetryRow(
                      k: 'Status',
                      v: Text(
                        isFrozen ? 'Frozen' : (isActive ? 'Active · Primary' : 'Ready'),
                        style: T.text(
                          12.5,
                          w: T.w600,
                          color: isFrozen ? T.cyan200 : T.emerald300,
                        ),
                      ),
                    ),
                    if (!current.isSyntheticPrimary) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (!isActive)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Btn.text(
                                  'Set Active',
                                  variant: BtnVariant.glass,
                                  onTap: () {
                                    ref
                                        .read(userProvider.notifier)
                                        .setActiveCard(current.raw.id);
                                    showToast(
                                      context,
                                      '${current.ui.name} set as active card',
                                    );
                                  },
                                ),
                              ),
                            ),
                          Expanded(
                            child: Btn(
                              variant: BtnVariant.danger,
                              onTap: () async {
                                final id = current.raw.id;
                                final name = current.ui.name;
                                ref.read(userProvider.notifier).deleteCard(id);
                                await _removeMeta(id);
                                if (!context.mounted) return;
                                setState(() {
                                  _idx = (_idx - 1).clamp(0, math.max(0, cards.length - 2));
                                  _flip = false;
                                });
                                showToast(context, '$name removed');
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.trash2, size: 15),
                                  SizedBox(width: 6),
                                  Text('Delete Card'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ── Add Card or Pass Button ──────────────────────────────────
            Btn(
              width: double.infinity,
              onTap: () => _openAddCardSheet(user),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 18),
                  SizedBox(width: 8),
                  Text('Add Card or Pass'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small Controls ──────────────────────────────────────────────────────────

class _RoundDockBtn extends StatelessWidget {
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;
  const _RoundDockBtn({
    required this.icon,
    this.primary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: .92,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: primary ? T.btnLiquidGradient : null,
          color: primary ? null : T.glassPillFill,
          border: Border.all(
            color: primary ? T.white(.4) : T.glassPillBorder,
            width: .5,
          ),
          boxShadow: primary ? T.btnShadow : null,
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

class _DockAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DockAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressScale(
        scale: .92,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? T.op(T.cyan400, .25) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? T.op(T.cyan300, .4) : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? T.cyan200 : T.white(.75),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.text(
                  10.5,
                  w: T.w600,
                  color: active ? T.cyan200 : T.white(.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelemetryRow extends StatelessWidget {
  final String k;
  final Widget v;
  const _TelemetryRow({required this.k, required this.v});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: T.text(12, color: T.white(.5))),
        const SizedBox(width: 12),
        Flexible(child: v),
      ],
    );
  }
}

// ── Back Card Face (1:1 CardsScreen.tsx) ────────────────────────────────────

class _CardBackFace extends StatefulWidget {
  final _ResolvedCard resolved;
  final String uid;
  final int tokenTick;
  final VoidCallback onCopyUid;

  const _CardBackFace({
    required this.resolved,
    required this.uid,
    required this.tokenTick,
    required this.onCopyUid,
  });

  @override
  State<_CardBackFace> createState() => _CardBackFaceState();
}

class _CardBackFaceState extends State<_CardBackFace> {
  int _cvvSecs = 0;
  Timer? _cvvTimer;

  @override
  void dispose() {
    _cvvTimer?.cancel();
    super.dispose();
  }

  void _revealCvv() {
    _cvvTimer?.cancel();
    setState(() => _cvvSecs = 10);
    _cvvTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cvvSecs <= 1) {
        t.cancel();
        setState(() => _cvvSecs = 0);
      } else {
        setState(() => _cvvSecs--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.resolved.ui;
    final m = ui_card.kMaterials[c.material] ?? ui_card.kMaterials['obsidian']!;

    if (c.kind == 'pass') {
      final isQr = (c.format ?? 'qr') == 'qr';
      return AspectRatio(
        aspectRatio: ui_card.kCardAspect,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(T.rCard),
            border: Border.all(color: T.white(.2)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: isQr ? 96 : 184,
                height: isQr ? 96 : 62,
                child: ui_card.CodeMark(qr: isQr, value: c.code ?? c.num),
              ),
              const SizedBox(height: 6),
              Text(
                c.code ?? c.num,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.mono(10.5, color: T.slate900),
              ),
              Text(
                'Show at the scanner',
                style: T.text(9, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    if (c.kind == 'bank') {
      final acctTail = (widget.resolved.acct ?? widget.resolved.raw.cardNumber)
          .replaceAll(RegExp(r'\s+'), '');
      final last4 = acctTail.length >= 4
          ? acctTail.substring(acctTail.length - 4)
          : acctTail;
      return AspectRatio(
        aspectRatio: ui_card.kCardAspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(T.rCard),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: m.base),
              for (final g in m.layers.reversed)
                DecoratedBox(decoration: BoxDecoration(gradient: g)),
              ColoredBox(color: T.blk(.45)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BANK', style: T.mono(8, color: T.white(.5))),
                    Text(c.bank ?? c.name, style: T.mono(11)),
                    const SizedBox(height: 8),
                    Text('ACCOUNT NO.', style: T.mono(8, color: T.white(.5))),
                    Text('•••• •••• $last4', style: T.mono(11)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EXPIRES', style: T.mono(8, color: T.white(.5))),
                            Text(
                              widget.resolved.raw.expiry.isNotEmpty
                                  ? widget.resolved.raw.expiry
                                  : '12/28',
                              style: T.mono(11),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CVV', style: T.mono(8, color: T.white(.5))),
                            Text('•••', style: T.mono(11)),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Secured by JCOP4 · double-tap to flip',
                      style: T.text(9, color: T.cyan200),
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(T.rCard),
                  border: Border.all(color: T.white(.2)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final cvvValue = widget.resolved.raw.cvv.isNotEmpty
        ? widget.resolved.raw.cvv
        : '428';
    final macHex = (0x8F2A + widget.tokenTick).toRadixString(16).toUpperCase();

    return AspectRatio(
      aspectRatio: ui_card.kCardAspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(T.rCard),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: m.base),
            for (final g in m.layers.reversed)
              DecoratedBox(decoration: BoxDecoration(gradient: g)),
            ColoredBox(color: T.blk(.45)),
            Column(
              children: [
                const SizedBox(height: 14),
                Container(height: 30, color: T.blk(.82)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _revealCvv,
                                child: Container(
                                  height: 30,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .92),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _cvvSecs > 0
                                            ? 'CVV $cvvValue'
                                            : 'Tap to reveal 10s',
                                        style: T.mono(10.5, color: T.slate900),
                                      ),
                                      Text(
                                        _cvvSecs > 0 ? '${_cvvSecs}s' : '•••',
                                        style: T.mono(
                                          10.5,
                                          w: T.w700,
                                          color: const Color(0xFF0E7490),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'HARDWARE UID',
                                style: T.mono(7.5, color: T.white(.5)),
                              ),
                              GestureDetector(
                                onTap: widget.onCopyUid,
                                child: Text(
                                  widget.uid.length > 20
                                      ? '${widget.uid.substring(0, 20)}…'
                                      : widget.uid,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: T.mono(9.5),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'APPLET AID',
                                style: T.mono(7.5, color: T.white(.5)),
                              ),
                              Text(
                                'F07461706174616E0101',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.mono(9.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: GridView.builder(
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  crossAxisSpacing: 1,
                                  mainAxisSpacing: 1,
                                ),
                                itemCount: 49,
                                itemBuilder: (_, i) {
                                  final on = ((i * 7 +
                                              widget.tokenTick * 13 +
                                              (i % 5) * widget.tokenTick) %
                                          3) ==
                                      0;
                                  return DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: on ? T.slate900 : Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'TM•$macHex•9000',
                              style: T.mono(7.5, color: T.cyan200),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(T.rCard),
                border: Border.all(color: T.white(.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 3-Layer X-Ray Hardware Inspection View ──────────────────────────────────

class _XRayExplodedCard extends StatelessWidget {
  final AnimationController traceAnim;
  final int pinRetriesLeft;
  final bool armed;

  const _XRayExplodedCard({
    required this.traceAnim,
    required this.pinRetriesLeft,
    required this.armed,
  });

  Widget _angledLayer(double dy, Widget child) {
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0014)
      ..rotateX(52 * math.pi / 180)
      ..rotateZ(-26 * math.pi / 180)
      ..scaleByDouble(0.84, 0.84, 1.0, 1.0);
    return Transform.translate(
      offset: Offset(0, dy),
      child: Transform(
        alignment: Alignment.center,
        transform: m,
        child: AspectRatio(
          aspectRatio: ui_card.kCardAspect,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Bottom Layer: Silicon Die (NXP J3R150 DIE)
        _angledLayer(
          46,
          Container(
            decoration: BoxDecoration(
              color: const Color(0xCC06141F),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: T.op(T.cyan300, .5)),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 118,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: T.op(T.cyan400, .12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: T.cyan300),
                boxShadow: T.glow(T.op(T.cyan400, .4), 24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NXP J3R150 DIE', style: T.mono(9, w: T.w700)),
                  Text(
                    'TapatMFAApplet',
                    style: T.mono(8, color: T.cyan200),
                  ),
                  Text('EEPROM ● OK', style: T.mono(8, color: T.cyan200)),
                  Text(
                    'PIN ${pinRetriesLeft < 0 ? 5 : pinRetriesLeft}/5 tries',
                    style: T.mono(8, color: T.cyan200),
                  ),
                  Text(
                    'TMAC tape: ${armed ? 'armed' : 'idle'}',
                    style: T.mono(8, color: T.cyan200),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Middle Layer: Copper ISO 14443-4 Coil + Animated Trace
        _angledLayer(
          0,
          Container(
            decoration: BoxDecoration(
              color: T.op(T.amber500, .06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: T.op(T.amber300, .5)),
            ),
            padding: const EdgeInsets.all(8),
            child: AnimatedBuilder(
              animation: traceAnim,
              builder: (_, _) => CustomPaint(
                painter: _AntennaPainter(traceAnim.value),
              ),
            ),
          ),
        ),

        // Top Layer: Polycarbonate + Hologram
        _angledLayer(
          -46,
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: T.white(.35)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x33FFFFFF),
                  Color(0x1A67E8F9),
                ],
              ),
            ),
            padding: const EdgeInsets.all(12),
            alignment: Alignment.topLeft,
            child: Text(
              'tap@tan · polycarbonate + hologram',
              style: T.text(11, w: T.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _AntennaPainter extends CustomPainter {
  final double progress;
  _AntennaPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = T.amber500
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 0; i < 4; i++) {
      final inset = 4.0 + i * 7.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - inset * 2,
            size.height - inset * 2,
          ),
          const Radius.circular(8),
        ),
        gold,
      );
    }

    // Traveling cyan APDU packet pulse around outermost loop
    final outer = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
          const Radius.circular(8),
        ),
      );
    for (final metric in outer.computeMetrics()) {
      final start = progress * metric.length;
      final seg = metric.length * 0.14;
      final end = start + seg;
      final pulsePaint = Paint()
        ..color = T.cyan400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;

      if (end <= metric.length) {
        canvas.drawPath(metric.extractPath(start, end), pulsePaint);
      } else {
        canvas.drawPath(metric.extractPath(start, metric.length), pulsePaint);
        canvas.drawPath(metric.extractPath(0, end - metric.length), pulsePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_AntennaPainter old) => old.progress != progress;
}

// ── 4-Step Add Card Studio Sheet (1:1 AddCard.tsx) ──────────────────────────

class _AddCardStudio extends StatefulWidget {
  final String defaultHolder;
  final Future<void> Function(CardData card, _CardMeta meta) onAddCard;

  const _AddCardStudio({
    required this.defaultHolder,
    required this.onAddCard,
  });

  @override
  State<_AddCardStudio> createState() => _AddCardStudioState();
}

class _AddCardStudioState extends State<_AddCardStudio> {
  int _step = 0; // 0 type, 1 details, 2 review, 3 done
  String _kind = 'bank'; // bank | virtual | qr | barcode
  String _material = 'cyber';
  String _network = 'Visa Tokenized';
  double _limit = 3000;

  late final _nameCtrl = TextEditingController();
  late final _codeCtrl = TextEditingController();
  late final _bankCtrl = TextEditingController();
  late final _acctCtrl = TextEditingController();
  late final _numCtrl = TextEditingController();
  late final _expCtrl = TextEditingController();
  late final _cvvCtrl = TextEditingController();
  late final _pinCtrl = TextEditingController();
  late final _holderCtrl = TextEditingController(text: widget.defaultHolder);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _bankCtrl.dispose();
    _acctCtrl.dispose();
    _numCtrl.dispose();
    _expCtrl.dispose();
    _cvvCtrl.dispose();
    _pinCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  bool get _isPass => _kind == 'qr' || _kind == 'barcode';

  bool get _isValid {
    if (_kind == 'bank') {
      final digits = _numCtrl.text.replaceAll(RegExp(r'\D'), '');
      final expOk = RegExp(r'^\d\d/\d\d$').hasMatch(_expCtrl.text.trim());
      return _bankCtrl.text.trim().isNotEmpty &&
          _acctCtrl.text.trim().length >= 8 &&
          digits.length == 16 &&
          expOk &&
          _cvvCtrl.text.trim().length >= 3 &&
          _pinCtrl.text.trim().length == 4 &&
          _holderCtrl.text.trim().isNotEmpty;
    }
    if (_isPass) {
      return _nameCtrl.text.trim().isNotEmpty && _codeCtrl.text.trim().length >= 4;
    }
    return _nameCtrl.text.trim().isNotEmpty && _holderCtrl.text.trim().isNotEmpty;
  }

  ui_card.CardData get _previewCard {
    final digits = _numCtrl.text.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : '0000';
    final prefix4 = digits.length >= 4 ? digits.substring(0, 4) : '0000';

    if (_isPass) {
      return ui_card.CardData(
        id: 'preview',
        name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'New pass',
        material: 'cyber',
        network: '',
        num: _codeCtrl.text.trim(),
        kind: 'pass',
        format: _kind,
        code: _codeCtrl.text.trim().isNotEmpty ? _codeCtrl.text.trim() : '000000',
      );
    }
    if (_kind == 'bank') {
      return ui_card.CardData(
        id: 'preview',
        name: _bankCtrl.text.trim().isNotEmpty ? '${_bankCtrl.text.trim()} ATM' : 'Bank card',
        material: 'indigo',
        network: 'Debit',
        num: '$prefix4 •••• •••• $last4',
        kind: 'bank',
        bank: _bankCtrl.text.trim(),
      );
    }
    return ui_card.CardData(
      id: 'preview',
      name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Virtual card',
      material: _material,
      network: _network,
      num: '4000 •••• •••• 0000',
      kind: 'virtual',
    );
  }

  List<(String, String)> get _reviewRows {
    final digits = _numCtrl.text.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : '0000';
    final acct = _acctCtrl.text.trim();
    final acctLast4 = acct.length >= 4 ? acct.substring(acct.length - 4) : acct;

    if (_isPass) {
      return [
        ('Type', _kind == 'qr' ? 'QR pass' : 'Barcode pass'),
        ('Name', _nameCtrl.text.trim()),
        ('Code', _codeCtrl.text.trim()),
      ];
    }
    if (_kind == 'bank') {
      return [
        ('Bank', _bankCtrl.text.trim()),
        ('Account no.', '•••• $acctLast4'),
        ('Card', '•••• $last4'),
        ('Expires', _expCtrl.text.trim()),
        ('Holder', _holderCtrl.text.trim().toUpperCase()),
        ('PIN', '•••• (stored on secure element)'),
      ];
    }
    return [
      ('Network', _network),
      ('Limit', '₱${_limit.toStringAsFixed(0)}'),
      ('Nickname', _nameCtrl.text.trim()),
      ('Holder', _holderCtrl.text.trim().toUpperCase()),
    ];
  }

  Future<void> _confirmDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: T.blk(.65),
      builder: (dCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Glass(
          kind: GlassKind.strong,
          radius: 28,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: T.op(T.cyan400, .15),
                ),
                child: const Icon(LucideIcons.shieldCheck, color: T.cyan300, size: 24),
              ),
              const SizedBox(height: 10),
              Text('Add this card?', style: T.text(17, w: T.w800)),
              const SizedBox(height: 4),
              Text(
                '${_previewCard.name} will be linked to your wallet and your hardware key.',
                textAlign: TextAlign.center,
                style: T.text(12.5, color: T.white(.55)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Btn.text(
                      'Cancel',
                      variant: BtnVariant.glass,
                      onTap: () => Navigator.pop(dCtx, false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Btn.text(
                      'Confirm',
                      onTap: () => Navigator.pop(dCtx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final rnd = math.Random();
    final digits = _numCtrl.text.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : '${1000 + rnd.nextInt(8999)}';
    final prefix4 = digits.length >= 4
        ? digits.substring(0, 4)
        : (_network.contains('Master') ? '5412' : '4${100 + rnd.nextInt(899)}');
    final maskedNum = _isPass
        ? _codeCtrl.text.trim()
        : '$prefix4 •••• •••• $last4';

    final cardId = 'card-${DateTime.now().millisecondsSinceEpoch}';
    final cardMat = _kind == 'bank'
        ? 'indigo'
        : _isPass
            ? 'cyber'
            : _material;
    final matColors = ui_card.kMaterials[cardMat]?.base ?? T.cyan600;

    final newCard = CardData(
      id: cardId,
      provider: _previewCard.name,
      cardNumber: maskedNum,
      holderName: _holderCtrl.text.trim().isNotEmpty
          ? _holderCtrl.text.trim().toUpperCase()
          : widget.defaultHolder,
      expiry: _expCtrl.text.trim().isNotEmpty ? _expCtrl.text.trim() : '12/29',
      cvv: _cvvCtrl.text.trim().isNotEmpty
          ? _cvvCtrl.text.trim()
          : '${100 + rnd.nextInt(899)}',
      type: _isPass
          ? _kind
          : _kind == 'bank'
              ? 'bank'
              : (_network.contains('Master') ? 'mastercard' : 'visa'),
      colors: [matColors, T.cyan600],
      balance: 0,
    );

    final meta = _CardMeta(
      kind: _isPass ? 'pass' : _kind,
      material: cardMat,
      format: _isPass ? _kind : null,
      code: _isPass ? _codeCtrl.text.trim() : null,
      bank: _kind == 'bank' ? _bankCtrl.text.trim() : null,
      acct: _kind == 'bank' ? _acctCtrl.text.trim() : null,
      limit: _limit,
    );

    await widget.onAddCard(newCard, meta);
    if (mounted) {
      setState(() => _step = 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final holder = _holderCtrl.text.trim().isNotEmpty
        ? _holderCtrl.text.trim().toUpperCase()
        : widget.defaultHolder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_step < 3) ...[
          Row(
            children: [
              if (_step > 0)
                GestureDetector(
                  onTap: () => setState(() => _step--),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      '‹ Back',
                      style: T.text(12, w: T.w700, color: T.cyan300),
                    ),
                  ),
                ),
              for (var n = 0; n < 3; n++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    margin: EdgeInsets.only(right: n == 2 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: n <= _step ? T.cyan300 : T.white(.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        if (_step == 0) ...[
          Text('What do you want to add?', style: T.text(12.5, color: T.white(.55))),
          const SizedBox(height: 10),
          for (final item in [
            (
              'bank',
              LucideIcons.database,
              'Bank / ATM card',
              'Full account: card number, expiry, account no. and PIN.',
              'Full details'
            ),
            (
              'virtual',
              LucideIcons.sparkles,
              '3D virtual card',
              'Mint a tokenized Visa or Mastercard with a spending limit.',
              'Instant'
            ),
            (
              'qr',
              LucideIcons.qrCode,
              'QR pass',
              'Store a ticket, membership or ID that scans as a QR.',
              'Pass only'
            ),
            (
              'barcode',
              LucideIcons.scanLine,
              'Barcode pass',
              'Loyalty, library or store cards that scan as a barcode.',
              'Pass only'
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PressScale(
                scale: .98,
                onTap: () => setState(() {
                  _kind = item.$1;
                  _step = 1;
                }),
                child: Glass(
                  radius: 22,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: T.op(T.cyan400, .15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(item.$2, color: T.cyan300, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.$3,
                                    style: T.text(14, w: T.w700),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: T.white(.1),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    item.$5,
                                    style: T.text(9, color: T.white(.6)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.$4,
                              style: T.text(
                                11.5,
                                color: T.white(.5),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, size: 16, color: T.white(.3)),
                    ],
                  ),
                ),
              ),
            ),
        ],

        if (_step == 1) ...[
          Center(
            child: SizedBox(
              width: 260,
              child: ui_card.CardFace(
                card: _previewCard,
                holder: holder,
                small: true,
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isPass) ...[
            Field(
              label: 'Pass name',
              controller: _nameCtrl,
              hint: _kind == 'qr' ? 'Concert ticket' : 'SM Advantage',
              onChanged: (_) => setState(() {}),
            ),
            Field(
              label: _kind == 'qr' ? 'QR content / link' : 'Barcode number',
              mono: true,
              controller: _codeCtrl,
              hint: _kind == 'qr' ? 'https://…' : '4800016644801',
              onChanged: (_) => setState(() {}),
            ),
            GestureDetector(
              onTap: () => setState(() {
                final rnd = math.Random();
                _codeCtrl.text = _kind == 'qr'
                    ? 'TAPAT-${100000 + rnd.nextInt(899999)}'
                    : '48000${10000000 + rnd.nextInt(89999999)}';
              }),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Scan from camera (demo fill)',
                  style: T.text(12, w: T.w600, color: T.cyan300),
                ),
              ),
            ),
          ],

          if (_kind == 'bank') ...[
            Field(
              label: 'Bank',
              controller: _bankCtrl,
              hint: 'BDO, BPI, Landbank…',
              onChanged: (_) => setState(() {}),
            ),
            Field(
              label: 'Account number',
              mono: true,
              controller: _acctCtrl,
              hint: '001234567890',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 14,
              onChanged: (_) => setState(() {}),
            ),
            Field(
              label: 'Card number',
              mono: true,
              controller: _numCtrl,
              hint: '0000 0000 0000 0000',
              keyboardType: TextInputType.number,
              maxLength: 19,
              onChanged: (v) {
                final clean = v.replaceAll(RegExp(r'\D'), '');
                final trimmed = clean.length > 16 ? clean.substring(0, 16) : clean;
                final buf = StringBuffer();
                for (var i = 0; i < trimmed.length; i++) {
                  if (i > 0 && i % 4 == 0) buf.write(' ');
                  buf.write(trimmed[i]);
                }
                final formatted = buf.toString();
                if (formatted != _numCtrl.text) {
                  _numCtrl.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
                setState(() {});
              },
            ),
            Row(
              children: [
                Expanded(
                  child: Field(
                    label: 'Expiry',
                    mono: true,
                    controller: _expCtrl,
                    hint: 'MM/YY',
                    maxLength: 5,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      var d = v.replaceAll(RegExp(r'\D'), '');
                      if (d.length > 4) d = d.substring(0, 4);
                      final out = d.length > 2
                          ? '${d.substring(0, 2)}/${d.substring(2)}'
                          : d;
                      if (out != _expCtrl.text) {
                        _expCtrl.value = TextEditingValue(
                          text: out,
                          selection: TextSelection.collapsed(offset: out.length),
                        );
                      }
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Field(
                    label: 'CVV',
                    mono: true,
                    obscure: true,
                    controller: _cvvCtrl,
                    maxLength: 3,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Field(
                    label: 'ATM PIN',
                    mono: true,
                    obscure: true,
                    controller: _pinCtrl,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            Field(
              label: 'Name on card',
              controller: _holderCtrl,
              onChanged: (v) {
                final up = v.toUpperCase();
                if (up != _holderCtrl.text) {
                  _holderCtrl.value = TextEditingValue(
                    text: up,
                    selection: TextSelection.collapsed(offset: up.length),
                  );
                }
                setState(() {});
              },
            ),
          ],

          if (_kind == 'virtual') ...[
            Text('Material', style: T.text(11, color: T.white(.5))),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final key in ['obsidian', 'cyber', 'chrome', 'emerald'])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: key == 'emerald' ? 0 : 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _material = key),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _material == key ? T.cyan300 : T.white(.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                height: 28,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: ui_card.kMaterials[key]!.base,
                                  gradient: ui_card.kMaterials[key]!.layers.last,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ui_card.kMaterials[key]!.label.split(' ').first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.text(10, color: T.white(.8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final net in ['Visa Tokenized', 'Mastercard Tokenized'])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: net.startsWith('Master') ? 0 : 8,
                      ),
                      child: GestureDetector(
                        onTap: () => setState(() => _network = net),
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _network == net
                                ? T.op(T.cyan400, .2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: _network == net
                                  ? T.op(T.cyan300, .6)
                                  : T.white(.1),
                            ),
                          ),
                          child: Text(
                            net.split(' ').first,
                            style: T.text(
                              12,
                              w: T.w600,
                              color: _network == net ? T.cyan200 : T.white(.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Spending limit: ', style: T.text(12, color: T.white(.6))),
                Text(
                  '₱${_limit.toStringAsFixed(0)}',
                  style: T.text(12, w: T.w700),
                ),
              ],
            ),
            Slider(
              value: _limit,
              min: 500,
              max: 20000,
              divisions: 39,
              activeColor: T.cyan400,
              inactiveColor: T.white(.15),
              onChanged: (v) => setState(() => _limit = v),
            ),
            Field(
              label: 'Nickname',
              controller: _nameCtrl,
              hint: 'Grocery card',
              onChanged: (_) => setState(() {}),
            ),
            Field(
              label: 'Cardholder name',
              controller: _holderCtrl,
              onChanged: (v) {
                final up = v.toUpperCase();
                if (up != _holderCtrl.text) {
                  _holderCtrl.value = TextEditingValue(
                    text: up,
                    selection: TextSelection.collapsed(offset: up.length),
                  );
                }
                setState(() {});
              },
            ),
          ],

          const SizedBox(height: 4),
          Btn.text(
            'Review',
            width: double.infinity,
            disabled: !_isValid,
            onTap: () => setState(() => _step = 2),
          ),
        ],

        if (_step == 2) ...[
          Center(
            child: SizedBox(
              width: 280,
              child: ui_card.CardFace(card: _previewCard, holder: holder, small: true),
            ),
          ),
          const SizedBox(height: 16),
          Glass(
            radius: 22,
            child: Column(
              children: [
                for (var i = 0; i < _reviewRows.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      border: i == _reviewRows.length - 1
                          ? null
                          : Border(bottom: BorderSide(color: T.white(.1))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _reviewRows[i].$1,
                          style: T.text(12.5, color: T.white(.5)),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _reviewRows[i].$2,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: T.text(12.5, w: T.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.lock, size: 14, color: T.cyan300),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _kind == 'bank'
                      ? 'Card number, CVV and PIN are encrypted and bound to your JCOP4 key. They never appear in plain text again.'
                      : 'Stored locally and encrypted on this device.',
                  style: T.text(11, color: T.white(.5), height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Btn.text(
            'Add to wallet',
            width: double.infinity,
            onTap: _confirmDialog,
          ),
        ],

        if (_step == 3) ...[
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: T.op(T.emerald400, .2),
                border: Border.all(color: T.op(T.emerald300, .5)),
                boxShadow: T.glow(T.op(T.emerald, .4), 36),
              ),
              child: const Icon(
                LucideIcons.check,
                size: 40,
                color: T.emerald300,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_previewCard.name} added',
            textAlign: TextAlign.center,
            style: T.text(22, w: T.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'It\'s ready in your Cards tab.',
            textAlign: TextAlign.center,
            style: T.text(13, color: T.white(.55)),
          ),
          const SizedBox(height: 24),
          Btn.text(
            'View card',
            width: double.infinity,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ],
    );
  }
}
