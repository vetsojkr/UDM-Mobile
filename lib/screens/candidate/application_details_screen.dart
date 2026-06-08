// screens/candidate/application_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicationDetailsScreen extends StatelessWidget {
  final String candidatureId;

  const ApplicationDetailsScreen({super.key, required this.candidatureId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Détail de la candidature"),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('candidatures').doc(candidatureId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Candidature introuvable'));
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String statut = data['statut'] ?? 'inconnu';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Programme : ${data['programme'] ?? ''}'),
                        Text('Nom : ${data['nom'] ?? ''}'),
                        Text('Email : ${data['email'] ?? ''}'),
                        Text('Téléphone : ${data['telephone'] ?? ''}'),
                        Text('Statut : $statut'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('candidatures')
                      .doc(candidatureId)
                      .collection('documents')
                      .snapshots(),
                  builder: (context, docSnapshot) {
                    if (!docSnapshot.hasData) return const SizedBox();
                    final docs = docSnapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Text('Aucun document');
                    }
                    return Column(
                      children: docs.map((doc) {
                        final docData = doc.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(docData['nomFichier'] ?? 'Document'),
                          subtitle: Text('Type : ${docData['type']}'),
                          trailing: const Icon(Icons.visibility),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}