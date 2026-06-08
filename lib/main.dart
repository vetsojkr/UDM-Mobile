import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/candidate/candidate_home.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'models/role.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const UDMApp());
}

class UDMApp extends StatelessWidget {
  const UDMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UDM Mobile',
      theme: AppTheme.lightTheme,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const RoleSelectionScreen();
        }

        // Vérifier si l'email a été validé
        if (!user.emailVerified) {
          return const EmailVerificationScreen();
        }

        return FutureBuilder<String?>(
          future: _authService.getUserRole(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = roleSnapshot.data;

            if (role == 'admin') {
              return const AdminHomeScreen();
            } else if (role == 'candidat') {
              return CandidateHomeScreen(role: UserRole.candidat);
            } else if (role == 'etudiant') {
              return const StudentHomeScreen();
            } else {
              // Compte supprimé ou rôle introuvable → déconnexion + message clair
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await FirebaseAuth.instance.signOut();
              });
              return const _AccountDeletedScreen();
            }
          },
        );
      },
    );
  }
}

/// Écran affiché quand le compte Firebase existe mais le document Firestore a été supprimé
class _AccountDeletedScreen extends StatelessWidget {
  const _AccountDeletedScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FB),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_circle_outlined, size: 64, color: Colors.red),
              ),
              SizedBox(height: 24),
              const Text(
                "Compte introuvable",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
              ),
              SizedBox(height: 12),
              const Text(
                "Ce compte n'existe plus ou a été supprimé.\nVeuillez créer un nouveau compte.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: Icon(Icons.arrow_back_rounded),
                  label: const Text("Retour à l'accueil"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}