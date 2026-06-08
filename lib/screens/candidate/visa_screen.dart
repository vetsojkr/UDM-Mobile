// lib/screens/candidate/visa_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/cloudinary_service.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
class _VC {
  static const Color primary   = Color(0xFF003087);
  static const Color gold      = Color(0xFFE8A020);
  static const Color success   = Color(0xFF10B981);
  static const Color warning   = Color(0xFFF59E0B);
  static const Color danger    = Color(0xFFEF4444);
  static const Color purple    = Color(0xFF7C3AED);
  static const Color bg        = Color(0xFFF0F4FB);
  static const Color surface   = Colors.white;
  static const Color textDark  = Color(0xFF1A1A2E);
  static const Color textMuted = Color(0xFF6B7280);

  static LinearGradient get blueGrad => const LinearGradient(
    colors: [Color(0xFF001A5C), Color(0xFF003087), Color(0xFF1A4FAF)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  static BoxDecoration card({double radius = 14}) => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [BoxShadow(
        color: primary.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
class VisaScreen extends StatefulWidget {
  const VisaScreen({super.key});
  @override
  State<VisaScreen> createState() => _VisaScreenState();
}

class _VisaScreenState extends State<VisaScreen> {
  final List<String> _requiredDocs = [
    'Passeport valide',
    "Lettre d'admission",
    'Preuve de logement',
    'Casier judiciaire',
    'Attestation de ressources',
  ];

  final Map<String, bool>   _uploadedDocs     = {};
  final Map<String, String> _uploadedDocsUrls = {};
  final List<Map<String, dynamic>> _complementaryDocs = [];

  bool   _isLoading              = false;
  bool   _hasAcceptedApplication = false;
  String _visaStatus             = 'non_demandee';
  String _currentUserId          = '';

  // Données visa approuvé
  String?   _numeroVisa;
  DateTime? _dateExpiration;
  DateTime? _dateEmission;

  final CloudinaryService _cloudinary = CloudinaryService();

  @override
  void initState() {
    super.initState();
    for (final doc in _requiredDocs) {
      _uploadedDocs[doc]     = false;
      _uploadedDocsUrls[doc] = '';
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() { _isLoading = true; _currentUserId = user.uid; });
    try {
      final acceptedQuery = await FirebaseFirestore.instance
          .collection('candidatures')
          .where('userId', isEqualTo: _currentUserId)
          .where('statut', isEqualTo: 'accepte')
          .where('paiementEffectue', isEqualTo: true)
          .limit(1).get();
      if (mounted) {
        setState(() => _hasAcceptedApplication = acceptedQuery.docs.isNotEmpty);
      }
      if (!_hasAcceptedApplication) return;

      FirebaseFirestore.instance
          .collection('visas').doc(_currentUserId).snapshots().listen((doc) {
        if (!mounted) return;
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _visaStatus  = data['statut'] as String? ?? 'non_demandee';
            _numeroVisa  = data['numero']  as String?;
            if (data['expiration']  != null) {
              _dateExpiration = (data['expiration']  as Timestamp).toDate();
            }
            if (data['dateEmission'] != null) {
              _dateEmission   = (data['dateEmission'] as Timestamp).toDate();
            }
            if (data['documentsObligatoires'] != null) {
              _uploadedDocs.addAll(
                  Map<String, bool>.from(data['documentsObligatoires'] as Map));
            }
            if (data['documentsObligatoiresUrls'] != null) {
              _uploadedDocsUrls.addAll(
                  Map<String, String>.from(data['documentsObligatoiresUrls'] as Map));
            }
          });
        } else {
          setState(() => _visaStatus = 'non_demandee');
        }
      });

      FirebaseFirestore.instance
          .collection('visas').doc(_currentUserId)
          .collection('documentsComplementaires')
          .orderBy('dateUpload', descending: true)
          .snapshots().listen((snapshot) {
        if (mounted) {
          setState(() {
            _complementaryDocs
              ..clear()
              ..addAll(snapshot.docs.map((d) => d.data()));
          });
        }
      });
    } catch (e) {
      debugPrint('Erreur chargement: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadDocument(String type, {bool isComplementary = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || !mounted) return;
      setState(() => _isLoading = true);
      final file = result.files.single;
      String? url;
      if (kIsWeb) {
        if (file.bytes != null) { url = await _cloudinary.uploadBytes(file.bytes!, file.name); }
      } else {
        if (file.path  != null) { url = await _cloudinary.uploadFile(File(file.path!)); }
        else if (file.bytes != null) { url = await _cloudinary.uploadBytes(file.bytes!, file.name); }
      }
      if (url != null) {
        if (isComplementary) {
          await FirebaseFirestore.instance
              .collection('visas').doc(_currentUserId)
              .collection('documentsComplementaires').add({
            'nomFichier': file.name, 'type': type, 'url': url,
            'dateUpload': FieldValue.serverTimestamp(),
          });
        } else {
          setState(() { _uploadedDocs[type] = true; _uploadedDocsUrls[type] = url!; });
          await FirebaseFirestore.instance.collection('visas').doc(_currentUserId).set({
            'documentsObligatoires':     _uploadedDocs,
            'documentsObligatoiresUrls': _uploadedDocsUrls,
          }, SetOptions(merge: true));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8), Text('$type téléversé'),
            ]),
            backgroundColor: _VC.success, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } else {
        throw Exception("Échec de l'upload");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'), backgroundColor: _VC.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitVisaRequest() async {
    if (_visaStatus != 'non_demandee') return;
    final missing = _requiredDocs.where((d) => !(_uploadedDocs[d] ?? false)).toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Documents manquants : ${missing.join(', ')}'),
        backgroundColor: _VC.danger, behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('visas').doc(_currentUserId).set({
        'statut': 'en_attente',
        'dateDemande': FieldValue.serverTimestamp(),
        'documentsObligatoires':     _uploadedDocs,
        'documentsObligatoiresUrls': _uploadedDocsUrls,
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Demande de visa envoyée ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers statut ──────────────────────────────────────────────────────────
  String   _statusText (String s) {
    switch (s) {
      case 'non_demandee': return 'Non demandé';
      case 'en_attente':   return 'En attente';
      case 'en_cours':     return 'En traitement';
      case 'approuve':     return 'Approuvé ✓';
      case 'rejete':       return 'Refusé';
      default:             return 'Inconnu';
    }
  }
  Color    _statusColor(String s) {
    switch (s) {
      case 'non_demandee': return _VC.textMuted;
      case 'en_attente':   return _VC.warning;
      case 'en_cours':     return _VC.purple;
      case 'approuve':     return _VC.success;
      case 'rejete':       return _VC.danger;
      default:             return _VC.textMuted;
    }
  }
  IconData _statusIcon (String s) {
    switch (s) {
      case 'approuve':   return Icons.check_circle_rounded;
      case 'rejete':     return Icons.cancel_rounded;
      case 'en_attente': return Icons.pending_rounded;
      case 'en_cours':   return Icons.hourglass_top_rounded;
      default:           return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _currentUserId.isEmpty) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: _VC.primary)));
    }
    if (!_hasAcceptedApplication) {
      return Scaffold(
        backgroundColor: _VC.bg,
        body: CustomScrollView(slivers: [
          _buildSliverAppBar(),
          SliverFillRemaining(child: Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: _VC.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: Icon(Icons.airplane_ticket_outlined, size: 56,
                    color: _VC.primary.withValues(alpha: 0.4))),
              const SizedBox(height: 20),
              Text('Service visa non disponible',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _VC.textDark)),
              const SizedBox(height: 8),
              Text('Accessible après acceptation de votre candidature et confirmation de votre paiement.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 13, color: _VC.textMuted)),
            ]),
          ))),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: _VC.bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _VC.primary))
          : CustomScrollView(slivers: [
              _buildSliverAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(delegate: SliverChildListDelegate([

                  // ── Statut ────────────────────────────────────────────────
                  _buildStatusCard(),
                  const SizedBox(height: 20),

                  // ── VISA APPROUVÉ → carte de confirmation ─────────────────
                  if (_visaStatus == 'approuve') ...[
                    _buildApprovedCard(),
                    const SizedBox(height: 20),
                  ],

                  // ── Documents obligatoires ────────────────────────────────
                  const _SectionHeader(
                      icon: Icons.folder_rounded, title: 'Documents obligatoires'),
                  const SizedBox(height: 10),
                  ..._requiredDocs.map((doc) => _DocTile(
                    doc: doc,
                    isUploaded: _uploadedDocs[doc] ?? false,
                    onUpload: _visaStatus == 'non_demandee'
                        ? () => _uploadDocument(doc)
                        : null,
                  )),

                  // ── Bouton soumettre ──────────────────────────────────────
                  if (_visaStatus == 'non_demandee') ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.send_rounded),
                        label: Text('Soumettre la demande de visa',
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _VC.primary, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _submitVisaRequest,
                      ),
                    ),
                  ],

                  // ── Documents complémentaires (après soumission) ──────────
                  if (_visaStatus != 'non_demandee') ...[
                    const SizedBox(height: 20),
                    _ComplementarySection(
                      docs: _complementaryDocs,
                      onUpload: () => _uploadDocument('Complément', isComplementary: true),
                    ),
                  ],

                  const SizedBox(height: 30),
                ])),
              ),
            ]),
    );
  }

  // ── Carte de confirmation visa approuvé ─────────────────────────────────────
  Widget _buildApprovedCard() {
    final fmt = DateFormat('dd MMMM yyyy', 'fr');
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF10B981)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: _VC.success.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // En-tête
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, color: Colors.white, size: 26)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Visa enregistré !',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Votre demande de visa a été approuvée et enregistrée.',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
          ])),
        ]),

        const SizedBox(height: 16),
        Divider(color: Colors.white.withValues(alpha: 0.25)),
        const SizedBox(height: 12),

        // Détails du visa
        if (_numeroVisa != null && _numeroVisa!.isNotEmpty)
          _ApprovedInfoRow(
            icon: Icons.confirmation_number_rounded,
            label: 'Numéro de visa',
            value: _numeroVisa!,
          ),
        if (_dateEmission != null)
          _ApprovedInfoRow(
            icon: Icons.play_circle_rounded,
            label: "Date d'émission",
            value: fmt.format(_dateEmission!),
          ),
        if (_dateExpiration != null) ...[
          _ApprovedInfoRow(
            icon: Icons.event_rounded,
            label: "Date d'expiration",
            value: fmt.format(_dateExpiration!),
          ),
          const SizedBox(height: 8),
          // Jours restants
          Builder(builder: (_) {
            final remaining = _dateExpiration!.difference(DateTime.now()).inDays;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.timer_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    remaining > 0
                        ? '$remaining jours restants avant expiration'
                        : 'Visa expiré — contactez l\'administration',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    softWrap: true,
                  ),
                ),
              ]),
            );
          }),
        ],

        // Message si pas encore de dates (admin pas encore renseigné)
        if (_dateExpiration == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                "Les détails de votre visa (dates, numéro) seront communiqués par l'administration.",
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
            ]),
          ),
      ]),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true, expandedHeight: 120,
      backgroundColor: _VC.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: _VC.blueGrad),
          child: Stack(children: [
            Positioned(top: -30, right: -30,
              child: Container(width: 150, height: 150,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: _VC.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.airplane_ticket_rounded, color: _VC.gold, size: 22)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Visa Étudiant',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('Suivi de votre demande',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                  ]),
                ]),
              ]),
            ),
          ]),
        ),
      ),
      title: Text('Visa Étudiant',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatusCard() {
    if (_visaStatus == 'rejete') {
      return Container(
        decoration: _VC.card(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(
                  color: _VC.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.cancel_rounded, color: _VC.danger, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Statut de la demande',
                  style: GoogleFonts.poppins(fontSize: 11, color: _VC.textMuted)),
              Text('Demande refusée',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700, color: _VC.danger)),
            ])),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _VC.danger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _VC.danger.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: _VC.danger, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                "Votre demande de visa a été refusée. Veuillez contacter l'administration.",
                style: GoogleFonts.poppins(fontSize: 12, color: _VC.danger))),
            ]),
          ),
        ]),
      );
    }

    final steps      = ['non_demandee', 'en_attente', 'en_cours', 'approuve'];
    final stepIdx    = steps.indexOf(_visaStatus).clamp(0, steps.length - 1);
    final stepLabels = ['Demande', 'En attente', 'Traitement', 'Approuvé'];

    return Container(
      decoration: _VC.card(),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
                color: _statusColor(_visaStatus).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(_statusIcon(_visaStatus), color: _statusColor(_visaStatus), size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Statut de la demande',
                style: GoogleFonts.poppins(fontSize: 11, color: _VC.textMuted)),
            Text(_statusText(_visaStatus),
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: _statusColor(_visaStatus))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: _statusColor(_visaStatus).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text('Étape ${stepIdx + 1}/${steps.length}',
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: _statusColor(_visaStatus))),
          ),
        ]),
        const SizedBox(height: 20),
        Row(children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(child: Container(height: 2,
                color: (i ~/ 2) < stepIdx ? _VC.success : _VC.bg));
          }
          final idx       = i ~/ 2;
          final isDone    = idx < stepIdx;
          final isCurrent = idx == stepIdx;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: isDone ? _VC.success
                    : isCurrent ? _statusColor(_visaStatus) : _VC.bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? _VC.success
                      : isCurrent ? _statusColor(_visaStatus) : const Color(0xFFD1D5DB),
                  width: 2),
              ),
              child: Center(child: isDone
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : isCurrent
                      ? Container(width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle))
                      : null),
            ),
            const SizedBox(height: 4),
            Text(stepLabels[idx], style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
              color: isCurrent ? _statusColor(_visaStatus) : _VC.textMuted)),
          ]);
        })),
      ]),
    );
  }
}

// ── Widget ligne d'info dans la carte approuvé ───────────────────────────────
class _ApprovedInfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ApprovedInfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, color: Colors.white70, size: 16),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10)),
        Text(value, style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS PARTAGÉS
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon; final String title;
  const _SectionHeader({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
          color: _VC.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: _VC.primary, size: 16)),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.poppins(
        fontSize: 15, fontWeight: FontWeight.w600, color: _VC.textDark)),
  ]);
}

class _DocTile extends StatelessWidget {
  final String doc;
  final bool isUploaded;
  final VoidCallback? onUpload;
  const _DocTile({required this.doc, required this.isUploaded, required this.onUpload});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: _VC.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: isUploaded
              ? _VC.success.withValues(alpha: 0.3) : const Color(0xFFE5E7EB)),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(width: 36, height: 36,
        decoration: BoxDecoration(
            color: (isUploaded ? _VC.success : _VC.textMuted).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(
            isUploaded ? Icons.check_circle_rounded : Icons.upload_file_rounded,
            color: isUploaded ? _VC.success : _VC.textMuted, size: 18)),
      title: Text(doc, style: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w500, color: _VC.textDark)),
      subtitle: Text(isUploaded ? 'Document prêt ✓' : 'En attente',
          style: GoogleFonts.poppins(fontSize: 11,
              color: isUploaded ? _VC.success : _VC.warning)),
      trailing: onUpload != null
          ? GestureDetector(
              onTap: onUpload,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: isUploaded
                        ? _VC.primary.withValues(alpha: 0.08) : _VC.primary,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(isUploaded ? 'Modifier' : 'Ajouter',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600,
                      color: isUploaded ? _VC.primary : Colors.white)),
              ))
          : null,
    ),
  );
}

class _ComplementarySection extends StatelessWidget {
  final List<Map<String, dynamic>> docs;
  final VoidCallback onUpload;
  const _ComplementarySection({required this.docs, required this.onUpload});

  String _fmtDate(dynamic ts) {
    if (ts == null) return '...';
    if (ts is Timestamp) return DateFormat('dd/MM/yyyy HH:mm').format(ts.toDate());
    return ts.toString();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _SectionHeader(icon: Icons.attach_file_rounded, title: 'Documents complémentaires'),
    const SizedBox(height: 6),
    Text("Ajoutez tout document supplémentaire demandé par l'administration.",
        style: GoogleFonts.poppins(fontSize: 12, color: _VC.textMuted)),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: onUpload,
      icon: const Icon(Icons.add_rounded),
      label: Text('Ajouter un document',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _VC.primary,
        side: const BorderSide(color: _VC.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    const SizedBox(height: 12),
    if (docs.isEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('Aucun document complémentaire.',
            style: GoogleFonts.poppins(color: _VC.textMuted, fontSize: 13))),
      )
    else
      ...docs.map((doc) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6, offset: const Offset(0, 2))]),
        child: ListTile(
          leading: Container(width: 36, height: 36,
            decoration: BoxDecoration(
                color: _VC.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.description_rounded, color: _VC.purple, size: 18)),
          title: Text(doc['nomFichier'] as String? ?? 'Document',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
          subtitle: Text('Ajouté le ${_fmtDate(doc['dateUpload'])}',
              style: GoogleFonts.poppins(fontSize: 11, color: _VC.textMuted)),
          trailing: const Icon(Icons.chevron_right_rounded, color: _VC.textMuted),
        ),
      )),
  ]);
}
