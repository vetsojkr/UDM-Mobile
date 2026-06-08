// lib/screens/student/student_home_screen.dart
// Module Étudiant — Interface redesignée avec graphismes et icônes enrichis
// Thème UDM International: Bleu #003087 + Or #E8A020

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/user_service.dart';
import '../../services/cloudinary_service.dart';
import 'student_visa_screen.dart';
import 'student_payment_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTES DE DESIGN
// ═══════════════════════════════════════════════════════════════════════════════

class _DS {
  static const Color primary    = Color(0xFF003087);
  static const Color gold       = Color(0xFFE8A020);
  static const Color bg         = Color(0xFFF0F4FB);
  static const Color surface    = Colors.white;
  static const Color textDark   = Color(0xFF1A1A2E);
  static const Color textMuted  = Color(0xFF6B7280);
  static const Color success    = Color(0xFF10B981);
  static const Color warning    = Color(0xFFF59E0B);
  static const Color danger     = Color(0xFFEF4444);
  static const Color purple     = Color(0xFF7C3AED);

  static LinearGradient get blueGrad => const LinearGradient(
    colors: [Color(0xFF001A5C), Color(0xFF003087), Color(0xFF1A4FAF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient get goldGrad => const LinearGradient(
    colors: [Color(0xFFE8A020), Color(0xFFF5C842)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient get successGrad => const LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration cardDecor({double radius = 16, Color? color}) => BoxDecoration(
    color: color ?? surface,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(color: primary.withValues(alpha: 0.06), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════════

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  Map<String, dynamic>? _userData;
  List<DocumentSnapshot> _acceptedCandidatures = [];
  bool _isLoading = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  final UserService _userService = UserService();
  StreamSubscription<DocumentSnapshot>? _userSub;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { if (mounted) setState(() => _isLoading = false); return; }
    try {
      // Stream temps réel → la photo de profil se met à jour automatiquement
      _userSub?.cancel();
      _userSub = FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(user.uid)
          .snapshots()
          .listen((snap) {
        if (mounted && snap.exists) {
          setState(() => _userData = snap.data());
        }
      });
      final data = await _userService.getCurrentUserData();
      final query = await FirebaseFirestore.instance
          .collection('candidatures')
          .where('userId', isEqualTo: user.uid)
          .where('statut', isEqualTo: 'accepte')
          .get();
      if (mounted) {
        setState(() {
          _userData = data;
          _acceptedCandidatures = query.docs;
          _isLoading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (e) {
      debugPrint("Student load error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _DS.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: _DS.blueGrad,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 36),
              ),
              SizedBox(height: 24),
              const CircularProgressIndicator(color: _DS.primary),
              SizedBox(height: 16),
              Text('Chargement...', style: GoogleFonts.poppins(color: _DS.textMuted, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final List<Widget> pages = [
      _DashboardStudent(userData: _userData, acceptedCandidatures: _acceptedCandidatures, onRefresh: _loadData),
      const StudentVisaScreen(),
      const StudentPaymentScreen(),
      const _DocumentsPortfolio(),
      const _TimetableScreen(),
      _ProfileStudent(userData: _userData),
    ];

    return Scaffold(
      backgroundColor: _DS.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: IndexedStack(index: _currentIndex, children: pages),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          _fadeCtrl.forward(from: 0);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM NAV PERSONNALISÉ
// ═══════════════════════════════════════════════════════════════════════════════

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (Icons.dashboard_rounded,       Icons.dashboard_outlined,      'Accueil'),
    (Icons.airplane_ticket_rounded, Icons.airplane_ticket_outlined,'Visa'),
    (Icons.account_balance_wallet,  Icons.account_balance_wallet_outlined, 'Paiements'),
    (Icons.folder_rounded,          Icons.folder_outlined,         'Docs'),
    (Icons.calendar_month_rounded,  Icons.calendar_month_outlined, 'Agenda'),
    (Icons.person_rounded,          Icons.person_outline_rounded,  'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _DS.surface,
        boxShadow: [BoxShadow(color: _DS.primary.withValues(alpha: 0.1), blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final (activeIcon, inactiveIcon, label) = _items[i];
              final isActive = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: EdgeInsets.all(isActive ? 6 : 0),
                          decoration: isActive ? BoxDecoration(
                            color: _DS.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ) : null,
                          child: Icon(
                            isActive ? activeIcon : inactiveIcon,
                            color: isActive ? _DS.primary : _DS.textMuted,
                            size: isActive ? 22 : 20,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(label, style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive ? _DS.primary : _DS.textMuted,
                        )),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD ÉTUDIANT
// ═══════════════════════════════════════════════════════════════════════════════

class _DashboardStudent extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final List<DocumentSnapshot> acceptedCandidatures;
  final VoidCallback onRefresh;
  const _DashboardStudent({required this.userData, required this.acceptedCandidatures, required this.onRefresh});


  @override
  Widget build(BuildContext context) {
    final prenom = userData?['prenom'] ?? 'Étudiant';
    final nom    = userData?['nom']    ?? '';
    final email  = userData?['email']  ?? '';
    final selectedDoc = acceptedCandidatures.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['isSelectedForEnrollment'] == true;
    }).firstOrNull;
    final selectedProg = selectedDoc != null
        ? (selectedDoc.data() as Map<String, dynamic>)['programme'] as String? ?? ''
        : (acceptedCandidatures.isNotEmpty
            ? (acceptedCandidatures.first.data() as Map<String, dynamic>)['programme'] as String? ?? ''
            : '');

    return Scaffold(
      backgroundColor: _DS.bg,
      body: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        color: _DS.primary,
        child: CustomScrollView(
          slivers: [
            // ── AppBar Hero ─────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: _DS.primary,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: BoxDecoration(gradient: _DS.blueGrad),
                  child: Stack(
                    children: [
                      // Cercles décoratifs
                      Positioned(
                        top: -40, right: -40,
                        child: _DecorCircle(size: 180, color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      Positioned(
                        top: 40, right: 60,
                        child: _DecorCircle(size: 90, color: Colors.white.withValues(alpha: 0.04)),
                      ),
                      Positioned(
                        bottom: -20, left: -30,
                        child: _DecorCircle(size: 120, color: _DS.gold.withValues(alpha: 0.12)),
                      ),
                      // Contenu aligné au bas pour éviter overflow
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              // Avatar
                              Container(
                                width: 58, height: 58,
                                decoration: BoxDecoration(
                                  gradient: _DS.goldGrad,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                ),
                                child: ClipOval(
                                  child: (userData?['photoUrl'] as String? ?? '').isNotEmpty
                                    ? Image.network(
                                        userData!['photoUrl'] as String,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            prenom.isNotEmpty ? prenom[0].toUpperCase() : 'E',
                                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          prenom.isNotEmpty ? prenom[0].toUpperCase() : 'E',
                                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                ),
                              ),
                              SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Bonjour 👋', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                                Text('$prenom $nom', style: GoogleFonts.poppins(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                                if (email.isNotEmpty)
                                  Text(email, style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
                              ])),
                              // Badge statut
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _DS.success,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.verified_rounded, color: Colors.white, size: 13),
                                  SizedBox(width: 4),
                                  Text('Étudiant', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ]),
                            if (selectedProg.isNotEmpty) ...[
                              SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.school_rounded, color: _DS.gold, size: 15),
                                  SizedBox(width: 6),
                                  Flexible(child: Text(selectedProg,
                                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  )),
                                ]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ),
                    ],
                  ),
                ),
              ),
              title: Text('Mon Espace', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),

            // ── Corps ────────────────────────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: SliverList(delegate: SliverChildListDelegate([
                // Cartes de stats rapides
                _QuickStatsRow(acceptedCount: acceptedCandidatures.length),
                SizedBox(height: 20),

                // Événements importants
                const _SectionHeader(icon: Icons.event_rounded, title: 'Événements à venir'),
                SizedBox(height: 10),
                const _EventCard(
                  title: 'Rentrée universitaire',
                  date: '5 Septembre 2026',
                  icon: Icons.school_rounded,
                  color: _DS.primary,
                  tag: 'Rentrée',
                ),
                SizedBox(height: 8),
                const _EventCard(
                  title: 'Date limite — Paiement des frais',
                  date: '30 Novembre 2026',
                  icon: Icons.account_balance_wallet_rounded,
                  color: _DS.warning,
                  tag: 'Finance',
                ),
                SizedBox(height: 8),
                const _EventCard(
                  title: 'Dépôt des documents visa',
                  date: '15 Octobre 2026',
                  icon: Icons.airplane_ticket_rounded,
                  color: _DS.purple,
                  tag: 'Visa',
                ),
                SizedBox(height: 20),

                // Actions rapides
                const _SectionHeader(icon: Icons.flash_on_rounded, title: 'Actions rapides'),
                SizedBox(height: 10),
                _QuickActionsGrid(),
                SizedBox(height: 30),
              ])),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS COMPOSANTS DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════════

class _DecorCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _DecorCircle({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(color: _DS.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: _DS.primary, size: 18),
    ),
    SizedBox(width: 10),
    Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: _DS.textDark)),
  ]);
}

class _QuickStatsRow extends StatelessWidget {
  final int acceptedCount;
  const _QuickStatsRow({required this.acceptedCount});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatCard(
        label: 'Admissions', value: '$acceptedCount',
        icon: Icons.check_circle_rounded, gradient: _DS.successGrad,
      )),
      SizedBox(width: 10),
      Expanded(child: _StatCard(
        label: 'Documents', value: '—',
        icon: Icons.folder_rounded, gradient: _DS.blueGrad,
      )),
      SizedBox(width: 10),
      Expanded(child: _StatCard(
        label: 'Visa', value: '—',
        icon: Icons.airplane_ticket_rounded, gradient: _DS.goldGrad,
      )),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final LinearGradient gradient;
  const _StatCard({required this.label, required this.value, required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: gradient.colors.first.withValues(alpha: 0.25), blurRadius: 10, offset: Offset(0, 4))]),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
      SizedBox(height: 8),
      Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
      Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
    ]),
  );
}




class _EventCard extends StatelessWidget {
  final String title, date, tag;
  final IconData icon;
  final Color color;
  const _EventCard({required this.title, required this.date, required this.icon, required this.color, required this.tag});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _DS.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border(left: BorderSide(color: color, width: 4)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textDark)),
      subtitle: Row(children: [
        const Icon(Icons.calendar_today_rounded, size: 11, color: _DS.textMuted),
        SizedBox(width: 4),
        Text(date, style: GoogleFonts.poppins(fontSize: 11, color: _DS.textMuted)),
      ]),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(tag, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ),
    ),
  );
}

class _QuickActionsGrid extends StatelessWidget {
  final _actions = const [
    (Icons.description_rounded, 'Mes Documents', _DS.primary),
    (Icons.airplane_ticket_rounded, 'Visa', Color(0xFF7C3AED)),
    (Icons.account_balance_wallet_rounded, 'Paiements', _DS.warning),
    (Icons.support_agent_rounded, 'Support', _DS.success),
  ];
  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.4,
    children: _actions.map((a) {
      final (icon, label, color) = a;
      return GestureDetector(
        onTap: () {},
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 22),
            SizedBox(width: 8),
            Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );
    }).toList(),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ÉCRAN DOCUMENTS
// ═══════════════════════════════════════════════════════════════════════════════

class _DocumentsPortfolio extends StatelessWidget {
  const _DocumentsPortfolio();

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: _DS.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: _DS.primary,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: BoxDecoration(gradient: _DS.blueGrad),
                child: Stack(children: [
                  Positioned(top: -20, right: -20,
                    child: _DecorCircle(size: 120, color: Colors.white.withValues(alpha: 0.05))),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('Mes Documents', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                        Text('Tous vos fichiers en un seul endroit', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('candidatures')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _DS.primary));
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return _EmptyState(
                      icon: Icons.folder_open_rounded,
                      title: 'Aucun document',
                      subtitle: 'Vos documents apparaîtront ici après une candidature.',
                    );
                  }
                  return Column(children: docs.map((cand) => _DocCandidatureCard(cand: cand)).toList());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocCandidatureCard extends StatelessWidget {
  final DocumentSnapshot cand;
  const _DocCandidatureCard({required this.cand});

  Color _statusColor(String? statut) {
    switch (statut) {
      case 'accepte': return _DS.success;
      case 'rejete': return _DS.danger;
      case 'en_attente': return _DS.warning;
      default: return _DS.textMuted;
    }
  }

  String _statusLabel(String? statut) {
    switch (statut) {
      case 'accepte': return 'Accepté';
      case 'rejete': return 'Rejeté';
      case 'en_attente': return 'En attente';
      default: return 'Inconnu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = cand.data() as Map<String, dynamic>;
    final programme = data['programme'] as String? ?? 'Programme';
    final statut = data['statut'] as String?;
    final color = _statusColor(statut);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _DS.cardDecor(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(gradient: _DS.blueGrad, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.folder_rounded, color: Colors.white, size: 22),
          ),
          title: Text(programme, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _DS.textDark)),
          subtitle: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(_statusLabel(statut), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ),
          children: [
            FutureBuilder<QuerySnapshot>(
              future: cand.reference.collection('documents').get(),
              builder: (context, dSnap) {
                if (!dSnap.hasData) return Padding(padding: const EdgeInsets.all(12), child: const LinearProgressIndicator(color: _DS.primary));
                final docList = dSnap.data!.docs;
                if (docList.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun document déposé', style: GoogleFonts.poppins(color: _DS.textMuted, fontSize: 13)),
                  );
                }
                return Column(children: [
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ...docList.map((d) => _DocItem(doc: d)),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openUrl(BuildContext context, String url) async {
  if (url.isEmpty) return;
  try {
    final uri = Uri.parse(url);
    // Try externalApplication first (best for mobile)
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!launched) {
      // Fallback to inAppWebView for mobile
      try { launched = await launchUrl(uri, mode: LaunchMode.inAppWebView); } catch (_) {}
    }
    if (!launched) {
      // Last resort: platformDefault
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Impossible d\'ouvrir le document'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Copier URL',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ));
    }
  }
}

class _DocItem extends StatelessWidget {
  final DocumentSnapshot doc;
  const _DocItem({required this.doc});
  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] as String? ?? 'Document';
    final nom  = data['nomFichier'] as String? ?? '';
    final url  = data['url'] as String? ?? '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: _DS.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.insert_drive_file_rounded, color: _DS.purple, size: 18),
      ),
      title: Text(type, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: _DS.textDark)),
      subtitle: nom.isNotEmpty ? Text(nom, style: GoogleFonts.poppins(fontSize: 11, color: _DS.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      trailing: url.isNotEmpty ? IconButton(
        icon: const Icon(Icons.open_in_new_rounded, size: 18, color: _DS.primary),
        onPressed: () => _openUrl(context, url),
      ) : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ÉCRAN AGENDA / EMPLOI DU TEMPS
// ═══════════════════════════════════════════════════════════════════════════════

class _TimetableScreen extends StatefulWidget {
  const _TimetableScreen();
  @override
  State<_TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<_TimetableScreen> {
  int _selectedDay = (DateTime.now().weekday - 1).clamp(0, 4); // 0 = lundi (clampé pour week-end)

  static const _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi'];
  static const _shortDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];

  static const _courses = {
    0: [
      {'heure': '08:00 – 10:00', 'cours': 'Algorithmique avancée', 'salle': 'B201', 'prof': 'Prof. Martin', 'color': 0xFF003087},
      {'heure': '10:15 – 12:15', 'cours': 'Bases de données', 'salle': 'A105', 'prof': 'Prof. Dupont', 'color': 0xFF7C3AED},
      {'heure': '14:00 – 16:00', 'cours': 'Réseaux informatiques', 'salle': 'C302', 'prof': 'Prof. Bernard', 'color': 0xFF059669},
    ],
    1: [
      {'heure': '08:00 – 10:00', 'cours': 'Mathématiques', 'salle': 'A201', 'prof': 'Prof. Leblanc', 'color': 0xFFE8A020},
      {'heure': '14:00 – 16:00', 'cours': 'Systèmes d\'exploitation', 'salle': 'Labo 1', 'prof': 'Prof. Simon', 'color': 0xFFEF4444},
    ],
    2: [
      {'heure': '10:15 – 12:15', 'cours': 'Génie logiciel', 'salle': 'B105', 'prof': 'Prof. Garcia', 'color': 0xFF003087},
      {'heure': '14:00 – 16:00', 'cours': 'IA & Machine Learning', 'salle': 'Labo 2', 'prof': 'Prof. Thomas', 'color': 0xFF7C3AED},
    ],
    3: [
      {'heure': '08:00 – 10:00', 'cours': 'Soutenance PFE', 'salle': 'C101', 'prof': 'Prof. Morel', 'color': 0xFFEF4444},
      {'heure': '10:15 – 12:15', 'cours': 'Soutenance PFE', 'salle': 'B305', 'prof': 'Prof. Laurent', 'color': 0xFF059669},
    ],
    4: [
      {'heure': '08:00 – 10:00', 'cours': 'Projet de fin d\'études', 'salle': 'Salle Projet', 'prof': 'Équipe encadrante', 'color': 0xFFE8A020},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final courses = _courses[_selectedDay] ?? [];
    return Scaffold(
      backgroundColor: _DS.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: _DS.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(decoration: BoxDecoration(gradient: _DS.blueGrad)),
            ),
            title: Text('Emploi du temps', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: _DS.primary,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: List.generate(5, (i) {
                final isSelected = _selectedDay == i;
                return Expanded(child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? _DS.gold : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_shortDays[i], style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : Colors.white70,
                      )),
                    ]),
                  ),
                ));
              })),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildListDelegate([
              Text(_days[_selectedDay],
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _DS.textDark)),
              Text('${courses.length} cours programmé${courses.length > 1 ? 's' : ''}',
                style: GoogleFonts.poppins(fontSize: 12, color: _DS.textMuted)),
              SizedBox(height: 16),
              if (courses.isEmpty) _EmptyState(
                icon: Icons.event_available_rounded,
                title: 'Pas de cours',
                subtitle: 'Vous êtes libre ce jour !',
              ) else
                ...courses.map((c) => _CourseCard(course: c)),
            ])),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  const _CourseCard({required this.course});
  @override
  Widget build(BuildContext context) {
    final color = Color(course['color'] as int);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 5,
          height: 90,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.horizontal(left: Radius.circular(14))),
        ),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(course['heure'] as String,
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(course['salle'] as String,
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ),
            ]),
            SizedBox(height: 4),
            Text(course['cours'] as String,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: _DS.textDark)),
            SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.person_rounded, size: 13, color: _DS.textMuted),
              SizedBox(width: 4),
              Text(course['prof'] as String,
                style: GoogleFonts.poppins(fontSize: 11, color: _DS.textMuted)),
            ]),
          ]),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ÉCRAN PROFIL ÉTUDIANT
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfileStudent extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const _ProfileStudent({required this.userData});
  @override
  State<_ProfileStudent> createState() => _ProfileStudentState();
}

class _ProfileStudentState extends State<_ProfileStudent> {
  bool _isUploadingPhoto = false;
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinary = CloudinaryService();

  Future<void> _pickAndUploadPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Choisir une photo', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ListTile(
          leading: Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _DS.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.photo_library_rounded, color: _DS.primary)),
          title: Text('Galerie', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
        ListTile(
          leading: Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _DS.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.camera_alt_rounded, color: _DS.gold)),
          title: Text('Caméra', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        const SizedBox(height: 16),
      ])),
    );
    if (source == null || !mounted) return;
    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final url = await _cloudinary.uploadFile(File(picked.path));
      if (url != null) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'photoUrl': url});
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Photo mise à jour ✓', style: GoogleFonts.poppins()),
            backgroundColor: _DS.success, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur photo : $e', style: GoogleFonts.poppins()),
          backgroundColor: _DS.danger, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user   = FirebaseAuth.instance.currentUser;
    final prenom = widget.userData?['prenom'] ?? 'Étudiant';
    final nom    = widget.userData?['nom']    ?? '';
    final tel    = widget.userData?['telephone'] ?? '—';
    final photoUrl = widget.userData?['photoUrl'] as String? ?? '';

    return Scaffold(
      backgroundColor: _DS.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            backgroundColor: _DS.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: _DS.blueGrad),
                child: Stack(children: [
                  Positioned(top: -30, right: -30, child: _DecorCircle(size: 150, color: Colors.white.withValues(alpha: 0.05))),
                  Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 40),
                    // Avatar avec bouton caméra
                    Stack(alignment: Alignment.bottomRight, children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(gradient: _DS.goldGrad, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3)),
                        child: ClipOval(
                          child: photoUrl.isNotEmpty
                            ? Image.network(photoUrl, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(child: Text(
                                  prenom.isNotEmpty ? prenom[0].toUpperCase() : 'E',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700))))
                            : Center(child: Text(
                                prenom.isNotEmpty ? prenom[0].toUpperCase() : 'E',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700))),
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickAndUploadPhoto,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: _DS.primary, shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)),
                          child: _isUploadingPhoto
                              ? const Padding(padding: EdgeInsets.all(5),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text('$prenom $nom', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(user?.email ?? '', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                  ])),
                ]),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildListDelegate([
              // Informations personnelles
              Container(
                decoration: _DS.cardDecor(),
                child: Column(children: [
                  _ProfileTile(icon: Icons.person_rounded, label: 'Nom complet', value: '$prenom $nom', color: _DS.primary),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _ProfileTile(icon: Icons.email_rounded, label: 'Email', value: user?.email ?? '—', color: _DS.purple),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _ProfileTile(icon: Icons.phone_rounded, label: 'Téléphone', value: tel, color: _DS.success),
                ]),
              ),
              const SizedBox(height: 16),

              // Paramètres
              Container(
                decoration: _DS.cardDecor(),
                child: Column(children: [
                  _ActionTile(
                    icon: Icons.add_a_photo_rounded,
                    label: 'Changer la photo de profil',
                    subtitle: 'Photo depuis la galerie ou la caméra',
                    color: _DS.gold,
                    onTap: _pickAndUploadPhoto,
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _ActionTile(
                    icon: Icons.lock_rounded,
                    label: 'Changer le mot de passe',
                    subtitle: 'Modifiez votre mot de passe',
                    color: _DS.primary,
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _ActionTile(
                    icon: Icons.help_rounded,
                    label: 'Aide & Support',
                    subtitle: "Contactez l'administration",
                    color: _DS.success,
                    onTap: () {},
                  ),
                ]),
              ),
              SizedBox(height: 20),

              // Bouton déconnexion
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Déconnexion', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                        content: Text('Voulez-vous vraiment vous déconnecter ?',
                          style: GoogleFonts.poppins(color: _DS.textMuted)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: _DS.danger),
                            child: const Text('Déconnecter'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseFirestore.instance.collection('utilisateurs').doc(FirebaseAuth.instance.currentUser?.uid ?? '').update({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()}).catchError((_){});
      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.pushReplacementNamed(context, '/');
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: _DS.danger),
                  label: Text('Se déconnecter', style: GoogleFonts.poppins(color: _DS.danger, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _DS.danger.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              SizedBox(height: 30),
            ])),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _ProfileTile({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18)),
      SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: _DS.textMuted)),
        Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _DS.textDark)),
      ])),
    ]),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Container(width: 40, height: 40,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 20)),
    title: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _DS.textDark)),
    subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: _DS.textMuted)),
    trailing: Icon(Icons.chevron_right_rounded, color: _DS.textMuted.withValues(alpha: 0.5)),
    onTap: onTap,
  );
}

// Dialog changement mot de passe étudiant
Future<void> _showChangePasswordDialog(BuildContext context) async {
  final currentCtrl = TextEditingController();
  final newCtrl     = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? error;
  bool obscCurrent = true, obscNew = true, obscConfirm = true;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Changer le mot de passe', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (error != null) Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(color: _DS.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Text(error!, style: GoogleFonts.poppins(color: _DS.danger, fontSize: 12))),
        _PwdInputField(controller: currentCtrl, label: 'Mot de passe actuel', obscure: obscCurrent, onToggle: () => setS(() => obscCurrent = !obscCurrent)),
        SizedBox(height: 12),
        _PwdInputField(controller: newCtrl, label: 'Nouveau mot de passe', obscure: obscNew, onToggle: () => setS(() => obscNew = !obscNew)),
        SizedBox(height: 12),
        _PwdInputField(controller: confirmCtrl, label: 'Confirmer', obscure: obscConfirm, onToggle: () => setS(() => obscConfirm = !obscConfirm)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: GoogleFonts.poppins())),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _DS.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            if (newCtrl.text.length < 6) { setS(() => error = 'Au moins 6 caractères'); return; }
            if (newCtrl.text != confirmCtrl.text) { setS(() => error = 'Les mots de passe ne correspondent pas'); return; }
            try {
              final user = FirebaseAuth.instance.currentUser!;
              final cred = EmailAuthProvider.credential(email: user.email!, password: currentCtrl.text);
              await user.reauthenticateWithCredential(cred);
              await user.updatePassword(newCtrl.text);
              if (ctx.mounted) { Navigator.pop(ctx); }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Mot de passe mis à jour ✓', style: GoogleFonts.poppins()),
                  backgroundColor: _DS.success, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
              }
            } catch (e) { setS(() => error = 'Mot de passe actuel incorrect'); }
          },
          child: Text('Enregistrer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    )),
  );
}

class _PwdInputField extends StatelessWidget {
  final TextEditingController controller; final String label; final bool obscure; final VoidCallback onToggle;
  const _PwdInputField({required this.controller, required this.label, required this.obscure, required this.onToggle});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, obscureText: obscure,
    style: GoogleFonts.poppins(fontSize: 13),
    decoration: InputDecoration(
      labelText: label, labelStyle: GoogleFonts.poppins(fontSize: 13, color: _DS.textMuted),
      filled: true, fillColor: _DS.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _DS.primary, width: 1.5)),
      suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: _DS.textMuted), onPressed: onToggle),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET ÉTAT VIDE
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(color: _DS.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: Icon(icon, color: _DS.primary.withValues(alpha: 0.4), size: 48),
      ),
      SizedBox(height: 16),
      Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: _DS.textDark)),
      SizedBox(height: 6),
      Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: _DS.textMuted), textAlign: TextAlign.center),
    ]),
  );
}