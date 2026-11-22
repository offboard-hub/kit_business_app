import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/links.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../widgets/app_header.dart';
import '../widgets/site_assistant_chat.dart';
import '../widgets/whatsapp.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late final PageController _pages;
  Timer? _minuteur;
  int _page = 0;
  final TextEditingController _email = TextEditingController();
  bool _envoiEmail = false;

  // --- Avis clients ---
  final TextEditingController _avisNom = TextEditingController();
  final TextEditingController _avisVille = TextEditingController();
  final TextEditingController _avisCommentaire = TextEditingController();
  Pays _avisPays = paysAfricains.first;
  int _noteAvis = 5;
  List<AvisSite> _avis = const [];
  bool _chargementAvis = true;
  bool _envoiAvis = false;

  static const List<String> _images = [
    'https://images.unsplash.com/photo-1553729459-efe14ef6055d?q=80&w=900&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?q=80&w=900&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?q=80&w=900&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=900&auto=format&fit=crop',
  ];

  static const List<String> _legendes = [
    'Un plan clair,\nadapté à votre marché',
    'Des prix justes,\nen FCFA',
    'Des clients qui\nreviennent',
    'Votre métier,\nstructuré',
  ];

  @override
  void initState() {
    super.initState();
    _pages = PageController(viewportFraction: 0.86);
    _minuteur = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pages.hasClients) return;
      _pages.nextPage(duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
    });
    _chargerAvis();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _pages.dispose();
    _email.dispose();
    _avisNom.dispose();
    _avisVille.dispose();
    _avisCommentaire.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  //  AVIS CLIENTS
  // --------------------------------------------------------------------------
  Future<void> _chargerAvis() async {
    final avis = await ApiService.listerAvis();
    if (!mounted) return;
    setState(() {
      _avis = avis;
      _chargementAvis = false;
    });
  }

  double get _noteMoyenne {
    if (_avis.isEmpty) return 0;
    final total = _avis.fold<int>(0, (somme, avis) => somme + avis.note);
    return total / _avis.length;
  }

  void _toast(String message, {Color couleur = K.clay}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: couleur,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _envoyerAvis() async {
    final nom = _avisNom.text.trim();
    final commentaire = _avisCommentaire.text.trim();

    if (nom.length < 2) {
      _toast('Indiquez votre nom (2 caractères minimum).');
      return;
    }
    if (commentaire.length < 5) {
      _toast('Écrivez un commentaire d\'au moins 5 caractères.');
      return;
    }

    setState(() => _envoiAvis = true);

    try {
      await ApiService.publierAvis(
        note: _noteAvis,
        nom: nom,
        pays: _avisPays.nom,
        ville: _avisVille.text.trim(),
        commentaire: commentaire,
      );

      if (!mounted) return;
      _avisNom.clear();
      _avisVille.clear();
      _avisCommentaire.clear();
      setState(() {
        _envoiAvis = false;
        _noteAvis = 5;
      });

      _toast('Merci pour votre avis, il est publié !', couleur: K.success);
      await _chargerAvis();
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _envoiAvis = false);
      _toast(
        erreur is ApiException ? erreur.message : 'Publication impossible pour le moment.',
        couleur: K.danger,
      );
    }
  }

  String _dateAvis(DateTime date) {
    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    return '$jour/$mois/${date.year}';
  }

  void _commander({String? metier, String? offre}) {
    Navigator.pushNamed(
      context,
      '/commande',
      arguments: <String, String?>{'metier': metier, 'offre': offre},
    );
  }

  Future<void> _recevoirInfos() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrez un email valide.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: K.clay,
        ),
      );
      return;
    }

    setState(() => _envoiEmail = true);
    await ApiService.envoyerEmailAccueil(email, source: 'accueil');
    if (!mounted) return;
    setState(() => _envoiEmail = false);
    _email.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('C\'est envoyé ! Vérifiez votre boîte de réception.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: K.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const AppHeader(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _hero(context),
                          _bandeauConfiance(),
                          const SizedBox(height: 54),
                          _offres(context),
                          const SizedBox(height: 64),
                          _kits(context),
                          const SizedBox(height: 64),
                          _etapes(),
                          const SizedBox(height: 64),
                          _avisSection(),
                          const SizedBox(height: 64),
                          _pays(),
                          const SizedBox(height: 56),
                          _appelFinal(context),
                          const SizedBox(height: 40),
                          _piedDePage(context),
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

  // --------------------------------------------------------------------------
  //  HÉRO
  // --------------------------------------------------------------------------
  Widget _hero(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final large = contraintes.maxWidth > 880;
        final blocTexte = Column(
          crossAxisAlignment: large ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Wrap(
              alignment: large ? WrapAlignment.start : WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: const [
                Puce(texte: '100 % FCFA', icone: Icons.payments_rounded),
                Puce(texte: '6 kits métiers', icone: Icons.grid_view_rounded),
                Puce(texte: 'Liens immédiats + Email', icone: Icons.send_rounded),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Votre business africain\nmérite un vrai plan.',
              textAlign: large ? TextAlign.start : TextAlign.center,
              style: TextStyle(
                color: K.sand,
                fontSize: large ? 46 : 33,
                height: 1.08,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choisissez votre métier en 1 clic. Recevez un livre stratégique, des prompts IA '
              'et un Google Sheet automatisé, écrits pour votre pays et vos clients — pas des conseils génériques.',
              textAlign: large ? TextAlign.start : TextAlign.center,
              style: const TextStyle(color: K.mist, fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: large ? WrapAlignment.start : WrapAlignment.center,
              children: [
                SizedBox(
                  width: large ? 250 : double.infinity,
                  child: OrButton(
                    label: 'Choisir mon kit',
                    icone: Icons.rocket_launch_rounded,
                    onPressed: () => _commander(),
                  ),
                ),
                AideWhatsApp(),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, color: K.mist, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Paiement sécurisé SasPay · mobile money & carte',
                    style: TextStyle(color: K.mist.withValues(alpha: 0.85), fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        );

        final blocVisuel = Column(
          children: [
            SizedBox(
              height: 300,
              child: PageView.builder(
                controller: _pages,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final actif = index == _page;
                  return AnimatedScale(
                    scale: actif ? 1 : 0.9,
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: actif ? 1 : 0.55,
                      duration: const Duration(milliseconds: 380),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: K.gold.withValues(alpha: actif ? 0.7 : 0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              _images[index % _images.length],
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(color: K.deep),
                              loadingBuilder: (context, child, progression) =>
                                  progression == null ? child : const ColoredBox(color: K.deep),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, K.night.withValues(alpha: 0.95)],
                                  stops: const [0.35, 1],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 20,
                              child: Text(
                                _legendes[index % _legendes.length],
                                style: const TextStyle(
                                  color: K.sand,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: K.night.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: K.gold.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pas encore décidé ?',
                    style: TextStyle(color: K.sand, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Recevez notre email d\'information : offres, kits et méthode.',
                    style: TextStyle(color: K.mist, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: K.sand, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'votre@email.com',
                            hintStyle: TextStyle(color: K.mist.withValues(alpha: 0.5), fontSize: 13),
                            filled: true,
                            fillColor: K.deep.withValues(alpha: 0.8),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          onPressed: _envoiEmail ? null : _recevoirInfos,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: K.gold,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _envoiEmail
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: K.night, strokeWidth: 2),
                                )
                              : const Icon(Icons.arrow_forward_rounded, color: K.night, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

        if (large) {
          return Padding(
            padding: const EdgeInsets.only(top: 26, bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: blocTexte),
                const SizedBox(width: 40),
                Expanded(flex: 5, child: blocVisuel),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Column(
            children: [
              blocTexte,
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, child: blocVisuel),
            ],
          ),
        );
      },
    );
  }

  Widget _bandeauConfiance() {
    const elements = [
      (Icons.account_balance_wallet_rounded, 'Mobile money & carte', 'Orange, Wave, MTN, Moov, Djamo'),
      (Icons.bolt_rounded, 'Livraison immédiate', 'Liens à l\'écran + email'),
      (Icons.verified_rounded, 'Paiement SasPay', '100 % FCFA, XOF / XAF'),
      (Icons.folder_open_rounded, 'Zéro fichier lourd', 'Tout est consultable en ligne'),
    ];

    return LayoutBuilder(
      builder: (context, contraintes) {
        final colonnes = contraintes.maxWidth > 900 ? 4 : (contraintes.maxWidth > 560 ? 2 : 1);
        final largeur = (contraintes.maxWidth - (colonnes - 1) * 12) / colonnes;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final element in elements)
              Container(
                width: largeur,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: K.deep.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Icon(element.$1, color: K.gold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            element.$2,
                            style: const TextStyle(color: K.sand, fontSize: 12.5, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            element.$3,
                            style: const TextStyle(color: K.mist, fontSize: 10.5),
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

  // --------------------------------------------------------------------------
  //  OFFRES
  // --------------------------------------------------------------------------
  Widget _offres(BuildContext context) {
    return Column(
      children: [
        const TitreSection(
          surtitre: 'Tarifs clairs, en FCFA',
          titre: 'Choisissez votre offre',
          sousTitre: 'Un paiement unique. Aucun abonnement. Vous recevez vos documents immédiatement après le paiement.',
          centre: true,
        ),
        const SizedBox(height: 30),
        LayoutBuilder(
          builder: (context, contraintes) {
            final colonnes = contraintes.maxWidth > 940
                ? 4
                : (contraintes.maxWidth > 560 ? 2 : 1);
            final largeur = (contraintes.maxWidth - (colonnes - 1) * 16) / colonnes;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                for (final offre in offres)
                  SizedBox(
                    width: largeur,
                    child: _carteOffre(context, offre),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _carteOffre(BuildContext context, Offre offre) {
    return GlassCard(
      miseEnAvant: offre.populaire,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (offre.populaire)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: K.gold, borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'LE PLUS CHOISI',
                style: TextStyle(color: K.night, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.6),
              ),
            ),
          Icon(offre.icone, color: K.gold, size: 26),
          const SizedBox(height: 12),
          Text(
            offre.titre,
            style: const TextStyle(color: K.sand, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            offre.description,
            style: const TextStyle(color: K.mist, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 16),
          Text(
            offre.prixAffiche,
            style: const TextStyle(color: K.goldSoft, fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Paiement unique',
            style: TextStyle(color: K.mist, fontSize: 11),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OrButton(
              label: 'Commander',
              plein: offre.populaire,
              hauteur: 44,
              onPressed: () => _commander(offre: offre.apiType),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  //  KITS MÉTIERS
  // --------------------------------------------------------------------------
  Widget _kits(BuildContext context) {
    return Column(
      children: [
        const TitreSection(
          surtitre: 'Kits métiers clés en main',
          titre: 'Votre secteur en 1 clic',
          sousTitre: 'Restaurant, boutique en ligne, élevage, beauté, services ou financement : '
              'le contenu est déjà pensé pour votre réalité de terrain.',
          centre: true,
        ),
        const SizedBox(height: 30),
        LayoutBuilder(
          builder: (context, contraintes) {
            final colonnes = contraintes.maxWidth > 940
                ? 3
                : (contraintes.maxWidth > 600 ? 2 : 1);
            final largeur = (contraintes.maxWidth - (colonnes - 1) * 14) / colonnes;

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final kit in kitsMetiers)
                  SizedBox(
                    width: largeur,
                    child: _carteKit(context, kit),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _carteKit(BuildContext context, KitMetier kit) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: K.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: K.gold.withValues(alpha: 0.3)),
                ),
                child: Text(kit.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  kit.label,
                  style: const TextStyle(color: K.sand, fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            kit.promesse,
            style: const TextStyle(color: K.mist, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _commander(metier: kit.code),
            child: Row(
              children: [
                const Text(
                  'Choisir ce kit',
                  style: TextStyle(color: K.gold, fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, color: K.gold.withValues(alpha: 0.8), size: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  //  ÉTAPES
  // --------------------------------------------------------------------------
  Widget _etapes() {
    const etapes = [
      (1, 'Choisissez votre métier', 'Sélectionnez votre secteur, l\'offre, votre pays et laissez votre numéro WhatsApp.'),
      (2, 'Payez avec SasPay', 'Mobile money ou carte bancaire, en FCFA. Le montant est affiché avant le paiement.'),
      (3, 'Recevez tout de suite', 'Votre livre, vos prompts et votre Google Sheet s\'affichent à l\'écran et arrivent par email.'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: K.deep.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: K.gold.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          const TitreSection(
            surtitre: 'Comment ça marche',
            titre: 'Trois étapes, deux minutes',
            centre: true,
          ),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, contraintes) {
              final large = contraintes.maxWidth > 760;
              final blocs = [
                for (final etape in etapes)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: K.gold, shape: BoxShape.circle),
                          child: Text(
                            '${etape.$1}',
                            style: const TextStyle(color: K.night, fontWeight: FontWeight.w900, fontSize: 17),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          etape.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: K.sand, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          etape.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: K.mist, fontSize: 12.5, height: 1.45),
                        ),
                      ],
                    ),
                  ),
              ];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: large
                    ? Row(
                        children: [
                          for (final bloc in blocs) Expanded(child: bloc),
                        ],
                      )
                    : Column(children: blocs),
              );
            },
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  //  PAYS
  // --------------------------------------------------------------------------
  // --------------------------------------------------------------------------
  //  NOTES & AVIS DE NOS CLIENTS
  // --------------------------------------------------------------------------
  Widget _avisSection() {
    return Column(
      children: [
        const TitreSection(
          surtitre: 'Votre expérience compte',
          titre: 'Notes & Avis de nos clients',
          sousTitre: 'Vous avez utilisé un kit ? Notez le site et racontez ce que cela vous a apporté. '
              'Les avis sont publiés immédiatement.',
          centre: true,
        ),
        const SizedBox(height: 20),
        if (_chargementAvis)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: CircularProgressIndicator(color: K.gold),
          )
        else if (_avis.isNotEmpty)
          _resumeAvis(),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, contraintes) {
            final large = contraintes.maxWidth > 880;
            final liste = _listeAvis();
            final formulaire = _formulaireAvis();

            if (large) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: liste),
                  const SizedBox(width: 20),
                  Expanded(flex: 4, child: formulaire),
                ],
              );
            }

            return Column(children: [liste, const SizedBox(height: 16), formulaire]);
          },
        ),
      ],
    );
  }

  Widget _resumeAvis() {
    final moyenne = _noteMoyenne.toStringAsFixed(1).replaceAll('.', ',');
    final libelle = _avis.length > 1 ? '${_avis.length} avis publiés' : '${_avis.length} avis publié';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Text(
            moyenne,
            style: const TextStyle(color: K.goldSoft, fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 6),
            child: Text('/5', style: TextStyle(color: K.mist, fontSize: 13)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _etoiles(_noteMoyenne.round(), 16),
                const SizedBox(height: 2),
                Text(libelle, style: const TextStyle(color: K.mist, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listeAvis() {
    if (_avis.isEmpty) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Aucun avis pour l\'instant',
              style: TextStyle(color: K.sand, fontSize: 15, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Soyez le premier à noter le site et à partager votre expérience après votre premier kit.',
              style: TextStyle(color: K.mist, fontSize: 12.5, height: 1.5),
            ),
          ],
        ),
      );
    }

    final affiches = _avis.take(6).toList();

    return Column(
      children: [
        for (final avis in affiches) _carteAvis(avis),
        if (_avis.length > affiches.length)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+ ${_avis.length - affiches.length} autres avis',
              style: const TextStyle(color: K.mist, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _carteAvis(AvisSite avis) {
    final details = <String>[
      if (avis.localisation.isNotEmpty) avis.localisation,
      _dateAvis(avis.createdAt),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: K.night.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: K.gold.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: K.gold.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: K.gold.withValues(alpha: 0.35)),
                ),
                child: Text(
                  avis.initiale,
                  style: const TextStyle(color: K.gold, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avis.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: K.sand, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: K.mist, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _etoiles(avis.note, 14),
          const SizedBox(height: 6),
          Text(
            avis.commentaire,
            style: const TextStyle(color: K.mist, fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _formulaireAvis() {
    return GlassCard(
      miseEnAvant: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Laissez votre avis',
            style: TextStyle(color: K.sand, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Une note et quelques lignes suffisent. Aucun compte n\'est nécessaire.',
            style: TextStyle(color: K.mist, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var etoile = 1; etoile <= 5; etoile++)
                IconButton(
                  onPressed: () => setState(() => _noteAvis = etoile),
                  tooltip: '$etoile étoile${etoile > 1 ? 's' : ''}',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: Icon(
                    etoile <= _noteAvis ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: K.gold,
                    size: 30,
                  ),
                ),
            ],
          ),
          Text(
            'Votre note : $_noteAvis/5',
            style: const TextStyle(color: K.mist, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _avisNom,
            maxLength: 60,
            style: const TextStyle(color: K.sand),
            decoration: champ(label: 'Votre nom', icone: Icons.person_rounded),
          ),
          const SizedBox(height: 2),
          TextField(
            controller: _avisVille,
            maxLength: 80,
            style: const TextStyle(color: K.sand),
            decoration: champ(label: 'Ville (optionnel)', icone: Icons.location_city_rounded),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: K.deep.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: K.gold.withValues(alpha: 0.18)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Pays>(
                value: _avisPays,
                isExpanded: true,
                dropdownColor: K.night,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: K.mist),
                items: [
                  for (final pays in paysAfricains)
                    DropdownMenuItem<Pays>(
                      value: pays,
                      child: Text(
                        '${pays.drapeau}  ${pays.nom}',
                        style: const TextStyle(color: K.sand, fontSize: 13),
                      ),
                    ),
                ],
                onChanged: (pays) {
                  if (pays != null) setState(() => _avisPays = pays);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _avisCommentaire,
            maxLines: 3,
            maxLength: 600,
            style: const TextStyle(color: K.sand),
            decoration: champ(
              label: 'Votre commentaire',
              hint: 'Ex : le plan d\'action m\'a aidé à fixer mes prix.',
              icone: Icons.rate_review_rounded,
            ),
          ),
          const SizedBox(height: 2),
          OrButton(
            label: 'Publier mon avis',
            icone: Icons.star_rounded,
            chargement: _envoiAvis,
            onPressed: _envoyerAvis,
          ),
        ],
      ),
    );
  }

  Widget _etoiles(int note, double taille) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var etoile = 0; etoile < 5; etoile++)
          Icon(
            etoile < note ? Icons.star_rounded : Icons.star_outline_rounded,
            color: K.gold,
            size: taille,
          ),
      ],
    );
  }

  Widget _pays() {
    return Column(
      children: [
        const TitreSection(
          surtitre: 'Partout en Afrique francophone',
          titre: 'Votre pays, votre devise',
          sousTitre: 'Les montants sont en FCFA (XOF / XAF), exactement comme vous payez au quotidien.',
          centre: true,
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final pays in paysAfricains)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: K.deep.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: K.gold.withValues(alpha: 0.18)),
                ),
                child: Text(
                  '${pays.drapeau} ${pays.nom}',
                  style: const TextStyle(color: K.sand, fontSize: 12),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _appelFinal(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [K.gold.withValues(alpha: 0.16), K.clay.withValues(alpha: 0.12)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: K.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          const Text(
            'Le bon plan coûte moins qu\'une journée de tâtonnement.',
            textAlign: TextAlign.center,
            style: TextStyle(color: K.sand, fontSize: 22, fontWeight: FontWeight.w900, height: 1.25),
          ),
          const SizedBox(height: 10),
          const Text(
            'À partir de 3 000 FCFA, vous repartez avec un plan écrit, des prompts prêts à l\'emploi '
            'et un tableau de gestion. Livré par email, liens immédiats à l\'écran.',
            textAlign: TextAlign.center,
            style: TextStyle(color: K.mist, fontSize: 14, height: 1.55),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: OrButton(
                  label: 'Choisir mon kit maintenant',
                  icone: Icons.rocket_launch_rounded,
                  onPressed: () => _commander(),
                ),
              ),
              AideWhatsApp(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _piedDePage(BuildContext context) {
    return Column(
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/cgv'),
              child: const Text('CGV', style: TextStyle(color: K.mist, fontSize: 12)),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/mentions-legales'),
              child: const Text('Mentions légales', style: TextStyle(color: K.mist, fontSize: 12)),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/faq'),
              child: const Text('FAQ', style: TextStyle(color: K.mist, fontSize: 12)),
            ),
            TextButton(
              onPressed: () => ouvrirLienAvecRetour(context, AppConfig.lienWhatsAppAide),
              child: const Text('Aide WhatsApp', style: TextStyle(color: K.green, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '© ${DateTime.now().year} Kit Business · ${AppConfig.emailSupport}',
          style: const TextStyle(color: K.mist, fontSize: 11),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
