// lib/screens/student/student_visa_screen.dart
// Visa Étudiant — Affichage conditions + validité visa (pas de demande)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class _SVC {
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
    boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.06), blurRadius: 12, offset: Offset(0, 4))],
  );
}

class StudentVisaScreen extends StatefulWidget {
  const StudentVisaScreen({super.key});
  @override
  State<StudentVisaScreen> createState() => _StudentVisaScreenState();
}

class _StudentVisaScreenState extends State<StudentVisaScreen> with SingleTickerProviderStateMixin {
  DateTime? _expirationDate;
  DateTime? _startDate;
  String _numeroVisa = '';
  String _visaStatus = 'approuve'; // par défaut étudiant a visa approuvé
  bool _isLoading = true;

  late final AnimationController _progressCtrl;
  late final Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _progressAnim = CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut);
    _loadVisaData();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVisaData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _isLoading = false); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('visas').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _visaStatus = data['statut'] as String? ?? 'approuve';
          _numeroVisa = data['numero'] as String? ?? '';
          if (data['expiration'] != null) _expirationDate = (data['expiration'] as Timestamp).toDate();
          if (data['dateEmission'] != null) _startDate = (data['dateEmission'] as Timestamp).toDate();
        });
        if (_visaStatus == 'approuve') _progressCtrl.forward();
      }
    } catch (e) {
      debugPrint('Visa load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SVC.bg,
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            pinned: true, expandedHeight: 100,
            backgroundColor: _SVC.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: _SVC.blueGrad),
                child: Stack(children: [
                  Positioned(top: -30, right: -30,
                    child: Container(width: 150, height: 150,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Row(children: [
                      Container(padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _SVC.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.airplane_ticket_rounded, color: _SVC.gold, size: 22)),
                      SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Visa Étudiant', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('Statut & validité', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
            title: Text('Visa Étudiant', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),

          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildListDelegate([
              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _SVC.primary)))
              else ...[
                // Graphique de validité
                if (_expirationDate != null)
                  _VisaValidityCard(
                    startDate: _startDate,
                    expirationDate: _expirationDate!,
                    numeroVisa: _numeroVisa,
                    progressAnim: _progressAnim,
                  )
                else
                  _NoVisaDataCard(),

                SizedBox(height: 16),

                // Conditions du visa
                _VisaConditionsCard(),

                SizedBox(height: 16),

                // Contacts utiles
                _ContactsCard(),

                SizedBox(height: 30),
              ],
            ])),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Carte validité visa
// ──────────────────────────────────────────────────────────────────────────────

class _VisaValidityCard extends StatelessWidget {
  final DateTime? startDate;
  final DateTime expirationDate;
  final String numeroVisa;
  final Animation<double> progressAnim;
  const _VisaValidityCard({required this.startDate, required this.expirationDate, required this.numeroVisa, required this.progressAnim});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 30));
    final totalDays = expirationDate.difference(start).inDays.clamp(1, 99999);
    final elapsedDays = now.difference(start).inDays.clamp(0, totalDays);
    final remainingDays = expirationDate.difference(now).inDays;
    final progress = (elapsedDays / totalDays).clamp(0.0, 1.0);
    final isExpired = remainingDays < 0;
    final isUrgent = remainingDays >= 0 && remainingDays < 60;
    final Color barColor = isExpired ? _SVC.danger : isUrgent ? _SVC.warning : _SVC.success;
    final fmt = DateFormat('dd/MM/yyyy');

    return Container(
      decoration: _SVC.card(radius: 16),
      padding: EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: barColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(isExpired ? Icons.warning_rounded : Icons.verified_rounded, color: barColor, size: 20)),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Validité du Visa', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: _SVC.textDark)),
            if (numeroVisa.isNotEmpty)
              Text('N° $numeroVisa', style: GoogleFonts.poppins(fontSize: 11, color: _SVC.textMuted)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: barColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(isExpired ? 'Expiré' : '$remainingDays j. restants',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: barColor)),
          ),
        ]),
        SizedBox(height: 20),

        // Arc graphique
        Center(child: AnimatedBuilder(
          animation: progressAnim,
          builder: (context, _) => CustomPaint(
            size: const Size(180, 100),
            painter: _ArcPainter(progress: progress * progressAnim.value, color: barColor, bgColor: barColor.withValues(alpha: 0.1)),
            child: SizedBox(width: 180, height: 100,
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(isExpired ? 'EXPIRÉ' : '${(progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: barColor)),
                Text(isExpired ? 'Renouvelez votre visa' : 'de la durée écoulée',
                  style: GoogleFonts.poppins(fontSize: 10, color: _SVC.textMuted)),
                SizedBox(height: 8),
              ]),
            ),
          ),
        )),
        SizedBox(height: 16),

        // Barre linéaire
        Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Début', style: GoogleFonts.poppins(fontSize: 10, color: _SVC.textMuted)),
            Text("Aujourd'hui", style: GoogleFonts.poppins(fontSize: 10, color: barColor, fontWeight: FontWeight.w600)),
            Text('Expiration', style: GoogleFonts.poppins(fontSize: 10, color: _SVC.textMuted)),
          ]),
          SizedBox(height: 6),
          Stack(children: [
            Container(height: 10, decoration: BoxDecoration(color: barColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10))),
            AnimatedBuilder(
              animation: progressAnim,
              builder: (context, _) => FractionallySizedBox(
                widthFactor: (progress * progressAnim.value).clamp(0, 1),
                child: Container(height: 10, decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [barColor.withValues(alpha: 0.6), barColor]),
                  borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ]),
          SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(fmt.format(start), style: GoogleFonts.poppins(fontSize: 10, color: _SVC.textMuted)),
            Text(fmt.format(expirationDate), style: GoogleFonts.poppins(fontSize: 10, color: _SVC.textMuted)),
          ]),
        ]),
        SizedBox(height: 16),

        // Résumé infos
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(color: _SVC.bg, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: _InfoChip(label: 'Durée totale', value: '$totalDays j.', icon: Icons.date_range_rounded, color: _SVC.primary)),
            Container(width: 1, height: 36, color: const Color(0xFFE5E7EB)),
            Expanded(child: _InfoChip(label: 'Restants', value: isExpired ? '0' : '$remainingDays j.', icon: Icons.timer_rounded, color: barColor)),
            Container(width: 1, height: 36, color: const Color(0xFFE5E7EB)),
            Expanded(child: _InfoChip(label: 'Expire le', value: fmt.format(expirationDate), icon: Icons.event_rounded, color: _SVC.purple)),
          ]),
        ),

        if (isUrgent || isExpired) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: barColor.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(isExpired ? Icons.error_rounded : Icons.warning_amber_rounded, color: barColor, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text(
                isExpired
                    ? "Votre visa a expiré. Contactez l'administration pour le renouvellement."
                    : "Votre visa expire dans $remainingDays jours. Pensez à contacter l'ambassade.",
                style: GoogleFonts.poppins(fontSize: 12, color: barColor, fontWeight: FontWeight.w500))),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _NoVisaDataCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(24),
    decoration: _SVC.card(radius: 16),
    child: Column(children: [
      Container(padding: EdgeInsets.all(20),
        decoration: BoxDecoration(color: _SVC.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: Icon(Icons.airplane_ticket_outlined, size: 48, color: _SVC.primary.withValues(alpha: 0.4))),
      SizedBox(height: 14),
      Text('Informations visa non disponibles', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: _SVC.textDark)),
      SizedBox(height: 6),
      Text("Les détails de votre visa apparaîtront ici une fois renseignés par l'administration.",
        textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12, color: _SVC.textMuted)),
    ]),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Conditions du visa
// ──────────────────────────────────────────────────────────────────────────────

class _VisaConditionsCard extends StatelessWidget {
  static const _conditions = [
    (Icons.school_rounded, 'Inscription universitaire valide', 'Votre inscription doit être renouvelée chaque année académique.'),
    (Icons.home_rounded, 'Résidence déclarée', "Votre adresse à Maurice doit être déclarée auprès des autorités d'immigration."),
    (Icons.work_off_rounded, 'Activité professionnelle limitée', 'Le visa étudiant autorise un travail à temps partiel maximum de 20h/semaine.'),
    (Icons.account_balance_rounded, 'Ressources financières suffisantes', 'Vous devez justifier de ressources suffisantes pour couvrir vos frais de vie.'),
    (Icons.notifications_active_rounded, 'Renouvellement avant expiration', 'La demande de renouvellement doit être faite au moins 6 semaines avant expiration.'),
    (Icons.flight_takeoff_rounded, 'Sortie et retour autorisés', "Vous pouvez quitter et entrer à Maurice librement pendant la durée de validité."),
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration: _SVC.card(radius: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Container(padding: EdgeInsets.all(6),
            decoration: BoxDecoration(color: _SVC.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.gavel_rounded, color: _SVC.primary, size: 16)),
          SizedBox(width: 8),
          Text("Conditions du Visa Étudiant", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: _SVC.textDark)),
        ]),
      ),
      const Divider(height: 1),
      ...List.generate(_conditions.length, (i) {
        final (icon, title, desc) = _conditions[i];
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: _SVC.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: _SVC.primary, size: 18)),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _SVC.textDark)),
                SizedBox(height: 2),
                Text(desc, style: GoogleFonts.poppins(fontSize: 11, color: _SVC.textMuted)),
              ])),
            ]),
          ),
          if (i < _conditions.length - 1) const Divider(height: 1, indent: 64, endIndent: 16),
        ]);
      }),
    ]),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Contacts utiles
// ──────────────────────────────────────────────────────────────────────────────

class _ContactsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_SVC.primary.withValues(alpha: 0.05), _SVC.gold.withValues(alpha: 0.05)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _SVC.primary.withValues(alpha: 0.12)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.contact_support_rounded, color: _SVC.primary, size: 18),
        SizedBox(width: 8),
        Text('Contacts utiles', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _SVC.primary)),
      ]),
      SizedBox(height: 12),
      const _ContactRow(label: 'Service Immigration Maurice', info: '+230 207 7000'),
      SizedBox(height: 8),
      const _ContactRow(label: 'Service Visa UDM', info: 'visa@udm.ac.mu'),
      SizedBox(height: 8),
      const _ContactRow(label: 'Urgences administratives', info: '+230 XXX XXXX'),
    ]),
  );
}

class _ContactRow extends StatelessWidget {
  final String label, info;
  const _ContactRow({required this.label, required this.info});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 12, color: _SVC.textMuted)),
      Text(info, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _SVC.textDark)),
    ],
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Widgets partagés
// ──────────────────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _InfoChip({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: color, size: 16),
    SizedBox(height: 3),
    Text(value, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
    Text(label, style: GoogleFonts.poppins(fontSize: 9, color: _SVC.textMuted), textAlign: TextAlign.center),
  ]);
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color, bgColor;
  const _ArcPainter({required this.progress, required this.color, required this.bgColor});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;
    final r = size.width / 2 - 12;
    const strokeW = 14.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(rect, math.pi, math.pi, false, Paint()..color = bgColor..style = PaintingStyle.stroke..strokeWidth = strokeW..strokeCap = StrokeCap.round);
    if (progress > 0) {
      canvas.drawArc(rect, math.pi, math.pi * progress, false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeW..strokeCap = StrokeCap.round);
    }
    final angle = math.pi + math.pi * progress;
    final dotX = cx + r * math.cos(angle);
    final dotY = cy + r * math.sin(angle);
    canvas.drawCircle(Offset(dotX, dotY), 8, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(dotX, dotY), 6, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}
