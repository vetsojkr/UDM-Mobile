// lib/screens/admin/admin_profile_screen.dart
// Profil Administrateur — redessiné

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_home_screen.dart'; // AdminDS
import '../../main.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'admin@udm.ac.mu';
    final initiale = email.isNotEmpty ? email[0].toUpperCase() : 'A';

    return Scaffold(
      backgroundColor: AdminDS.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true, expandedHeight: 220,
          backgroundColor: AdminDS.primary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(gradient: AdminDS.blueGrad),
              child: Stack(children: [
                Positioned(top: -40, right: -40,
                  child: Container(width: 180, height: 180,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
                Positioned(bottom: -20, left: -20,
                  child: Container(width: 100, height: 100,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AdminDS.gold.withValues(alpha: 0.1)))),
                Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(height: 40),
                  // Avatar Admin
                  Container(width: 82, height: 82,
                    decoration: BoxDecoration(
                      gradient: AdminDS.goldGrad,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: AdminDS.gold.withValues(alpha: 0.4), blurRadius: 16, offset: Offset(0, 6))],
                    ),
                    child: Center(child: Text(initiale,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)))),
                  SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: AdminDS.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AdminDS.gold.withValues(alpha: 0.4))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.admin_panel_settings_rounded, color: AdminDS.gold, size: 14),
                      SizedBox(width: 6),
                      Text('Administrateur', style: GoogleFonts.poppins(color: AdminDS.gold, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  SizedBox(height: 8),
                  Text(email, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                ])),
              ]),
            ),
          ),
          title: Text('Mon Profil', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        ),

        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Stats admin
            _AdminQuickStats(),
            SizedBox(height: 20),

            // Informations du compte
            const _SectionLabel(label: 'Informations du compte'),
            SizedBox(height: 8),
            Container(decoration: AdminDS.cardDecor(), child: Column(children: [
              _InfoTile(icon: Icons.email_rounded, label: 'Email', value: email, color: AdminDS.primary),
              const Divider(height: 1, indent: 56, endIndent: 16),
              const _InfoTile(icon: Icons.badge_rounded, label: 'Rôle', value: 'Administrateur', color: AdminDS.gold),
              const Divider(height: 1, indent: 56, endIndent: 16),
              const _InfoTile(icon: Icons.verified_user_rounded, label: 'Statut', value: 'Compte actif', color: AdminDS.success),
            ])),
            SizedBox(height: 20),

            // Paramètres
            const _SectionLabel(label: 'Paramètres'),
            SizedBox(height: 8),
            Container(decoration: AdminDS.cardDecor(), child: Column(children: [
              const _SettingTile(icon: Icons.notifications_rounded, label: 'Notifications', color: AdminDS.warning),
              const Divider(height: 1, indent: 56, endIndent: 16),
              _SettingTile(icon: Icons.lock_rounded, label: 'Changer le mot de passe', color: AdminDS.primary, onTap: () => _showAdminPasswordDialog(context)),
              const Divider(height: 1, indent: 56, endIndent: 16),
              const _SettingTile(icon: Icons.security_rounded, label: 'Sécurité du compte', color: AdminDS.purple),
              const Divider(height: 1, indent: 56, endIndent: 16),
              const _SettingTile(icon: Icons.help_outline_rounded, label: 'Aide & Support', color: AdminDS.success),
            ])),
            SizedBox(height: 24),

            // Déconnexion
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.logout_rounded),
                label: Text('Se déconnecter', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminDS.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('Déconnexion', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                      content: Text('Quitter la session administrateur ?',
                        style: GoogleFonts.poppins(color: AdminDS.textMuted)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: GoogleFonts.poppins())),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: AdminDS.danger, foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Text('Déconnecter', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await FirebaseFirestore.instance.collection('utilisateurs').doc(FirebaseAuth.instance.currentUser?.uid ?? '').update({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()}).catchError((_){});
      await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const AuthWrapper()), (r) => false);
                  }
                },
              ),
            ),
            SizedBox(height: 30),
          ])),
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AdminDS.textMuted, letterSpacing: 0.8));
}

class _InfoTile extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _InfoTile({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18)),
      SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted)),
        Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AdminDS.textDark)),
      ])),
    ]),
  );
}

Future<void> _showAdminPasswordDialog(BuildContext context) async {
  final currentCtrl = TextEditingController();
  final newCtrl     = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? error;
  bool o1 = true, o2 = true, o3 = true;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Changer le mot de passe', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (error != null) Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(color: AdminDS.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Text(error!, style: GoogleFonts.poppins(color: AdminDS.danger, fontSize: 12))),
        _PwdField(controller: currentCtrl, label: 'Mot de passe actuel', obscure: o1, onToggle: () => setS(() => o1 = !o1)),
        SizedBox(height: 12),
        _PwdField(controller: newCtrl, label: 'Nouveau mot de passe', obscure: o2, onToggle: () => setS(() => o2 = !o2)),
        SizedBox(height: 12),
        _PwdField(controller: confirmCtrl, label: 'Confirmer', obscure: o3, onToggle: () => setS(() => o3 = !o3)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: GoogleFonts.poppins())),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AdminDS.primary, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            if (newCtrl.text.length < 6) { setS(() => error = 'Au moins 6 caractères'); return; }
            if (newCtrl.text != confirmCtrl.text) { setS(() => error = 'Mots de passe différents'); return; }
            try {
              final user = FirebaseAuth.instance.currentUser!;
              final cred = EmailAuthProvider.credential(email: user.email!, password: currentCtrl.text);
              await user.reauthenticateWithCredential(cred);
              await user.updatePassword(newCtrl.text);
              if (ctx.mounted) { Navigator.pop(ctx); }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Mot de passe mis à jour ✓', style: GoogleFonts.poppins()),
                  backgroundColor: AdminDS.success, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
              }
            } catch (e) { setS(() => error = 'Mot de passe actuel incorrect'); }
          },
          child: Text('Enregistrer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    )),
  );
}

class _PwdField extends StatelessWidget {
  final TextEditingController controller; final String label; final bool obscure; final VoidCallback onToggle;
  const _PwdField({required this.controller, required this.label, required this.obscure, required this.onToggle});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, obscureText: obscure,
    style: GoogleFonts.poppins(fontSize: 13),
    decoration: InputDecoration(
      labelText: label, labelStyle: GoogleFonts.poppins(fontSize: 13, color: AdminDS.textMuted),
      filled: true, fillColor: AdminDS.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminDS.primary, width: 1.5)),
      suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: AdminDS.textMuted), onPressed: onToggle),
    ),
  );
}

class _SettingTile extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback? onTap;
  const _SettingTile({required this.icon, required this.label, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Container(width: 36, height: 36,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 18)),
    title: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AdminDS.textDark)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AdminDS.textMuted),
    onTap: () {},
  );
}

class _AdminQuickStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('utilisateurs').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final candidats = docs.where((d) => (d.data() as Map)['role'] == 'candidat').length;
        final etudiants = docs.where((d) => (d.data() as Map)['role'] == 'etudiant').length;
        return Row(children: [
          Expanded(child: _MiniStat(label: 'Candidats', value: '$candidats', icon: Icons.person_search_rounded, color: AdminDS.purple)),
          SizedBox(width: 10),
          Expanded(child: _MiniStat(label: 'Étudiants', value: '$etudiants', icon: Icons.school_rounded, color: AdminDS.primary)),
          SizedBox(width: 10),
          Expanded(child: _MiniStat(label: 'Total', value: '${docs.length}', icon: Icons.people_rounded, color: AdminDS.success)),
        ]);
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 20),
      SizedBox(height: 6),
      Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AdminDS.textMuted)),
    ]),
  );
}

// Extension purple pour AdminDS