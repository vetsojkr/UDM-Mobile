import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:udm_application/services/auth_service.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String _message = '';
  User? _user;

  // Cooldown pour éviter les surcharges Firebase
  bool _cooldown = false;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _checkVerification();
  }

  Future<void> _checkVerification() async {
    await _authService.reloadUser();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  Future<void> _startCooldown() async {
    setState(() {
      _cooldown = true;
      _cooldownSeconds = 60;
    });
    for (int i = 59; i >= 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _cooldownSeconds = i);
    }
    if (mounted) setState(() => _cooldown = false);
  }

  Future<void> _resendVerificationEmail() async {
    if (_cooldown) return;
    setState(() {
      _isLoading = true;
      _message = '';
    });
    try {
      await _authService.sendEmailVerification();
      setState(() {
        _message = 'Un nouvel email de vérification a été envoyé.';
      });
      _startCooldown();
    } catch (e) {
      setState(() {
        _message = 'Erreur : $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification email')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email_outlined, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Vérifiez votre adresse email',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Un email de vérification a été envoyé à ${_user?.email ?? ''}. Cliquez sur le lien dans cet email pour activer votre compte.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            // Message spam
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Si vous ne trouvez pas l\'email dans votre boîte principale, pensez à vérifier vos spams ou courriers indésirables.',
                      style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_message, style: const TextStyle(color: Colors.green)),
              ),
            ElevatedButton.icon(
              onPressed: (_isLoading || _cooldown) ? null : _resendVerificationEmail,
              icon: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh),
              label: Text(_cooldown
                  ? 'Renvoyer dans $_cooldownSeconds s'
                  : 'Renvoyer l\'email'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter et revenir à la connexion'),
            ),
          ],
        ),
      ),
    );
  }
}