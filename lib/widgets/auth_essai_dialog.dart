import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../services/api.dart';

/// Modale d'inscription / connexion utilisée avant le démarrage de l'essai
/// gratuit Studio Live. Le compte est créé si nécessaire, l'essai est démarré
/// côté serveur, puis l'email d'accueil / d'activation est envoyé via Resend.
Future<bool> demarrerEssaiAvecCompte(BuildContext context) async {
  final resultat = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _AuthEssaiDialog(),
  );
  return resultat == true;
}

class _AuthEssaiDialog extends StatefulWidget {
  const _AuthEssaiDialog();

  @override
  State<_AuthEssaiDialog> createState() => _AuthEssaiDialogState();
}

class _AuthEssaiDialogState extends State<_AuthEssaiDialog> {
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _inscription = true;
  bool _chargement = false;
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final email = _email.text.trim().toLowerCase();
    final motDePasse = _motDePasse.text;
    final nom = _nom.text.trim();

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
      setState(() => _erreur = 'Entrez une adresse email valide.');
      return;
    }
    if (motDePasse.length < 6) {
      setState(() => _erreur = 'Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }
    if (_inscription && nom.length < 2) {
      setState(() => _erreur = 'Entrez votre nom (2 caractères minimum).');
      return;
    }

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    final auth = Supabase.instance.client.auth;
    var compteCree = false;

    try {
      if (_inscription) {
        // Inscription native Supabase : confirmation par email via le SMTP
        // Resend configuré dans Supabase Auth.
        final inscription = await auth.signUp(
          email: email,
          password: motDePasse,
          data: <String, dynamic>{'full_name': nom},
          emailRedirectTo: AppConfig.siteUrl,
        );
        if (inscription.session == null) {
          if (!mounted) return;
          setState(() {
            _chargement = false;
            _erreur =
                'Compte créé. Un email de confirmation vient de vous être envoyé à $email. '
                'Cliquez sur le lien, puis revenez ici et choisissez « J\'ai déjà un compte » '
                'pour activer votre essai de 3 jours.';
          });
          return;
        }
        compteCree = true;
      } else {
        await auth.signInWithPassword(email: email, password: motDePasse);
      }

      try {
        await ApiService.demarrerEssai();
        // Un seul email par adresse : il porte le message d'activation d'essai.
        await ApiService.envoyerEmailAccueil(
          email,
          prenom: nom.isEmpty ? null : nom,
          source: 'essai',
        );
      } catch (erreurEssai) {
        // Si l'essai a déjà été utilisé, on garde un message clair mais on
        // laisse le compte connecté : l'utilisateur pourra s'abonner.
        if (!compteCree) rethrow;
        await ApiService.envoyerEmailAccueil(
          email,
          prenom: nom.isEmpty ? null : nom,
          source: 'inscription',
        );
        rethrow;
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = _message(erreur);
      });
    }
  }

  String _message(Object erreur) {
    if (erreur is ApiException) return erreur.message;
    if (erreur is AuthException) {
      final texte = erreur.message.toLowerCase();
      if (texte.contains('already registered')) {
        return 'Un compte existe déjà avec cet email. Passez en mode connexion.';
      }
      if (texte.contains('invalid login credentials')) {
        return 'Email ou mot de passe incorrect.';
      }
      if (texte.contains('email not confirmed')) {
        return 'Confirmez votre adresse email avant de vous connecter.';
      }
      return erreur.message;
    }
    return 'Opération impossible pour le moment. Réessayez dans un instant.';
  }

  @override
  Widget build(BuildContext context) {
    final peutFermer = !_chargement;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: GlassCard(
          miseEnAvant: true,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: K.marque,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.card_giftcard_rounded, color: K.bg, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Votre essai de 3 jours',
                            style: TextStyle(
                              color: K.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sans carte bancaire, sans prélèvement.',
                            style: TextStyle(color: K.muted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: peutFermer ? () => Navigator.pop(context, false) : null,
                      icon: const Icon(Icons.close_rounded, color: K.muted, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_inscription) ...<Widget>[
                  TextField(
                    controller: _nom,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: K.text),
                    decoration: champ(
                      label: 'Votre nom',
                      icone: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: K.text),
                  decoration: champ(
                    label: 'Votre email',
                    icone: Icons.alternate_email_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _motDePasse,
                  obscureText: true,
                  onSubmitted: (_) => _chargement ? null : _valider(),
                  style: const TextStyle(color: K.text),
                  decoration: champ(
                    label: 'Mot de passe (6 caractères min.)',
                    icone: Icons.key_rounded,
                  ),
                ),
                if (_erreur != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: K.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: K.danger.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _erreur!,
                      style: const TextStyle(color: K.danger, fontSize: 11.5, height: 1.45),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                OrButton(
                  label: _inscription
                      ? 'Créer mon compte & démarrer l\'essai'
                      : 'Se connecter & démarrer l\'essai',
                  icone: _inscription ? Icons.rocket_launch_rounded : Icons.login_rounded,
                  chargement: _chargement,
                  onPressed: _chargement ? null : _valider,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _chargement
                      ? null
                      : () => setState(() {
                            _inscription = !_inscription;
                            _erreur = null;
                          }),
                  child: Text(
                    _inscription
                        ? 'J\'ai déjà un compte · Se connecter'
                        : 'Pas encore de compte · S\'inscrire',
                    style: const TextStyle(color: K.or, fontSize: 12),
                  ),
                ),
                const Text(
                  'L\'essai inclut la régie, le chat IA (20 messages/jour) et la salle live. '
                  'Le Livre Guide s\'ouvre après l\'abonnement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: K.faint, fontSize: 10.5, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
