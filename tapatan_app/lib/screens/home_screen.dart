import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/user_provider.dart';
import '../ui/card_face.dart' as ui_card;
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import '../utils/lucide_icons.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onArmCard;
  final Function(String)? onOpenOverlay;
  final Function(String)? onNavigateTab;

  const HomeScreen({
    super.key,
    this.onArmCard,
    this.onOpenOverlay,
    this.onNavigateTab,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hideBalance = false;
  bool _cardHovered = false;
  String _filter = 'all'; // all | nfc | sare | cashin

  Timer? _armedTick;
  int _armedSecsLeft = 300;

  @override
  void initState() {
    super.initState();
    _armedTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final armed = ref.read(userProvider).cardArmed;
      if (armed) {
        if (_armedSecsLeft > 0) {
          setState(() => _armedSecsLeft--);
        }
      } else if (_armedSecsLeft != 300) {
        setState(() => _armedSecsLeft = 300);
      }
    });
  }

  @override
  void dispose() {
    _armedTick?.cancel();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _peso(double amount) {
    final abs = amount.abs().toStringAsFixed(2);
    final parts = abs.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return '${amount < 0 ? '-' : ''}₱$intPart.${parts[1]}';
  }

  String _mmss(int secs) {
    final s = secs.clamp(0, 3599);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  ui_card.CardData _toUiCard(CardData? card, String cardId) {
    if (card == null) {
      final tail = cardId.length >= 4
          ? cardId.substring(cardId.length - 4)
          : '8821';
      return ui_card.CardData(
        id: 'primary-jcop4',
        name: 'Tapat JCOP4',
        material: 'obsidian',
        network: 'ISO 14443-4',
        num: '4532 •••• •••• $tail',
        physical: true,
      );
    }
    final isPrimary =
        card.id == 'card-tapat-primary' || card.provider.contains('JCOP4');
    final mat = isPrimary
        ? 'obsidian'
        : card.type.toLowerCase() == 'mastercard'
            ? 'indigo'
            : 'cyber';
    return ui_card.CardData(
      id: card.id,
      name: card.provider,
      material: mat,
      network: isPrimary
          ? 'ISO 14443-4'
          : (card.type.toLowerCase() == 'mastercard'
              ? 'Mastercard Tokenized'
              : 'Visa Tokenized'),
      num: card.cardNumber,
      physical: isPrimary,
    );
  }

  // ── Modals (1:1 React Sheets) ─────────────────────────────────────────────

  void _openCashInSheet() {
    final ctrl = TextEditingController(text: '500');
    double amt = 500;
    showAppSheet(
      context,
      title: 'Cash In',
      child: StatefulBuilder(
        builder: (ctx, setModal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [100, 500, 1000, 5000].map((v) {
                final selected = amt == v.toDouble();
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: v == 5000 ? 0 : 8),
                    child: PressScale(
                      onTap: () => setModal(() {
                        amt = v.toDouble();
                        ctrl.text = v.toString();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? T.op(T.cyan400, .2) : T.white(.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? T.op(T.cyan300, .6) : T.white(.1),
                          ),
                        ),
                        child: Text(
                          '₱$v',
                          style: T.text(
                            13,
                            w: T.w700,
                            color: selected ? T.cyan200 : T.white(.75),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Field(
              label: 'Custom amount (₱)',
              mono: true,
              controller: ctrl,
              hint: '0.00',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) =>
                  setModal(() => amt = double.tryParse(v.trim()) ?? 0),
            ),
            const SizedBox(height: 6),
            Btn.text(
              'Confirm Cash In',
              width: double.infinity,
              disabled: amt <= 0,
              onTap: () {
                ref.read(userProvider.notifier).topUp(amt);
                Navigator.pop(ctx);
                showToast(context, '${_peso(amt)} added to wallet');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openSendSheet(UserState user) {
    final toCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    showAppSheet(
      context,
      title: 'Send Money · P2P',
      child: StatefulBuilder(
        builder: (ctx, setModal) {
          final n = double.tryParse(amtCtrl.text.trim()) ?? 0;
          final exceeds = n > user.balance;
          final canSend = toCtrl.text.trim().isNotEmpty && n > 0 && !exceeds;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Field(
                label: 'Recipient email or phone',
                controller: toCtrl,
                hint: 'juan@email.com',
                onChanged: (_) => setModal(() {}),
              ),
              Field(
                label: 'Amount (₱)',
                mono: true,
                controller: amtCtrl,
                hint: '0.00',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setModal(() {}),
              ),
              Field(
                label: 'Note',
                controller: noteCtrl,
                hint: 'Pamasahe / Sar-E split',
                onChanged: (_) => setModal(() {}),
              ),
              if (exceeds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Amount exceeds balance (${_peso(user.balance)})',
                    textAlign: TextAlign.center,
                    style: T.text(12, color: T.red400),
                  ),
                ),
              Btn.text(
                'Send via tap@tan',
                width: double.infinity,
                disabled: !canSend,
                onTap: () {
                  ref.read(userProvider.notifier).sendMoney(
                        n,
                        recipient: 'To ${toCtrl.text.trim()}',
                        type: 'send',
                      );
                  Navigator.pop(ctx);
                  showToast(context, 'Sent ${_peso(n)} via tap@tan');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _openQrSheet(UserState user) {
    int mode = 0; // 0 = Scan QR, 1 = My Receive QR
    showAppSheet(
      context,
      title: 'QR Pay & Receive',
      child: StatefulBuilder(
        builder: (ctx, setModal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Glass(
              kind: GlassKind.pill,
              radius: 16,
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  for (final entry in [(0, 'Scan Merchant QR'), (1, 'My Receive QR')])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModal(() => mode = entry.$1),
                        child: Container(
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: mode == entry.$1
                                ? T.white(.18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            entry.$2,
                            style: T.text(
                              12,
                              w: T.w700,
                              color:
                                  mode == entry.$1 ? Colors.white : T.white(.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (mode == 0) ...[
              Container(
                height: 230,
                decoration: BoxDecoration(
                  color: T.blk(.55),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: T.white(.12)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Corner markers
                    for (final align in [
                      Alignment.topLeft,
                      Alignment.topRight,
                      Alignment.bottomLeft,
                      Alignment.bottomRight,
                    ])
                      Align(
                        alignment: align,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              border: Border(
                                top: align.y < 0
                                    ? const BorderSide(
                                        color: T.cyan300, width: 2.5)
                                    : BorderSide.none,
                                bottom: align.y > 0
                                    ? const BorderSide(
                                        color: T.cyan300, width: 2.5)
                                    : BorderSide.none,
                                left: align.x < 0
                                    ? const BorderSide(
                                        color: T.cyan300, width: 2.5)
                                    : BorderSide.none,
                                right: align.x > 0
                                    ? const BorderSide(
                                        color: T.cyan300, width: 2.5)
                                    : BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Container(
                      width: 170,
                      height: 2,
                      decoration: BoxDecoration(
                        color: T.cyan300,
                        boxShadow: T.glow(T.cyan300, 12),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      child: Text(
                        'Align QR Ph / Merchant code inside frame',
                        style: T.text(11.5, color: T.white(.45)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Btn.text(
                'Simulate Merchant QR · Aling Nena\'s',
                variant: BtnVariant.glass,
                width: double.infinity,
                onTap: () {
                  Navigator.pop(ctx);
                  showToast(context, 'Merchant QR detected · Aling Nena\'s');
                },
              ),
            ] else ...[
              Center(
                child: Container(
                  width: 164,
                  height: 164,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ui_card.CodeMark(
                    qr: true,
                    value: user.email.isNotEmpty ? user.email : user.cardId,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Glass(
                radius: 18,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACCOUNT NAME',
                        style: T.mono(9.5, color: T.white(.45))),
                    const SizedBox(height: 2),
                    Text(
                      user.name.isNotEmpty ? user.name : 'Tapat Member',
                      style: T.text(15, w: T.w700),
                    ),
                    const SizedBox(height: 8),
                    Text('ACCOUNT EMAIL / ID',
                        style: T.mono(9.5, color: T.white(.45))),
                    const SizedBox(height: 2),
                    Text(
                      user.email.isNotEmpty ? user.email : user.cardId,
                      style: T.mono(12, color: T.cyan300),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openHistorySheet(UserState user) {
    showAppSheet(
      context,
      title: 'Transaction History (${user.transactions.length})',
      tall: true,
      child: user.transactions.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(LucideIcons.activity, size: 40, color: T.white(.25)),
                  const SizedBox(height: 8),
                  Text('No transactions yet',
                      style: T.text(13, color: T.white(.5))),
                ],
              ),
            )
          : Glass(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < user.transactions.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: T.white(.08)),
                    _buildTxRow(user.transactions[i], i),
                  ],
                ],
              ),
            ),
    );
  }

  List<TransactionData> _filteredTransactions(UserState user) {
    return user.transactions.where((t) {
      switch (_filter) {
        case 'nfc':
          return t.type == 'nfc';
        case 'sare':
          return t.name.toLowerCase().contains('sar-e') ||
              t.name.toLowerCase().contains('aling') ||
              t.type == 'send';
        case 'cashin':
          return t.amount > 0;
        default:
          return true;
      }
    }).toList();
  }

  String _formatCompact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final activeUiCard = _toUiCard(user.activeCard, user.cardId);
    final holderUpper = user.name.trim().isNotEmpty
        ? user.name.trim().toUpperCase()
        : 'TAPAT MEMBER';
    final firstName = user.name.trim().isNotEmpty
        ? user.name.trim().split(RegExp(r'\s+')).first
        : 'Member';
    final initials = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
    final filteredList = _filteredTransactions(user);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, T.navBottomPad),
      children: [
        // ── 1. Top Greeting + Notification + Avatar ────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(), style: T.text(12, color: T.white(.55))),
                Text(firstName, style: T.text(21, w: T.w800)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: T.op(T.emerald400, .15),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: T.op(T.emerald300, .35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.badgeCheck,
                          size: 12, color: T.emerald300),
                      const SizedBox(width: 4),
                      Text(
                        'KYC Verified',
                        style: T.text(10, w: T.w600, color: T.emerald300),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                PressScale(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showToast(
                      context,
                      user.sarePendingOrder != null
                          ? 'Pending Sar-E request: ${_peso(user.sarePendingOrder!.totalAmount)}'
                          : 'No security alerts · 0 rejected MACs',
                    );
                  },
                  child: Stack(
                    children: [
                      Glass(
                        kind: GlassKind.pill,
                        width: 40,
                        height: 40,
                        child: const Icon(LucideIcons.bell,
                            size: 18, color: Colors.white),
                      ),
                      Positioned(
                        top: 8,
                        right: 9,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: T.red400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PressScale(
                  onTap: () => widget.onNavigateTab?.call('profile'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: T.btnLiquidGradient,
                      boxShadow: T.btnShadow,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials.isEmpty ? 'U' : initials,
                      style: T.text(13, w: T.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── 2. Hero Card Tile + Wallet Balance + Arm CTA ───────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: T.glassGradient,
            border: Border.all(
              color: user.cardArmed
                  ? T.op(T.emerald300, .75)
                  : T.glassBorder,
              width: user.cardArmed ? 1.0 : 0.6,
            ),
            boxShadow: user.cardArmed
                ? [
                    BoxShadow(
                        color: T.op(T.emerald, .32),
                        blurRadius: 36,
                        spreadRadius: 1),
                  ]
                : T.glassShadow,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTapDown: (_) => setState(() => _cardHovered = true),
                onTapUp: (_) {
                  setState(() => _cardHovered = false);
                  widget.onNavigateTab?.call('cards');
                },
                onTapCancel: () => setState(() => _cardHovered = false),
                child: TweenAnimationBuilder<Offset>(
                  tween: Tween(
                    begin: const Offset(5, -6),
                    end: _cardHovered ? Offset.zero : const Offset(5, -6),
                  ),
                  duration: const Duration(milliseconds: 220),
                  builder: (_, v, child) {
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 1 / 1000)
                        ..rotateX(v.dx * math.pi / 180)
                        ..rotateY(v.dy * math.pi / 180),
                      child: child,
                    );
                  },
                  child: ui_card.CardFace(
                    card: activeUiCard,
                    holder: holderUpper,
                    tiltX: _cardHovered ? 0.15 : -0.2,
                    tiltY: 0.1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wallet balance',
                            style: T.text(11, color: T.white(.50))),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            _hideBalance ? '₱ ••••••' : _peso(user.balance),
                            key: ValueKey(_hideBalance),
                            style: T.text(28, w: T.w800, height: 1.05),
                          ),
                        ),
                      ],
                    ),
                    GlassIconBtn(
                      icon:
                          _hideBalance ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 36,
                      iconSize: 16,
                      onTap: () =>
                          setState(() => _hideBalance = !_hideBalance),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Row(
                  children: [
                    const Icon(LucideIcons.trendingUp,
                        size: 12, color: T.emerald300),
                    const SizedBox(width: 4),
                    Text(
                      'In +₱${_formatCompact(user.totalIncome)}',
                      style: T.text(11, w: T.w600, color: T.emerald300),
                    ),
                    const SizedBox(width: 14),
                    const Icon(LucideIcons.arrowUpRight,
                        size: 12, color: T.red400),
                    const SizedBox(width: 4),
                    Text(
                      'Out ₱${_formatCompact(user.totalExpenses)}',
                      style: T.text(11, w: T.w600, color: T.red400),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: !user.cardArmed
                    ? Btn(
                        width: double.infinity,
                        onTap: widget.onArmCard,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(LucideIcons.nfc, size: 17),
                            SizedBox(width: 8),
                            Text('Arm Card for NFC Payment'),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: T.op(T.amber500, .15),
                              borderRadius: BorderRadius.circular(99),
                              border:
                                  Border.all(color: T.op(T.amber300, .4)),
                            ),
                            child: Text(
                              _mmss(_armedSecsLeft),
                              style: T.mono(12, color: T.amber300),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Btn.text(
                              'Tap to Pay Now',
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              onTap: () => widget.onOpenOverlay?.call('nfc'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Btn.text(
                            'Disarm',
                            variant: BtnVariant.glass,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            onTap: () {
                              ref
                                  .read(userProvider.notifier)
                                  .completeTransaction();
                              showToast(context, 'Card disarmed');
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 3. Quick Actions Row ───────────────────────────────────────────
        Row(
          children: [
            _quickTile(LucideIcons.banknote, 'Cash In', _openCashInSheet),
            const SizedBox(width: 10),
            _quickTile(
                LucideIcons.send, 'Send / P2P', () => _openSendSheet(user)),
            const SizedBox(width: 10),
            _quickTile(LucideIcons.nfc, 'Tap to Pay',
                () => widget.onOpenOverlay?.call('nfc')),
            const SizedBox(width: 10),
            _quickTile(
                LucideIcons.scanLine, 'Scan QR', () => _openQrSheet(user)),
          ],
        ),

        // ── 4. Pending Sar-E Payment Banner ────────────────────────────────
        if (user.sarePendingOrder != null) ...[
          const SizedBox(height: 16),
          Glass(
            kind: GlassKind.tint,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.shoppingBasket,
                        color: T.cyan200, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pending Sar-E order · ${user.sarePendingOrder!.merchant}',
                            style: T.text(11, color: T.white(.60)),
                          ),
                          Text(
                            _peso(user.sarePendingOrder!.totalAmount),
                            style: T.text(18, w: T.w800),
                          ),
                        ],
                      ),
                    ),
                    Btn.text(
                      'Pay with Card',
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      onTap: () => widget.onOpenOverlay?.call('nfc'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: LinkText(
                    'Decline pending order',
                    onTap: () =>
                        ref.read(userProvider.notifier).clearSarEOrder(),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 22),

        // ── 5. Recent Activity + Filter Pills ──────────────────────────────
        SectionHeader(
          'Recent activity',
          trailing: PressScale(
            onTap: () => _openHistorySheet(user),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('See all', style: T.text(12, w: T.w600, color: T.cyan300)),
                Icon(LucideIcons.chevronRight, size: 14, color: T.cyan300),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in [
                ('all', 'All'),
                ('nfc', 'NFC Tap'),
                ('sare', 'Sar-E / P2P'),
                ('cashin', 'Cash In'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PressScale(
                    onTap: () => setState(() => _filter = f.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _filter == f.$1
                            ? T.op(T.cyan400, .20)
                            : T.white(.05),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: _filter == f.$1
                              ? T.op(T.cyan300, .60)
                              : T.white(.10),
                        ),
                      ),
                      child: Text(
                        f.$2,
                        style: T.text(
                          12,
                          w: T.w600,
                          color:
                              _filter == f.$1 ? T.cyan200 : T.white(.60),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Glass(
          padding: EdgeInsets.zero,
          child: filteredList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  child: Center(
                    child: Text(
                      'No transactions yet',
                      style: T.text(12.5, color: T.white(.45)),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < math.min(filteredList.length, 6); i++) ...[
                      if (i > 0) Divider(height: 1, color: T.white(.10)),
                      _buildTxRow(filteredList[i], i),
                    ],
                  ],
                ),
        ),

        const SizedBox(height: 16),

        // ── 6. Sar-E Store Promo Tile ──────────────────────────────────────
        PressScale(
          onTap: () => widget.onNavigateTab?.call('sare'),
          child: Glass(
            kind: GlassKind.tint,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: T.op(T.cyan500, .20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      const Icon(LucideIcons.store, color: T.cyan300, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shop on Sar-E Store', style: T.text(13.5, w: T.w700)),
                      Text(
                        'Sari-sari catalog with 1-tap Turing card checkout',
                        style: T.text(11, color: T.white(.50)),
                      ),
                    ],
                  ),
                ),
                Badge2(
                  'OPEN',
                  color: T.cyan400,
                  textColor: T.cyan200,
                  fontSize: 9.5,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickTile(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: PressScale(
        scale: 0.93,
        onTap: onTap,
        child: Glass(
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: T.cyan300),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.text(10.5, w: T.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTxRow(TransactionData tx, int idx) {
    final isIn = tx.amount > 0;
    final macSuffix = ((0x8F2A + idx * 37) & 0xFFFF)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(4, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isIn ? T.op(T.emerald400, .15) : T.white(.10),
            ),
            child: Icon(
              tx.type == 'nfc'
                  ? LucideIcons.wifi
                  : (isIn ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight),
              size: 16,
              color: isIn ? T.emerald300 : T.white(.85),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.text(13, w: T.w600),
                ),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: '${tx.time} ',
                      style: T.text(11, color: T.white(.45)),
                    ),
                    TextSpan(
                      text: 'TM•$macSuffix',
                      style: T.mono(10.5, color: T.op(T.cyan300, .80)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          Text(
            '${isIn ? '+' : ''}${_peso(tx.amount)}',
            style: T.text(
              13,
              w: T.w700,
              color: isIn ? T.emerald300 : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
