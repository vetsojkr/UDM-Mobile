import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'candidature_service.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CandidatureService _candidatureService = CandidatureService();

  /// Simule un paiement de 50 000 MUR pour une candidature acceptée
  Future<bool> processPayment({
    required String candidatureId,
    required String description,
    required String region,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    // Vérifier que la candidature existe et est acceptée
    final candidatureDoc = await _firestore.collection('candidatures').doc(candidatureId).get();
    if (!candidatureDoc.exists) throw Exception('Candidature introuvable');
    final data = candidatureDoc.data() as Map<String, dynamic>;
    if (data['statut'] != 'accepte') throw Exception('Cette candidature n\'est pas acceptée');
    if (data['paiementEffectue'] == true) throw Exception('Paiement déjà effectué');

    // Simulation délai réseau
    await Future.delayed(const Duration(seconds: 2));

    // Simulation échec aléatoire (10% pour test)
    if (DateTime.now().millisecondsSinceEpoch % 10 == 0) {
      throw Exception('Transaction refusée (simulation)');
    }

    // Enregistrer la transaction
    await _firestore.collection('transactions').add({
      'userId': user.uid,
      'candidatureId': candidatureId,
      'montant': 50000,
      'devise': 'MUR',
      'description': description,
      'statut': 'reussi',
      'date': FieldValue.serverTimestamp(),
    });

    // Marquer paiement effectué dans la candidature
    await _candidatureService.markPaymentDone(candidatureId, region: region);
    return true;
  }

  /// Vérifie si le paiement a été effectué pour une candidature
  Future<bool> hasPaid(String candidatureId) async {
    final doc = await _firestore.collection('candidatures').doc(candidatureId).get();
    if (!doc.exists) return false;
    return (doc.data() as Map<String, dynamic>)['paiementEffectue'] ?? false;
  }

  /// Historique des paiements de l'utilisateur
  Stream<QuerySnapshot> getPaymentHistory() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .snapshots();
  }
}