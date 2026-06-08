import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'role_selection_screen.dart';
import 'package:udm_application/screens/admin/admin_home_screen.dart';
import 'package:udm_application/screens/candidate/candidate_home.dart';
import 'package:udm_application/screens/student/student_home_screen.dart';
import 'package:udm_application/services/auth_service.dart';
import 'package:udm_application/models/role.dart';

class LoginScreen extends StatefulWidget {
  final String? expectedRole;
  const LoginScreen({super.key, this.expectedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final user = await _authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (user == null) throw Exception("Échec de connexion");
      final role = await _authService.getUserRole(user.uid);
      if (!mounted) return;
      if (role == null) {
        await _authService.signOut();
        throw Exception("Ce compte n'existe plus ou a été supprimé. Contactez l'administrateur.");
      }
      if (!user.emailVerified && role != 'admin') {
        await _authService.signOut();
        setState(() { _errorMessage = 'Veuillez vérifier votre email avant de vous connecter.'; _isLoading = false; });
        return;
      }
      if (widget.expectedRole != null && role != widget.expectedRole && role != 'admin') {
        await _authService.signOut();
        String errorMsg;
        if (widget.expectedRole == 'candidat' && role == 'etudiant') {
          errorMsg = 'Ce compte est un compte étudiant. Utilisez le bouton "Étudiant".';
        } else if (widget.expectedRole == 'etudiant' && role == 'candidat') {
          errorMsg = 'Ce compte est un compte candidat. Utilisez le bouton "Candidat".';
        } else {
          errorMsg = 'Rôle non autorisé pour cette connexion.';
        }
        setState(() { _errorMessage = errorMsg; _isLoading = false; });
        return;
      }
      Widget nextScreen;
      switch (role) {
        case 'admin': nextScreen = const AdminHomeScreen(); break;
        case 'etudiant': nextScreen = const StudentHomeScreen(); break;
        default: nextScreen = CandidateHomeScreen(role: UserRole.candidat);
      }
      await _authService.setOnline();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => nextScreen));
    } catch (e) {
      setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(hintText: 'Entrez votre email', border: OutlineInputBorder()),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez saisir votre email')));
                return;
              }
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _authService.sendPasswordResetEmail(email);
                if (mounted) messenger.showSnackBar(const SnackBar(content: Text('Email de réinitialisation envoyé !'), backgroundColor: Colors.green));
              } catch (e) {
                if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen())),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Theme.of(context).primaryColor, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo agrandi
                      Image.asset(
                        'assets/images/logo_udm.png',
                        height: 220, width: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.school, size: 120),
                      ),
                      SizedBox(height: 8),
                      const Text('Connexion', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) { if (v == null || v.isEmpty) return 'Email requis'; if (!v.contains('@')) return 'Email invalide'; return null; },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: _obscurePassword,
                        validator: (v) { if (v == null || v.isEmpty) return 'Mot de passe requis'; if (v.length < 6) return '6 caractères minimum'; return null; },
                      ),
                      SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: _forgotPassword, child: const Text('Mot de passe oublié ?')),
                      ),
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 4),
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Text(_errorMessage!, style: TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                        ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                              : const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600), maxLines: 1),
                                ),
                        ),
                      ),
                      SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: const Text("Pas encore de compte ? S'inscrire"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
