import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../utils/lucide_icons.dart';

class VirtualCardsScreen extends ConsumerStatefulWidget {
  const VirtualCardsScreen({super.key});

  @override
  ConsumerState<VirtualCardsScreen> createState() => _VirtualCardsScreenState();
}

class _VirtualCardsScreenState extends ConsumerState<VirtualCardsScreen> {
  int _activeIdx = 0;
  bool _showCVV = false;

  static const _providers = ['GCash', 'Maya', 'Custom'];
  static const _networks = ['visa', 'mastercard'];
  static const _presetColors = {
    'GCash': [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF0EA5E9)],
    'Maya': [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
    'Custom': [Color(0xFF0891B2), Color(0xFF06B6D4), Color(0xFF22D3EE)],
  };

  String _formProvider = 'GCash';
  String _formCardNumber = '';
  String _formHolderName = '';
  String _formExpiry = '';
  String _formCvv = '';
  String _formType = 'visa';

  String _formatCardInput(String val) {
    final digits = val.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(limited[i]);
    }
    return buffer.toString();
  }

  String _formatExpiry(String val) {
    final digits = val.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    if (limited.length > 2) return '${limited.substring(0, 2)}/${limited.substring(2)}';
    return limited;
  }

  void _handleAddCard(UserState user) {
    if (_formCardNumber.isEmpty || _formHolderName.isEmpty || _formExpiry.isEmpty || _formCvv.isEmpty) return;

    final raw = _formCardNumber.replaceAll(' ', '');
    final masked = '${raw.length >= 4 ? raw.substring(0, 4) : raw} •••• •••• ${raw.length >= 4 ? raw.substring(raw.length - 4) : ''}';

    final newCard = CardData(
      id: 'card-${DateTime.now().millisecondsSinceEpoch}',
      provider: _formProvider,
      cardNumber: masked,
      holderName: (_formHolderName.isNotEmpty ? _formHolderName : user.name).toUpperCase(),
      expiry: _formExpiry,
      cvv: _formCvv,
      type: _formType,
      colors: _presetColors[_formProvider]!,
    );

    ref.read(userProvider.notifier).addVirtualCard(newCard);
    Navigator.pop(context);
    _resetForm();
  }

  void _resetForm() {
    setState(() {
      _formProvider = 'GCash';
      _formCardNumber = '';
      _formHolderName = '';
      _formExpiry = '';
      _formCvv = '';
      _formType = 'visa';
    });
  }

  void _showAddCardModal(BuildContext context, UserState user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setModal) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF031424), Color(0xFF020B18)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Upload Virtual Card', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      GestureDetector(
                        onTap: () { Navigator.pop(ctx); _resetForm(); },
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
                          child: Icon(LucideIcons.x, size: 16, color: Colors.white.withOpacity(0.6)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Provider selection
                  Text('Provider', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: _providers.map((p) {
                      final colors = _presetColors[p]!;
                      final isSelected = _formProvider == p;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setModal(() {
                              _formProvider = p;
                              _formType = p == 'Maya' ? 'mastercard' : 'visa';
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(colors: [colors[0].withOpacity(0.55), colors[1].withOpacity(0.4)])
                                    : null,
                                color: isSelected ? null : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? colors[0].withOpacity(0.6) : Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Text(p, textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                                  fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                )),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Card Number
                  _buildFormLabel('Card Number'),
                  _buildFormInput(
                    hint: '1234 5678 9012 3456',
                    value: _formCardNumber,
                    monospace: true,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setModal(() => _formCardNumber = _formatCardInput(v)),
                  ),
                  const SizedBox(height: 12),

                  // Holder Name
                  _buildFormLabel('Card Holder Name'),
                  _buildFormInput(
                    hint: user.name.isNotEmpty ? user.name.toUpperCase() : 'JUAN DELA CRUZ',
                    value: _formHolderName,
                    onChanged: (v) => setModal(() => _formHolderName = v),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormLabel('Expiry'),
                            _buildFormInput(
                              hint: 'MM/YY',
                              value: _formExpiry,
                              monospace: true,
                              keyboardType: TextInputType.number,
                              onChanged: (v) => setModal(() => _formExpiry = _formatExpiry(v)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormLabel('CVV'),
                            _buildFormInput(
                              hint: '•••',
                              value: _formCvv,
                              obscure: true,
                              keyboardType: TextInputType.number,
                              onChanged: (v) => setModal(() => _formCvv = v.replaceAll(RegExp(r'\D'), '').length > 4 ? _formCvv : v.replaceAll(RegExp(r'\D'), '')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Network
                  _buildFormLabel('Network'),
                  const SizedBox(height: 8),
                  Row(
                    children: _networks.map((n) {
                      final isSelected = _formType == n;
                      final colors = _presetColors[_formProvider]!;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setModal(() => _formType = n),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0891B2).withOpacity(0.25) : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? colors[0].withOpacity(0.5) : Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Text(n.substring(0, 1).toUpperCase() + n.substring(1), textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF22D3EE) : Colors.white.withOpacity(0.5),
                                  fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                )),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  GestureDetector(
                    onTap: () => _handleAddCard(user),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0891B2)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Color(0x660891B2), blurRadius: 30, offset: Offset(0, 8))],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.checkCircle, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Upload Card', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text('🔒 Card details are encrypted end-to-end', style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
  );

  Widget _buildFormInput({
    required String hint,
    required String value,
    required Function(String) onChanged,
    bool monospace = false,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: TextField(
        obscureText: obscure,
        keyboardType: keyboardType,
        style: TextStyle(
          color: Colors.white, fontSize: 14,
          fontFamily: monospace ? 'monospace' : null,
          letterSpacing: monospace ? 1.5 : null,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontFamily: monospace ? 'monospace' : null),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
        ),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final cards = user.virtualCards;
    final displayCard = cards.isNotEmpty && _activeIdx < cards.length ? cards[_activeIdx] : null;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 120),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Virtual Cards', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    Text('${cards.length} card${cards.length != 1 ? "s" : ""} linked', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
                GestureDetector(
                  onTap: () => _showAddCardModal(context, user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0x800369A1), Color(0x660891B2)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.35)),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.plus, size: 15, color: Color(0xFF38BDF8)),
                        SizedBox(width: 4),
                        Text('Add Card', style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3D Card Display
          Center(
            child: cards.isEmpty || displayCard == null
                ? GestureDetector(
                    onTap: () => _showAddCardModal(context, user),
                    child: Container(
                      width: 320, height: 190,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.3), width: 2),
                        color: const Color(0xFF0891B2).withOpacity(0.05),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: const Color(0xFF0891B2).withOpacity(0.15),
                            ),
                            child: const Icon(LucideIcons.creditCard, size: 24, color: Color(0xFF38BDF8)),
                          ),
                          const SizedBox(height: 12),
                          Text('Upload your first virtual card', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                : _buildCard3D(displayCard, displayCard.id == user.activeCardId),
          ),
          const SizedBox(height: 16),

          // Dot navigator
          if (cards.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(cards.length, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _activeIdx = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _activeIdx ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == _activeIdx ? const Color(0xFF0891B2).withOpacity(0.9) : Colors.white.withOpacity(0.2),
                    ),
                  ),
                );
              }),
            ),
          if (cards.length > 1) const SizedBox(height: 16),

          // Card details panel
          if (displayCard != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Card Details', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                        Row(
                          children: [
                            const Icon(LucideIcons.shield, size: 13, color: Color(0xFF34D399)),
                            const SizedBox(width: 4),
                            const Text('Encrypted', style: TextStyle(color: Color(0xFF34D399), fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 3,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildDetailBox('CARD NUMBER', displayCard.cardNumber),
                        _buildCvvBox(displayCard.cvv),
                        _buildDetailBox('EXPIRES', displayCard.expiry),
                        _buildDetailBox('NETWORK', displayCard.type.toUpperCase()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Card list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ALL LINKED CARDS', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                ...List.generate(cards.length, (i) {
                  final card = cards[i];
                  final isActive = card.id == user.activeCardId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF0369A1).withOpacity(0.18) : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? const Color(0xFF0891B2).withOpacity(0.3) : Colors.white.withOpacity(0.07),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [card.colors[0], card.colors[1]],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(card.provider, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                    if (isActive) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          color: const Color(0xFF10B981).withOpacity(0.15),
                                        ),
                                        child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(card.cardNumber, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              if (!isActive)
                                GestureDetector(
                                  onTap: () {
                                    ref.read(userProvider.notifier).setActiveCard(card.id);
                                    setState(() => _activeIdx = i);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: const Color(0xFF0891B2).withOpacity(0.15),
                                      border: Border.all(color: const Color(0xFF0891B2).withOpacity(0.25)),
                                    ),
                                    child: const Text('Set Active', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                )
                              else
                                const Icon(LucideIcons.star, size: 15, color: Color(0xFF38BDF8)),
                              if (cards.length > 1) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    ref.read(userProvider.notifier).deleteCard(card.id);
                                    if (_activeIdx >= cards.length - 1) setState(() => _activeIdx = 0);
                                  },
                                  child: Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.red.withOpacity(0.12),
                                    ),
                                    child: const Icon(LucideIcons.trash2, size: 13, color: Color(0xFFF87171)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                // Add card prompt
                GestureDetector(
                  onTap: () => _showAddCardModal(context, user),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withOpacity(0.03),
                      border: Border.all(color: Colors.white.withOpacity(0.12), style: BorderStyle.solid),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFF0891B2).withOpacity(0.10),
                          ),
                          child: const Icon(LucideIcons.upload, size: 16, color: Color(0xFF38BDF8)),
                        ),
                        const SizedBox(width: 12),
                        Text('Upload another virtual card', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                        const Spacer(),
                        Icon(LucideIcons.chevronRight, size: 14, color: Colors.white.withOpacity(0.25)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard3D(CardData card, bool isActive) {
    return Container(
      width: 320, height: 190,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: card.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: card.colors.first.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 12)),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(card.provider, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const Icon(LucideIcons.wifi, color: Colors.white, size: 22),
            ],
          ),
          const Spacer(),
          Text(card.cardNumber, style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'monospace', letterSpacing: 2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CARD HOLDER', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, letterSpacing: 1.2)),
                  Text(card.holderName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EXPIRES', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, letterSpacing: 1.2)),
                  Text(card.expiry, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildCvvBox(String cvv) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('CVV', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(_showCVV ? cvv : '•••', style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showCVV = !_showCVV),
                child: Icon(_showCVV ? LucideIcons.eyeOff : LucideIcons.eye, size: 12, color: Colors.white.withOpacity(0.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
