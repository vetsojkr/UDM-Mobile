// lib/screens/admin/admin_home_screen.dart
// Module Admin — Navigation principale redesignée
// Thème UDM International: Bleu #003087 + Or #E8A020

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_candidatures_list_screen.dart';
import 'admin_candidates_list_screen.dart';
import 'admin_visa_list_screen.dart';
import 'admin_profile_screen.dart';

// ── Constantes design partagées ──────────────────────────────────────────────
class AdminDS {
  static const Color primary      = Color(0xFF003087);
  static const Color primaryLight = Color(0xFF1A4FAF);
  static const Color gold         = Color(0xFFE8A020);
  static const Color bg           = Color(0xFFF0F4FB);
  static const Color surface      = Colors.white;
  static const Color textDark     = Color(0xFF1A1A2E);
  static const Color textMuted    = Color(0xFF6B7280);
  static const Color success      = Color(0xFF10B981);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color danger       = Color(0xFFEF4444);
  static const Color purple       = Color(0xFF7C3AED);

  static LinearGradient get blueGrad => const LinearGradient(
    colors: [Color(0xFF001A5C), Color(0xFF003087), Color(0xFF1A4FAF)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static LinearGradient get goldGrad => const LinearGradient(
    colors: [Color(0xFFE8A020), Color(0xFFF5C842)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  static BoxDecoration cardDecor({double radius = 14}) => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.06), blurRadius: 12, offset: Offset(0, 4))],
  );

  static Color statusColor(String s) {
    switch (s) {
      case 'accepte':         return success;
      case 'refuse':          return danger;
      case 'en_verification': return warning;
      case 'promu_etudiant':  return const Color(0xFF7C3AED); // violet
      default:                return primaryLight;
    }
  }
  static String statusLabel(String s) {
    switch (s) {
      case 'accepte':         return 'Accepté';
      case 'refuse':          return 'Refusé';
      case 'en_verification': return 'En vérification';
      case 'promu_etudiant':  return 'Promu étudiant';
      default:                return 'Soumis';
    }
  }
  static IconData statusIcon(String s) {
    switch (s) {
      case 'accepte':         return Icons.check_circle_rounded;
      case 'refuse':          return Icons.cancel_rounded;
      case 'en_verification': return Icons.pending_rounded;
      case 'promu_etudiant':  return Icons.school_rounded;
      default:                return Icons.send_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  final List<Widget> _pages = [
    const _AdminDashboard(),
    const AdminCandidaturesListScreen(),
    AdminCandidatesListScreen(),
    const AdminVisaListScreen(),
    const AdminProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminDS.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: _AdminBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) { setState(() => _currentIndex = i); _fadeCtrl.forward(from: 0); },
      ),
    );
  }
}

// ── Bottom Nav Admin ─────────────────────────────────────────────────────────
class _AdminBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _AdminBottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (Icons.dashboard_rounded,     Icons.dashboard_outlined,      'Tableau'),
    (Icons.list_alt_rounded,      Icons.list_alt_outlined,       'Candidatures'),
    (Icons.people_rounded,        Icons.people_outline_rounded,  'Utilisateurs'),
    (Icons.airplane_ticket_rounded, Icons.airplane_ticket_outlined, 'Visas'),
    (Icons.manage_accounts_rounded, Icons.manage_accounts_outlined, 'Admin'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminDS.surface,
        boxShadow: [BoxShadow(color: AdminDS.primary.withValues(alpha: 0.1), blurRadius: 20, offset: Offset(0, -4))],
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
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.all(isActive ? 6 : 0),
                      decoration: isActive ? BoxDecoration(
                        color: AdminDS.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ) : null,
                      child: Icon(isActive ? activeIcon : inactiveIcon,
                        color: isActive ? AdminDS.primary : AdminDS.textMuted,
                        size: isActive ? 22 : 20),
                    ),
                    SizedBox(height: 2),
                    Text(label, style: GoogleFonts.poppins(
                      fontSize: 9, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? AdminDS.primary : AdminDS.textMuted,
                    )),
                  ]),
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
// TABLEAU DE BORD ADMIN
// ═══════════════════════════════════════════════════════════════════════════════
class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminDS.bg,
      body: CustomScrollView(slivers: [
        // Hero AppBar
        SliverAppBar(
          pinned: true, expandedHeight: 160,
          backgroundColor: AdminDS.primary,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Container(
              decoration: BoxDecoration(gradient: AdminDS.blueGrad),
              child: Stack(children: [
                Positioned(top: -40, right: -40,
                  child: Container(width: 180, height: 180,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
                Positioned(bottom: -20, left: -20,
                  child: Container(width: 120, height: 120,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AdminDS.gold.withValues(alpha: 0.1)))),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        Container(width: 44, height: 44,
                          decoration: BoxDecoration(gradient: AdminDS.goldGrad, borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5)),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22)),
                        SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text('Administration', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                          Text('UDM International', style: GoogleFonts.poppins(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                        ]),
                      ]),
                      SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: AdminDS.success, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.circle, color: Colors.white, size: 7),
                          SizedBox(width: 5),
                          Text('Système actif', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          title: Text('Tableau de bord', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        ),

        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Stats temps réel
            _AdminStatsGrid(),
            SizedBox(height: 20),
            // Candidatures récentes
            _SectionTitle(icon: Icons.history_rounded, title: 'Candidatures récentes'),
            SizedBox(height: 10),
            _RecentCandidatures(),
            SizedBox(height: 20),
            // Répartition statuts
            _SectionTitle(icon: Icons.pie_chart_rounded, title: 'Répartition des statuts'),
            SizedBox(height: 10),
            _StatusSummary(),
            SizedBox(height: 30),
          ])),
        ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon; final String title;
  const _SectionTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: EdgeInsets.all(6),
      decoration: BoxDecoration(color: AdminDS.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: AdminDS.primary, size: 18)),
    SizedBox(width: 10),
    Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AdminDS.textDark)),
  ]);
}

class _AdminStatsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('candidatures').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final total     = docs.length;
        final acceptes  = docs.where((d) => (d.data() as Map)['statut'] == 'accepte').length;
        final enAttente = docs.where((d) => (d.data() as Map)['statut'] == 'soumis').length;
        final refuses   = docs.where((d) => (d.data() as Map)['statut'] == 'refuse').length;

        return GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55,
          children: [
            _StatTile(label: 'Total candidatures', value: '$total', icon: Icons.folder_copy_rounded,
              gradient: AdminDS.blueGrad),
            _StatTile(label: 'Acceptées', value: '$acceptes', icon: Icons.check_circle_rounded,
              gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)])),
            _StatTile(label: 'En attente', value: '$enAttente', icon: Icons.pending_rounded,
              gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)])),
            _StatTile(label: 'Refusées', value: '$refuses', icon: Icons.cancel_rounded,
              gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)])),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value; final IconData icon; final LinearGradient gradient;
  const _StatTile({required this.label, required this.value, required this.icon, required this.gradient});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: gradient.colors.first.withValues(alpha: 0.25), blurRadius: 10, offset: Offset(0, 4))]),
    padding: EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
        ),
      ]),
    ]),
  );
}

class _RecentCandidatures extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('candidatures')
          .orderBy('dateSoumission', descending: true).limit(5).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AdminDS.primary));
        final docs = snap.data!.docs;
        if (docs.isEmpty) return _EmptyWidget(label: 'Aucune candidature récente');
        return Column(children: docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final statut = d['statut'] as String? ?? 'soumis';
          final date = (d['dateSoumission'] as Timestamp?)?.toDate();
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: AdminDS.cardDecor(),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Container(width: 40, height: 40,
                decoration: BoxDecoration(gradient: AdminDS.blueGrad, borderRadius: BorderRadius.circular(10)),
                child: Center(child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('utilisateurs').doc(d['userId'] as String? ?? '').get(),
                  builder: (ctx, uSnap) {
                    String initials = '?';
                    if (uSnap.hasData && uSnap.data!.exists) {
                      final u = uSnap.data!.data() as Map<String, dynamic>;
                      final p = (u['prenom'] as String? ?? '').trim();
                      final n = (u['nom'] as String? ?? '').trim();
                      initials = '${p.isNotEmpty ? p[0] : ''}${n.isNotEmpty ? n[0] : ''}'.toUpperCase();
                      if (initials.isEmpty) initials = '?';
                    }
                    return Text(initials, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700));
                  },
                ))),
              title: Text('${d['prenom'] ?? ''} ${d['nom'] ?? ''}',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AdminDS.textDark)),
              subtitle: Text(d['programme'] ?? '',
                style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AdminDS.statusColor(statut).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(AdminDS.statusLabel(statut),
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AdminDS.statusColor(statut)))),
                if (date != null) Text(
                  '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}',
                  style: GoogleFonts.poppins(fontSize: 10, color: AdminDS.textMuted)),
              ]),
            ),
          );
        }).toList());
      },
    );
  }
}

class _StatusSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('candidatures').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final total = docs.isEmpty ? 1 : docs.length;
        final statuts = {'soumis': 0, 'en_verification': 0, 'accepte': 0, 'refuse': 0};
        for (var d in docs) {
          final s = (d.data() as Map)['statut'] as String? ?? 'soumis';
          statuts[s] = (statuts[s] ?? 0) + 1;
        }
        return Container(
          padding: EdgeInsets.all(16),
          decoration: AdminDS.cardDecor(),
          child: Column(children: statuts.entries.map((e) {
            final pct = e.value / total;
            final color = AdminDS.statusColor(e.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Icon(AdminDS.statusIcon(e.key), color: color, size: 16),
                    SizedBox(width: 6),
                    Text(AdminDS.statusLabel(e.key),
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AdminDS.textDark)),
                  ]),
                  Text('${e.value}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                ]),
                SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(value: pct, minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color))),
              ]),
            );
          }).toList()),
        );
      },
    );
  }
}

class _EmptyWidget extends StatelessWidget {
  final String label;
  const _EmptyWidget({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(child: Text(label, style: GoogleFonts.poppins(color: AdminDS.textMuted))),
  );
}