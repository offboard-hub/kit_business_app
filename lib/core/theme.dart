import 'package:flutter/material.dart';

/// ============================================================================
///  PALETTE — indigo du Sahel, or et sable (identité Kit Business)
/// ============================================================================
class K {
  const K._();

  static const Color night = Color(0xFF14123A);
  static const Color deep = Color(0xFF1F1B55);
  static const Color gold = Color(0xFFE8B04B);
  static const Color goldSoft = Color(0xFFF3D38F);
  static const Color sand = Color(0xFFF6EBD4);
  static const Color clay = Color(0xFFB8643C);
  static const Color mist = Color(0xFFB9B4D6);
  static const Color green = Color(0xFF25D366); // WhatsApp
  static const Color success = Color(0xFF2E7D5B);
  static const Color danger = Color(0xFFB3261E);

  static const LinearGradient fond = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deep, night],
  );

  static const LinearGradient or = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldSoft, gold, clay],
    stops: [0.0, 0.55, 1.0],
  );
}

// ============================================================================
//  MOTIF BOGOLAN
// ============================================================================
class BogolanPainter extends CustomPainter {
  const BogolanPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pinceau = Paint()
      ..color = K.gold.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const pas = 56.0;
    for (double y = 0; y < size.height + pas; y += pas) {
      for (double x = 0; x < size.width + pas; x += pas) {
        final centre = Offset(x, y);
        final chemin = Path()
          ..moveTo(centre.dx, centre.dy - 14)
          ..lineTo(centre.dx + 14, centre.dy)
          ..lineTo(centre.dx, centre.dy + 14)
          ..lineTo(centre.dx - 14, centre.dy)
          ..close();
        canvas.drawPath(chemin, pinceau);
        canvas.drawCircle(centre.translate(pas / 2, pas / 2), 1.6, pinceau);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PatternBackground extends StatelessWidget {
  const PatternBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: K.fond),
      child: CustomPaint(painter: const BogolanPainter(), child: child),
    );
  }
}

// ============================================================================
//  LOGO
// ============================================================================
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 60});

  final double size;

  @override
  Widget build(BuildContext context) {
    final rayon = BorderRadius.circular(size * 0.28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: rayon,
        gradient: K.or,
        boxShadow: [
          BoxShadow(
            color: K.gold.withValues(alpha: 0.4),
            blurRadius: size * 0.45,
            spreadRadius: -size * 0.05,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: rayon,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size * 0.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0.35), Colors.transparent],
                  ),
                ),
              ),
            ),
            Icon(Icons.rocket_launch_rounded, color: K.night, size: size * 0.52),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  COMPOSANTS PARTAGÉS
// ============================================================================
class OrButton extends StatelessWidget {
  const OrButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icone,
    this.plein = true,
    this.hauteur = 52,
    this.chargement = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icone;
  final bool plein;
  final double hauteur;
  final bool chargement;

  @override
  Widget build(BuildContext context) {
    final contenu = chargement
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: K.night, strokeWidth: 2.5),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icone != null) ...[
                Icon(icone, size: 19, color: plein ? K.night : K.gold),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: plein ? K.night : K.gold,
                  ),
                ),
              ),
            ],
          );

    return SizedBox(
      height: hauteur,
      width: plein ? double.infinity : null,
      child: ElevatedButton(
        onPressed: chargement ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: plein ? K.gold : Colors.transparent,
          foregroundColor: plein ? K.night : K.gold,
          elevation: plein ? 6 : 0,
          shadowColor: K.gold.withValues(alpha: 0.35),
          side: plein ? null : const BorderSide(color: K.gold, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: contenu,
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.miseEnAvant = false,
    this.couleur,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool miseEnAvant;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: couleur ?? (miseEnAvant ? K.deep : K.night.withValues(alpha: 0.72)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: miseEnAvant ? K.gold : K.gold.withValues(alpha: 0.22),
          width: miseEnAvant ? 2 : 1,
        ),
        boxShadow: miseEnAvant
            ? [BoxShadow(color: K.gold.withValues(alpha: 0.16), blurRadius: 28, offset: const Offset(0, 10))]
            : null,
      ),
      child: child,
    );
  }
}

class Puce extends StatelessWidget {
  const Puce({super.key, required this.texte, this.icone, this.couleur = K.gold});

  final String texte;
  final IconData? icone;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 14, color: couleur),
            const SizedBox(width: 6),
          ],
          Text(
            texte,
            style: TextStyle(color: couleur, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Décoration commune des champs de saisie.
InputDecoration champ({
  required String label,
  String? hint,
  IconData? icone,
  Widget? suffixe,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(color: K.mist.withValues(alpha: 0.55), fontSize: 14),
    labelStyle: const TextStyle(color: K.mist),
    filled: true,
    fillColor: K.deep.withValues(alpha: 0.65),
    prefixIcon: icone == null ? null : Icon(icone, color: K.mist, size: 20),
    suffixIcon: suffixe,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: K.gold.withValues(alpha: 0.18)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: K.gold, width: 1.6),
    ),
  );
}

/// Titre de section avec surtitre doré.
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
      crossAxisAlignment: centre ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          surtitre.toUpperCase(),
          textAlign: centre ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: K.gold,
            fontSize: 12,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          titre,
          textAlign: centre ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: K.sand,
            fontSize: 28,
            height: 1.18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        if (sousTitre != null) ...[
          const SizedBox(height: 10),
          Text(
            sousTitre!,
            textAlign: centre ? TextAlign.center : TextAlign.start,
            style: const TextStyle(color: K.mist, fontSize: 15, height: 1.55),
          ),
        ],
      ],
    );
  }
}
