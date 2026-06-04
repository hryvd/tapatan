import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../utils/lucide_icons.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSignOut;
  final Function(String)? onNavigate;

  const ProfileScreen({super.key, this.onSignOut, this.onNavigate});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final Map<String, bool> _toggles = {
    'Biometric Auth': true,
    'Notifications': true,
  };

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (name.isNotEmpty) return name[0].toUpperCase();
    return 'U';
  }

  void _showPinModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF031424), Color(0xFF020B18)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Change PIN', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Enter your new 6-digit card PIN', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              const SizedBox(height: 20),
              _buildPinField('Current PIN'),
              const SizedBox(height: 12),
              _buildPinField('New PIN'),
              const SizedBox(height: 12),
              _buildPinField('Confirm New PIN'),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0891B2)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: Text('Save PIN', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: TextField(
            obscureText: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '● ● ● ● ● ●',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), letterSpacing: 4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  void _showPersonalInfoModal(BuildContext context, UserState user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF120832), Color(0xFF0A0020)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Personal Information', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _buildInfoRow('Full Name', user.name.isNotEmpty ? user.name : 'Not set', LucideIcons.user),
            _buildInfoRow('Email', user.email.isNotEmpty ? user.email : 'Not set', LucideIcons.mail),
            _buildInfoRow('Account Type', 'Individual', LucideIcons.shield),
            _buildInfoRow('Member Since', 'June 2025', LucideIcons.calendar),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: const Center(child: Text('Close', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF0369A1).withOpacity(0.15),
            ),
            child: Icon(icon, size: 15, color: const Color(0xFF38BDF8)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 0.5)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  void _showHelpCenter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        builder: (ctx, scroll) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF120832), Color(0xFF0A0020)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text('Help Center', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildFaqItem('How does NFC payment work?', 'Tap your Java Card to the back of your phone to write a secure token. Then tap your phone at any NFC-enabled POS terminal to complete the payment.'),
                    _buildFaqItem('How do I arm my card?', 'On the home screen, press "Enable Transaction" and follow the NFC unlock flow to arm your card for one-time payment.'),
                    _buildFaqItem('What happens after a payment?', 'After each NFC payment, your card is automatically disarmed for security. You\'ll need to re-arm it for your next transaction.'),
                    _buildFaqItem('How do I add a virtual card?', 'Go to the Cards tab and tap "Add Card". Enter your card details and select your provider.'),
                    _buildFaqItem('Is my data secure?', 'Yes. All card tokens are encrypted end-to-end and expire automatically after 5 minutes.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(answer, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    final menuSections = [
      {
        'title': 'ACCOUNT',
        'items': [
          {'icon': LucideIcons.user, 'label': 'Personal Information', 'color': 0xFF0891B2, 'action': () => _showPersonalInfoModal(context, user)},
          {'icon': LucideIcons.creditCard, 'label': 'Linked Banks & Cards', 'color': 0xFF2563EB, 'badge': '${user.virtualCards.length}', 'action': () => widget.onNavigate?.call('cards')},
          {'icon': LucideIcons.star, 'label': 'Upgrade to Premium', 'color': 0xFFF59E0B, 'highlight': true, 'action': () {}},
        ],
      },
      {
        'title': 'SECURITY',
        'items': [
          {'icon': LucideIcons.lock, 'label': 'Change PIN', 'color': 0xFF06B6D4, 'action': () => _showPinModal(context)},
          {'icon': LucideIcons.fingerprint, 'label': 'Biometric Auth', 'color': 0xFF10B981, 'toggle': true},
          {'icon': LucideIcons.shield, 'label': 'Privacy Settings', 'color': 0xFF0891B2, 'action': () {}},
          {'icon': LucideIcons.info, 'label': 'Security Info & Card Lock', 'color': 0xFFEF4444, 'action': () => Navigator.pushNamed(context, '/security')},
        ],
      },
      {
        'title': 'PREFERENCES',
        'items': [
          {'icon': LucideIcons.bell, 'label': 'Notifications', 'color': 0xFFF59E0B, 'toggle': true},
          {'icon': LucideIcons.wifi, 'label': 'NFC & Java Card Settings', 'color': 0xFF06B6D4, 'action': () {}},
        ],
      },
      {
        'title': 'SUPPORT',
        'items': [
          {'icon': LucideIcons.helpCircle, 'label': 'Help Center', 'color': 0xFF64748B, 'action': () => _showHelpCenter(context)},
          {'icon': LucideIcons.logOut, 'label': 'Sign Out', 'color': 0xFFEF4444, 'danger': true, 'action': () async {
            await ref.read(userProvider.notifier).clearUser();
            widget.onSignOut?.call();
          }},
        ],
      },
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          // Profile Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x590369A1), Color(0x470891B2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Stack(
              children: [
                // Ambient orb
                Positioned(
                  top: -30, right: -30,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0891B2).withOpacity(0.25),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0369A1), Color(0xFF0891B2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                            boxShadow: const [BoxShadow(color: Color(0x590891B2), blurRadius: 25, offset: Offset(0, 8))],
                          ),
                          child: Center(
                            child: Text(
                              _initials(user.name),
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.name.isNotEmpty ? user.name : 'Your Name',
                                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: const Color(0xFFF59E0B).withOpacity(0.18),
                                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(LucideIcons.star, size: 9, color: Color(0xFFFBBF24)),
                                        const SizedBox(width: 2),
                                        const Text('PRO', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 9, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.email.isNotEmpty ? user.email : 'your@email.com',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Stats row
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black.withOpacity(0.2),
                      ),
                      child: Row(
                        children: [
                          _buildStatItem('Cards', '${user.virtualCards.length}', true),
                          _buildStatItem('Transactions', '${user.transactions.length}', true),
                          _buildStatItem('NFC Pays', '${user.nfcPayCount}', false),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Menu sections
          ...menuSections.map((section) {
            final title = section['title'] as String;
            final items = section['items'] as List<Map<String, dynamic>>;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: List.generate(items.length, (ii) {
                      final item = items[ii];
                      final icon = item['icon'] as IconData;
                      final label = item['label'] as String;
                      final color = Color(item['color'] as int);
                      final isToggle = item.containsKey('toggle') && item['toggle'] == true;
                      final isDanger = item.containsKey('danger') && item['danger'] == true;
                      final isHighlight = item.containsKey('highlight') && item['highlight'] == true;
                      final badge = item['badge'] as String?;
                      final action = item['action'] as VoidCallback?;
                      final isOn = _toggles[label] ?? false;

                      return GestureDetector(
                        onTap: () {
                          if (isToggle) {
                            setState(() => _toggles[label] = !isOn);
                          } else {
                            action?.call();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: ii > 0 ? Border(top: BorderSide(color: Colors.white.withOpacity(0.05))) : null,
                            color: isHighlight ? const Color(0xFFF59E0B).withOpacity(0.06) : Colors.transparent,
                            borderRadius: ii == items.length - 1
                                ? const BorderRadius.vertical(bottom: Radius.circular(24))
                                : ii == 0
                                    ? const BorderRadius.vertical(top: Radius.circular(24))
                                    : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: color.withOpacity(0.15),
                                ),
                                child: Icon(icon, size: 15, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDanger
                                        ? const Color(0xFFEF4444)
                                        : isHighlight
                                            ? const Color(0xFFF59E0B)
                                            : Colors.white.withOpacity(0.85),
                                  ),
                                ),
                              ),
                              if (badge != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: const Color(0xFF0891B2).withOpacity(0.2),
                                  ),
                                  child: Text(badge, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              if (isToggle)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 40, height: 24,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: isOn ? const Color(0xFF0891B2).withOpacity(0.6) : Colors.white.withOpacity(0.12),
                                    border: Border.all(color: isOn ? const Color(0xFF0891B2).withOpacity(0.5) : Colors.white.withOpacity(0.12)),
                                  ),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 200),
                                    alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      width: 16, height: 16,
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                    ),
                                  ),
                                )
                              else if (!isDanger)
                                Icon(LucideIcons.chevronRight, size: 15, color: Colors.white.withOpacity(0.2)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }),

          // App info footer
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.checkCircle, size: 12, color: Color(0xFF34D399)),
                  const SizedBox(width: 6),
                  Text('Secured by end-to-end encryption', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                ],
              ),
              const SizedBox(height: 4),
              Text('tap@tan v1.0.0 · Build 2025.06', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool hasBorder) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: hasBorder ? Border(right: BorderSide(color: Colors.white.withOpacity(0.08))) : null,
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
