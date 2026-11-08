import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/lucide_icons.dart';
import '../providers/user_provider.dart';
import '../services/nfc_service.dart';

// ── Virtual Cards Screen ──────────────────────────────────────────────────

class VirtualCardsScreen extends ConsumerStatefulWidget {
  const VirtualCardsScreen({super.key});

  @override
  ConsumerState<VirtualCardsScreen> createState() => _VirtualCardsScreenState();
}

class _VirtualCardsScreenState extends ConsumerState<VirtualCardsScreen> {
  bool _showAddCard = false;
  bool _isReadingCard = false;
  String _readCardStatus = '';
  int _mockSigCounter = 42;

  // Add card form
  final _providerCtrl = TextEditingController();
  final _cardNoCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  String _cardType = 'visa';

  static const _teal = Color(0xFF06B6D4);
  static const _green = Color(0xFF34D399);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFF87171);

  @override
  void dispose() {
    _providerCtrl.dispose();
    _cardNoCtrl.dispose();
    _nameCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  void _addCard() {
    if (_providerCtrl.text.isEmpty || _cardNoCtrl.text.isEmpty) return;
    final card = CardData(
      id: 'card-${DateTime.now().millisecondsSinceEpoch}',
      provider: _providerCtrl.text,
      cardNumber: _cardNoCtrl.text,
      holderName: _nameCtrl.text,
      expiry: _expiryCtrl.text,
      cvv: _cvvCtrl.text,
      type: _cardType,
      colors: _cardType == 'visa'
          ? [const Color(0xFF1E3A5F), const Color(0xFF0369A1)]
          : [const Color(0xFF3B0764), const Color(0xFF7C3AED)],
      balance: 0.0,
    );
    ref.read(userProvider.notifier).addVirtualCard(card);
    setState(() => _showAddCard = false);
    _providerCtrl.clear();
    _cardNoCtrl.clear();
    _nameCtrl.clear();
    _expiryCtrl.clear();
    _cvvCtrl.clear();
  }

  Future<void> _tapToReadCard() async {
    if (_isReadingCard) return;
    final user = ref.read(userProvider);
    setState(() {
      _isReadingCard = true;
      _readCardStatus = 'Hold your Tapat JCOP4 Card steady against the phone…';
    });

    final targetCardId =
        user.cardId.isNotEmpty ? user.cardId : NfcService.generateCardId();

    // Provision / sync this signed-in account's real identity onto the card
    // and read its hardware UID in one Turing-authenticated tap!
    final result = await NfcService.writeCardIdentity(
      targetCardId,
      user.email,
      name: user.name,
    );
    if (!mounted) return;

    if (result['success'] == true) {
      final uid = (result['uid'] as String?) ?? '';
      ref.read(userProvider.notifier).updateJcopCardInfo(
            uid: uid,
            pinRetriesLeft: 5,
            lifecycleState: 'ENROLLED',
          );
      setState(() {
        _isReadingCard = false;
        _readCardStatus =
            'Bound to ${user.name} · JCOP4 UID: ${uid.isNotEmpty ? uid : "Verified"}';
        _mockSigCounter++;
      });
    } else {
      setState(() {
        _isReadingCard = false;
        _readCardStatus =
            (result['error'] as String?) ?? 'Failed to read Tapat JCOP4 card.';
      });
    }
  }

  String _lifecycleLabel(String state) {
    switch (state) {
      case 'op_ready': return 'PERSONALIZED';
      case 'secured': return 'PIN_SET';
      case 'ENROLLED': return 'ENROLLED';
      case 'locked': return 'PIN_BLOCKED';
      case 'terminated': return 'TERMINATED';
      default: return 'UNKNOWN';
    }
  }

  Color _lifecycleColor(String state) {
    switch (state) {
      case 'op_ready': return _teal;
      case 'secured': return _amber;
      case 'ENROLLED': return _green;
      case 'locked': return _red;
      case 'terminated': return _red;
      default: return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final cards = user.virtualCards;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cards', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => setState(() => _showAddCard = !_showAddCard),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0891B2)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_showAddCard ? LucideIcons.x : LucideIcons.plus, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Add card form ─────────────────────────────────────
                if (_showAddCard) ...[
                  _AddCardForm(
                    providerCtrl: _providerCtrl,
                    cardNoCtrl: _cardNoCtrl,
                    nameCtrl: _nameCtrl,
                    expiryCtrl: _expiryCtrl,
                    cvvCtrl: _cvvCtrl,
                    cardType: _cardType,
                    onCardTypeChanged: (t) => setState(() => _cardType = t),
                    onAdd: _addCard,
                    onCancel: () => setState(() => _showAddCard = false),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Virtual cards carousel ────────────────────────────
                if (cards.isEmpty && !_showAddCard) ...[
                  _EmptyCardsPlaceholder(onAdd: () => setState(() => _showAddCard = true)),
                  const SizedBox(height: 24),
                ] else ...[
                  ...cards.map((card) => _CardTile(
                    card: card,
                    isActive: card.id == user.activeCardId,
                    onSetActive: () => ref.read(userProvider.notifier).setActiveCard(card.id),
                    onDelete: () => ref.read(userProvider.notifier).deleteCard(card.id),
                  )),
                  const SizedBox(height: 24),
                ],

                // ── Tapat Card hardware section ───────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0369A1).withOpacity(0.25),
                        const Color(0xFF0891B2).withOpacity(0.15),
                        const Color(0xFF06B6D4).withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _teal.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF0369A1).withOpacity(0.2), blurRadius: 32, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: _teal.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _teal.withOpacity(0.3)),
                            ),
                            child: Icon(LucideIcons.creditCard, color: _teal, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tapat Card', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const Text('JCOP J3R150 · Hardware', style: TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                          const Spacer(),
                          // Lifecycle chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _lifecycleColor(user.cardLifecycleState).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _lifecycleColor(user.cardLifecycleState).withOpacity(0.4)),
                            ),
                            child: Text(
                              _lifecycleLabel(user.cardLifecycleState),
                              style: TextStyle(
                                color: _lifecycleColor(user.cardLifecycleState),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0x1AFFFFFF)),
                      const SizedBox(height: 16),

                      // Hardware stats grid
                      Row(
                        children: [
                          Expanded(
                            child: _HardwareStat(
                              label: 'Hardware UID',
                              value: user.jcopCardUid.isNotEmpty
                                  ? user.jcopCardUid.substring(0, user.jcopCardUid.length.clamp(0, 14))
                                  : 'Not read',
                              color: _teal,
                            ),
                          ),
                          Expanded(
                            child: _HardwareStat(
                              label: 'PIN Tries Left',
                              value: user.pinRetriesLeft == -1
                                  ? 'Unknown'
                                  : user.pinRetriesLeft == 0
                                      ? 'BLOCKED'
                                      : '${user.pinRetriesLeft} / 5',
                              color: user.pinRetriesLeft == 0 ? _red : _amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _HardwareStat(
                              label: 'Signature Counter',
                              value: '$_mockSigCounter',
                              color: _green,
                            ),
                          ),
                          Expanded(
                            child: _HardwareStat(
                              label: 'Card ID',
                              value: user.cardId.isNotEmpty
                                  ? user.cardId.substring(0, user.cardId.length.clamp(0, 18)) + '…'
                                  : 'Not registered',
                              color: _teal,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Tap to read button
                      GestureDetector(
                        onTap: _isReadingCard ? null : _tapToReadCard,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: _isReadingCard
                                ? null
                                : const LinearGradient(
                                    colors: [Color(0xFF0369A1), Color(0xFF0891B2)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            color: _isReadingCard ? Colors.white.withOpacity(0.06) : null,
                            borderRadius: BorderRadius.circular(14),
                            border: _isReadingCard
                                ? Border.all(color: Colors.white.withOpacity(0.10))
                                : null,
                          ),
                          child: _isReadingCard
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Reading…', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14)),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.nfc, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text('Tap to Verify & Sync Card', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                        ),
                      ),

                      if (_readCardStatus.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _readCardStatus,
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card Tile ─────────────────────────────────────────────────────────────

class _CardTile extends StatelessWidget {
  final CardData card;
  final bool isActive;
  final VoidCallback onSetActive;
  final VoidCallback onDelete;

  const _CardTile({
    required this.card,
    required this.isActive,
    required this.onSetActive,
    required this.onDelete,
  });

  String _masked(String num) {
    final clean = num.replaceAll(' ', '');
    if (clean.length >= 4) return '•••• •••• •••• ${clean.substring(clean.length - 4)}';
    return num;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: card.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: card.colors.last.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: isActive ? Border.all(color: Colors.white.withOpacity(0.4), width: 1.5) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(card.provider, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    if (isActive)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    // Network type
                    Text(
                      card.type.toUpperCase(),
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(_masked(card.cardNumber), style: const TextStyle(color: Colors.white, fontSize: 17, letterSpacing: 2, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CARD HOLDER', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 9, letterSpacing: 1)),
                    Text(card.holderName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EXPIRES', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 9, letterSpacing: 1)),
                    Text(card.expiry, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('AVAILABLE MONEY', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 9, letterSpacing: 1)),
                    Text('₱${card.balance.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (!isActive)
                  GestureDetector(
                    onTap: onSetActive,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Set Active', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.trash2, color: Colors.red.shade300, size: 14),
                        const SizedBox(width: 4),
                        Text('Delete', style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Card Form ─────────────────────────────────────────────────────────

class _AddCardForm extends StatelessWidget {
  final TextEditingController providerCtrl;
  final TextEditingController cardNoCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController expiryCtrl;
  final TextEditingController cvvCtrl;
  final String cardType;
  final ValueChanged<String> onCardTypeChanged;
  final VoidCallback onAdd;
  final VoidCallback onCancel;

  const _AddCardForm({
    required this.providerCtrl,
    required this.cardNoCtrl,
    required this.nameCtrl,
    required this.expiryCtrl,
    required this.cvvCtrl,
    required this.cardType,
    required this.onCardTypeChanged,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0369A1).withOpacity(0.2),
            const Color(0xFF0891B2).withOpacity(0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Virtual Card', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _FormField(controller: providerCtrl, label: 'Bank / Provider'),
          const SizedBox(height: 10),
          _FormField(controller: cardNoCtrl, label: 'Card Number'),
          const SizedBox(height: 10),
          _FormField(controller: nameCtrl, label: 'Card Holder Name'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _FormField(controller: expiryCtrl, label: 'MM/YY')),
              const SizedBox(width: 10),
              Expanded(child: _FormField(controller: cvvCtrl, label: 'CVV')),
            ],
          ),
          const SizedBox(height: 12),
          // Card type toggle
          Row(
            children: ['visa', 'mastercard'].map((t) {
              final isSelected = cardType == t;
              return GestureDetector(
                onTap: () => onCardTypeChanged(t),
                child: Container(
                  margin: EdgeInsets.only(right: t == 'visa' ? 10 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0891B2)])
                        : null,
                    color: isSelected ? null : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Text(
                    t == 'visa' ? 'VISA' : 'Mastercard',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: const Center(child: Text('Cancel', style: TextStyle(color: Colors.white54))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0891B2)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('Add Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _FormField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

// ── Hardware Stat ─────────────────────────────────────────────────────────

class _HardwareStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HardwareStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Empty Placeholder ─────────────────────────────────────────────────────

class _EmptyCardsPlaceholder extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyCardsPlaceholder({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.creditCard, color: Colors.white.withOpacity(0.2), size: 48),
          const SizedBox(height: 16),
          Text('No virtual cards', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15)),
          const SizedBox(height: 8),
          Text('Add a card to track your balances', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0891B2)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Add Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
