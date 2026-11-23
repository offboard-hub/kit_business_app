import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/logo_ebooklive.dart';
import '../widgets/whatsapp.dart';

/// ============================================================================
///  SPLASH / PRÉCHARGEUR FLUTTER
///  Affiché tant que Supabase et le pays de l'utilisateur sont initialisés.
///  Le même univers visuel que le preloader web (`web/index.html`) : fond
///  #090D16, logo vectoriel animé, barre de progression, message rassurant.
/// ============================================================================
class SplashPage extends StatelessWidget {
  const SplashPage({
    super.key,
    required this.progression,
    this.message = 'Préparation de votre boutique…',
    this.erreur,
    this.onReessayer,
    this.onContinuer,
  });

  final double progression;
  final String message;
  final Object? erreur;
  final VoidCallback? onReessayer;
  final VoidCallback? onContinuer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: K.bg,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ColoredBox(color: K.bg),
          Positioned(
            top: -280,
            left: -200,
            child: _Halo(couleur: K.or, taille: 680, opacite: 0.13),
          ),
          Positioned(
            bottom: -300,
            right: -220,
            child: _Halo(couleur: K.emeraude, taille: 700, opacite: 0.10),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const LogoEbookliveAnime(size: 116),
                    const SizedBox(height: 26),
                    const WordmarkEbooklive(taille: 30),
                    const SizedBox(height: 10),
                    const Text(
                      'La Boutique  ·  Studio Live',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: K.muted,
                        fontSize: 12,
                        letterSpacing: 2.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 38),
                    if (erreur != null)
                      _Erreur(
                        erreur: erreur!,
                        onReessayer: onReessayer,
                        onContinuer: onContinuer,
                      )
                    else ...<Widget>[
                      _Barre(progression: progression),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        child: Text(
                          message,
                          key: ValueKey<String>(message),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: K.muted,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      const _Confiance(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Barre extends StatelessWidget {
  const _Barre({required this.progression});

  final double progression;

  @override
  Widget build(BuildContext context) {
    final valeur = progression.clamp(0, 1).toDouble();
    return Column(
      children: <Widget>[
        Container(
          height: 6,
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: valeur),
              duration: const Duration(milliseconds: 620),
              curve: Curves.easeOutCubic,
              builder: (context, animee, _) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: animee == 0 ? 0.04 : animee,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: K.marque,
                        boxShadow: <BoxShadow>[
                          BoxShadow(color: Color(0x5534D399), blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${(valeur * 100).round()} %',
          style: const TextStyle(
            color: K.faint,
            fontSize: 10.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Confiance extends StatelessWidget {
  const _Confiance();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: const <Widget>[
        _MiniPreuve(icone: Icons.lock_outline_rounded, texte: 'Paiement sécurisé'),
        _MiniPreuve(icone: Icons.public_rounded, texte: 'Tous les pays'),
        _MiniPreuve(icone: Icons.bolt_rounded, texte: 'Livraison immédiate'),
      ],
    );
  }
}

class _MiniPreuve extends StatelessWidget {
  const _MiniPreuve({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icone, size: 13, color: K.faint),
        const SizedBox(width: 5),
        Text(texte, style: const TextStyle(color: K.faint, fontSize: 10.5)),
      ],
    );
  }
}

class _Erreur extends StatelessWidget {
  const _Erreur({
    required this.erreur,
    this.onReessayer,
    this.onContinuer,
  });

  final Object erreur;
  final VoidCallback? onReessayer;
  final VoidCallback? onContinuer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: K.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: K.danger.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: <Widget>[
              const Icon(Icons.wifi_off_rounded, color: K.danger, size: 26),
              const SizedBox(height: 10),
              const Text(
                'Connexion impossible pour le moment',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: K.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$erreur',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: K.muted, fontSize: 11.5, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            if (onContinuer != null)
              Expanded(
                child: OrButton(
                  label: 'Continuer',
                  plein: false,
                  hauteur: 46,
                  onPressed: onContinuer,
                ),
              ),
            if (onContinuer != null && onReessayer != null) const SizedBox(width: 10),
            if (onReessayer != null)
              Expanded(
                child: OrButton(
                  label: 'Réessayer',
                  icone: Icons.refresh_rounded,
                  hauteur: 46,
                  onPressed: onReessayer,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const AideWhatsApp(),
      ],
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.couleur, required this.taille, required this.opacite});

  final Color couleur;
  final double taille;
  final double opacite;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[couleur.withValues(alpha: opacite), couleur.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
