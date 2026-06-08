// lib/services/deletion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DeletionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> deleteUserCompletely(
    String userId, {
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Suppression des candidatures…');

    // ── 1. Candidatures + sous-collections ────────────────────────────────
    try {
      final candidatures = await _db
          .collection('candidatures')
          .where('userId', isEqualTo: userId)
          .get();

      for (final candidatureDoc in candidatures.docs) {
        final candidatureId = candidatureDoc.id;

        try {
          final docsSnap = await _db
              .collection('candidatures')
              .doc(candidatureId)
              .collection('documents')
              .get();
          for (final d in docsSnap.docs) {
            await d.reference.delete();
          }
        } catch (e) {
          debugPrint('DeletionService: erreur docs $candidatureId: $e');
        }

        try {
          final paiements = await _db
              .collection('candidatures')
              .doc(candidatureId)
              .collection('paiements_semestre')
              .get();
          for (final p in paiements.docs) {
            await p.reference.delete();
          }
        } catch (e) {
          debugPrint('DeletionService: erreur paiements $candidatureId: $e');
        }

        await candidatureDoc.reference.delete();
      }
    } catch (e) {
      debugPrint('DeletionService: erreur candidatures userId=$userId: $e');
    }

    // ── 2. Visa + documentsComplementaires ────────────────────────────────
    onProgress?.call('Suppression du visa…');
    try {
      final visaRef = _db.collection('visas').doc(userId);
      final visaDoc = await visaRef.get();

      if (visaDoc.exists) {
        try {
          final complDocs = await visaRef
              .collection('documentsComplementaires')
              .get();
          for (final d in complDocs.docs) {
            await d.reference.delete();
          }
        } catch (e) {
          debugPrint('DeletionService: erreur documentsComplementaires: $e');
        }
        await visaRef.delete();
      }
    } catch (e) {
      debugPrint('DeletionService: erreur visa userId=$userId: $e');
    }

    // ── 3. Conversations ─────────────────────────────────────────────────
    try {
      final convs = await _db
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .get();
      for (final conv in convs.docs) {
        try {
          final msgs = await conv.reference.collection('messages').get();
          for (final m in msgs.docs) {
            await m.reference.delete();
          }
          await conv.reference.delete();
        } catch (e) {
          debugPrint('DeletionService: erreur conversation ${conv.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('DeletionService: erreur conversations: $e');
    }

    // ── 4. Document utilisateur Firestore (en dernier) ────────────────────
    onProgress?.call('Suppression du compte…');
    await _db.collection('utilisateurs').doc(userId).delete();

    debugPrint('DeletionService: userId=$userId supprimé.');
  }
}
