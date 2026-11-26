import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/config.dart';
import '../core/countries.dart';
import '../core/links.dart';
import '../core/models.dart';
import '../core/pricing.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../widgets/app_header.dart';
import '../widgets/country_picker.dart';
import '../widgets/logo_ebooklive.dart';
import '../widgets/site_assistant_chat.dart';

/// ============================================================================
///  ACCUEIL — deux univers, zéro surcharge.
///  L'utilisateur voit immédiatement « La Boutique » et « Studio Live »,
///  avec les prix convertis dans la devise de son pays.
/// ============================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<AvisSite> _avis = const <AvisSite>[];
  bool _chargementAvis = true;

  @override
  void initState() {
    super.initState();
    _chargerAvis();
  }

  Future<void> _chargerAvis() async {
    final avis = await ApiService.listerAvis(limite: 6);
    if (!mounted) return;
    setState(() {
      _avis = avis;
      _chargementAvis = false;
    });
  }

  void _aller(String route) => Navigator.pushNamed(context, route);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                const AppHeader(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1140),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _Hero(onBoutique: () => _aller('/boutique'), onStudio: () => _aller('/studio-live')),
                          const SizedBox(height: 34),
                          _DeuxUnivers(
                            onBoutique: () => _aller('/boutique'),
                            onStudio: () => _aller('/studio-live'),
                          ),
                          const SizedBox(height: 54),
                          _BandeauConfiance(),
                          const SizedBox(height: 66),
                          _Parcours(),
                          const SizedBox(height: 66),
                          _SectionPays(),
                          const SizedBox(height: 66),
                          _SectionAvis(
                            avis: _avis,
                            chargement: _chargementAvis,
                            onRafraichir: _chargerAvis,
                          ),
                          const SizedBox(height: 66),
                          _AppelFinal(
                            onBoutique: () => _aller('/boutique'),
                            onStudio: () => _aller('/studio-live'),
                          ),
                          const SizedBox(height: 40),
                          const _PiedDePage(),
                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: const SiteAssistantChat(),
    );
  }
}

// ============================================================================
//  HÉRO
// ============================================================================
class _Hero extends StatelessWidget {
  const _Hero({required this.onBoutique, required this.onStudio});

  final VoidCallback onBoutique;
  final VoidCallback onStudio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final large = contraintes.maxWidth > 900;
        final texte = _BlocTexteHero(onBoutique: onBoutique, onStudio: onStudio);
        const visuel = _VisuelHero();

        return Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 8),
          child: large
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(flex: 6, child: texte),
                    const SizedBox(width: 46),
                    const Expanded(flex: 5, child: visuel),
                  ],
                )
              : Column(
                  children: <Widget>[
                    texte,
                    const SizedBox(height: 34),
                    visuel,
                  ],
                ),
        );
      },
    );
  }
}

class _BlocTexteHero extends StatelessWidget {
  const _BlocTexteHero({required this.onBoutique, required this.onStudio});

  final VoidCallback onBoutique;
  final VoidCallback onStudio;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PaysMonde>(
      valueListenable: CountryStore.pays,
      builder: (context, pays, _) {
        final kit = Prix.devisKit(3000, pays);
        final studio = Prix.devisStudio(pays);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                const Puce(texte: 'e-booklive', icone: Icons.travel_explore_rounded),
                Puce(
                  texte: pays.viaSasPay ? 'Prix en ${pays.devise}' : 'Prix en ${pays.devisePaddle}',
                  icone: Icons.payments_rounded,
                  couleur: K.emeraude,
                ),
                const Puce(texte: 'Sans abonnement caché', icone: Icons.verified_rounded),
              ],
            ),
            const SizedBox(height: 22),
            const _TitreDegrade(
              avant: 'Deux univers.\nUn seul standard : ',
              accent: 'le vôtre.',
            ),
            const SizedBox(height: 18),
            const Text(
              'Des kits business écrits pour votre métier, et un studio live complet '
              'pour vendre en direct. Prix affichés dans votre devise, paiement local '
              'ou international, livraison immédiate.',
              style: TextStyle(color: K.muted, fontSize: 16, height: 1.65),
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                SizedBox(
                  width: 230,
                  child: OrButton(
                    label: 'Explorer La Boutique',
                    icone: Icons.storefront_rounded,
                    onPressed: onBoutique,
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: OrButton(
                    label: 'Découvrir le Studio Live',
                    icone: Icons.sensors_rounded,
                    plein: false,
                    onPressed: onStudio,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                const Icon(Icons.auto_awesome_rounded, color: K.or, size: 14),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Kits dès ${kit.principal}  ·  Studio Live ${studio.principal} / 30 jours',
                    style: const TextStyle(color: K.faint, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TitreDegrade extends StatelessWidget {
  const _TitreDegrade({required this.avant, required this.accent});

  final String avant;
  final String accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final taille = contraintes.maxWidth > 760 ? 52.0 : 36.0;
        return Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: avant,
                style: TextStyle(
                  color: K.text,
                  fontSize: taille,
                  height: 1.07,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.8,
                ),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: ShaderMask(
                  shaderCallback: (bounds) => K.marque.createShader(bounds),
                  child: Text(
                    accent,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: taille,
                      height: 1.07,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VisuelHero extends StatefulWidget {
  const _VisuelHero();

  @override
  State<_VisuelHero> createState() => _VisuelHeroState();
}

class _VisuelHeroState extends State<_VisuelHero> {
  bool _cameraProduits = true;
  int _phase = 0;
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _minuteur = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _phase = (_phase + 1) % 4);
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 430,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: GlassCard(
              padding: EdgeInsets.zero,
              rayon: 26,
              child: Column(
                children: <Widget>[
                  _BarreFenetre(),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 550),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _cameraProduits
                                  ? const <Color>[
                                      Color(0xFF10251F),
                                      Color(0xFF0C1820),
                                      Color(0xFF111827),
                                    ]
                                  : const <Color>[
                                      Color(0xFF1A2030),
                                      Color(0xFF141A2A),
                                      Color(0xFF111827),
                                    ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: -55,
                          top: -70,
                          child: Container(
                            width: 230,
                            height: 230,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: <Color>[
                                  (_cameraProduits ? K.emeraude : K.or)
                                      .withValues(alpha: 0.23),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 13,
                          left: 13,
                          right: 13,
                          child: _OngletsVitrine(
                            cameraProduits: _cameraProduits,
                            onCamera: () => setState(() => _cameraProduits = true),
                            onEcran: () => setState(() => _cameraProduits = false),
                          ),
                        ),
                        Positioned(
                          top: 62,
                          left: 16,
                          right: 16,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            child: _cameraProduits
                                ? _ProduitVitrine(key: const ValueKey<String>('camera'))
                                : _EcranVitrine(key: const ValueKey<String>('ecran')),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) => FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.08),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            ),
                            child: _phase == 0
                                ? const _BulleChat(
                                    key: ValueKey<String>('question'),
                                    texte: 'Bonjour, la robe wax est disponible en taille M ?',
                                    auteur: 'Client · TikTok',
                                    assistant: false,
                                  )
                                : _phase == 1
                                    ? const _BulleChat(
                                        key: ValueKey<String>('reponse'),
                                        texte:
                                            'Oui, il en reste 4 en taille M. Je vous envoie le lien de paiement sécurisé.',
                                        auteur: 'Awa IA · réponse instantanée',
                                        assistant: true,
                                      )
                                    : _phase == 2
                                        ? const _MiniPaiement(key: ValueKey<String>('paiement'))
                                        : const _MiniPaiement(
                                            key: ValueKey<String>('paiement-final'),
                                            confirme: true,
                                          ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: K.emeraude.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: K.emeraude, size: 15),
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Text(
                            'Le chat IA répond, propose le paiement et confirme la commande.',
                            style: TextStyle(color: K.muted, fontSize: 10.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_phase >= 2)
            Positioned(
              left: -14,
              bottom: 58,
              child: AnimatedOpacity(
                opacity: _phase == 3 ? 1 : 0.82,
                duration: const Duration(milliseconds: 300),
                child: _PastilleFlottante(
                  icone: Icons.check_circle_rounded,
                  titre: _phase == 3 ? 'Commande confirmée' : 'Paiement sécurisé',
                  sousTitre: _phase == 3 ? 'Robe wax · 9 000 FCFA' : 'Lien envoyé au client',
                  couleur: K.emeraude,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OngletsVitrine extends StatelessWidget {
  const _OngletsVitrine({
    required this.cameraProduits,
    required this.onCamera,
    required this.onEcran,
  });

  final bool cameraProduits;
  final VoidCallback onCamera;
  final VoidCallback onEcran;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _OngletVitrine(
            label: 'Caméra Produits',
            icone: Icons.videocam_rounded,
            actif: cameraProduits,
            onTap: onCamera,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _OngletVitrine(
            label: 'Partage d\'Écran',
            icone: Icons.screen_share_rounded,
            actif: !cameraProduits,
            onTap: onEcran,
          ),
        ),
      ],
    );
  }
}

class _OngletVitrine extends StatelessWidget {
  const _OngletVitrine({
    required this.label,
    required this.icone,
    required this.actif,
    required this.onTap,
  });

  final String label;
  final IconData icone;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: actif ? K.surface.withValues(alpha: 0.82) : K.bg.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: actif ? K.or.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.09),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icone, size: 13, color: actif ? K.or : K.faint),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: actif ? K.text : K.faint,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProduitVitrine extends StatelessWidget {
  const _ProduitVitrine({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Robe wax édition limitée',
          style: TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        ValueListenableBuilder<PaysMonde>(
          valueListenable: CountryStore.pays,
          builder: (context, pays, _) {
            final prix = Prix.devisKit(9000, pays);
            return Text(
              '${prix.principal} · stock M : 4',
              style: const TextStyle(color: K.orSoft, fontSize: 11),
            );
          },
        ),
        const SizedBox(height: 14),
        Center(
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: K.marque,
              boxShadow: <BoxShadow>[
                BoxShadow(color: K.or.withValues(alpha: 0.3), blurRadius: 28),
              ],
            ),
            child: const Icon(Icons.play_arrow_rounded, color: K.bg, size: 44),
          ),
        ),
      ],
    );
  }
}

class _EcranVitrine extends StatelessWidget {
  const _EcranVitrine({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Icon(Icons.screen_share_rounded, color: K.or, size: 15),
            SizedBox(width: 6),
            Text(
              'Partage d\'écran · fiche produit',
              style: TextStyle(color: K.text, fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 92,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: K.bg.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(width: 150, height: 7, decoration: BoxDecoration(color: K.or.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              Container(width: 220, height: 6, decoration: BoxDecoration(color: K.muted.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Container(width: 180, height: 6, decoration: BoxDecoration(color: K.emeraude.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4))),
              const Spacer(),
              const Text(
                'Tableau de ventes · stock · marge',
                style: TextStyle(color: K.faint, fontSize: 8.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BulleChat extends StatelessWidget {
  const _BulleChat({
    super.key,
    required this.texte,
    required this.auteur,
    required this.assistant,
  });

  final String texte;
  final String auteur;
  final bool assistant;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: assistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
        decoration: BoxDecoration(
          color: assistant ? K.emeraude.withValues(alpha: 0.12) : K.or.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: assistant ? K.emeraude.withValues(alpha: 0.3) : K.or.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              auteur,
              style: TextStyle(
                color: assistant ? K.emeraude : K.or,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(texte, style: const TextStyle(color: K.text, fontSize: 10.5, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _MiniPaiement extends StatelessWidget {
  const _MiniPaiement({super.key, this.confirme = false});

  final bool confirme;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: K.emeraude.withValues(alpha: confirme ? 0.16 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: K.emeraude.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(confirme ? Icons.check_circle_rounded : Icons.lock_rounded, color: K.emeraude, size: 17),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  confirme ? 'Commande confirmée' : 'Lien de paiement sécurisé',
                  style: const TextStyle(color: K.text, fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
                Text(
                  confirme ? 'Robe wax · paiement reçu' : 'SasPay / Paddle · en 1 clic',
                  style: const TextStyle(color: K.faint, fontSize: 8.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarreFenetre extends StatelessWidget {
  const _BarreFenetre();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: K.border)),
      ),
      child: Row(
        children: <Widget>[
          for (final couleur in <Color>[K.danger, K.or, K.emeraude])
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: couleur.withValues(alpha: 0.7), shape: BoxShape.circle),
              ),
            ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'ebooklive / studio-live',
              style: TextStyle(color: K.faint, fontSize: 10.5, letterSpacing: 0.2),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: K.emeraude.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: K.emeraude.withValues(alpha: 0.35)),
            ),
            child: const Text(
              'EN DIRECT',
              style: TextStyle(
                color: K.emeraude,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PastilleFlottante extends StatelessWidget {
  const _PastilleFlottante({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.couleur,
  });

  final IconData icone;
  final String titre;
  final String sousTitre;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: K.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icone, color: couleur, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                titre,
                style: const TextStyle(color: K.text, fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
              Text(sousTitre, style: const TextStyle(color: K.faint, fontSize: 9.5)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  LES DEUX UNIVERS
// ============================================================================
class _DeuxUnivers extends StatelessWidget {
  const _DeuxUnivers({required this.onBoutique, required this.onStudio});

  final VoidCallback onBoutique;
  final VoidCallback onStudio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final large = contraintes.maxWidth > 780;
        final boutique = _CarteUnivers(
          numero: '01',
          surtitre: 'La Boutique',
          titre: 'Des kits business\nsur mesure',
          description:
              'Choisissez votre secteur, votre offre, puis recevez un livre '
              'stratégique, des prompts IA et un tableau de gestion générés pour vous.',
          points: const <String>[
            '8 secteurs + « Autre métier »',
            'Paiement en 2 étapes, sans compte',
            'Livraison immédiate par email',
          ],
          icone: Icons.storefront_rounded,
          couleur: K.or,
          route: 'SasPay & Paddle',
          onTap: onBoutique,
          cta: 'Choisir mon kit',
          prix: _PrixBoutique(),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF221C0D), Color(0xFF111827)],
          ),
        );
        final studio = _CarteUnivers(
          numero: '02',
          surtitre: 'Studio Live',
          titre: 'Vendez en direct,\ncomme un studio pro',
          description:
              'Une régie live modulaire, un co-animateur à distance, un chat IA '
              'commercial et votre Livre Guide Live personnalisé.',
          points: const <String>[
            'Jitsi, caméra produits ou partage d\'écran',
            'Chat IA temps réel DeepSeek',
            'Livre Guide offert, envoyé par email',
          ],
          icone: Icons.sensors_rounded,
          couleur: K.emeraude,
          route: '10 \$ / 30 jours',
          onTap: onStudio,
          cta: 'Ouvrir le Studio Live',
          prix: _PrixStudio(),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF0B241D), Color(0xFF111827)],
          ),
        );

        if (large) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: boutique),
                const SizedBox(width: 18),
                Expanded(child: studio),
              ],
            ),
          );
        }
        return Column(
          children: <Widget>[
            boutique,
            const SizedBox(height: 16),
            studio,
          ],
        );
      },
    );
  }
}

class _CarteUnivers extends StatefulWidget {
  const _CarteUnivers({
    required this.numero,
    required this.surtitre,
    required this.titre,
    required this.description,
    required this.points,
    required this.icone,
    required this.couleur,
    required this.route,
    required this.onTap,
    required this.cta,
    required this.prix,
    required this.gradient,
  });

  final String numero;
  final String surtitre;
  final String titre;
  final String description;
  final List<String> points;
  final IconData icone;
  final Color couleur;
  final String route;
  final VoidCallback onTap;
  final String cta;
  final Widget prix;
  final Gradient gradient;

  @override
  State<_CarteUnivers> createState() => _CarteUniversState();
}

class _CarteUniversState extends State<_CarteUnivers> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    final rayon = BorderRadius.circular(24);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: rayon,
            gradient: widget.gradient,
            border: Border.all(
              color: widget.couleur.withValues(alpha: _survol ? 0.55 : 0.28),
              width: 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.couleur.withValues(alpha: _survol ? 0.14 : 0.06),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: rayon,
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: -70,
                  top: -70,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          widget.couleur.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: widget.couleur.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: widget.couleur.withValues(alpha: 0.3)),
                            ),
                            child: Icon(widget.icone, color: widget.couleur, size: 23),
                          ),
                          const Spacer(),
                          Text(
                            widget.numero,
                            style: TextStyle(
                              color: widget.couleur.withValues(alpha: 0.45),
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        widget.surtitre.toUpperCase(),
                        style: TextStyle(
                          color: widget.couleur,
                          fontSize: 10.5,
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.titre,
                        style: const TextStyle(
                          color: K.text,
                          fontSize: 26,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.description,
                        style: const TextStyle(color: K.muted, fontSize: 13, height: 1.6),
                      ),
                      const SizedBox(height: 18),
                      for (final point in widget.points)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(Icons.check_circle_rounded, size: 15, color: widget.couleur),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  point,
                                  style: const TextStyle(color: K.text, fontSize: 12.5, height: 1.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),
                      widget.prix,
                      const SizedBox(height: 18),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OrButton(
                              label: widget.cta,
                              plein: false,
                              icone: Icons.arrow_forward_rounded,
                              hauteur: 46,
                              onPressed: widget.onTap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Icon(Icons.lock_outline_rounded, size: 12, color: K.faint),
                          const SizedBox(width: 5),
                          Text(
                            widget.route,
                            style: const TextStyle(color: K.faint, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
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

class _PrixBoutique extends StatelessWidget {
  const _PrixBoutique();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PaysMonde>(
      valueListenable: CountryStore.pays,
      builder: (context, pays, _) {
        final devis = Prix.devisKit(3000, pays);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              devis.principal,
              style: const TextStyle(
                color: K.orSoft,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(width: 7),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'à partir de',
                style: TextStyle(color: K.faint, fontSize: 10.5),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PrixStudio extends StatelessWidget {
  const _PrixStudio();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PaysMonde>(
      valueListenable: CountryStore.pays,
      builder: (context, pays, _) {
        final devis = Prix.devisStudio(pays);
        final principal = devis.devise == 'USD'
            ? '10,00 \$'
            : devis.principal;
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 7,
          runSpacing: 3,
          children: <Widget>[
            Text(
              principal,
              style: const TextStyle(
                color: K.emeraudeSoft,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                '/ 30 jours',
                style: TextStyle(color: K.faint, fontSize: 10.5),
              ),
            ),
            if (devis.indicatif != null) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  devis.indicatif!,
                  style: const TextStyle(color: K.faint, fontSize: 9.5),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ============================================================================
//  CONFIANCE
// ============================================================================
class _BandeauConfiance extends StatelessWidget {
  const _BandeauConfiance();

  @override
  Widget build(BuildContext context) {
    const elements = <(IconData, String, String)>[
      (Icons.public_rounded, 'Tous les pays', '23 pays SasPay en devise locale, Paddle ailleurs'),
      (Icons.lock_rounded, 'Paiement sécurisé', 'Mobile money, carte, TVA gérée'),
      (Icons.bolt_rounded, 'Livraison immédiate', 'Liens à l\'écran et par email'),
      (Icons.auto_awesome_rounded, 'IA DeepSeek & Gemini', 'Un contenu écrit pour votre métier'),
    ];

    return LayoutBuilder(
      builder: (context, contraintes) {
        final colonnes = contraintes.maxWidth > 900 ? 4 : (contraintes.maxWidth > 520 ? 2 : 1);
        final largeur = (contraintes.maxWidth - (colonnes - 1) * 12) / colonnes;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            for (final element in elements)
              Container(
                width: largeur,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: K.surface.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: K.border),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: K.or.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(element.$1, color: K.or, size: 17),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            element.$2,
                            style: const TextStyle(
                              color: K.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            element.$3,
                            style: const TextStyle(color: K.faint, fontSize: 10.5, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ============================================================================
//  PARCOURS
// ============================================================================
class _Parcours extends StatelessWidget {
  const _Parcours();

  @override
  Widget build(BuildContext context) {
    const etapes = <(String, String, IconData)>[
      ('Choisissez votre univers', 'La Boutique pour un kit métier, ou Studio Live pour vendre en direct.', Icons.grid_view_rounded),
      ('Sélectionnez votre offre', 'Votre secteur, votre kit, votre pays. Les prix se convertissent instantanément.', Icons.tune_rounded),
      ('Recevez ou animez', 'Kit livré par email, ou régie live ouverte avec votre Livre Guide.', Icons.rocket_launch_rounded),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: K.surface.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: K.border),
      ),
      child: Column(
        children: <Widget>[
          const TitreSection(
            surtitre: 'Simple par design',
            titre: 'Trois étapes, aucune surcharge',
            centre: true,
          ),
          const SizedBox(height: 30),
          LayoutBuilder(
            builder: (context, contraintes) {
              final large = contraintes.maxWidth > 760;
              final blocs = <Widget>[
                for (var index = 0; index < etapes.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: K.orGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(etapes[index].$3, color: K.bg, size: 23),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '0${index + 1}',
                          style: const TextStyle(
                            color: K.or,
                            fontSize: 10,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          etapes[index].$1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: K.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          etapes[index].$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: K.muted, fontSize: 11.5, height: 1.5),
                        ),
                      ],
                    ),
                  ),
              ];
              return large
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final bloc in blocs) Expanded(child: bloc),
                      ],
                    )
                  : Column(children: blocs);
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  PAYS & DEVISES
// ============================================================================
class _SectionPays extends StatelessWidget {
  const _SectionPays();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const TitreSection(
          surtitre: 'Partout dans le monde',
          titre: 'Votre pays, votre devise',
          sousTitre: 'Sélectionnez votre pays : tous les prix se convertissent automatiquement. '
              'SasPay encaisse en devise locale dans 23 pays, Paddle couvre le reste du monde.',
          centre: true,
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: const EdgeInsets.all(22),
          child: ValueListenableBuilder<PaysMonde>(
            valueListenable: CountryStore.pays,
            builder: (context, pays, _) {
              final kit = Prix.devisKit(9000, pays);
              final studio = Prix.devisStudio(pays);
              return Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(pays.drapeau, style: const TextStyle(fontSize: 30)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              pays.nom,
                              style: const TextStyle(
                                color: K.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${pays.devise} · ${pays.indicatif}',
                              style: const TextStyle(color: K.faint, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      BadgeFournisseur(nom: pays.viaSasPay ? 'SasPay' : 'Paddle'),
                      const SizedBox(width: 12),
                      const PaysSelector(compact: true),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, contraintes) {
                      final large = contraintes.maxWidth > 620;
                      final cartes = <Widget>[
                        _ApercuPrix(
                          label: 'Pack Complet — La Boutique',
                          valeur: kit.principal,
                          detail: kit.indicatif ?? 'Paiement unique',
                          couleur: K.or,
                        ),
                        _ApercuPrix(
                          label: 'Studio Live — 30 jours',
                          valeur: studio.principal == '10,00 \$' ? '10,00 \$' : studio.principal,
                          detail: studio.indicatif ?? 'Livre Guide offert',
                          couleur: K.emeraude,
                        ),
                      ];
                      return large
                          ? Row(
                              children: <Widget>[
                                Expanded(child: cartes[0]),
                                const SizedBox(width: 12),
                                Expanded(child: cartes[1]),
                              ],
                            )
                          : Column(
                              children: <Widget>[
                                cartes[0],
                                const SizedBox(height: 10),
                                cartes[1],
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 16),
                  RoutePaiementBandeau(pays: pays),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ApercuPrix extends StatelessWidget {
  const _ApercuPrix({
    required this.label,
    required this.valeur,
    required this.detail,
    required this.couleur,
  });

  final String label;
  final String valeur;
  final String detail;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: K.bg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: K.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: K.muted, fontSize: 10.5)),
          const SizedBox(height: 6),
          Text(
            valeur,
            style: TextStyle(
              color: couleur,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(detail, style: const TextStyle(color: K.faint, fontSize: 9.5)),
        ],
      ),
    );
  }
}

// ============================================================================
//  AVIS (lecture compacte + formulaire en dialogue)
// ============================================================================
class _SectionAvis extends StatelessWidget {
  const _SectionAvis({
    required this.avis,
    required this.chargement,
    required this.onRafraichir,
  });

  final List<AvisSite> avis;
  final bool chargement;
  final Future<void> Function() onRafraichir;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TitreSection(
          surtitre: 'Ils ont structuré leur business',
          titre: 'Ils utilisent déjà e-booklive',
          sousTitre: 'Des retours de vrais clients, sans filtre.',
          centre: true,
        ),
        const SizedBox(height: 22),
        if (chargement)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(color: K.or, strokeWidth: 2.4),
            ),
          )
        else if (avis.isEmpty)
          GlassCard(
            child: Column(
              children: <Widget>[
                const Icon(Icons.rate_review_rounded, color: K.faint, size: 26),
                const SizedBox(height: 8),
                const Text(
                  'Aucun avis pour l\'instant. Soyez le premier à partager votre expérience.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: K.muted, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => _ouvrirFormulaire(context),
                  child: const Text('Laisser un avis', style: TextStyle(color: K.or)),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final avis in avis.take(3)) _CarteAvis(avis: avis),
            ],
          ),
        const SizedBox(height: 8),
        if (avis.isNotEmpty)
          TextButton(
            onPressed: () => _ouvrirFormulaire(context),
            child: const Text(
              'Laisser un avis',
              style: TextStyle(color: K.muted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _ouvrirFormulaire(BuildContext context) async {
    final publie = await showDialog<bool>(
      context: context,
      builder: (context) => const _DialogueAvis(),
    );
    if (publie == true) await onRafraichir();
  }
}

class _CarteAvis extends StatelessWidget {
  const _CarteAvis({required this.avis});

  final AvisSite avis;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: K.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: K.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: K.or.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: K.or.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    avis.initiale,
                    style: const TextStyle(color: K.or, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    avis.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: K.text, fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ),
                _Etoiles(note: avis.note),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              avis.commentaire,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: K.muted, fontSize: 12, height: 1.55),
            ),
            if (avis.localisation.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                avis.localisation,
                style: const TextStyle(color: K.faint, fontSize: 9.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Etoiles extends StatelessWidget {
  const _Etoiles({required this.note});

  final int note;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < 5; i++)
          Icon(
            i < note ? Icons.star_rounded : Icons.star_outline_rounded,
            color: K.or,
            size: 13,
          ),
      ],
    );
  }
}

class _DialogueAvis extends StatefulWidget {
  const _DialogueAvis();

  @override
  State<_DialogueAvis> createState() => _DialogueAvisState();
}

class _DialogueAvisState extends State<_DialogueAvis> {
  final TextEditingController _nom = TextEditingController();
  final TextEditingController _ville = TextEditingController();
  final TextEditingController _commentaire = TextEditingController();
  int _note = 5;
  bool _envoi = false;

  @override
  void dispose() {
    _nom.dispose();
    _ville.dispose();
    _commentaire.dispose();
    super.dispose();
  }

  Future<void> _publier() async {
    if (_nom.text.trim().length < 2) {
      _toast('Indiquez votre nom.');
      return;
    }
    if (_commentaire.text.trim().length < 5) {
      _toast('Écrivez quelques mots sur votre expérience.');
      return;
    }
    setState(() => _envoi = true);
    try {
      await ApiService.publierAvis(
        note: _note,
        nom: _nom.text.trim(),
        pays: CountryStore.pays.value.nom,
        ville: _ville.text.trim(),
        commentaire: _commentaire.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _envoi = false);
      _toast(erreur is ApiException ? erreur.message : 'Publication impossible.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Laisser un avis',
                  style: TextStyle(color: K.text, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Votre retour aide les autres entrepreneurs.',
                  style: TextStyle(color: K.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    for (var etoile = 1; etoile <= 5; etoile++)
                      IconButton(
                        onPressed: () => setState(() => _note = etoile),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        icon: Icon(
                          etoile <= _note ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: K.or,
                          size: 26,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text('$_note/5', style: const TextStyle(color: K.muted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nom,
                  maxLength: 60,
                  style: const TextStyle(color: K.text),
                  decoration: champ(label: 'Votre nom', icone: Icons.person_rounded),
                ),
                TextField(
                  controller: _ville,
                  maxLength: 60,
                  style: const TextStyle(color: K.text),
                  decoration: champ(label: 'Ville (optionnel)', icone: Icons.location_city_rounded),
                ),
                TextField(
                  controller: _commentaire,
                  maxLines: 3,
                  maxLength: 600,
                  style: const TextStyle(color: K.text),
                  decoration: champ(
                    label: 'Votre commentaire',
                    hint: 'Ce que e-booklive vous a apporté…',
                    multiligne: true,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OrButton(
                        label: 'Annuler',
                        plein: false,
                        hauteur: 44,
                        onPressed: _envoi ? null : () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OrButton(
                        label: 'Envoyer',
                        hauteur: 44,
                        chargement: _envoi,
                        onPressed: _publier,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  APPEL FINAL + PIED DE PAGE
// ============================================================================
class _AppelFinal extends StatelessWidget {
  const _AppelFinal({required this.onBoutique, required this.onStudio});

  final VoidCallback onBoutique;
  final VoidCallback onStudio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF221C0D), Color(0xFF0B241D)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: K.or.withValues(alpha: 0.32)),
      ),
      child: Column(
        children: <Widget>[
          const LogoEbooklive(size: 54),
          const SizedBox(height: 16),
          const Text(
            'Votre prochain chapitre commence ici.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: K.text,
              fontSize: 26,
              height: 1.2,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Un kit métier pour structurer, un studio live pour vendre. '
            'Les deux sont prêts en quelques minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: K.muted, fontSize: 13.5, height: 1.6),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 230,
                child: OrButton(
                  label: 'Explorer La Boutique',
                  icone: Icons.storefront_rounded,
                  onPressed: onBoutique,
                ),
              ),
              SizedBox(
                width: 230,
                child: OrButton(
                  label: 'Découvrir le Studio Live',
                  icone: Icons.sensors_rounded,
                  plein: false,
                  onPressed: onStudio,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PiedDePage extends StatelessWidget {
  const _PiedDePage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Divider(color: K.border),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: <Widget>[
            _LienPied(label: 'La Boutique', onTap: () => Navigator.pushNamed(context, '/boutique')),
            _LienPied(label: 'Studio Live', onTap: () => Navigator.pushNamed(context, '/studio-live')),
            _LienPied(label: 'Guide & Tutoriel', onTap: () => Navigator.pushNamed(context, '/guide')),
            _LienPied(label: 'CGV', onTap: () => Navigator.pushNamed(context, '/cgv')),
            _LienPied(
              label: 'Confidentialité',
              onTap: () => Navigator.pushNamed(context, '/confidentialite'),
            ),
            _LienPied(
              label: 'Remboursement',
              onTap: () => Navigator.pushNamed(context, '/remboursement'),
            ),
            _LienPied(label: 'Contact', onTap: () => Navigator.pushNamed(context, '/contact')),
            _LienPied(label: 'Mentions légales', onTap: () => Navigator.pushNamed(context, '/mentions-legales')),
            _LienPied(label: 'FAQ', onTap: () => Navigator.pushNamed(context, '/faq')),
            _LienPied(
              label: 'Aide WhatsApp',
              couleur: K.green,
              onTap: () => ouvrirLienAvecRetour(context, AppConfig.lienWhatsAppAide),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'e-booklive · La Boutique & Studio Live',
          style: TextStyle(color: K.faint, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          '© ${DateTime.now().year} e-booklive · ${AppConfig.emailSupport}',
          style: const TextStyle(color: K.faint, fontSize: 10),
        ),
      ],
    );
  }
}

class _LienPied extends StatelessWidget {
  const _LienPied({
    required this.label,
    required this.onTap,
    this.couleur = K.muted,
  });

  final String label;
  final VoidCallback onTap;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: couleur,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 11.5)),
    );
  }
}
