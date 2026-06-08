// lib/screens/candidate/payment_screen.dart
// Écran Paiement — calendrier 100% dynamique (anneeInscription + programme + region)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/payment_service.dart';
import 'candidate_home.dart';
import '../../models/role.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
class _PC {
  static const Color primary   = Color(0xFF003087);
  static const Color gold      = Color(0xFFE8A020);
  static const Color success   = Color(0xFF10B981);
  static const Color warning   = Color(0xFFF59E0B);
  static const Color danger    = Color(0xFFEF4444);
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
    boxShadow: [
      BoxShadow(
          color: primary.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4))
    ],
  );
}

// ── Helpers globaux ───────────────────────────────────────────────────────────

String _fmtMontant(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} MUR';

/// Durée totale du programme : Master → 2 ans | sinon → 3 ans.
int _getDuree(String programme) {
  final p = programme.toLowerCase();
  return (p.contains('master') || p.contains('mastère')) ? 2 : 3;
}

/// Frais de scolarité selon la région et le type de programme.
/// Master : 150 000 MUR / an (toutes régions)
/// Licence / BEng / Diplôme : SADC = 49 000 | Hors SADC = 84 000
int _tuitionFee(String region, {bool isMaster = false}) {
  if (isMaster) return 150000;
  return region == 'SADC' ? 49000 : 84000;
}

// ═══════════════════════════════════════════════════════════════════════════════
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  bool    _isLoading = false;
  String? _selectedCandidatureId;
  String  _region     = 'SADC';
  Map<String, dynamic> _selectedData = {};

  final _cardNumberController = TextEditingController();
  final _expiryController     = TextEditingController();
  final _cvvController        = TextEditingController();
  final _formKey              = GlobalKey<FormState>();

  static const int _applicationFee = 700;

  bool get _isMaster {
    final prog = (_selectedData['programme'] as String? ?? '').toLowerCase();
    return prog.contains('master') || prog.contains('mastere');
  }

  int get _tuition     => _tuitionFee(_region, isMaster: _isMaster);
  int get _amountToPay => _tuition + _applicationFee;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String? _validateCard(String? v) {
    if (v == null || v.isEmpty) return 'Numéro requis';
    final c = v.replaceAll(RegExp(r'\s'), '');
    if (c.length < 13 || c.length > 19) return '13 à 19 chiffres';
    if (!RegExp(r'^\d+$').hasMatch(c)) return 'Chiffres uniquement';
    return null;
  }

  String? _validateExpiry(String? v) {
    if (v == null || v.isEmpty) return 'MM/AA requis';
    if (!RegExp(r'^(0[1-9]|1[0-2])\/(\d{2})$').hasMatch(v)) return 'Format MM/AA';
    final p = v.split('/');
    final m = int.parse(p[0]); final y = int.parse(p[1]) + 2000;
    if (DateTime(y, m)
        .isBefore(DateTime(DateTime.now().year, DateTime.now().month))) {
      return 'Carte expirée';
    }
    return null;
  }

  String? _validateCvv(String? v) {
    if (v == null || v.isEmpty) return 'CVV requis';
    if (!RegExp(r'^\d{3,4}$').hasMatch(v)) return '3 ou 4 chiffres';
    return null;
  }

  Future<void> _processPayment() async {
    if (_selectedCandidatureId == null) {
      _showSnack('Sélectionnez un programme', _PC.warning);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      _showSnack('Remplissez les informations bancaires', _PC.warning);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final description =
          'Paiement complet — Frais dossier + scolarité (${_fmtMontant(_amountToPay)})';
      await _paymentService.processPayment(
        candidatureId: _selectedCandidatureId!,
        description:   description,
        region:        _region,
      );
      if (!mounted) return;
      _showSnack('✅ Paiement réussi !', _PC.success);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => CandidateHomeScreen(role: UserRole.candidat)),
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('❌ Erreur : $e', _PC.danger);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: _PC.bg,
        body: Center(child: Text('Non connecté', style: GoogleFonts.poppins())),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('candidatures')
        .where('userId', isEqualTo: user.uid)
        .where('statut', isEqualTo: 'accepte')
        .where('paiementEffectue', isEqualTo: false)
        .snapshots();

    return Scaffold(
      backgroundColor: _PC.bg,
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _PC.primary));
          }
          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) return _AlreadyPaidOrEmpty(userId: user.uid);

          // Init sélection
          if (_selectedCandidatureId == null && docs.isNotEmpty) {
            _selectedCandidatureId = docs.first.id;
            _selectedData = docs.first.data() as Map<String, dynamic>;
            final savedRegion = _selectedData['region'] as String?;
            if (savedRegion != null) _region = savedRegion;
          }

          return CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 120,
              backgroundColor: _PC.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(gradient: _PC.blueGrad),
                  child: Stack(children: [
                    Positioned(
                      top: -30, right: -30,
                      child: Container(
                        width: 150, height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _PC.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: _PC.gold, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Paiement',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white, fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              Text('Frais de scolarité UDM',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
              title: Text('Paiement',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Programme ───────────────────────────────────────
                  _Section(
                    title: 'Programme',
                    icon: Icons.school_rounded,
                    child: Column(children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCandidatureId,
                        isExpanded: true,
                        items: docs.map((doc) {
                          final d       = doc.data() as Map<String, dynamic>;
                          final prog    = (d['programme'] ?? '?') as String;
                          final annee   = (d['anneeInscription'] as int?) ?? 1;
                          final isMst   = prog.toLowerCase().contains('master');
                          final suffix  = isMst ? ' (M$annee)' : ' (Année $annee)';
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text('$prog$suffix',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: _PC.textDark)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          final doc  = docs.firstWhere((d) => d.id == val);
                          final data = doc.data() as Map<String, dynamic>;
                          setState(() {
                            _selectedCandidatureId = val;
                            _selectedData          = data;
                            final r = data['region'] as String?;
                            if (r != null) _region = r;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Choisir un programme',
                          filled: true, fillColor: _PC.bg,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Text('Région :',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: _PC.textMuted,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(width: 12),
                        _RegionChip(
                            label: 'SADC',
                            selected: _region == 'SADC',
                            onTap: () => setState(() => _region = 'SADC')),
                        const SizedBox(width: 8),
                        _RegionChip(
                            label: 'Hors SADC',
                            selected: _region == 'non-SADC',
                            onTap: () => setState(() => _region = 'non-SADC')),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // ── Récapitulatif ────────────────────────────────────
                  _Section(
                    title: 'Récapitulatif',
                    icon: Icons.receipt_long_rounded,
                    child: Column(children: [
                      _AmountRow(
                          label: 'Frais de dossier',
                          amount: _fmtMontant(_applicationFee),
                          color: _PC.textMuted),
                      const SizedBox(height: 6),
                      _AmountRow(
                          label: _isMaster ? 'Frais de scolarité (Master)' : 'Frais de scolarité ($_region)',
                          amount: _fmtMontant(_tuition),
                          color: _PC.textMuted),
                      const Divider(height: 20),
                      _AmountRow(
                          label: 'Total à payer',
                          amount: _fmtMontant(_amountToPay),
                          color: _PC.success,
                          isBold: true),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  // ── Infos bancaires ──────────────────────────────────
                  _Section(
                    title: 'Informations de paiement',
                    icon: Icons.credit_card_rounded,
                    child: Form(
                      key: _formKey,
                      child: Column(children: [
                        Row(children: [
                          _CardBadge(label: 'VISA', color: const Color(0xFF1A1F71)),
                          const SizedBox(width: 6),
                          _CardBadge(label: 'MC',   color: const Color(0xFFEB001B)),
                          const SizedBox(width: 6),
                          _CardBadge(label: 'AMEX', color: const Color(0xFF007CC3)),
                        ]),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _cardNumberController,
                          keyboardType: TextInputType.number,
                          validator: _validateCard,
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: _PC.textDark,
                              letterSpacing: 2),
                          decoration: _fieldDeco(
                              'Numéro de carte', Icons.credit_card_rounded),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: _expiryController,
                              keyboardType: TextInputType.number,
                              validator: _validateExpiry,
                              inputFormatters: [_ExpiryDateFormatter()],
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: _PC.textDark),
                              decoration: _fieldDeco(
                                  'MM/AA', Icons.date_range_rounded),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cvvController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              validator: _validateCvv,
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: _PC.textDark),
                              decoration:
                                  _fieldDeco('CVV', Icons.lock_rounded),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.lock_rounded,
                              size: 12, color: _PC.success),
                          const SizedBox(width: 4),
                          Text('Paiement sécurisé SSL 256-bit',
                              style: GoogleFonts.poppins(
                                  fontSize: 10, color: _PC.textMuted)),
                        ]),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Bouton payer ─────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _PC.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text('Payer ${_fmtMontant(_amountToPay)}',
                                    style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  InputDecoration _fieldDeco(String label, IconData icon) => InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icon, size: 18, color: _PC.textMuted),
        filled:     true, fillColor: _PC.bg,
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: _PC.textMuted),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _PC.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _PC.danger)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET : Déjà payé ou aucune candidature
// ═══════════════════════════════════════════════════════════════════════════════
class _AlreadyPaidOrEmpty extends StatelessWidget {
  final String userId;
  const _AlreadyPaidOrEmpty({required this.userId});

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('candidatures')
            .where('userId', isEqualTo: userId)
            .where('statut', isEqualTo: 'accepte')
            .where('paiementEffectue', isEqualTo: true)
            .get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _PC.primary));
          }
          final hasPaid  = snap.hasData && snap.data!.docs.isNotEmpty;
          final paidDocs = snap.data?.docs ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (hasPaid ? _PC.success : _PC.textMuted)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasPaid ? Icons.check_circle_rounded : Icons.info_rounded,
                    size: 56,
                    color: hasPaid ? _PC.success : _PC.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  hasPaid
                      ? 'Frais de scolarité payés ✓'
                      : 'Aucune candidature en attente',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: hasPaid ? _PC.success : _PC.textDark),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    hasPaid
                        ? 'Vos frais de scolarité ont été enregistrés avec succès.'
                        : 'Aucune candidature acceptée en attente de paiement.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: _PC.textMuted),
                  ),
                ),
                if (hasPaid && paidDocs.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _CalendrierPaiements(paidDoc: paidDocs.first),
                ],
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET : Calendrier dynamique
// ═══════════════════════════════════════════════════════════════════════════════
class _CalendrierPaiements extends StatelessWidget {
  final QueryDocumentSnapshot paidDoc;
  const _CalendrierPaiements({required this.paidDoc});

  @override
  Widget build(BuildContext context) {
    final data = paidDoc.data() as Map<String, dynamic>;

    final programme        = data['programme'] as String? ?? '';
    final region           = data['region']    as String? ?? 'SADC';
    // ✅ Lire l'année d'inscription sauvegardée lors de la candidature
    final anneeInscription = (data['anneeInscription'] as int?) ?? 1;

    final dureeTotal  = _getDuree(programme);
    final isMaster    = programme.toLowerCase().contains('master') ||
        programme.toLowerCase().contains('mastère');
    final tuition     = _tuitionFee(region, isMaster: isMaster);

    // Année académique courante (commence en septembre)
    final now           = DateTime.now();
    final anneeCourante = now.month >= 9 ? now.year : now.year - 1;

    // Années restantes depuis l'année d'inscription
    final anneesRestantes = dureeTotal - anneeInscription + 1;

    final titreSection =
        isMaster ? 'Calendrier — Master' : 'Calendrier des paiements';

    final rows = <Widget>[];
    for (int i = 0; i < anneesRestantes; i++) {
      final anneeNum   = anneeInscription + i;
      final startYear  = anneeCourante + i;
      // ✅ Label adapté : M1/M2 pour Master, Année 1/2/3 pour Licence
      final anneeLabel = isMaster ? 'M$anneeNum' : 'Année $anneeNum';
      final isPaid     = i == 0;

      rows.add(_FutureYearRow(
        anneeLabel:  anneeLabel,
        periodLabel: '$startYear/${startYear + 1}',
        amount:      _fmtMontant(tuition),
        status:      isPaid ? 'Payé' : 'À venir',
        color:       isPaid ? _PC.success : _PC.textMuted,
        isPaid:      isPaid,
      ));
      if (i < anneesRestantes - 1) rows.add(const SizedBox(height: 8));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _PC.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _PC.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calendar_month_rounded,
                color: _PC.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(titreSection,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: _PC.primary)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(programme,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: _PC.textMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('Région : $region',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: _PC.textMuted)),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...rows,
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _PC.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: _PC.warning.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: _PC.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Les frais des années suivantes seront actualisés chaque '
                    'année académique. Contactez l\'administration pour tout '
                    'renseignement.',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: _PC.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS RÉUTILISABLES
// ═══════════════════════════════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  final String title; final IconData icon; final Widget child;
  const _Section({required this.title, required this.icon, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: _PC.card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: _PC.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: _PC.primary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: _PC.textDark)),
            ]),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ]),
      );
}

class _RegionChip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _RegionChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _PC.primary : _PC.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? _PC.primary : const Color(0xFFE5E7EB)),
          ),
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _PC.textMuted)),
        ),
      );
}

class _AmountRow extends StatelessWidget {
  final String label, amount; final Color color; final bool isBold;
  const _AmountRow(
      {required this.label, required this.amount,
       required this.color, this.isBold = false});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: isBold ? 14 : 13,
                  fontWeight:
                      isBold ? FontWeight.w700 : FontWeight.w400,
                  color: isBold ? _PC.textDark : _PC.textMuted)),
          Text(amount,
              style: GoogleFonts.poppins(
                  fontSize: isBold ? 15 : 13,
                  fontWeight:
                      isBold ? FontWeight.w800 : FontWeight.w500,
                  color: color)),
        ],
      );
}

class _CardBadge extends StatelessWidget {
  final String label; final Color color;
  const _CardBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );
}

class _FutureYearRow extends StatelessWidget {
  final String anneeLabel, periodLabel, amount, status;
  final Color color; final bool isPaid;
  const _FutureYearRow({
    required this.anneeLabel, required this.periodLabel,
    required this.amount, required this.status,
    required this.color, required this.isPaid,
  });
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle),
          child: Icon(
              isPaid ? Icons.check_rounded : Icons.access_time_rounded,
              size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$anneeLabel — $periodLabel',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: _PC.textDark)),
            Text(amount,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: _PC.textMuted)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
          child: Text(status,
              style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ),
      ]);
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length > 4) return oldValue;
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i == 2) formatted += '/';
      formatted += digits[i];
    }
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
