// screens/candidate/candidate_home.dart
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'candidature_screen.dart';
import 'mes_candidatures_screen.dart';
import 'suivi_screen.dart';
import 'visa_screen.dart';
import 'profile_screen.dart';
import 'payment_screen.dart';
import '../../models/role.dart';

class CandidateHomeScreen extends StatefulWidget {
  final UserRole role;
  const CandidateHomeScreen({super.key, required this.role});

  @override
  State<CandidateHomeScreen> createState() => _CandidateHomeScreenState();
}

class _CandidateHomeScreenState extends State<CandidateHomeScreen> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(role: widget.role),
      const CandidatureScreen(),
      MesCandidaturesScreen(),
      const SuiviScreen(),
      const PaymentScreen(),
      const VisaScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 10,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Accueil"),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: "Candidature"),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: "Candidatures"),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: "Suivi"),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: "Paiement"),
          BottomNavigationBarItem(icon: Icon(Icons.airplane_ticket), label: "Visa"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }
}