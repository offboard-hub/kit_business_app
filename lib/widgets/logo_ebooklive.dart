import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ============================================================================
///  LOGO e-booklive — 100 % vectoriel (CustomPainter)
///
///  Emblème : un livre ouvert dont les pages se prolongent en ondes de
///  diffusion live. Dégradé or → émeraude, typographie géométrique soignée.
///  Le même dessin est reproduit en SVG dans `web/index.html` (splash + favicon)
///  pour que l'écran de chargement et l'application soient parfaitement alignés.
/// ============================================================================

const Color _orClair = Color(0xFFFBE3A4);
const Color _or = Color(0xFFE7B84B);
const Color _orProfond = Color(0xFFC99A2E);
const Color _emeraude = Color(0xFF34D399);
const Color _emeraudeProfond = Color(0xFF059669);
const Color _encre = Color(0xFF090D16);
const Color _surface = Color(0xFF111827);

/// Emblème seul (carré arrondi + livre + ondes).
class LogoEbooklive extends StatelessWidget {
  const LogoEbooklive({
    super.key,
    this.size = 40,
    this.avecFond = true,
    this.progression = 1,
  });

  final double size;
  final bool avecFond;

  /// 0 → 1 : permet de dessiner le logo progressivement (splash animé).
  final double progression;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PeintreLogo(
          avecFond: avecFond,
          progression: progression.clamp(0, 1).toDouble(),
        ),
      ),
    );
  }
}

/// Logo animé : les ondes de diffusion pulsent doucement, en boucle.
class LogoEbookliveAnime extends StatefulWidget {
  const LogoEbookliveAnime({super.key, this.size = 96});

  final double size;

  @override
  State<LogoEbookliveAnime> createState() => _LogoEbookliveAnimeState();
}

class _LogoEbookliveAnimeState extends State<LogoEbookliveAnime>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur;

  @override
  void initState() {
    super.initState();
    _controleur = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controleur,
      builder: (context, _) {
        final onde = (math.sin(_controleur.value * math.pi * 2) + 1) / 2;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _PeintreLogo(
              avecFond: true,
              progression: 1,
              pulsation: onde,
              halo: true,
            ),
          ),
        );
      },
    );
  }
}

class _PeintreLogo extends CustomPainter {
  const _PeintreLogo({
    required this.avecFond,
    required this.progression,
    this.pulsation = 0,
    this.halo = false,
  });

  final bool avecFond;
  final double progression;
  final double pulsation;
  final bool halo;

  @override
  void paint(Canvas canvas, Size size) {
    final facteur = size.width / 96;
    canvas.save();
    canvas.scale(facteur);

    const rect = Rect.fromLTWH(0, 0, 96, 96);
    final badge = RRect.fromRectAndRadius(
      rect.deflate(2),
      const Radius.circular(24),
    );

    if (halo) {
      final lueur = Paint()
        ..shader = const RadialGradient(
          colors: <Color>[Color(0x5534D399), Color(0x00090D16)],
        ).createShader(const Rect.fromLTWH(-20, -20, 136, 136));
      canvas.drawCircle(const Offset(48, 48), 66, lueur);
    }

    if (avecFond) {
      final fond = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF162033), _surface, Color(0xFF0A0F19)],
          stops: <double>[0, 0.55, 1],
        ).createShader(rect);
      canvas.drawRRect(badge, fond);

      final bord = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0x99E7B84B), Color(0x5534D399)],
        ).createShader(rect);
      canvas.drawRRect(badge, bord);
    }

    // ------------------------------------------------------------------
    //  LIVRE OUVERT
    // ------------------------------------------------------------------
    final livre = Rect.fromLTWH(16, 52, 64, 28);
    final encreLivre = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[_orClair, _or, _orProfond],
      ).createShader(livre)
      ..isAntiAlias = true;

    final pageGauche = Path()
      ..moveTo(19, 57)
      ..cubicTo(29, 52.5, 39.5, 53.5, 48, 60)
      ..lineTo(48, 74)
      ..cubicTo(39.5, 67.5, 29, 66.5, 19, 70.5)
      ..close();

    final pageDroite = Path()
      ..moveTo(77, 57)
      ..cubicTo(67, 52.5, 56.5, 53.5, 48, 60)
      ..lineTo(48, 74)
      ..cubicTo(56.5, 67.5, 67, 66.5, 77, 70.5)
      ..close();

    canvas.drawPath(pageGauche, encreLivre);
    canvas.drawPath(pageDroite, encreLivre);

    // Pli central + lignes de texte discrètes.
    final pli = Paint()
      ..color = _encre.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(48, 60), const Offset(48, 74), pli);

    final lignes = Paint()
      ..color = _encre.withValues(alpha: 0.20)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = 64.0 + i * 3.4;
      canvas.drawLine(Offset(24, y), Offset(42, y + 1.2), lignes);
      canvas.drawLine(Offset(54, y + 1.2), Offset(72, y), lignes);
    }

    // ------------------------------------------------------------------
    //  SIGNAL LIVE (point + ondes concentriques)
    // ------------------------------------------------------------------
    final centre = const Offset(48, 39);
    const rayons = <double>[9, 16.5, 24];
    for (var i = 0; i < rayons.length; i++) {
      final seuil = (i + 1) / (rayons.length + 0.6);
      if (progression < seuil) continue;
      final opacite = 0.55 + 0.45 * (1 - i / rayons.length);
      final pinceau = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.1
        ..strokeCap = StrokeCap.round
        ..color = _or.withValues(alpha: opacite);
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: rayons[i]),
        math.pi,
        math.pi,
        false,
        pinceau,
      );
    }

    // Halo du point central (pulsation à l'écran de chargement).
    if (pulsation > 0) {
      final lueur = Paint()
        ..color = _emeraude.withValues(alpha: 0.18 * pulsation);
      canvas.drawCircle(centre, 11 + 5 * pulsation, lueur);
    }

    final point = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[_emeraude, _emeraudeProfond],
      ).createShader(Rect.fromCircle(center: centre, radius: 6));
    canvas.drawCircle(centre, 5.2, point);

    final eclat = Paint()..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawCircle(
      Offset(centre.dx - 1.4, centre.dy - 1.6),
      1.45,
      eclat,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PeintreLogo ancien) {
    return ancien.progression != progression ||
        ancien.pulsation != pulsation ||
        ancien.avecFond != avecFond ||
        ancien.halo != halo;
  }
}

/// Le mot-symbole « e-booklive » (typographie géométrique, poids variables).
class WordmarkEbooklive extends StatelessWidget {
  const WordmarkEbooklive({
    super.key,
    this.taille = 20,
    this.clair = true,
    this.montrerPoint = true,
  });

  final double taille;

  /// `true` sur fond sombre, `false` sur fond clair.
  final bool clair;
  final bool montrerPoint;

  @override
  Widget build(BuildContext context) {
    final principal = clair ? const Color(0xFFF1F5FB) : _encre;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: 'e',
            style: TextStyle(
              color: _or,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          TextSpan(
            text: '-book',
            style: TextStyle(
              color: principal,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
            ),
          ),
          TextSpan(
            text: 'live',
            style: const TextStyle(
              color: _emeraude,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          if (montrerPoint)
            const TextSpan(
              text: '.',
              style: TextStyle(color: _or, fontWeight: FontWeight.w900),
            ),
        ],
      ),
      style: TextStyle(fontSize: taille, height: 1.05),
    );
  }
}

/// Logo + mot-symbole, prêt à poser dans une barre de navigation.
class LogoLockup extends StatelessWidget {
  const LogoLockup({
    super.key,
    this.tailleLogo = 38,
    this.tailleTexte = 19,
    this.sousTitre,
    this.clair = true,
  });

  final double tailleLogo;
  final double tailleTexte;
  final String? sousTitre;
  final bool clair;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LogoEbooklive(size: tailleLogo),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              WordmarkEbooklive(taille: tailleTexte, clair: clair),
              if (sousTitre != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  sousTitre!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: clair
                        ? const Color(0xFF93A3B8)
                        : const Color(0xFF475569),
                    fontSize: 10,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
