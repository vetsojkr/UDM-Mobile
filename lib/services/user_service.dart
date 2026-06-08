import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // === Méthodes pour l'authentification et l'utilisateur courant ===
  
  String? getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  /// Récupère les données de l'utilisateur actuellement connecté
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = getCurrentUser();
    if (user == null) return null;
    final doc = await getUserData(user.uid);
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }
    return null;
  }

  // === Méthodes Firestore ===

  Future<DocumentSnapshot> getUserData(String uid) async {
    return await _firestore.collection('utilisateurs').doc(uid).get();
  }

  Stream<QuerySnapshot> getUsersByRole(String role) {
    return _firestore
        .collection('utilisateurs')
        .where('role', isEqualTo: role)
        .snapshots();
  }

  Future<void> createUser({
    required String uid,
    required String email,
    required String nom,
    required String prenom,
    String telephone = '',
    required String role,
    DateTime? dateNaissance, // nouveau champ optionnel
  }) async {
    final Map<String, dynamic> data = {
      'uid': uid,
      'email': email,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'role': role,
      'dateCreation': FieldValue.serverTimestamp(),
    };
    if (dateNaissance != null) {
      data['dateNaissance'] = Timestamp.fromDate(dateNaissance);
    }
    await _firestore.collection('utilisateurs').doc(uid).set(data);
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    await _firestore.collection('utilisateurs').doc(uid).update({
      'role': newRole,
    });
  }

  Future<void> deleteUserDocument(String uid) async {
    await _firestore.collection('utilisateurs').doc(uid).delete();
  }

  Stream<QuerySnapshot> getUserCandidatures(String uid) {
    return _firestore
        .collection('candidatures')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  Future<void> updateUserProfile({
    required String uid,
    String? nom,
    String? prenom,
    String? telephone,
    DateTime? dateNaissance,
  }) async {
    Map<String, dynamic> data = {};
    if (nom != null) data['nom'] = nom;
    if (prenom != null) data['prenom'] = prenom;
    if (telephone != null) data['telephone'] = telephone;
    if (dateNaissance != null) data['dateNaissance'] = Timestamp.fromDate(dateNaissance);
    if (data.isNotEmpty) {
      await _firestore.collection('utilisateurs').doc(uid).update(data);
    }
  }
}