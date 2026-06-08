// lib/screens/admin/admin_candidate_detail_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/user_service.dart';
import '../../services/candidature_service.dart';
import '../../services/deletion_service.dart';
import 'admin_home_screen.dart'; // AdminDS

class AdminCandidateDetailScreen extends StatefulWidget {
  final String userId;
  const AdminCandidateDetailScreen({super.key, required this.userId});

  @override
  State<AdminCandidateDetailScreen> createState() =>
      _AdminCandidateDetailScreenState();
}

class _AdminCandidateDetailScreenState extends State<AdminCandidateDetailScreen> {
  final UserService _userService = UserService();
  final CandidatureService _candidatureService = CandidatureService();
  final DeletionService _deletionService = DeletionService();
  bool _isUpgrading = false;

  Future<void> _openDocument(String url) async {
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL du document non disponible'), backgroundColor: Colors.orange));
      }
      return;
    }
    try {
      final uri = Uri.parse(url);
      bool launched = false;
      try { launched = await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
      if (!launched) {
        try { launched = await launchUrl(uri, mode: LaunchMode.inAppWebView); } catch (_) {}
      }
      if (!launched && mounted) { await launchUrl(uri, mode: LaunchMode.platformDefault); }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Impossible d\'ouvrir le document'),
          backgroundColor: AdminDS.danger, behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _promoteToStudent() async {
    setState(() => _isUpgrading = true);
    try {
      await FirebaseFirestore.instance
          .collection('utilisateurs').doc(widget.userId)
          .update({'role': 'etudiant'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Utilisateur promu étudiant ✓', style: GoogleFonts.poppins()),
          backgroundColor: AdminDS.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e', style: GoogleFonts.poppins()),
          backgroundColor: AdminDS.danger, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isUpgrading = false);
    }
  }

  Future<void> _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AdminDS.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.delete_outline_rounded, color: AdminDS.danger, size: 20)),
          const SizedBox(width: 10),
          Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Text(
          'Cette action est irréversible.\nToutes ses données seront supprimées.',
          style: GoogleFonts.poppins(color: AdminDS.textMuted, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminDS.danger, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _deletionService.deleteUserCompletely(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Utilisateur supprimé ✓', style: GoogleFonts.poppins()),
          backgroundColor: AdminDS.success, behavior: SnackBarBehavior.floating));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'), backgroundColor: AdminDS.danger));
      }
    }
  }

  String _statutLabel(String s) {
    switch (s) {
      case 'soumis': return 'Soumis';
      case 'en_verification': return 'En vérification';
      case 'accepte': return 'Accepté';
      case 'refuse': return 'Refusé';
      case 'brouillon': return 'Brouillon';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminDS.bg,
      body: FutureBuilder<DocumentSnapshot>(
        future: _userService.getUserData(widget.userId),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: AdminDS.primary)));
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return Scaffold(body: Center(child: Text('Utilisateur introuvable.',
              style: GoogleFonts.poppins(color: AdminDS.textMuted))));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final nom = userData['nom'] as String? ?? 'Inconnu';
          final prenom = userData['prenom'] as String? ?? '';
          final email = userData['email'] as String? ?? '';
          final telephone = userData['telephone'] as String? ?? 'Non renseigné';
          final role = userData['role'] as String? ?? 'candidat';
          final photoUrl = userData['photoUrl'] as String? ?? '';
          final fullName = '$prenom $nom'.trim();
          final initiales = '${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}'.toUpperCase();

          return FutureBuilder<List<QuerySnapshot>>(
            future: Future.wait([
              FirebaseFirestore.instance
                  .collection('candidatures')
                  .where('userId', isEqualTo: widget.userId)
                  .where('statut', isEqualTo: 'accepte')
                  .where('paiementEffectue', isEqualTo: true)
                  .get(),
              FirebaseFirestore.instance
                  .collection('candidatures')
                  .where('userId', isEqualTo: widget.userId)
                  .where('statut', isEqualTo: 'promu_etudiant')
                  .where('paiementEffectue', isEqualTo: true)
                  .get(),
            ]),
            builder: (context, paymentSnapshot) {
              final hasPaid = paymentSnapshot.hasData &&
                  paymentSnapshot.data!.any((qs) => qs.docs.isNotEmpty);

              return CustomScrollView(slivers: [
                // ── AppBar Hero ────────────────────────────────────────────────
                SliverAppBar(
                  pinned: true, expandedHeight: 200,
                  backgroundColor: AdminDS.primary,
                  actions: [
                    IconButton(
                      icon: Container(padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20)),
                      onPressed: _deleteUser),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(gradient: AdminDS.blueGrad),
                      child: Stack(children: [
                        Positioned(top: -30, right: 60,
                          child: Container(width: 120, height: 120,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                            Row(children: [
                              // ── Photo de profil ─────────────────────────────
                              Container(width: 60, height: 60,
                                decoration: BoxDecoration(
                                  gradient: AdminDS.goldGrad,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                                ),
                                child: ClipOval(child: photoUrl.isNotEmpty
                                  ? Image.network(photoUrl, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(child: Text(initiales,
                                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))))
                                  : Center(child: Text(initiales,
                                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))))),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(fullName.isNotEmpty ? fullName : 'Candidat',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                // ── Email bien visible ────────────────────────
                                Row(children: [
                                  const Icon(Icons.email_rounded, color: Colors.white70, size: 13),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(email,
                                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ]),
                                const SizedBox(height: 2),
                                // ── Téléphone bien visible ────────────────────
                                Row(children: [
                                  const Icon(Icons.phone_rounded, color: Colors.white70, size: 13),
                                  const SizedBox(width: 4),
                                  Text(telephone.isNotEmpty && telephone != 'Non renseigné' ? telephone : '—',
                                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                                ]),
                              ])),
                            ]),
                            const SizedBox(height: 8),
                            // Badge rôle
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: role == 'etudiant' ? AdminDS.success.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(role == 'etudiant' ? Icons.school_rounded : Icons.person_rounded,
                                  color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(role == 'etudiant' ? 'Étudiant' : 'Candidat',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                  title: Text('Détail du profil',
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(delegate: SliverChildListDelegate([

                    // ── Informations de contact ────────────────────────────────
                    _Section(title: 'Informations de contact', icon: Icons.contact_page_rounded, children: [
                      _InfoRow(icon: Icons.person_rounded, label: 'Nom complet', value: fullName.isNotEmpty ? fullName : '—', color: AdminDS.primary),
                      const Divider(height: 1, indent: 42),
                      _InfoRow(icon: Icons.email_rounded, label: 'Adresse email', value: email.isNotEmpty ? email : '—', color: AdminDS.purple),
                      const Divider(height: 1, indent: 42),
                      _InfoRow(icon: Icons.phone_rounded, label: 'Téléphone', value: telephone.isNotEmpty ? telephone : '—', color: AdminDS.success),
                    ]),
                    const SizedBox(height: 16),

                    // ── Promotion étudiant ─────────────────────────────────────
                    if (role == 'candidat') ...[
                      Container(
                        decoration: AdminDS.cardDecor(),
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: AdminDS.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.verified_user_rounded, color: AdminDS.success, size: 16)),
                            const SizedBox(width: 8),
                            Text('Promotion étudiant', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AdminDS.textDark)),
                          ]),
                          const SizedBox(height: 12),
                          if (!hasPaid)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AdminDS.warning.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AdminDS.warning.withValues(alpha: 0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.warning_amber_rounded, color: AdminDS.warning, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Promotion disponible uniquement après acceptation et paiement.',
                                  style: GoogleFonts.poppins(fontSize: 12, color: AdminDS.warning))),
                              ]),
                            ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isUpgrading || !hasPaid ? null : _promoteToStudent,
                              icon: _isUpgrading
                                  ? const SizedBox(width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.verified_user_rounded, size: 18),
                              label: Text('Promouvoir en étudiant', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminDS.success, foregroundColor: Colors.white,
                                disabledBackgroundColor: AdminDS.textMuted.withValues(alpha: 0.2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Candidatures ───────────────────────────────────────────
                    _Section(title: 'Candidatures', icon: Icons.assignment_rounded, children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: _userService.getUserCandidatures(widget.userId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(padding: EdgeInsets.all(12),
                              child: LinearProgressIndicator(color: AdminDS.primary));
                          }
                          final candidatures = snapshot.data?.docs ?? [];
                          if (candidatures.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(children: [
                                Icon(Icons.folder_open_rounded, color: AdminDS.textMuted.withValues(alpha: 0.4), size: 22),
                                const SizedBox(width: 10),
                                Text('Aucune candidature', style: GoogleFonts.poppins(color: AdminDS.textMuted)),
                              ]),
                            );
                          }
                          return Column(children: candidatures.map((candidature) {
                            final data = candidature.data() as Map<String, dynamic>;
                            final programme = data['programme'] as String? ?? 'Programme inconnu';
                            final statut = data['statut'] as String? ?? 'brouillon';
                            final paiement = data['paiementEffectue'] as bool? ?? false;
                            final candidatureId = candidature.id;

                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('visas')
                                  .doc(widget.userId)
                                  .get(),
                              builder: (context, visaSnapshot) {
                                final visaData = visaSnapshot.data?.data() as Map<String, dynamic>?;
                                final visaStatut = visaData?['statut'] as String? ?? '';
                                final visaApprouve = visaStatut == 'approuve';
                                final visaRefuse   = visaStatut == 'refuse';
                                final hasVisa      = visaStatut.isNotEmpty;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(color: AdminDS.bg, borderRadius: BorderRadius.circular(10)),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  title: Text(programme,
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AdminDS.textDark)),
                                  subtitle: Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                    // Badge statut candidature
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AdminDS.statusColor(statut).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6)),
                                      child: Text(_statutLabel(statut),
                                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600,
                                          color: AdminDS.statusColor(statut))),
                                    ),
                                    // Badge paiement
                                    if (paiement)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AdminDS.success.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6)),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          const Icon(Icons.payments_rounded, size: 9, color: AdminDS.success),
                                          const SizedBox(width: 3),
                                          Text('Payé',
                                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AdminDS.success)),
                                        ]),
                                      ),
                                    // Badge visa
                                    if (hasVisa)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (visaApprouve
                                              ? AdminDS.success
                                              : visaRefuse
                                                  ? AdminDS.danger
                                                  : AdminDS.warning)
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6)),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(
                                            visaApprouve
                                                ? Icons.flight_takeoff_rounded
                                                : visaRefuse
                                                    ? Icons.cancel_rounded
                                                    : Icons.hourglass_empty_rounded,
                                            size: 9,
                                            color: visaApprouve
                                                ? AdminDS.success
                                                : visaRefuse
                                                    ? AdminDS.danger
                                                    : AdminDS.warning,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            visaApprouve
                                                ? 'Visa approuvé'
                                                : visaRefuse
                                                    ? 'Visa refusé'
                                                    : 'Visa en cours',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: visaApprouve
                                                  ? AdminDS.success
                                                  : visaRefuse
                                                      ? AdminDS.danger
                                                      : AdminDS.warning,
                                            ),
                                          ),
                                        ]),
                                      ),
                                  ]),
                                  children: [
                                    FutureBuilder<QuerySnapshot>(
                                      future: _candidatureService.getDocumentsStream(candidatureId).first,
                                      builder: (context, docSnapshot) {
                                        if (docSnapshot.connectionState == ConnectionState.waiting) {
                                          return const Padding(padding: EdgeInsets.all(8),
                                            child: LinearProgressIndicator(color: AdminDS.primary));
                                        }
                                        final docs = docSnapshot.data?.docs ?? [];
                                        if (docs.isEmpty) {
                                          return Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text('Aucun document joint',
                                              style: GoogleFonts.poppins(fontSize: 12, color: AdminDS.textMuted)));
                                        }
                                        return Column(children: docs.map((doc) {
                                          final docData = doc.data() as Map<String, dynamic>;
                                          final url = docData['url'] as String? ?? '';
                                          return ListTile(
                                            dense: true,
                                            leading: Container(width: 32, height: 32,
                                              decoration: BoxDecoration(color: AdminDS.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                              child: const Icon(Icons.picture_as_pdf_rounded, color: AdminDS.danger, size: 16)),
                                            title: Text(docData['type'] ?? 'Document',
                                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AdminDS.textDark)),
                                            subtitle: Text(docData['nomFichier'] ?? '',
                                              style: GoogleFonts.poppins(fontSize: 10, color: AdminDS.textMuted),
                                              maxLines: 1, overflow: TextOverflow.ellipsis),
                                            trailing: url.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.open_in_new_rounded, color: AdminDS.primary, size: 18),
                                                  onPressed: () => _openDocument(url))
                                              : null,
                                          );
                                        }).toList());
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                              }, // fin FutureBuilder visa
                            );
                          }).toList());
                        },
                      ),
                    ]),
                    const SizedBox(height: 30),
                  ])),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}

// ── Widgets internes ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: AdminDS.cardDecor(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AdminDS.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AdminDS.primary, size: 16)),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AdminDS.textDark)),
        ]),
      ),
      const Divider(height: 1),
      Padding(padding: const EdgeInsets.all(14), child: Column(children: children)),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AdminDS.textMuted)),
        Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AdminDS.textDark)),
      ])),
    ]),
  );
}
