import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../widgets/app_header.dart';
import '../widgets/whatsapp.dart';

/// ============================================================================
///  AUTHENTIFICATION — connexion ou création automatique du compte
///  (aucun lien de confirmation : l'accès est immédiat).
/// ============================================================================
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _motDePasse = TextEditingController();
  bool _chargement = false;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  void _toast(String message, Color couleur) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: couleur, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _connexion() async {
    final email = _email.text.trim();
    final motDePasse = _motDePasse.text.trim();

    if (email.isEmpty || motDePasse.length < 6) {
      _toast('Entrez un email et un mot de passe (6 caractères minimum).', K.clay);
      return;
    }

    setState(() => _chargement = true);
    final auth = Supabase.instance.client.auth;

    try {
      try {
        await auth.signInWithPassword(email: email, password: motDePasse);
      } on AuthException catch (erreur) {
        if (!erreur.message.toLowerCase().contains('invalid login credentials')) rethrow;

        final creation = await auth.signUp(email: email, password: motDePasse);
        if (creation.session == null) {
          if (!mounted) return;
          _toast(
            'Compte créé. Confirmez votre email pour vous connecter (option à désactiver dans Supabase).',
            K.gold,
          );
          setState(() => _chargement = false);
          return;
        }
      }

      // Email d'accueil informatif, sans lien de confirmation.
      await ApiService.envoyerEmailAccueil(email, source: 'inscription');

      if (!mounted) return;
      setState(() => _chargement = false);
      Navigator.pushReplacementNamed(context, '/mon-espace');
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _chargement = false);
      _toast(
        erreur is AuthException ? erreur.message : 'Connexion impossible pour le moment.',
        K.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const AppHeader(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
                      child: GlassCard(
                        miseEnAvant: true,
                        padding: const EdgeInsets.all(26),
                        child: Column(
                          children: [
                            const AppLogo(size: 64),
                            const SizedBox(height: 16),
                            const Text(
                              'Votre espace e-booklive',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: K.sand, fontSize: 21, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Retrouvez vos kits, vos liens et vos commandes. Pas de confirmation d\'email.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: K.mist, fontSize: 12.5, height: 1.5),
                            ),
                            const SizedBox(height: 22),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: K.sand),
                              decoration: champ(
                                label: 'Votre email',
                                icone: Icons.alternate_email_rounded,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _motDePasse,
                              obscureText: true,
                              style: const TextStyle(color: K.sand),
                              decoration: champ(
                                label: 'Mot de passe',
                                icone: Icons.key_rounded,
                              ),
                            ),
                            const SizedBox(height: 22),
                            OrButton(
                              label: 'Se connecter / S\'inscrire',
                              icone: Icons.login_rounded,
                              chargement: _chargement,
                              onPressed: _connexion,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Pas de compte ? Il sera créé automatiquement.',
                              style: TextStyle(color: K.mist, fontSize: 11.5),
                            ),
                            const SizedBox(height: 18),
                            const Divider(color: Colors.white12),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                              icon: const Icon(Icons.arrow_back_rounded, size: 16, color: K.mist),
                              label: const Text(
                                'Retour à l\'accueil',
                                style: TextStyle(color: K.mist, fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const AideWhatsApp(pleinLargeur: true),
                            const SizedBox(height: 12),
                            Text(
                              'Une question ? ${AppConfig.emailSupport}',
                              style: TextStyle(color: K.mist.withValues(alpha: 0.8), fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
