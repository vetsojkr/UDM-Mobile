import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CandidatureService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Récupération ---
  Future<DocumentSnapshot?> getCurrentCandidature() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final snapshot = await _firestore
        .collection('candidatures')
        .where('userId', isEqualTo: user.uid)
        .where('statut', isNotEqualTo: 'brouillon')
        .orderBy('statut')
        .orderBy('dateCreation', descending: true)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty ? snapshot.docs.first : null;
  }

  Future<DocumentSnapshot?> getCurrentDraft() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final snapshot = await _firestore
        .collection('candidatures')
        .where('userId', isEqualTo: user.uid)
        .where('statut', isEqualTo: 'brouillon')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty ? snapshot.docs.first : null;
  }

  Future<String> createDraft({
    required String nom,
    required String email,
    required String telephone,
    required String programme,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final docRef = await _firestore.collection('candidatures').add({
      'userId': user?.uid,
      'nom': nom,
      'email': email,
      'telephone': telephone,
      'programme': programme,
      'statut': 'brouillon',
      'paiementEffectue': false,
      'dateCreation': FieldValue.serverTimestamp(),
      'dateModification': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateDraft(String candidatureId, Map<String, dynamic> data) async {
    data['dateModification'] = FieldValue.serverTimestamp();
    await _firestore.collection('candidatures').doc(candidatureId).update(data);
  }

  // --- Documents ---
  Future<void> addDocument({
    required String candidatureId,
    required String nomFichier,
    required String type,
    required String url,
  }) async {
    await _firestore
        .collection('candidatures')
        .doc(candidatureId)
        .collection('documents')
        .add({
      'nomFichier': nomFichier,
      'type': type,
      'url': url,
      'dateUpload': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getDocumentsStream(String candidatureId) {
    return _firestore
        .collection('candidatures')
        .doc(candidatureId)
        .collection('documents')
        .orderBy('dateUpload', descending: true)
        .snapshots();
  }

  Future<bool> hasAllRequiredDocuments(String candidatureId) async {
    final snapshot = await _firestore
        .collection('candidatures')
        .doc(candidatureId)
        .collection('documents')
        .get();
    final existingTypes = snapshot.docs.map((d) => d['type'] as String).toSet();
    const required = {'CV', 'Diplôme', 'Passeport', 'Lettre de motivation'};
    return required.every((type) => existingTypes.contains(type));
  }

  // --- Statuts simplifiés ---
  Future<void> updateStatut(String candidatureId, String newStatut) async {
    await _firestore.collection('candidatures').doc(candidatureId).update({
      'statut': newStatut,
      'dateModification': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitCandidature(String candidatureId) async {
    await updateStatut(candidatureId, 'soumis');
    await _firestore.collection('candidatures').doc(candidatureId).update({
      'dateSoumission': FieldValue.serverTimestamp(),
    });
  }

  // --- Paiement ---
  Future<void> markPaymentDone(String candidatureId, {String region = 'SADC'}) async {
    await _firestore.collection('candidatures').doc(candidatureId).update({
      'paiementEffectue': true,
      'region': region,
      'datePaiement': FieldValue.serverTimestamp(),
    });
  }

  // --- Suppression candidature ---
  Future<void> deleteCandidature(String candidatureId) async {
    final docRef = _firestore.collection('candidatures').doc(candidatureId);
    // Supprimer les sous-collections (documents)
    final docs = await docRef.collection('documents').get();
    for (var doc in docs.docs) {
      await doc.reference.delete();
    }
    await docRef.delete();
  }
}