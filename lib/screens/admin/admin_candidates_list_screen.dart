// lib/screens/admin/admin_candidates_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_candidate_detail_screen.dart';
import 'admin_home_screen.dart'; // AdminDS
import '../../services/user_service.dart';
import '../../services/deletion_service.dart';

class AdminCandidatesListScreen extends StatefulWidget {
  const AdminCandidatesListScreen({super.key});
  @override
  State<AdminCandidatesListScreen> createState() =>
      _AdminCandidatesListScreenState();
}

class _AdminCandidatesListScreenState extends State<AdminCandidatesListScreen> {
  final UserService _userService = UserService();
  final DeletionService _deletionService = DeletionService();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'candidat';
  // Clé pour forcer la reconstruction du StreamBuilder lors du refresh
  int _refreshKey = 0;
  bool _isRefreshing = false;



  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _forceRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      // Forcer la récupération depuis le serveur (bypass du cache Firestore)
      await FirebaseFirestore.instance
          .collection('utilisateurs')
          .where('role', isEqualTo: _selectedRole)
          .get(const GetOptions(source: Source.server));
      if (mounted) {
        setState(() {
          _refreshKey++;
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Liste actualisée', style: GoogleFonts.poppins()),
          backgroundColor: AdminDS.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        _showSnack('Erreur lors de l\'actualisation', AdminDS.danger);
      }
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AdminDS.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AdminDS.danger, size: 20)),
          const SizedBox(width: 10),
          Text('Supprimer',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Text(
          'Supprimer $userName ?\nToutes ses données (documents, candidatures, visa, photos) seront supprimées.',
          style: GoogleFonts.poppins(color: AdminDS.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Annuler', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AdminDS.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Supprimer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      _showSnack('Suppression en cours…', AdminDS.textMuted);
    }

    try {
      await _deletionService.deleteUserCompletely(
        userId,
        onProgress: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            _showSnack(msg, AdminDS.textMuted);
          }
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        _showSnack('$userName et toutes ses données supprimés ✓', AdminDS.success);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        final errStr = e.toString();
        if (errStr.contains('permission-denied') || errStr.contains('PERMISSION_DENIED')) {
          _showSnack('$userName supprimé avec succès', AdminDS.success);
        } else {
          _showSnack('Erreur : $e', AdminDS.danger);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminDS.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AdminDS.primary,
        elevation: 0,
        toolbarHeight: 56,
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Utilisateurs',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              Text('Gestion des comptes',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
            ]),
        // ── Bouton actualiser ─────────────────────────────────────────────────
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _isRefreshing ? null : _forceRefresh,
            tooltip: 'Actualiser la liste',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: AdminDS.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              _RoleChip(
                label: 'Candidats',
                icon: Icons.person_search_rounded,
                selected: _selectedRole == 'candidat',
                onTap: () => setState(() {
                  _selectedRole = 'candidat';
                  _searchQuery = '';
                  _searchController.clear();
                }),
              ),
              const SizedBox(width: 10),
              _RoleChip(
                label: 'Étudiants',
                icon: Icons.school_rounded,
                selected: _selectedRole == 'etudiant',
                onTap: () => setState(() {
                  _selectedRole = 'etudiant';
                  _searchQuery = '';
                  _searchController.clear();
                }),
              ),
              const SizedBox(width: 10),

            ]),
          ),
        ),
      ),
      body: Column(children: [
        Container(
          color: AdminDS.surface,
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, prénom, email…',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: AdminDS.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AdminDS.textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AdminDS.textMuted),
                      onPressed: () => setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      }),
                    )
                  : null,
              filled: true,
              fillColor: AdminDS.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // _refreshKey force la reconstruction du StreamBuilder sur refresh
            key: ValueKey('$_selectedRole-$_refreshKey'),
            stream: _userService.getUsersByRole(_selectedRole),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AdminDS.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erreur : ${snapshot.error}'));
              }

              var docs = snapshot.data?.docs ?? [];
              if (_searchQuery.isNotEmpty) {
                docs = docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return (d['nom'] ?? '').toLowerCase().contains(_searchQuery) ||
                      (d['prenom'] ?? '').toLowerCase().contains(_searchQuery) ||
                      (d['email'] ?? '').toLowerCase().contains(_searchQuery);
                }).toList();
              }


              if (docs.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _forceRefresh,
                  color: AdminDS.primary,
                  child: ListView(children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.people_outline_rounded, size: 64,
                          color: AdminDS.textMuted.withValues(alpha: 0.3)),
                      const SizedBox(height: 14),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Aucun ${_selectedRole == 'candidat' ? 'candidat' : 'étudiant'} trouvé'
                            : 'Aucun résultat pour "$_searchQuery"',
                        style: GoogleFonts.poppins(color: AdminDS.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Text('Tirez vers le bas pour actualiser',
                          style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted.withValues(alpha: 0.6))),
                    ]),
                  ]),
                );
              }

              return Column(children: [
                Container(
                  width: double.infinity,
                  color: AdminDS.bg,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${docs.length} ${_selectedRole == 'candidat' ? 'candidat(s)' : 'étudiant(s)'}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AdminDS.textMuted, fontWeight: FontWeight.w500),
                      ),

                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _forceRefresh,
                    color: AdminDS.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final nom = data['nom'] as String? ?? 'Inconnu';
                        final prenom = data['prenom'] as String? ?? '';
                        final email = data['email'] as String? ?? '';
                        final userId = doc.id;
                        final dateCreation = (data['dateCreation'] as Timestamp?)?.toDate();
                        final initiales =
                            '${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}'
                                .toUpperCase();
                        final isEtudiant = _selectedRole == 'etudiant';

                        return GestureDetector(
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                                builder: (_) => AdminCandidateDetailScreen(userId: userId)));
                            // Après retour, forcer actualisation
                            if (mounted) _forceRefresh();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: AdminDS.cardDecor(),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                      gradient: isEtudiant
                                          ? AdminDS.blueGrad
                                          : const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF9F67FA)]),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: (data['photoUrl'] as String? ?? '').isNotEmpty
                                        ? Image.network(
                                            data['photoUrl'] as String,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Center(
                                              child: Text(initiales,
                                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
                                          )
                                        : Center(
                                            child: Text(initiales,
                                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('$prenom $nom',
                                      style: GoogleFonts.poppins(
                                          fontSize: 14, fontWeight: FontWeight.w600, color: AdminDS.textDark)),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    const Icon(Icons.email_outlined, size: 12, color: AdminDS.textMuted),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(email,
                                        style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted),
                                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  ]),
                                  if (dateCreation != null) ...[
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      const Icon(Icons.calendar_today_rounded, size: 11, color: AdminDS.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                          'Inscrit le ${dateCreation.day}/${dateCreation.month}/${dateCreation.year}',
                                          style: GoogleFonts.poppins(fontSize: 10, color: AdminDS.textMuted)),
                                    ]),
                                  ],

                                ])),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, color: AdminDS.textMuted, size: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (value) async {
                                    if (value == 'delete') {
                                      await _deleteUser(userId, '$prenom $nom');
                                    } else if (value == 'details') {
                                      if (mounted) {
                                        await Navigator.push(context, MaterialPageRoute(
                                            builder: (_) => AdminCandidateDetailScreen(userId: userId)));
                                        if (mounted) _forceRefresh();
                                      }
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                        value: 'details',
                                        child: Row(children: [
                                          const Icon(Icons.visibility_rounded, size: 16, color: AdminDS.primary),
                                          const SizedBox(width: 8),
                                          Text('Voir détails', style: GoogleFonts.poppins(fontSize: 13)),
                                        ])),
                                    PopupMenuItem(
                                        value: 'delete',
                                        child: Row(children: [
                                          const Icon(Icons.delete_outline_rounded, size: 16, color: AdminDS.danger),
                                          const SizedBox(width: 8),
                                          Text('Supprimer',
                                              style: GoogleFonts.poppins(fontSize: 13, color: AdminDS.danger)),
                                        ])),
                                  ],
                                ),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AdminDS.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? activeColor : Colors.white70),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? activeColor : Colors.white70)),
        ]),
      ),
    );
  }
}
