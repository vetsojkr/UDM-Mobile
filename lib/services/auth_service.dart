import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Inscription avec email/mot de passe + envoi de vérification
  Future<User?> registerWithEmailAndPassword({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    DateTime? dateNaissance,
    required String role,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      await user?.sendEmailVerification();

      if (user != null) {
        await _firestore.collection('utilisateurs').doc(user.uid).set({
          'prenom': firstName,
          'nom': lastName,
          'email': email,
          'telephone': phone ?? '',
          'dateNaissance': dateNaissance != null ? Timestamp.fromDate(dateNaissance) : null,
          'role': role,
          'photoUrl': '',
          'isEmailVerified': false,
          'status': 'actif',
          'dateCreation': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw _getFirebaseAuthErrorMessage(e);
    } catch (e) {
      throw 'Une erreur inattendue s\'est produite. Réessayez.';
    }
  }

  /// Connexion
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _getFirebaseAuthErrorMessage(e);
    } catch (e) {
      throw 'Une erreur inattendue s\'est produite. Réessayez.';
    }
  }

  /// Envoi d'email de réinitialisation
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _getFirebaseAuthErrorMessage(e);
    } catch (e) {
      throw 'Impossible d\'envoyer l\'email. Réessayez.';
    }
  }

  /// Renvoyer l'email de vérification
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Recharger l'utilisateur
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Récupérer le rôle depuis Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('utilisateurs').doc(uid).get();
      if (doc.exists) {
        return doc.get('role') as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Marquer l'utilisateur comme en ligne
  Future<void> setOnline() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('utilisateurs').doc(user.uid).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Marquer l'utilisateur comme hors ligne
  Future<void> setOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('utilisateurs').doc(user.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

    /// Déconnexion
  Future<void> signOut() async {
    await setOffline();
    await _auth.signOut();
  }

  /// Traduction des erreurs Firebase en français
  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      // Inscription
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé par un autre compte.';
      case 'invalid-email':
        return 'L\'adresse email n\'est pas valide.';
      case 'weak-password':
        return 'Le mot de passe est trop faible (6 caractères minimum).';
      
      // Connexion
      case 'user-not-found':
        return 'Aucun compte associé à cet email. Vérifiez votre adresse email.';
      case 'wrong-password':
        return 'Mot de passe incorrect. Vérifiez vos identifiants.';
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect. Vérifiez vos identifiants.';
      case 'user-disabled':
        return 'Ce compte a été désactivé. Contactez l\'administrateur.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      
      default:
        return 'Erreur : ${e.message}';
    }
  }
}