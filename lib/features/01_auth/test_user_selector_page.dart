import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TestUserSelectorPage extends StatefulWidget {
  const TestUserSelectorPage({super.key});

  @override
  State<TestUserSelectorPage> createState() => _TestUserSelectorPageState();
}

class _TestUserSelectorPageState extends State<TestUserSelectorPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Map<String, ({String email, String password})> testUsers = const {
    'Pierre': (
      email: 'pierre@agenda-social.test',
      password: 'Test1234!',
    ),
    'Alex': (
      email: 'alex@agenda-social.test',
      password: 'Test1234!',
    ),
    'Jack': (
      email: 'jack@agenda-social.test',
      password: 'Test1234!',
    ),
  };

  String? _loadingUserLabel;
  String? _errorMessage;

  Future<void> _selectUser(BuildContext context, String userLabel) async {
    final trimmedUserLabel = userLabel.trim();
    if (trimmedUserLabel.isEmpty) return;

    final credentials = testUsers[trimmedUserLabel];
    if (credentials == null) {
      setState(() {
        _errorMessage = 'Utilisateur de test introuvable.';
      });
      return;
    }

    setState(() {
      _loadingUserLabel = trimmedUserLabel;
      _errorMessage = null;
    });

    try {
      final currentUser = _auth.currentUser;

      if (currentUser != null) {
        await _auth.signOut();
      }

      await _auth.signInWithEmailAndPassword(
        email: credentials.email,
        password: credentials.password,
      );

      if (!mounted) return;

      // Rien à faire ici :
      // app.dart écoute authStateChanges() et navigue automatiquement.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = switch (e.code) {
          'user-not-found' => 'Compte de test introuvable dans Firebase Auth.',
          'wrong-password' => 'Mot de passe incorrect pour ce compte de test.',
          'invalid-email' => 'Email de test invalide.',
          'invalid-credential' => 'Identifiants Firebase invalides.',
          'operation-not-allowed' =>
            'Connexion email/mot de passe non activée dans Firebase Auth.',
          _ => 'Connexion impossible : ${e.message ?? e.code}',
        };
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Connexion impossible : $e';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loadingUserLabel = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserEmail = _auth.currentUser?.email?.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un utilisateur de test'),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: testUsers.length,
              itemBuilder: (context, index) {
                final String userLabel = testUsers.keys.elementAt(index).trim();
                final credentials = testUsers[userLabel];
                final userEmail = credentials?.email.trim().toLowerCase() ?? '';

                final bool isLoading = _loadingUserLabel == userLabel;
                final bool isSelected =
                    currentUserEmail != null && currentUserEmail == userEmail;

                return ListTile(
                  leading: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                  title: Text(userLabel),
                  subtitle: isSelected
                      ? const Text('Utilisateur actuellement connecté')
                      : null,
                  enabled: _loadingUserLabel == null,
                  onTap: () => _selectUser(context, userLabel),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}