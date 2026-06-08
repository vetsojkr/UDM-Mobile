// lib/screens/admin/admin_candidature_detail_screen.dart
// Détail d'une candidature — redessiné

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_home_screen.dart'; // AdminDS
import '../../services/candidature_service.dart';

class AdminCandidatureDetailScreen extends StatefulWidget {
  final String candidatureId;
  const AdminCandidatureDetailScreen({super.key, required this.candidatureId});
  @override
  State<AdminCandidatureDetailScreen> createState() => _AdminCandidatureDetailScreenState();
}

class _AdminCandidatureDetailScreenState extends State<AdminCandidatureDetailScreen> {
  final CandidatureService _service = CandidatureService();
  bool _isUpdating = false;

  final _statutsOptions = const [
    {'value': 'soumis',           'label': 'Soumis'},
    {'value': 'en_verification',  'label': 'En vérification (Doyen)'},
    {'value': 'accepte',          'label': 'Accepté (SSE)'},
    {'value': 'refuse',           'label': 'Refusé'},
    {'value': 'promu_etudiant',   'label': 'Promu étudiant'},
  ];

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
      if (!launched && mounted) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le document: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteCandidature() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AdminDS.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.delete_outline_rounded, color: AdminDS.danger)),
          const SizedBox(width: 10),
          Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ]),
        content: Text('Cette action est irréversible. Supprimer définitivement cette candidature ?',
          style: GoogleFonts.poppins(color: AdminDS.textMuted, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminDS.danger, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) { return; }
    try {
      await _service.deleteCandidature(widget.candidatureId);
      if (mounted) {
        _showSnack('Candidature supprimée', AdminDS.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) { _showSnack('Erreur : $e', AdminDS.danger); }
    }
  }

  Future<void> _updateStatut(String newStatut) async {
    setState(() => _isUpdating = true);
    try {
      await _service.updateStatut(widget.candidatureId, newStatut);
      if (mounted) { _showSnack('Statut mis à jour : ${AdminDS.statusLabel(newStatut)}', AdminDS.success); }
    } catch (e) {
      if (mounted) { _showSnack('Erreur : $e', AdminDS.danger); }
    } finally {
      if (mounted) { setState(() => _isUpdating = false); }
    }
  }

  /// Promouvoir le candidat en étudiant avec confirmation
  Future<void> _promouvoirEtudiant() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.school_rounded, color: Color(0xFF7C3AED))),
          const SizedBox(width: 10),
          Text('Promouvoir en étudiant',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Voulez-vous promouvoir ce candidat au statut Étudiant ?',
            style: GoogleFonts.poppins(color: AdminDS.textDark, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2))),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Le statut passera à "Promu étudiant" et le candidat sera notifié dans son suivi.',
                style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted))),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.poppins())),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.school_rounded, size: 16),
            label: Text('Promouvoir', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _updateStatut('promu_etudiant');
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminDS.bg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('candidatures').doc(widget.candidatureId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: AdminDS.primary)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(body: Center(child: Text('Candidature introuvable.',
              style: GoogleFonts.poppins(color: AdminDS.textMuted))));
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final statut = data['statut'] as String? ?? 'soumis';
          final paiement = data['paiementEffectue'] as bool? ?? false;
          final nom = data['nom'] as String? ?? 'N/A';
          final prenom = data['prenom'] as String? ?? '';
          final email = data['email'] as String? ?? 'N/A';
          final tel = data['telephone'] as String? ?? 'N/A';
          final programme = data['programme'] as String? ?? 'N/A';
          final date = (data['dateSoumission'] as Timestamp?)?.toDate();
          final initiales = '${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}'.toUpperCase();

          return CustomScrollView(slivers: [
            // AppBar
            SliverAppBar(
              pinned: true, expandedHeight: 180,
              backgroundColor: AdminDS.primary,
              actions: [
                IconButton(
                  icon: Container(padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20)),
                  onPressed: _deleteCandidature),
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
                          Container(width: 52, height: 52,
                            decoration: BoxDecoration(gradient: AdminDS.goldGrad, borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5)),
                            child: Center(child: Text(initiales,
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)))),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('$prenom $nom', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            Text(programme, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (date != null) Text(
                              'Soumis le ${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}',
                              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
                          ])),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
              title: Text('Dossier candidature', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(delegate: SliverChildListDelegate([
                // ── Statut & Paiement ──────────────────────────────────────
                _Section(title: 'Statut du dossier', icon: Icons.assignment_turned_in_rounded, child: Column(children: [
                  // Sélecteur statut
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AdminDS.statusColor(statut).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminDS.statusColor(statut).withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: AdminDS.statusColor(statut).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                        child: Icon(AdminDS.statusIcon(statut), color: AdminDS.statusColor(statut), size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Statut actuel', style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted)),
                        Text(AdminDS.statusLabel(statut),
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AdminDS.statusColor(statut))),
                      ])),
                      if (_isUpdating)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AdminDS.primary))
                      else
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: statut,
                            icon: const Icon(Icons.edit_rounded, size: 18, color: AdminDS.primary),
                            style: GoogleFonts.poppins(fontSize: 13, color: AdminDS.textDark),
                            items: _statutsOptions.map((opt) => DropdownMenuItem(
                              value: opt['value'], child: Text(opt['label']!))).toList(),
                            onChanged: (v) { if (v != null) _updateStatut(v); },
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  // ── Bouton Promotion ─────────────────────────────────
                  if (statut == 'accepte' && paiement)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 2),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUpdating ? null : _promouvoirEtudiant,
                          icon: const Icon(Icons.school_rounded, size: 18),
                          label: Text('Promouvoir en étudiant',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  // Paiement
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: (paiement ? AdminDS.success : AdminDS.warning).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (paiement ? AdminDS.success : AdminDS.warning).withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Icon(paiement ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
                        color: paiement ? AdminDS.success : AdminDS.warning, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Paiement scolarité', style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted)),
                        Text(paiement ? 'Paiement confirmé' : 'En attente de paiement',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600,
                            color: paiement ? AdminDS.success : AdminDS.warning)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (paiement ? AdminDS.success : AdminDS.warning).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(paiement ? 'Payé' : 'Impayé',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700,
                            color: paiement ? AdminDS.success : AdminDS.warning)),
                      ),
                    ]),
                  ),
                ])),
                const SizedBox(height: 16),

                // ── Informations personnelles ─────────────────────────────
                _Section(title: 'Informations personnelles', icon: Icons.person_rounded, child: Column(children: [
                  _InfoRow(icon: Icons.person_rounded,  label: 'Nom complet',   value: '$prenom $nom', color: AdminDS.primary),
                  const Divider(height: 1, indent: 42, endIndent: 0),
                  _InfoRow(icon: Icons.email_rounded,   label: 'Email',         value: email, color: AdminDS.purple),
                  const Divider(height: 1, indent: 42, endIndent: 0),
                  _InfoRow(icon: Icons.phone_rounded,   label: 'Téléphone',     value: tel, color: AdminDS.success),
                  const Divider(height: 1, indent: 42, endIndent: 0),
                  _InfoRow(icon: Icons.school_rounded,  label: 'Programme',     value: programme, color: AdminDS.gold),
                ])),
                const SizedBox(height: 16),

                // ── Documents ─────────────────────────────────────────────
                _Section(title: 'Documents joints', icon: Icons.folder_rounded, child:
                  StreamBuilder<QuerySnapshot>(
                    stream: _service.getDocumentsStream(widget.candidatureId),
                    builder: (context, docSnap) {
                      if (!docSnap.hasData) {
                        return const Padding(padding: EdgeInsets.all(12),
                          child: LinearProgressIndicator(color: AdminDS.primary));
                      }
                      final docs = docSnap.data!.docs;
                      if (docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(children: [
                            Icon(Icons.folder_open_rounded, color: AdminDS.textMuted.withValues(alpha: 0.4), size: 24),
                            const SizedBox(width: 10),
                            Text('Aucun document téléversé.', style: GoogleFonts.poppins(color: AdminDS.textMuted)),
                          ]),
                        );
                      }
                      return Column(children: List.generate(docs.length, (i) {
                        final docData = docs[i].data() as Map<String, dynamic>;
                        final url = docData['url'] as String? ?? '';
                        final type = docData['type'] as String? ?? 'Fichier';
                        final fichier = docData['nomFichier'] as String? ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: AdminDS.bg, borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            Container(width: 36, height: 36,
                              decoration: BoxDecoration(color: AdminDS.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.picture_as_pdf_rounded, color: AdminDS.danger, size: 18)),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(type, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AdminDS.textDark)),
                              if (fichier.isNotEmpty) Text(fichier, style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            ])),
                            if (url.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.open_in_new_rounded, color: AdminDS.primary, size: 20),
                                onPressed: () => _openDocument(url)),
                          ]),
                        );
                      }));
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ])),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Widgets internes ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title; final IconData icon; final Widget child;
  const _Section({required this.title, required this.icon, required this.child});
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
      Padding(padding: const EdgeInsets.all(14), child: child),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
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