import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_home_screen.dart'; // AdminDS

class AdminVisaDetailScreen extends StatefulWidget {
  final String userId;
  const AdminVisaDetailScreen({super.key, required this.userId});

  @override
  State<AdminVisaDetailScreen> createState() => _AdminVisaDetailScreenState();
}

class _AdminVisaDetailScreenState extends State<AdminVisaDetailScreen> {
  final List<Map<String, String>> _statutsOptions = [
    {'value': 'non_demandee', 'label': 'Non demandée'},
    {'value': 'en_attente',   'label': 'Soumise'},
    {'value': 'en_cours',     'label': 'En traitement'},
    {'value': 'approuve',     'label': 'Approuvé'},
    {'value': 'rejete',       'label': 'Refusé'},
  ];

  final _numeroController   = TextEditingController();
  DateTime? _dateEmission;
  DateTime? _dateExpiration;
  bool _isSavingDates = false;

  @override
  void dispose() {
    _numeroController.dispose();
    super.dispose();
  }

  String _normaliseStatut(String raw) {
    const mapping = {
      'refuse': 'rejete', 'refusé': 'rejete',
      'en_traitement': 'en_cours', 'soumise': 'en_attente',
      'non_demande': 'non_demandee',
    };
    return mapping[raw] ?? raw;
  }

  Future<void> _openDocument(String url, String docName) async {
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aucune URL pour $docName'), backgroundColor: Colors.orange));
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
          SnackBar(content: Text('Impossible d\'ouvrir $docName'), backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _updateVisaStatus(String newStatus) async {
    await FirebaseFirestore.instance.collection('visas').doc(widget.userId).update({
      'statut': newStatus,
      'dateModification': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Statut mis à jour', style: GoogleFonts.poppins()),
        backgroundColor: AdminDS.success, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _saveVisaDates() async {
    if (_dateEmission == null || _dateExpiration == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez renseigner les deux dates'), backgroundColor: Colors.orange));
      return;
    }
    if (_dateExpiration!.isBefore(_dateEmission!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La date d\'expiration doit être après la date d\'émission'),
        backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSavingDates = true);
    try {
      final data = <String, dynamic>{
        'dateEmission': Timestamp.fromDate(_dateEmission!),
        'expiration':   Timestamp.fromDate(_dateExpiration!),
        'dateModification': FieldValue.serverTimestamp(),
        'statut': 'approuve',
      };
      if (_numeroController.text.trim().isNotEmpty) {
        data['numero'] = _numeroController.text.trim();
      }
      await FirebaseFirestore.instance.collection('visas').doc(widget.userId)
          .set(data, SetOptions(merge: true));

      // ────────────────────────────────────────────────────────────────────────

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Visa enregistré avec succès ✓',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AdminDS.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSavingDates = false);
    }
  }

  // Méthode corrigée avec le bon import
  Future<void> _pickDate(BuildContext context, bool isEmission) async {
    final now = DateTime.now();
    final initial = isEmission
        ? (_dateEmission ?? now)
        : (_dateExpiration ?? now.add(const Duration(days: 365)));
    final first = isEmission ? DateTime(2020) : (_dateEmission ?? DateTime(2020));
    final last  = DateTime(2035);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      locale: const Locale('fr', 'FR'),
      builder: (ctx, child) {
        return Localizations.override(
          context: ctx,
          locale: const Locale('fr', 'FR'),
          delegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          child: Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFF003087))),
            child: child!,
          ),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isEmission) {
          _dateEmission = picked;
        } else {
          _dateExpiration = picked;
        }
      });
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approuve':   return AdminDS.success;
      case 'rejete':     return AdminDS.danger;
      case 'en_cours':   return AdminDS.warning;
      case 'en_attente': return AdminDS.primaryLight;
      default:           return AdminDS.textMuted;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'approuve':   return 'Approuvé';
      case 'rejete':     return 'Refusé';
      case 'en_cours':   return 'En traitement';
      case 'en_attente': return 'Soumise';
      default:           return 'Non demandée';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Scaffold(
      backgroundColor: AdminDS.bg,
      appBar: AppBar(
        title: Text('Détail de la demande de visa',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: AdminDS.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true, elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('visas').doc(widget.userId).snapshots(),
        builder: (context, visaSnapshot) {
          if (visaSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AdminDS.primary));
          }

          Map<String, dynamic> visaData = {};
          bool visaExists = false;
          if (visaSnapshot.hasData && visaSnapshot.data!.exists) {
            visaData = visaSnapshot.data!.data() as Map<String, dynamic>;
            visaExists = true;
          }

          final rawStatut   = visaData['statut'] as String? ?? 'non_demandee';
          final currentStatut = _normaliseStatut(rawStatut);
          if (visaExists && rawStatut != currentStatut) {
            FirebaseFirestore.instance.collection('visas').doc(widget.userId)
                .update({'statut': currentStatut});
          }

          final numeroVisa  = visaData['numero']       as String? ?? '';
          final expiration  = visaData['expiration']   as Timestamp?;
          final dateEmission = visaData['dateEmission'] as Timestamp?;
          final dateDemande = visaData['dateDemande']  as Timestamp?;
          final documentsObligatoires     = visaData['documentsObligatoires']     as Map<String, dynamic>? ?? {};
          final documentsObligatoiresUrls = visaData['documentsObligatoiresUrls'] as Map<String, dynamic>? ?? {};
          final statusColor = _statusColor(currentStatut);

          if (_dateEmission == null && dateEmission != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) { setState(() => _dateEmission = dateEmission.toDate()); }
            });
          }
          if (_dateExpiration == null && expiration != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) { setState(() => _dateExpiration = expiration.toDate()); }
            });
          }
          if (_numeroController.text.isEmpty && numeroVisa.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) { _numeroController.text = numeroVisa; }
            });
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('utilisateurs').doc(widget.userId).get(),
            builder: (context, userSnapshot) {
              String userName = 'Utilisateur';
              String initials = '?';
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final u = userSnapshot.data!.data() as Map<String, dynamic>;
                final p = (u['prenom'] as String? ?? '').trim();
                final n = (u['nom']    as String? ?? '').trim();
                userName = '$p $n'.trim();
                if (userName.isEmpty) userName = u['email'] as String? ?? 'Sans nom';
                initials = '${p.isNotEmpty ? p[0] : ''}${n.isNotEmpty ? n[0] : ''}'.toUpperCase();
                if (initials.isEmpty) initials = '?';
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Carte demandeur + statut
                  Container(
                    decoration: AdminDS.cardDecor(),
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Container(width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF9F67FA)]),
                              borderRadius: BorderRadius.circular(12)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: (userSnapshot.hasData && userSnapshot.data!.exists &&
                                      ((userSnapshot.data!.data() as Map<String,dynamic>)['photoUrl'] as String? ?? '').isNotEmpty)
                                  ? Image.network(
                                      (userSnapshot.data!.data() as Map<String,dynamic>)['photoUrl'] as String,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(child: Text(initials,
                                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))))
                                  : Center(child: Text(initials,
                                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
                            )),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(userName, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AdminDS.textDark)),
                            if (dateDemande != null) Row(children: [
                              const Icon(Icons.calendar_today_rounded, size: 11, color: AdminDS.textMuted),
                              const SizedBox(width: 4),
                              Text('Demande le ${fmt.format(dateDemande.toDate())}',
                                style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted)),
                            ]),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                            child: Text(_statusLabel(currentStatut),
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                          ),
                        ]),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Modifier le statut', style: GoogleFonts.poppins(fontSize: 12, color: AdminDS.textMuted)),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(color: AdminDS.bg, borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE5E7EB))),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: currentStatut, isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminDS.textMuted),
                                items: _statutsOptions.map((opt) => DropdownMenuItem(
                                  value: opt['value'],
                                  child: Row(children: [
                                    Container(width: 8, height: 8,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor(opt['value']!))),
                                    const SizedBox(width: 8),
                                    Text(opt['label']!, style: GoogleFonts.poppins(fontSize: 14, color: AdminDS.textDark)),
                                  ]),
                                )).toList(),
                                onChanged: (v) { if (v != null) _updateVisaStatus(v); },
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // Section dates de validité
                  Container(
                    decoration: AdminDS.cardDecor(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(children: [
                          Container(padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: AdminDS.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.airplane_ticket_rounded, color: AdminDS.success, size: 18)),
                          const SizedBox(width: 8),
                          Text('Renseigner / Modifier le Visa',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AdminDS.textDark)),
                          const Spacer(),
                          Text('Affiché sur la page visa étudiant',
                            style: GoogleFonts.poppins(fontSize: 10, color: AdminDS.textMuted)),
                        ]),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Numéro de visa', style: GoogleFonts.poppins(fontSize: 12, color: AdminDS.textMuted)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _numeroController,
                            style: GoogleFonts.poppins(fontSize: 14, color: AdminDS.textDark),
                            decoration: InputDecoration(
                              hintText: 'Ex: MU-2026-123456',
                              hintStyle: GoogleFonts.poppins(fontSize: 13, color: AdminDS.textMuted),
                              prefixIcon: const Icon(Icons.numbers_rounded, color: AdminDS.primary, size: 18),
                              filled: true, fillColor: AdminDS.bg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AdminDS.primary, width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text("Date d'émission du visa", style: GoogleFonts.poppins(fontSize: 12, color: AdminDS.textMuted)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _pickDate(context, true),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: AdminDS.bg, borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _dateEmission != null
                                    ? AdminDS.primary.withValues(alpha: 0.5) : const Color(0xFFE5E7EB))),
                              child: Row(children: [
                                Icon(Icons.event_rounded,
                                  color: _dateEmission != null ? AdminDS.primary : AdminDS.textMuted, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  _dateEmission != null ? fmt.format(_dateEmission!) : 'Sélectionner une date',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: _dateEmission != null ? AdminDS.textDark : AdminDS.textMuted,
                                    fontWeight: _dateEmission != null ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.chevron_right_rounded, color: AdminDS.textMuted.withValues(alpha: 0.5)),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text("Date d'expiration du visa", style: GoogleFonts.poppins(fontSize: 12, color: AdminDS.textMuted)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () => _pickDate(context, false),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: AdminDS.bg, borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _dateExpiration != null
                                    ? AdminDS.warning.withValues(alpha: 0.6) : const Color(0xFFE5E7EB))),
                              child: Row(children: [
                                Icon(Icons.event_busy_rounded,
                                  color: _dateExpiration != null ? AdminDS.warning : AdminDS.textMuted, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  _dateExpiration != null ? fmt.format(_dateExpiration!) : 'Sélectionner une date',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: _dateExpiration != null ? AdminDS.textDark : AdminDS.textMuted,
                                    fontWeight: _dateExpiration != null ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.chevron_right_rounded, color: AdminDS.textMuted.withValues(alpha: 0.5)),
                              ]),
                            ),
                          ),

                          if (_dateEmission != null && _dateExpiration != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AdminDS.success.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AdminDS.success.withValues(alpha: 0.2)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.info_outline_rounded, color: AdminDS.success, size: 14),
                                const SizedBox(width: 6),
                                Expanded(child: Text(
                                  'Durée : ${_dateExpiration!.difference(_dateEmission!).inDays} jours  •  Expire le ${fmt.format(_dateExpiration!)}',
                                  style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.success),
                                )),
                              ]),
                            ),
                          ],

                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSavingDates ? null : _saveVisaDates,
                              icon: _isSavingDates
                                  ? const SizedBox(width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save_rounded, size: 18),
                              label: Text(
                                _isSavingDates ? 'Enregistrement...' : 'Enregistrer le visa',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminDS.success, foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  if (numeroVisa.isNotEmpty || expiration != null)
                    Container(
                      decoration: AdminDS.cardDecor(),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          Row(children: [
                            Container(padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: AdminDS.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.verified_rounded, color: AdminDS.primary, size: 16)),
                            const SizedBox(width: 8),
                            Text('Visa actuel', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AdminDS.textDark)),
                          ]),
                          const SizedBox(height: 12),
                          if (numeroVisa.isNotEmpty) _InfoRow(label: 'N° Visa', value: numeroVisa, icon: Icons.numbers_rounded, color: AdminDS.primary),
                          if (dateEmission != null) ...[
                            if (numeroVisa.isNotEmpty) const SizedBox(height: 8),
                            _InfoRow(label: "Date d'émission", value: fmt.format(dateEmission.toDate()), icon: Icons.event_rounded, color: AdminDS.success),
                          ],
                          if (expiration != null) ...[
                            const SizedBox(height: 8),
                            _InfoRow(label: 'Expiration', value: fmt.format(expiration.toDate()), icon: Icons.event_busy_rounded, color: AdminDS.warning),
                          ],
                        ]),
                      ),
                    ),

                  const SizedBox(height: 16),

                  const _SectionTitle(title: 'Documents obligatoires', icon: Icons.folder_rounded),
                  const SizedBox(height: 8),
                  if (documentsObligatoires.isEmpty)
                    const _EmptyDocs(label: 'Aucun document obligatoire téléversé.')
                  else
                    ...documentsObligatoires.entries.map((entry) {
                      final type = entry.key;
                      final isUploaded = entry.value == true;
                      final url = documentsObligatoiresUrls[type]?.toString() ?? '';
                      return _DocCard(
                        type: type, isUploaded: isUploaded, url: url,
                        onOpen: url.isNotEmpty ? () => _openDocument(url, type) : null,
                      );
                    }),

                  const SizedBox(height: 16),

                  const _SectionTitle(title: 'Documents complémentaires', icon: Icons.attach_file_rounded),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('visas').doc(widget.userId)
                        .collection('documentsComplementaires')
                        .orderBy('dateUpload', descending: true)
                        .snapshots(),
                    builder: (context, docsSnapshot) {
                      if (docsSnapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator(color: AdminDS.primary);
                      }
                      final docs = docsSnapshot.data?.docs ?? [];
                      if (docs.isEmpty) return const _EmptyDocs(label: 'Aucun document complémentaire.');
                      return Column(children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final url = data['url'] as String? ?? '';
                        final nom = data['nomFichier'] as String? ?? 'Document';
                        final type = data['type'] as String? ?? '';
                        return _DocCard(
                          type: nom, isUploaded: url.isNotEmpty, url: url,
                          subtitle: type,
                          onOpen: url.isNotEmpty ? () => _openDocument(url, nom) : null,
                        );
                      }).toList());
                    },
                  ),
                  const SizedBox(height: 30),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionTitle({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: AdminDS.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: AdminDS.primary, size: 16)),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AdminDS.textDark)),
  ]);
}

class _InfoRow extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _InfoRow({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 32, height: 32,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 16)),
    const SizedBox(width: 10),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AdminDS.textMuted)),
      Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AdminDS.textDark)),
    ]),
  ]);
}

class _DocCard extends StatelessWidget {
  final String type, url; final bool isUploaded; final String? subtitle; final VoidCallback? onOpen;
  const _DocCard({required this.type, required this.isUploaded, required this.url, this.subtitle, this.onOpen});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: AdminDS.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isUploaded ? AdminDS.success.withValues(alpha: 0.3) : const Color(0xFFE5E7EB)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(width: 36, height: 36,
        decoration: BoxDecoration(
          color: (isUploaded ? AdminDS.success : AdminDS.textMuted).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(isUploaded ? Icons.check_circle_rounded : Icons.upload_file_rounded,
          color: isUploaded ? AdminDS.success : AdminDS.textMuted, size: 18)),
      title: Text(type, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AdminDS.textDark)),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(subtitle!, style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted))
          : Text(isUploaded ? 'Déposé ✓' : 'Non déposé',
              style: GoogleFonts.poppins(fontSize: 11, color: isUploaded ? AdminDS.success : AdminDS.textMuted)),
      trailing: onOpen != null
          ? IconButton(
              icon: const Icon(Icons.open_in_new_rounded, size: 18, color: AdminDS.primary),
              onPressed: onOpen)
          : null,
    ),
  );
}

class _EmptyDocs extends StatelessWidget {
  final String label;
  const _EmptyDocs({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Center(child: Text(label, style: GoogleFonts.poppins(color: AdminDS.textMuted, fontSize: 13))),
  );
}