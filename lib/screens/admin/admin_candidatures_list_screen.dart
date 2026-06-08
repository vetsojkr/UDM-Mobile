// lib/screens/admin/admin_candidatures_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_candidature_detail_screen.dart';
import 'admin_home_screen.dart';

class AdminCandidaturesListScreen extends StatefulWidget {
  const AdminCandidaturesListScreen({super.key});
  @override
  State<AdminCandidaturesListScreen> createState() => _AdminCandidaturesListScreenState();
}

class _AdminCandidaturesListScreenState extends State<AdminCandidaturesListScreen>
    with TickerProviderStateMixin {

  // ── Contrôleurs d'onglets ────────────────────────────────────────────────
  TabController? _tabController;
  List<String>   _programmes = [];

  // ── Filtres ──────────────────────────────────────────────────────────────
  String _searchQuery  = '';
  String _filterStatut = 'tous';

  // ── Clé pour forcer la reconstruction du TabController ───────────────────
  // (quand la liste de programmes change suite à un snapshot)
  String _lastProgrammesKey = '';

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // Reconstruit le TabController uniquement si les programmes ont changé
  void _rebuildTabs(List<String> programmes) {
    final key = programmes.join(',');
    if (key == _lastProgrammesKey) return; // rien à faire
    _lastProgrammesKey = key;

    final currentIndex = _tabController?.index ?? 0;
    final oldCtrl = _tabController;

    _tabController = programmes.isNotEmpty
        ? TabController(
            length: programmes.length,
            vsync: this,
            initialIndex: currentIndex < programmes.length ? currentIndex : 0,
          )
        : null;

    // Dispose l'ancien après le build
    WidgetsBinding.instance.addPostFrameCallback((_) => oldCtrl?.dispose());
  }

  List<QueryDocumentSnapshot> _filtered(List<QueryDocumentSnapshot> list) {
    return list.where((doc) {
      final d  = doc.data() as Map<String, dynamic>;
      final q  = _searchQuery.toLowerCase();
      final ok = q.isEmpty ||
          (d['nom']    ?? '').toLowerCase().contains(q) ||
          (d['prenom'] ?? '').toLowerCase().contains(q) ||
          (d['email']  ?? '').toLowerCase().contains(q);
      final statutOk = _filterStatut == 'tous' ||
          (d['statut'] ?? 'soumis') == _filterStatut;
      return ok && statutOk;
    }).toList();
  }

  // ── Groupement docs → programmes ─────────────────────────────────────────
  Map<String, List<QueryDocumentSnapshot>> _group(List<QueryDocumentSnapshot> docs) {
    final Map<String, List<QueryDocumentSnapshot>> g = {'Tous': []};
    for (final doc in docs) {
      final prog = (doc.data() as Map<String, dynamic>)['programme'] as String? ?? 'Autre';
      g.putIfAbsent(prog, () => []).add(doc);
      g['Tous']!.add(doc);
    }
    return g;
  }

  @override
  Widget build(BuildContext context) {
    // ── StreamBuilder directement dans build — temps réel garanti ───────────
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('candidatures')
          .orderBy('dateSoumission', descending: true)
          .snapshots(),
      builder: (context, snapshot) {

        // Chargement initial
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            backgroundColor: AdminDS.bg,
            body: const Center(child: CircularProgressIndicator(color: AdminDS.primary)),
          );
        }

        // Groupement et reconstruction des onglets
        final docs     = snapshot.data?.docs ?? [];
        final grouped  = _group(docs);
        final progs    = ['Tous', ...grouped.keys.where((k) => k != 'Tous').toList()..sort()];

        // Rebuild tabs si nécessaire (sans setState — déjà dans build)
        _rebuildTabs(progs);
        _programmes = progs;

        // Aucune candidature
        if (progs.isEmpty || _tabController == null) {
          return Scaffold(
            backgroundColor: AdminDS.bg,
            appBar: _buildAppBar(isEmpty: true),
            body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.folder_open_rounded, size: 64,
                  color: AdminDS.textMuted.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text('Aucune candidature trouvée.',
                  style: GoogleFonts.poppins(color: AdminDS.textMuted)),
            ])),
          );
        }

        return Scaffold(
          backgroundColor: AdminDS.bg,
          appBar: _buildAppBar(isEmpty: false),
          body: Column(children: [
            // ── Barre recherche + filtre ────────────────────────────────────
            _buildSearchBar(),
            // ── Contenu par onglet ─────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController!,
                children: _programmes.map((prog) {
                  final all      = grouped[prog] ?? [];
                  final filtered = _filtered(all);

                  if (filtered.isEmpty) {
                    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search_off_rounded, size: 52,
                          color: AdminDS.textMuted.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('Aucun résultat',
                          style: GoogleFonts.poppins(color: AdminDS.textMuted)),
                    ]));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _buildCard(filtered[i]),
                  );
                }).toList(),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar({required bool isEmpty}) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AdminDS.primary,
      elevation: 0,
      toolbarHeight: 56,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
        Text('Candidatures',
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        Text('Par programme universitaire',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
      ]),
      bottom: isEmpty || _tabController == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AdminDS.blueGrad,
                  border: Border(
                      bottom: BorderSide(
                          color: AdminDS.gold.withValues(alpha: 0.3), width: 1)),
                ),
                child: TabBar(
                  controller: _tabController!,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: AdminDS.gold,
                  indicatorWeight: 3,
                  labelStyle:
                      GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tabs: _programmes.map((p) => Tab(text: p, height: 40)).toList(),
                ),
              ),
            ),
    );
  }

  // ── Barre de recherche ────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: AdminDS.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher…',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: AdminDS.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AdminDS.textMuted),
              filled: true, fillColor: AdminDS.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: AdminDS.bg, borderRadius: BorderRadius.circular(10)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterStatut,
              icon: const Icon(Icons.filter_list_rounded, size: 18, color: AdminDS.primary),
              style: GoogleFonts.poppins(fontSize: 12, color: AdminDS.textDark),
              items: const [
                DropdownMenuItem(value: 'tous',           child: Text('Tous')),
                DropdownMenuItem(value: 'soumis',         child: Text('Soumis')),
                DropdownMenuItem(value: 'en_verification',child: Text('En vérif.')),
                DropdownMenuItem(value: 'accepte',        child: Text('Acceptés')),
                DropdownMenuItem(value: 'refuse',         child: Text('Refusés')),
              ],
              onChanged: (v) => setState(() => _filterStatut = v ?? 'tous'),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Carte candidature ─────────────────────────────────────────────────────
  Widget _buildCard(QueryDocumentSnapshot doc) {
    final data     = doc.data() as Map<String, dynamic>;
    final statut   = data['statut']  as String? ?? 'soumis';
    final date     = (data['dateSoumission'] as Timestamp?)?.toDate();
    final nom      = data['nom']    as String? ?? 'Inconnu';
    final prenom   = data['prenom'] as String? ?? '';
    final email    = data['email']  as String? ?? '';
    final initials = '${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}'
        .toUpperCase();

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AdminCandidatureDetailScreen(candidatureId: doc.id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: AdminDS.cardDecor(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(gradient: AdminDS.blueGrad,
                  borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(initials,
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$prenom $nom',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AdminDS.textDark)),
              const SizedBox(height: 2),
              Text(email,
                  style: GoogleFonts.poppins(fontSize: 11, color: AdminDS.textMuted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (date != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 10, color: AdminDS.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    '${date.day.toString().padLeft(2, '0')}/'
                    '${date.month.toString().padLeft(2, '0')}/${date.year}',
                    style: GoogleFonts.poppins(fontSize: 10, color: AdminDS.textMuted)),
                ]),
              ],
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminDS.statusColor(statut).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AdminDS.statusIcon(statut),
                      size: 11, color: AdminDS.statusColor(statut)),
                  const SizedBox(width: 3),
                  Text(AdminDS.statusLabel(statut),
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AdminDS.statusColor(statut))),
                ]),
              ),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right_rounded, color: AdminDS.textMuted, size: 18),
            ]),
          ]),
        ),
      ),
    );
  }
}
