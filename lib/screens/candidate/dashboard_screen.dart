import 'package:flutter/material.dart';
import '../../models/role.dart';
import 'candidature_screen.dart';
import 'mes_candidatures_screen.dart';  // renommé
import 'suivi_screen.dart';
import 'visa_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatelessWidget {
  final UserRole role;
  const DashboardScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Accueil"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bannière animée (zoom au chargement)
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, double scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/UDM.JPG'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        "Université des Mascareignes",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Bienvenue sur votre espace candidat",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Rôle : ${role.name}",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              "Utilisez les onglets ci-dessous ou cliquez sur les cartes :",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              context,
              Icons.assignment,
              "Candidature",
              "Soumettre une nouvelle demande",
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CandidatureScreen())),
            ),
            _buildInfoCard(
              context,
              Icons.folder,
              "Mes candidatures",  
              "Consulter vos dossiers et documents",
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>  MesCandidaturesScreen())), // classe renommée
            ),
            _buildInfoCard(
              context,
              Icons.timeline,
              "Suivi",
              "État d'avancement de vos dossiers",
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SuiviScreen())),
            ),
            _buildInfoCard(
              context,
              Icons.airplane_ticket,
              "Visa",
              "Gérer votre dossier de visa",
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const VisaScreen())),
            ),
            _buildInfoCard(
              context,
              Icons.person,
              "Profil",
              "Modifier vos informations",
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuad,
      builder: (context, double opacity, child) {
        return Opacity(opacity: opacity, child: child);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListTile(
              leading: Icon(icon,
                  size: 32, color: Theme.of(context).colorScheme.primary),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ),
        ),
      ),
    );
  }
}