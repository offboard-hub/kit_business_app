import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../widgets/logo_ebooklive.dart';

/// ============================================================================
///  DESIGN SYSTEM e-booklive
///  Fond sombre profond (#090D16), verre dépoli (#111827), accents or/émeraude.
///  Inspiré des meilleures plateformes SaaS (Stripe / Linear / Vercel) :
///  espacements larges, bordures fines, une seule action principale par écran.
/// ============================================================================
class K {
  const K._();

  // Fonds
  static const Color bg = Color(0xFF090D16);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceAlt = Color(0xFF151D2E);
  static const Color surfaceHigh = Color(0xFF1A2436);
  static const Color surfaceDeep = Color(0xFF070A12);

  // Bordures
  static const Color border = Color(0xFF1E293B);
  static const Color borderLight = Color(0xFF2A3A52);

  // Textes
  static const Color text = Color(0xFFE8EDF5);
  static const Color muted = Color(0xFF93A3B8);
  static const Color faint = Color(0xFF7C8CA3);

  // Marque — or & émeraude
  static const Color or = Color(0xFFE7B84B);
  static const Color orSoft = Color(0xFFF6D98A);
  static const Color orDeep = Color(0xFFC99A2E);
  static const Color emeraude = Color(0xFF34D399);
  static const Color emeraudeSoft = Color(0xFF6EE7B7);
  static const Color emeraudeDeep = Color(0xFF059669);

  // Accents (alias historiques conservés)
  static const Color accent = or;
  static const Color accentSoft = orSoft;
  static const Color accentDeep = orDeep;
  static const Color teal = emeraude;
  static const Color success = emeraude;
  static const Color warning = or;
  static const Color danger = Color(0xFFF87171);
  static const Color green = Color(0xFF25D366);

  // Alias historiques (les anciennes pages continuent de compiler).
  static const Color night = bg;
  static const Color deep = surface;
  static const Color gold = or;
  static const Color goldSoft = orSoft;
  static const Color sand = text;
  static const Color mist = muted;
  static const Color clay = warning;

  static const LinearGradient fond = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[bg, surfaceDeep],
  );

  /// Dégradé de marque or → émeraude (logo, liserés, accents premium).
  static const LinearGradient marque = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[orSoft, or, emeraude],
    stops: <double>[0, 0.52, 1],
  );

  static const LinearGradient orGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[orSoft, or, orDeep],
  );

  /// Alias utilisés par les anciennes pages.
  static const LinearGradient accentGradient = orGradient;

  static const LinearGradient verre = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xE6111827), Color(0xB3111827)],
  );

  static const LinearGradient direct = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[emeraudeDeep, emeraude],
  );

  static const List<BoxShadow> ombreDouce = <BoxShadow>[
    BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 16)),
  ];
}

// ============================================================================
//  FOND — halos radiaux + grille technique discrète, aucun motif lourd
// ============================================================================
class PatternBackground extends StatelessWidget {
  const PatternBackground({super.key, required this.child, this.grille = true});

  final Widget child;
  final bool grille;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: K.bg,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (grille) const Positioned.fill(child: CustomPaint(painter: _Grille())),
          Positioned(
            top: -300,
            left: -220,
            child: _Halo(couleur: K.or, taille: 720, opacite: 0.09),
          ),
          Positioned(
            bottom: -320,
            right: -220,
            child: _Halo(couleur: K.emeraude, taille: 680, opacite: 0.07),
          ),
          Positioned(
            top: 220,
            right: -180,
            child: _Halo(couleur: K.or, taille: 420, opacite: 0.04),
          ),
          Positioned.fill(child: child),
        ],
      ),
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

class _Grille extends CustomPainter {
  const _Grille();

  @override
  void paint(Canvas canvas, Size size) {
    final pinceau = Paint()
      ..strokeWidth = 1
      ..shader = RadialGradient(
        radius: 1.1,
        colors: <Color>[Colors.white.withValues(alpha: 0.035), Colors.transparent],
      ).createShader(Offset.zero & size);

    const pas = 64.0;
    for (var x = 0.0; x < size.width; x += pas) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), pinceau);
    }
    for (var y = 0.0; y < size.height; y += pas) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pinceau);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter ancien) => false;
}

// ============================================================================
//  LOGO & WORDMARK (compatibilité avec les pages existantes)
// ============================================================================
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => LogoEbooklive(size: size);
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.taille = 19, this.surClair = false});

  final double taille;
  final bool surClair;

  @override
  Widget build(BuildContext context) =>
      WordmarkEbooklive(taille: taille, clair: !surClair);
}

// ============================================================================
//  CARTES EN VERRE DÉPOLI
// ============================================================================
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.miseEnAvant = false,
    this.couleur,
    this.rayon = 22,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool miseEnAvant;
  final Color? couleur;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    final bordure = BorderRadius.circular(rayon);

    return Container(
      decoration: BoxDecoration(
        borderRadius: bordure,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
          if (miseEnAvant)
            BoxShadow(
              color: K.or.withValues(alpha: 0.08),
              blurRadius: 44,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: bordure,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: couleur ?? K.surface.withValues(alpha: 0.72),
              borderRadius: bordure,
              border: Border.all(
                color: miseEnAvant
                    ? K.or.withValues(alpha: 0.42)
                    : K.border.withValues(alpha: 0.9),
                width: 1,
              ),
              gradient: couleur == null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        K.surface.withValues(alpha: miseEnAvant ? 0.92 : 0.82),
                        K.surface.withValues(alpha: 0.55),
                      ],
                    )
                  : null,
            ),
            child: ClipRRect(
              borderRadius: bordure,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0.02),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: padding, child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte plus légère, sans flou (listes longues, mobile).
class CarteSimple extends StatelessWidget {
  const CarteSimple({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.miseEnAvant = false,
    this.rayon = 18,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool miseEnAvant;
  final double rayon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bordure = BorderRadius.circular(rayon);
    final contenu = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: padding,
      decoration: BoxDecoration(
        color: K.surface.withValues(alpha: 0.62),
        borderRadius: bordure,
        border: Border.all(
          color: miseEnAvant ? K.or.withValues(alpha: 0.55) : K.border,
          width: miseEnAvant ? 1.4 : 1,
        ),
      ),
      child: child,
    );

    if (onTap == null) return contenu;
    return Material(
      color: Colors.transparent,
      borderRadius: bordure,
      child: InkWell(borderRadius: bordure, onTap: onTap, child: contenu),
    );
  }
}

// ============================================================================
//  BOUTONS
// ============================================================================
class OrButton extends StatefulWidget {
  const OrButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icone,
    this.plein = true,
    this.hauteur = 50,
    this.chargement = false,
    this.large = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icone;
  final bool plein;
  final double hauteur;
  final bool chargement;
  final bool large;

  @override
  State<OrButton> createState() => _OrButtonState();
}

class _OrButtonState extends State<OrButton> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    final actif = widget.onPressed != null && !widget.chargement;
    final rayon = BorderRadius.circular(13);

    final contenu = widget.chargement
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: widget.plein ? K.bg : K.text,
              strokeWidth: 2.4,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.icone != null) ...<Widget>[
                Icon(
                  widget.icone,
                  size: 18,
                  color: widget.plein ? K.bg : K.text,
                ),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    letterSpacing: -0.2,
                    color: widget.plein ? K.bg : K.text,
                  ),
                ),
              ),
            ],
          );

    return MouseRegion(
      cursor: actif ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        height: widget.hauteur,
        width: widget.large ? double.infinity : null,
        decoration: BoxDecoration(
          gradient: widget.plein
              ? (_survol && actif ? K.marque : K.orGradient)
              : null,
          color: widget.plein ? null : K.surface.withValues(alpha: 0.5),
          borderRadius: rayon,
          border: widget.plein
              ? null
              : Border.all(
                  color: _survol && actif
                      ? K.or.withValues(alpha: 0.7)
                      : K.borderLight,
                ),
          boxShadow: widget.plein && actif
              ? <BoxShadow>[
                  BoxShadow(
                    color: K.or.withValues(alpha: _survol ? 0.38 : 0.24),
                    blurRadius: _survol ? 30 : 22,
                    offset: const Offset(0, 9),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: rayon,
          child: InkWell(
            borderRadius: rayon,
            onTap: actif ? widget.onPressed : null,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: contenu,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icone,
    this.hauteur = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icone;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hauteur,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icone == null ? const SizedBox.shrink() : Icon(icone, size: 17),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: K.text,
          side: const BorderSide(color: K.borderLight),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
    );
  }
}

// ============================================================================
//  PASTILLES, TITRES, BADGES
// ============================================================================
class Puce extends StatelessWidget {
  const Puce({super.key, required this.texte, this.icone, this.couleur = K.or});

  final String texte;
  final IconData? icone;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: couleur.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icone != null) ...<Widget>[
            Icon(icone, size: 13, color: couleur),
            const SizedBox(width: 6),
          ],
          Text(
            texte,
            style: TextStyle(
              color: couleur,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class BadgeFournisseur extends StatelessWidget {
  const BadgeFournisseur({super.key, required this.nom, this.actif = true});

  final String nom;
  final bool actif;

  @override
  Widget build(BuildContext context) {
    final couleur = nom.toLowerCase().contains('saspay') ? K.or : K.emeraude;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: (actif ? couleur : K.faint).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (actif ? couleur : K.faint).withValues(alpha: 0.32),
        ),
      ),
      child: Text(
        nom,
        style: TextStyle(
          color: actif ? couleur : K.muted,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class TitreSection extends StatelessWidget {
  const TitreSection({
    super.key,
    required this.surtitre,
    required this.titre,
    this.sousTitre,
    this.centre = false,
  });

  final String surtitre;
  final String titre;
  final String? sousTitre;
  final bool centre;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          centre ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          surtitre.toUpperCase(),
          textAlign: centre ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: K.or,
            fontSize: 11,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          titre,
          textAlign: centre ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: K.text,
            fontSize: 32,
            height: 1.14,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.1,
          ),
        ),
        if (sousTitre != null) ...<Widget>[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              sousTitre!,
              textAlign: centre ? TextAlign.center : TextAlign.start,
              style: const TextStyle(color: K.muted, fontSize: 15, height: 1.65),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
//  ANIMATION D'APPARITION
// ============================================================================
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.retard = Duration.zero});

  final Widget child;
  final Duration retard;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 620 + retard.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, valeur, enfant) {
        return Opacity(
          opacity: valeur.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - valeur)),
            child: enfant,
          ),
        );
      },
      child: child,
    );
  }
}

// ============================================================================
//  CHAMPS DE SAISIE
// ============================================================================
InputDecoration champ({
  required String label,
  String? hint,
  IconData? icone,
  Widget? suffixe,
  Widget? prefixe,
  bool multiligne = false,
  String? helper,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    alignLabelWithHint: multiligne,
    hintStyle: const TextStyle(color: K.faint, fontSize: 13),
    labelStyle: const TextStyle(color: K.muted, fontSize: 13),
    helperStyle: const TextStyle(color: K.faint, fontSize: 11),
    filled: true,
    fillColor: K.bg.withValues(alpha: 0.45),
    prefixIcon: icone == null ? prefixe : Icon(icone, color: K.faint, size: 19),
    suffixIcon: suffixe,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: K.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: K.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: K.or, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: K.danger, width: 1.2),
    ),
  );
}

/// Bouton texte discret (liens de navigation secondaires).
class LienDiscret extends StatelessWidget {
  const LienDiscret({
    super.key,
    required this.label,
    required this.onPressed,
    this.icone,
    this.couleur = K.muted,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icone;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: couleur,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icone != null) ...<Widget>[
            Icon(icone, size: 15),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
