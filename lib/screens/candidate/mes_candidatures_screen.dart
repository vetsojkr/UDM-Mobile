import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../../services/candidature_service.dart';

class MesCandidaturesScreen extends StatelessWidget {
  MesCandidaturesScreen({super.key});

  final CandidatureService _candidatureService = CandidatureService();

  Future<void> _openDocument(BuildContext context, String url, String fileName) async {
    final uri = Uri.parse(url);
    final lowerUrl = url.toLowerCase();

    if (kIsWeb) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien'))
        );
      }
      return;
    }

    if (lowerUrl.endsWith('.jpg') || lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') || lowerUrl.endsWith('.webp')) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done && context.mounted) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        throw Exception('Téléchargement échoué');
      }
    } catch (e) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir ce fichier'))
        );
      }
    }
  }

  Future<void> _deleteCandidature(BuildContext context, String candidatureId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la candidature'),
        content: const Text('Voulez-vous vraiment supprimer cette candidature ?\nTous les documents seront définitivement perdus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _candidatureService.deleteCandidature(candidatureId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Candidature supprimée'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getStatusText(String statut) {
    switch (statut) {
      case 'soumis': return 'Soumis';
      case 'en_verification': return 'En vérification';
      case 'accepte': return 'Accepté';
      case 'refuse': return 'Refusé';
      default: return 'Brouillon';
    }
  }

  Color _getStatusColor(String statut) {
    switch (statut) {
      case 'soumis': return Colors.orange;
      case 'en_verification': return Colors.blue;
      case 'accepte': return Colors.green;
      case 'refuse': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Utilisateur non connecté')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Mes candidatures"), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('candidatures')
            .where('userId', isEqualTo: user.uid)
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
            return const Center(child: Text('Aucune candidature trouvée.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final candidature = docs[index];
              final data = candidature.data() as Map<String, dynamic>;
              final programme = data['programme'] ?? 'Programme inconnu';
              final statut = data['statut'] ?? 'brouillon';
              final dateSoumission = data['dateSoumission'] as Timestamp?;
              final paiementEffectue = data['paiementEffectue'] ?? false;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(statut).withValues(alpha: 0.2),
                    child: Icon(Icons.assignment, color: _getStatusColor(statut)),
                  ),
                  title: Text(
                    programme,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(statut).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusText(statut),
                              style: TextStyle(color: _getStatusColor(statut), fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (paiementEffectue)
                            const Chip(
                              label: Text('Payé'),
                              backgroundColor: Colors.green,
                              labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                      if (dateSoumission != null)
                        Text(
                          'Soumis le : ${dateSoumission.toDate().day}/${dateSoumission.toDate().month}/${dateSoumission.toDate().year}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteCandidature(context, candidature.id),
                        tooltip: 'Supprimer la candidature',
                      ),
                      const Icon(Icons.folder_open),
                    ],
                  ),
                  children: [
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Documents joints', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: candidature.reference.collection('documents').snapshots(),
                      builder: (context, docSnapshot) {
                        if (docSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ));
                        }
                        if (!docSnapshot.hasData || docSnapshot.data!.docs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Aucun document joint', style: TextStyle(fontStyle: FontStyle.italic)),
                          );
                        }
                        final docsList = docSnapshot.data!.docs;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docsList.length,
                          itemBuilder: (context, i) {
                            final docData = docsList[i].data() as Map<String, dynamic>;
                            final nomFichier = docData['nomFichier'] ?? 'Document';
                            final urlDoc = docData['url'] ?? '';
                            if (urlDoc.isEmpty) return const SizedBox();
                            return ListTile(
                              leading: const Icon(Icons.description, color: Colors.blue),
                              title: Text(nomFichier),
                              subtitle: Text('Type : ${docData['type'] ?? 'Inconnu'}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.visibility, color: Colors.blue),
                                onPressed: () => _openDocument(context, urlDoc, nomFichier),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}