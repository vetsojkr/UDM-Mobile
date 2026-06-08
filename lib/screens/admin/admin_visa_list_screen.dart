// lib/screens/admin/admin_visa_list_screen.dart
// Demandes de visa — redessinée

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_visa_detail_screen.dart';
import 'admin_home_screen.dart'; // AdminDS

class AdminVisaListScreen extends StatefulWidget {
  const AdminVisaListScreen({super.key});
  @override
  State<AdminVisaListScreen> createState() => _AdminVisaListScreenState();
}

class _AdminVisaListScreenState extends State<AdminVisaListScreen> {
  String _filterStatut = 'tous';
  // Clé pour forcer la reconstruction du StreamBuilder lors du refresh
  int _refreshKey = 0;

  Color _visaStatusColor(String s) {
    switch (s) {
      case 'approuve':   return AdminDS.success;
      case 'rejete':     return AdminDS.danger;
      case 'en_cours':   return AdminDS.warning;
      case 'en_attente': return AdminDS.primaryLight;
      default:           return AdminDS.textMuted;
    }
  }

  String _visaStatusLabel(String s) {
    switch (s) {
      case 'approuve':   return 'Approuvé';
      case 'rejete':     return 'Rejeté';
      case 'en_cours':   return 'En traitement';
      case 'en_attente': return 'Soumise';
      default:           return 'Non demandé';
    }
  }

  IconData _visaStatusIcon(String s) {
    switch (s) {
      case 'approuve':   return Icons.check_circle_rounded;
      case 'rejete':     return Icons.cancel_rounded;
      case 'en_cours':   return Icons.pending_rounded;
      case 'en_attente': return Icons.send_rounded;
      default:           return Icons.hourglass_empty_rounded;
    }
  }

  Future<void> _forceRefresh() async {
    // Forcer un rechargement depuis le serveur Firestore
    await FirebaseFirestore.instance
        .collection('visas')
        .get(const GetOptions(source: Source.server));
    if (mounted) {
      setState(() => _refreshKey++);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Liste actualisée', style: GoogleFonts.poppins()),
        backgroundColor: AdminDS.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminDS.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AdminDS.primary,
        elevation: 0,
        toolbarHeight: 56,
        title: Row(children: [
          const Icon(Icons.airplane_ticket_rounded, color: AdminDS.gold, size: 22),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Demandes de Visa',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Suivi en temps réel',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10)),
          ]),
        ]),
        // ── Bouton actualiser ─────────────────────────────────────────────────
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _forceRefresh,
            tooltip: 'Actualiser la liste',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: AdminDS.primary,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['tous', 'en_attente', 'en_cours', 'approuve', 'rejete'].map((s) {
                  final isSelected = _filterStatut == s;
                  final label = s == 'tous' ? 'Tous' : _visaStatusLabel(s);
                  return GestureDetector(
                    onTap: () => setState(() => _filterStatut = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(label, style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: isSelected ? AdminDS.primary : Colors.white70)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // _refreshKey force la reconstruction du StreamBuilder sur refresh
        key: ValueKey(_refreshKey),
        stream: FirebaseFirestore.instance.collection('visas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AdminDS.primary));
          }
          var docs = snapshot.data?.docs ?? [];
          if (_filterStatut != 'tous') {
            docs = docs.where((d) => (d.data() as Map)['statut'] == _filterStatut).toList();
          }
          if (docs.isEmpty) {
            return RefreshIndicator(
              onRefresh: _forceRefresh,
              color: AdminDS.primary,
              child: ListView(children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.airplane_ticket_outlined, size: 64, color: AdminDS.textMuted.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('Aucune demande de visa', style: GoogleFonts.poppins(color: AdminDS.textMuted)),
                  const SizedBox(height: 8),
                  Text('Tirez vers le bas pour actualiser',
                      style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted.withValues(alpha: 0.6))),
                ]),
              ]),
            );
          }

          return RefreshIndicator(
            onRefresh: _forceRefresh,
            color: AdminDS.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final userId = doc.id;
                final statut = data['statut'] as String? ?? 'non_demandee';
                final dateDemande = (data['dateDemande'] as Timestamp?)?.toDate();
                final statusColor = _visaStatusColor(statut);

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('utilisateurs').doc(userId).get(),
                  builder: (context, userSnap) {
                    String nom = 'Utilisateur inconnu';
                    String email = '';
                    String initiales = '?';
                    if (userSnap.hasData && userSnap.data!.exists) {
                      final u = userSnap.data!.data() as Map<String, dynamic>;
                      final p = u['prenom'] as String? ?? '';
                      final n = u['nom'] as String? ?? '';
                      nom = '$p $n'.trim();
                      email = u['email'] as String? ?? '';
                      if (nom.isEmpty) nom = email;
                      initiales = '${p.isNotEmpty ? p[0] : ''}${n.isNotEmpty ? n[0] : ''}'.toUpperCase();
                      if (initiales.isEmpty) initiales = '?';
                    }

                    return GestureDetector(
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AdminVisaDetailScreen(userId: userId)));
                        // Après retour, forcer actualisation
                        if (mounted) _forceRefresh();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: AdminDS.cardDecor(),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            // Avatar
                            Container(width: 48, height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF9F67FA)]),
                                borderRadius: BorderRadius.circular(12)),
                              child: Center(child: Text(initiales,
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)))),
                            const SizedBox(width: 12),
                            // Infos
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(nom, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AdminDS.textDark)),
                              if (email.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.email_outlined, size: 12, color: AdminDS.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(email, style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted),
                                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ]),
                              ],
                              if (dateDemande != null) ...[
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.calendar_today_rounded, size: 11, color: AdminDS.textMuted),
                                  const SizedBox(width: 4),
                                  Text('${dateDemande.day.toString().padLeft(2,'0')}/${dateDemande.month.toString().padLeft(2,'0')}/${dateDemande.year}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted)),
                                ]),
                              ],
                            ])),
                            // Statut
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(_visaStatusIcon(statut), size: 12, color: statusColor),
                                  const SizedBox(width: 4),
                                  Text(_visaStatusLabel(statut),
                                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                                ]),
                              ),
                              const SizedBox(height: 6),
                              const Icon(Icons.chevron_right_rounded, color: AdminDS.textMuted, size: 18),
                            ]),
                          ]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
