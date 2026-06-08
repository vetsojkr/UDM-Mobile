// lib/screens/student/student_payment_screen.dart
// Paiement Étudiant — Affiche les frais payés et le calendrier dynamique

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class _SPC {
  static const Color primary   = Color(0xFF003087);
  static const Color gold      = Color(0xFFE8A020);
  static const Color success   = Color(0xFF10B981);
  static const Color bg        = Color(0xFFF0F4FB);
  static const Color surface   = Colors.white;
  static const Color textDark  = Color(0xFF1A1A2E);
  static const Color textMuted = Color(0xFF6B7280);

  static LinearGradient get blueGrad => const LinearGradient(
    colors: [Color(0xFF001A5C), Color(0xFF003087), Color(0xFF1A4FAF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(int amount) {
  return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} MUR';
}

/// Master → 2 ans | sinon → 3 ans
int _getDuree(String programme) {
  final p = programme.toLowerCase();
  return (p.contains('master') || p.contains('mastère')) ? 2 : 3;
}

bool _isMasterProg(String programme) {
  final p = programme.toLowerCase();
  return p.contains('master') || p.contains('mastère');
}

/// Master = 150 000 MUR | SADC = 49 000 | Hors SADC = 84 000
int _tuitionFee(String region, String programme) {
  if (_isMasterProg(programme)) return 150000;
  return region == 'SADC' ? 49000 : 84000;
}

// ══════════════════════════════════════════════════════════════════════════════
class StudentPaymentScreen extends StatelessWidget {
  const StudentPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: _SPC.bg,
        body: Center(child: Text('Non connecté', style: GoogleFonts.poppins())),
      );
    }

    return Scaffold(
      backgroundColor: _SPC.bg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ───────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: _SPC.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: _SPC.blueGrad),
                child: Stack(children: [
                  Positioned(
                    top: -30, right: -30,
                    child: Container(
                      width: 150, height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _SPC.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: _SPC.gold, size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Suivi des frais de scolarité',
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
            title: Text(
              'Paiements',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),

          // ── Contenu ──────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('candidatures')
                  .where('userId', isEqualTo: user.uid)
                  .where('paiementEffectue', isEqualTo: true)
                  .get(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: _SPC.primary),
                      ),
                    ),
                  );
                }

                // Filtrer : accepte OU promu_etudiant
                final allDocs = snap.data?.docs ?? [];
                final docs = allDocs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final s = d['statut'] as String? ?? '';
                  return s == 'accepte' || s == 'promu_etudiant';
                }).toList();

                if (docs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'Aucun paiement enregistré.',
                          style: GoogleFonts.poppins(color: _SPC.textMuted),
                        ),
                      ),
                    ),
                  );
                }

                // ── Lecture Firestore ─────────────────────────────────────
                final d                = docs.first.data() as Map<String, dynamic>;
                final programme        = d['programme']        as String? ?? '';
                final region           = d['region']           as String? ?? 'SADC';
                final anneeInscription = (d['anneeInscription'] as int?) ?? 1;

                final isMaster         = _isMasterProg(programme);
                final dureeTotal       = _getDuree(programme);
                final tuition          = _tuitionFee(region, programme);
                final totalPaid        = tuition + 700;
                final anneesRestantes  = dureeTotal - anneeInscription + 1;

                // Année académique courante
                final now           = DateTime.now();
                final anneeCourante = now.month >= 9 ? now.year : now.year - 1;

                // Labels
                final anneePayeeLabel = isMaster
                    ? 'M$anneeInscription'
                    : 'Année $anneeInscription';
                final tuitionStr = _fmt(tuition);
                final totalStr   = _fmt(totalPaid);

                return SliverList(
                  delegate: SliverChildListDelegate([

                    // ── Frais payés ───────────────────────────────────────
                    _Card(
                      headerIcon:      Icons.check_circle_rounded,
                      headerIconColor: _SPC.success,
                      headerTitle:     'Frais de scolarité payés',
                      child: Column(children: [
                        if (programme.isNotEmpty) ...[
                          Row(children: [
                            const Icon(Icons.school_rounded,
                                size: 14, color: _SPC.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(programme,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: _SPC.textMuted)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          if (!isMaster)
                            Row(children: [
                              const Icon(Icons.public_rounded,
                                  size: 14, color: _SPC.textMuted),
                              const SizedBox(width: 6),
                              Text('Région : $region',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, color: _SPC.textMuted)),
                            ]),
                          const SizedBox(height: 12),
                        ],
                        _PayRow(
                          label:       'Frais dossier',
                          amount:      '700 MUR',
                          status:      'Payé',
                          statusColor: _SPC.success,
                        ),
                        const SizedBox(height: 8),
                        _PayRow(
                          label:       'Frais de scolarité ($anneePayeeLabel)',
                          amount:      '$tuitionStr / an',
                          status:      'Payé',
                          statusColor: _SPC.success,
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total payé',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _SPC.textDark)),
                            Text(totalStr,
                                style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _SPC.success)),
                          ],
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // ── Calendrier dynamique ──────────────────────────────
                    _Card(
                      headerIcon:      Icons.calendar_month_rounded,
                      headerIconColor: _SPC.primary,
                      headerTitle:     isMaster
                          ? 'Calendrier — Master'
                          : 'Calendrier des paiements',
                      child: Column(
                        children: List.generate(anneesRestantes, (i) {
                          final anneeNum  = anneeInscription + i;
                          final startYear = anneeCourante + i;
                          final endYear   = startYear + 1;

                          final label = isMaster
                              ? 'M$anneeNum — $startYear/$endYear'
                              : 'Année $anneeNum — $startYear/$endYear';

                          final isPaid = i == 0;

                          return Column(children: [
                            if (i > 0) ...[
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                            ],
                            _YearPayRow(
                              year:   label,
                              amount: tuitionStr,
                              isPaid: isPaid,
                            ),
                            if (i < anneesRestantes - 1)
                              const SizedBox(height: 10),
                          ]);
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Note informative ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _SPC.gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _SPC.gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: _SPC.gold, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Les frais des années suivantes seront actualisés "
                              "chaque année académique. Contactez l'administration "
                              "pour tout renseignement.",
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: _SPC.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS INTERNES
// ══════════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final IconData headerIcon;
  final Color    headerIconColor;
  final String   headerTitle;
  final Widget   child;

  const _Card({
    required this.headerIcon,
    required this.headerIconColor,
    required this.headerTitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _SPC.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _SPC.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: headerIconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(headerIcon, color: headerIconColor, size: 16),
                ),
                const SizedBox(width: 8),
                Text(headerTitle,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _SPC.textDark)),
              ]),
            ),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ),
      );
}

class _PayRow extends StatelessWidget {
  final String label, amount, status;
  final Color  statusColor;

  const _PayRow({
    required this.label,
    required this.amount,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: _SPC.textMuted),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(amount,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _SPC.textDark)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status,
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
        ],
      );
}

class _YearPayRow extends StatelessWidget {
  final String year, amount;
  final bool   isPaid;

  const _YearPayRow({
    required this.year,
    required this.amount,
    required this.isPaid,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: (isPaid ? _SPC.success : _SPC.textMuted)
                .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPaid ? Icons.check_rounded : Icons.schedule_rounded,
            size: 16,
            color: isPaid ? _SPC.success : _SPC.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(year,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _SPC.textDark)),
              Text(amount,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: _SPC.textMuted)),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (isPaid ? _SPC.success : _SPC.textMuted)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isPaid ? 'Payé' : 'À venir',
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isPaid ? _SPC.success : _SPC.textMuted),
          ),
        ),
      ]);
}
