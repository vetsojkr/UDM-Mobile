import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'application_details_screen.dart';
import 'payment_screen.dart';
import 'visa_screen.dart';

class SuiviScreen extends StatelessWidget {
  const SuiviScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('Utilisateur non connecté')));
    }

    return Scaffold(
      appBar: AppBar(
          title: const Text('Suivi des candidatures'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('candidatures')
            .where('userId', isEqualTo: user.uid)
            .orderBy('dateSoumission', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Aucune candidature soumise.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc  = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final String statut           = data['statut'] ?? 'soumis';
              final bool   paiementEffectue = data['paiementEffectue'] ?? false;
              final String candidatureId    = doc.id;

              // ── Infos programme + année ──────────────────────────────────
              final String programme     = data['programme'] ?? 'Programme inconnu';
              final int    annee         = (data['anneeInscription'] as int?) ?? 1;
              final bool   isMaster      = programme.toLowerCase().contains('master');
              // Label d'année affiché dans la carte
              final String anneeLabel    = isMaster ? 'M$annee' : 'Année $annee';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ApplicationDetailsScreen(candidatureId: candidatureId),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── En-tête ────────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    programme,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  // ✅ Affiche l'année d'inscription
                                  Text(
                                    'Inscription en $anneeLabel',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () =>
                                  _confirmDeletion(context, candidatureId),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),
                        Text('Soumis le : ${_formatDate(data['dateSoumission'])}'),

                        // ── Barre de progression ───────────────────────────
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _getProgressValue(statut, paiementEffectue),
                              backgroundColor: Colors.grey.shade300,
                              color: _getStatusColor(statut, paiementEffectue),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _getStatusText(statut, paiementEffectue),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(statut, paiementEffectue),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 16),

                        // ── Promu étudiant ─────────────────────────────────
                        if (statut == 'promu_etudiant')
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Row(children: [
                                Icon(Icons.school_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Félicitations ! 🎓',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              const Text(
                                'Votre dossier a été validé et vous êtes officiellement '
                                'promu(e) au statut d\'étudiant(e) à l\'UDM. '
                                'Bienvenue !',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.5),
                              ),
                            ]),
                          ),

                        // ── Étape 1 : accepté, paiement requis ────────────
                        // ✅ PAS de montant affiché ici : la région n'est pas
                        //    encore choisie. Le candidat la choisira sur
                        //    l'écran PaymentScreen.
                        if (statut == 'accepte' && !paiementEffectue)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PaymentScreen()),
                              ),
                              icon: const Icon(Icons.payment),
                              label: const Text('Procéder au paiement des frais de scolarité'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),

                        // ── Étape 2 : paiement effectué → gestion visa ────
                        if (statut == 'accepte' && paiementEffectue)
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('visas')
                                .doc(user.uid)
                                .snapshots(),
                            builder: (context, visaSnap) {
                              final visaData = visaSnap.data?.data()
                                  as Map<String, dynamic>?;
                              final visaStatut =
                                  visaData?['statut'] as String? ??
                                      'non_demandee';
                              final visaApprouve = visaStatut == 'approuve';

                              if (visaApprouve) {
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.green.shade300),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Colors.green),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Visa approuvé ✅ — Votre inscription est en cours de finalisation.',
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                return SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const VisaScreen()),
                                    ),
                                    icon: const Icon(
                                        Icons.airplane_ticket_rounded),
                                    label: Text(
                                      visaStatut == 'non_demandee'
                                          ? 'Soumettre ma demande de visa'
                                          : 'Visa en cours (${_getVisaStatusText(visaStatut)})',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF003087),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Suppression ──────────────────────────────────────────────────────────
  Future<void> _confirmDeletion(BuildContext context, String docId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la candidature ?'),
        content: const Text(
            'Cette action est irréversible. Voulez-vous vraiment supprimer ce dossier ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('candidatures')
            .doc(docId)
            .delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Candidature supprimée avec succès')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur lors de la suppression : $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ── Helpers statut ────────────────────────────────────────────────────────
  double _getProgressValue(String statut, bool paiementEffectue) {
    switch (statut) {
      case 'soumis':          return 0.2;
      case 'en_verification': return 0.4;
      case 'accepte':         return paiementEffectue ? 0.85 : 0.6;
      case 'refuse':          return 1.0;
      case 'promu_etudiant':  return 1.0;
      default:                return 0.0;
    }
  }

  Color _getStatusColor(String statut, bool paiementEffectue) {
    switch (statut) {
      case 'soumis':          return Colors.orange;
      case 'en_verification': return Colors.blue;
      case 'accepte':         return paiementEffectue ? Colors.teal : Colors.green;
      case 'refuse':          return Colors.red;
      case 'promu_etudiant':  return const Color(0xFF7C3AED);
      default:                return Colors.grey;
    }
  }

  String _getStatusText(String statut, bool paiementEffectue) {
    switch (statut) {
      case 'soumis':          return 'Soumis';
      case 'en_verification': return 'En vérification';
      case 'accepte':
        return paiementEffectue
            ? 'Payé — Demande de visa'
            : 'Accepté — Paiement requis';
      case 'refuse':          return 'Refusé';
      case 'promu_etudiant':  return 'Promu étudiant 🎓';
      default:                return 'Inconnu';
    }
  }

  String _getVisaStatusText(String visaStatut) {
    switch (visaStatut) {
      case 'en_attente': return 'en attente';
      case 'en_cours':   return 'en traitement';
      case 'approuve':   return 'approuvé';
      case 'rejete':     return 'refusé';
      default:           return 'non demandé';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Date inconnue';
    if (timestamp is Timestamp) {
      final DateTime date = timestamp.toDate();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }
    return '$timestamp';
  }
}
