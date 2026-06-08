// lib/screens/candidate/profile_screen.dart
// Profil Candidat — Photo + Changer mdp, infos non modifiables

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:udm_application/main.dart';
import '../../services/cloudinary_service.dart';

const Color _primary   = Color(0xFF003087);
const Color _gold      = Color(0xFFE8A020);
const Color _success   = Color(0xFF10B981);
const Color _danger    = Color(0xFFEF4444);
const Color _bg        = Color(0xFFF0F4FB);
const Color _textDark  = Color(0xFF1A1A2E);
const Color _textMuted = Color(0xFF6B7280);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  String? _photoUrl;
  String _nom = '';
  String _prenom = '';
  String _telephone = '';

  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinary = CloudinaryService();

  StreamSubscription<DocumentSnapshot>? _userSub;

  @override
  void initState() {
    super.initState();
    _listenUserData();
  }

  void _listenUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _userSub = FirebaseFirestore.instance
        .collection('utilisateurs')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      if (snap.exists && mounted) {
        final data = snap.data() as Map<String, dynamic>;
        setState(() {
          _nom       = data['nom']       as String? ?? '';
          _prenom    = data['prenom']    as String? ?? '';
          _telephone = data['telephone'] as String? ?? '';
          _photoUrl  = data['photoUrl']  as String?;
        });
      }
    });
  }

  Future<void> _pickAndUploadPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        SizedBox(height: 16),
        Text('Choisir une photo', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        SizedBox(height: 16),
        ListTile(
          leading: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: _primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.photo_library_rounded, color: _primary)),
          title: Text('Galerie', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
        ListTile(
          leading: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: _gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.camera_alt_rounded, color: _gold)),
          title: Text('Caméra', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        SizedBox(height: 16),
      ])),
    );
    if (source == null || !mounted) return;
    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final url = await _cloudinary.uploadFile(File(picked.path));
      if (url != null) {
        final user = FirebaseAuth.instance.currentUser!;
        await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).update({'photoUrl': url});
        if (mounted) { setState(() { _photoUrl = url; }); }
        if (mounted) { _showSnack('Photo mise à jour ✓', _success); }
      }
    } catch (e) {
      if (mounted) { _showSnack('Erreur photo : $e', _danger); }
    } finally {
      if (mounted) { setState(() => _isLoading = false); }
    }
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscCurrent = true, obscNew = true, obscConfirm = true;
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Changer le mot de passe', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (error != null) Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: _danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Text(error!, style: GoogleFonts.poppins(color: _danger, fontSize: 12))),
          _PwdField(controller: currentCtrl, label: 'Mot de passe actuel', obscure: obscCurrent, onToggle: () => setS(() => obscCurrent = !obscCurrent)),
          SizedBox(height: 12),
          _PwdField(controller: newCtrl, label: 'Nouveau mot de passe', obscure: obscNew, onToggle: () => setS(() => obscNew = !obscNew)),
          SizedBox(height: 12),
          _PwdField(controller: confirmCtrl, label: 'Confirmer le mot de passe', obscure: obscConfirm, onToggle: () => setS(() => obscConfirm = !obscConfirm)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: GoogleFonts.poppins())),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              if (newCtrl.text.length < 6) { setS(() => error = 'Le mot de passe doit avoir au moins 6 caractères'); return; }
              if (newCtrl.text != confirmCtrl.text) { setS(() => error = 'Les mots de passe ne correspondent pas'); return; }
              try {
                final user = FirebaseAuth.instance.currentUser!;
                final cred = EmailAuthProvider.credential(email: user.email!, password: currentCtrl.text);
                await user.reauthenticateWithCredential(cred);
                await user.updatePassword(newCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _showSnack('Mot de passe mis à jour ✓', _success);
              } catch (e) {
                setS(() => error = 'Mot de passe actuel incorrect');
              }
            },
            child: Text('Enregistrer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      )),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Déconnexion', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Voulez-vous vraiment vous déconnecter ?', style: GoogleFonts.poppins(color: _textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _danger, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('utilisateurs').doc(FirebaseAuth.instance.currentUser?.uid ?? '').update({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()}).catchError((_){});
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthWrapper()), (_) => false);
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
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Non connecté')));
    final fullName = '$_prenom $_nom'.trim();
    final initials = '${_prenom.isNotEmpty ? _prenom[0] : ''}${_nom.isNotEmpty ? _nom[0] : ''}'.toUpperCase();

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(slivers: [
        // ── Hero header ──────────────────────────────────────────────────────
        SliverAppBar(
          pinned: true, expandedHeight: 250,
          backgroundColor: _primary,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            // Title centré dans la FlexibleSpaceBar — uniquement quand réduite
            titlePadding: EdgeInsets.zero,
            background: Container(
              decoration: BoxDecoration(gradient: LinearGradient(
                colors: [Color(0xFF001A5C), Color(0xFF003087), Color(0xFF1A4FAF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              )),
              child: Stack(children: [
                Positioned(top: -40, right: -40, child: Container(width: 180, height: 180,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
                Positioned(bottom: -20, left: -20, child: Container(width: 120, height: 120,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _gold.withValues(alpha: 0.1)))),
                Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  // Espace pour éviter l'overlap avec la barre de statut
                  SizedBox(height: 56),
                  // Avatar avec bouton photo
                  Stack(alignment: Alignment.bottomRight, children: [
                    Container(width: 90, height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE8A020), Color(0xFFF5C842)]),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: _photoUrl != null && _photoUrl!.isNotEmpty
                          ? ClipOval(child: Image.network(_photoUrl!, fit: BoxFit.cover))
                          : Center(child: Text(initials.isNotEmpty ? initials : '?',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)))),
                    GestureDetector(
                      onTap: _pickAndUploadPhoto,
                      child: Container(width: 30, height: 30,
                        decoration: BoxDecoration(color: _primary, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                        child: _isLoading
                            ? Padding(padding: const EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15)),
                    ),
                  ]),
                  SizedBox(height: 10),
                  Text(fullName.isNotEmpty ? fullName : 'Candidat',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  Text(user.email ?? '', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                  SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.person_rounded, color: Colors.white70, size: 12),
                      SizedBox(width: 4),
                      Text('Candidat', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ])),
              ]),
            ),
          ),
        ),

        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // ── Informations personnelles (lecture seule) ─────────────────────
            _SectionLabel(label: 'Informations personnelles'),
            SizedBox(height: 8),
            Container(
              decoration: _cardDecor(),
              child: Column(children: [
                _InfoTile(icon: Icons.badge_rounded, label: 'Nom complet', value: fullName.isNotEmpty ? fullName : '—', color: _primary),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _InfoTile(icon: Icons.email_rounded, label: 'Email', value: user.email ?? '—', color: const Color(0xFF7C3AED)),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _InfoTile(icon: Icons.phone_rounded, label: 'Téléphone', value: _telephone.isNotEmpty ? _telephone : '—', color: _success),
              ]),
            ),
            SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Ces informations sont gérées par l\'administration.',
                style: GoogleFonts.poppins(fontSize: 11, color: _textMuted, fontStyle: FontStyle.italic)),
            ),
            SizedBox(height: 20),

            // ── Sécurité du compte ───────────────────────────────────────────
            _SectionLabel(label: 'Sécurité du compte'),
            SizedBox(height: 8),
            Container(
              decoration: _cardDecor(),
              child: Column(children: [
                _ActionTile(
                  icon: Icons.lock_rounded,
                  label: 'Changer le mot de passe',
                  subtitle: 'Modifiez votre mot de passe de connexion',
                  color: _primary,
                  onTap: _changePassword,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _ActionTile(
                  icon: Icons.add_a_photo_rounded,
                  label: 'Changer la photo de profil',
                  subtitle: 'Photo depuis la galerie ou la caméra',
                  color: _gold,
                  onTap: _pickAndUploadPhoto,
                ),
              ]),
            ),
            SizedBox(height: 20),

            // ── Déconnexion ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, color: _danger),
                label: Text('Se déconnecter', style: GoogleFonts.poppins(color: _danger, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _danger.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            SizedBox(height: 30),
          ])),
        ),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
BoxDecoration _cardDecor() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.06), blurRadius: 12, offset: Offset(0, 4))],
);

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _textMuted, letterSpacing: 0.5));
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
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: _textMuted)),
        Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark)),
      ])),
    ]),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon; final String label, subtitle; final Color color; final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Container(width: 40, height: 40,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 20)),
    title: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark)),
    subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: _textMuted)),
    trailing: Icon(Icons.chevron_right_rounded, color: _textMuted.withValues(alpha: 0.5)),
    onTap: onTap,
  );
}

class _PwdField extends StatelessWidget {
  final TextEditingController controller; final String label; final bool obscure; final VoidCallback onToggle;
  const _PwdField({required this.controller, required this.label, required this.obscure, required this.onToggle});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    style: GoogleFonts.poppins(fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(fontSize: 13, color: _textMuted),
      filled: true, fillColor: _bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primary, width: 1.5)),
      suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: _textMuted), onPressed: onToggle),
    ),
  );
}
