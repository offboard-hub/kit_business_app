import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/app_header.dart';
import '../widgets/site_assistant_chat.dart';

/// ============================================================================
///  GUIDE & TUTORIEL — 3 étapes illustrées, interactives et concrètes.
/// ============================================================================
class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  int _etape = 0;

  static const List<_EtapeGuide> _etapes = <_EtapeGuide>[
    _EtapeGuide(
      surtitre: 'ÉTAPE 01',
      titre: 'Commander dans La Boutique',
      resume:
          'Deux écrans suffisent : votre métier, puis votre kit et votre pays. Les prix se convertissent automatiquement.',
      icone: Icons.storefront_rounded,
      couleur: Color(0xFFE7B84B),
      points: <String>[
        'Choisissez votre secteur parmi les 8 métiers, ou « Autre métier » et décrivez votre activité.',
        'Sélectionnez votre kit : Prompts IA, Sheet, Livre Stratégique ou Pack Complet.',
        'Choisissez votre pays : le prix s\'affiche dans votre devise locale (SasPay) ou en EUR/USD (Paddle).',
        'Renseignez le nom de votre projet, votre WhatsApp et votre email.',
        'Payez en mobile money ou par carte : le kit est généré et envoyé immédiatement par email.',
      ],
      astuce:
          'Aucun compte n\'est nécessaire pour commander. Gardez l\'email de livraison : c\'est lui qui contient vos liens.',
      action: 'Ouvrir La Boutique',
      route: '/boutique',
    ),
    _EtapeGuide(
      surtitre: 'ÉTAPE 02',
      titre: 'Configurer ma régie Studio Live',
      resume:
          'Solo ou duo, caméra produits ou partage d\'écran : la régie s\'adapte à votre façon de vendre.',
      icone: Icons.sensors_rounded,
      couleur: Color(0xFF34D399),
      points: <String>[
        'Abonnez-vous pour 10 \$ / 30 jours, converti dans votre devise.',
        'Choisissez vos plateformes : salle e-booklive, TikTok Live, YouTube Live, Instagram Live.',
        'Format : animez seul ou invitez un co-animateur avec un lien unique.',
        'Mode visuel : caméra produits (mode, accessoires) ou partage d\'écran (formation, logiciel).',
        'Remplissez la Fiche Produit IA, puis lancez la salle Jitsi depuis l\'onglet « Salle en direct ».',
      ],
      astuce:
          'Le lien co-animateur ressemble à /live/votre-salle?invite=… : envoyez-le à votre partenaire, il monte depuis n\'importe où.',
      action: 'Découvrir le Studio Live',
      route: '/studio-live',
    ),
    _EtapeGuide(
      surtitre: 'ÉTAPE 03',
      titre: 'Utiliser le Chat IA & le Livre Guide',
      resume:
          'Pendant le live, l\'IA répond aux spectateurs. Après le paiement, votre Livre Guide est rédigé pour votre métier.',
      icone: Icons.auto_awesome_rounded,
      couleur: Color(0xFF6EE7B7),
      points: <String>[
        'Le chat IA (DeepSeek) utilise votre Fiche Produit pour répondre aux questions des spectateurs.',
        'Pour une question posée sur TikTok ou Instagram, saisissez-la : la réponse arrive en quelques secondes.',
        'Cliquez sur « Copier en 1 clic » et collez la réponse directement dans le chat du réseau social.',
        'Votre Livre Guide Live est généré dès l\'activation : script d\'accroche, structure, caméra, vente.',
        'Il reste accessible dans l\'onglet « Mon Livre Guide » et vous est envoyé par email.',
      ],
      astuce:
          'L\'assistante Awa, en bas à droite, connaît les prix par pays et peut vous guider à tout moment.',
      action: 'Parler à l\'assistante IA',
      route: '/assistant',
    ),
  ];

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
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: <Widget>[
                          const SizedBox(height: 22),
                          const Puce(texte: 'Guide & Tutoriel', icone: Icons.menu_book_rounded),
                          const SizedBox(height: 16),
                          const Text(
                            'Tout comprendre\nen trois étapes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: K.text,
                              fontSize: 42,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Commander un kit, configurer sa régie live, utiliser le chat IA et le '
                            'Livre Guide. Aucun jargon, uniquement ce qu\'il faut faire.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: K.muted, fontSize: 14.5, height: 1.65),
                          ),
                          const SizedBox(height: 28),
                          _navigationEtapes(),
                          const SizedBox(height: 22),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            child: _contenuEtape(_etapes[_etape], key: ValueKey<int>(_etape)),
                          ),
                          const SizedBox(height: 54),
                          _faq(),
                          const SizedBox(height: 50),
                          _appelFinal(),
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

  Widget _navigationEtapes() {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final large = contraintes.maxWidth > 640;
        return Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: K.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: K.border),
          ),
          child: large
              ? Row(
                  children: <Widget>[
                    for (var index = 0; index < _etapes.length; index++)
                      Expanded(
                        child: _BoutonNavigation(
                          actif: _etape == index,
                          numero: '0${index + 1}',
                          label: _etapes[index].titre,
                          icone: _etapes[index].icone,
                          onTap: () => setState(() => _etape = index),
                        ),
                      ),
                  ],
                )
              : Row(
                  children: <Widget>[
                    for (var index = 0; index < _etapes.length; index++)
                      Expanded(
                        child: _BoutonNavigation(
                          actif: _etape == index,
                          numero: '0${index + 1}',
                          label: '',
                          icone: _etapes[index].icone,
                          onTap: () => setState(() => _etape = index),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _contenuEtape(_EtapeGuide etape, {Key? key}) {
    return GlassCard(
      key: key,
      padding: const EdgeInsets.all(26),
      child: LayoutBuilder(
        builder: (context, contraintes) {
          final large = contraintes.maxWidth > 780;
          final texte = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: etape.couleur.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: etape.couleur.withValues(alpha: 0.3)),
                    ),
                    child: Icon(etape.icone, color: etape.couleur, size: 20),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    etape.surtitre,
                    style: TextStyle(
                      color: etape.couleur,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                etape.titre,
                style: const TextStyle(
                  color: K.text,
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                etape.resume,
                style: const TextStyle(color: K.muted, fontSize: 12.5, height: 1.6),
              ),
              const SizedBox(height: 16),
              for (final point in etape.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_rounded, color: etape.couleur, size: 15),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          point,
                          style: const TextStyle(color: K.text, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: etape.couleur.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: etape.couleur.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.lightbulb_rounded, color: etape.couleur, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        etape.astuce,
                        style: const TextStyle(color: K.muted, fontSize: 10.5, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 260,
                child: OrButton(
                  label: etape.action,
                  icone: Icons.arrow_forward_rounded,
                  onPressed: () => Navigator.pushNamed(context, etape.route),
                ),
              ),
            ],
          );

          final visuel = _Illustration(etape: etape, index: _etape);
          return large
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 6, child: texte),
                    const SizedBox(width: 26),
                    Expanded(flex: 5, child: visuel),
                  ],
                )
              : Column(
                  children: <Widget>[
                    visuel,
                    const SizedBox(height: 22),
                    texte,
                  ],
                );
        },
      ),
    );
  }

  Widget _faq() {
    const questions = <(String, String)>[
      (
        'Ai-je besoin d\'un compte pour commander un kit ?',
        'Non. La commande se fait avec votre email et votre WhatsApp. Le compte sert à retrouver '
            'vos achats et à accéder à la régie Studio Live.',
      ),
      (
        'Comment les prix sont-ils convertis ?',
        'Vous choisissez votre pays. Dans les 23 pays SasPay, le prix est calculé dans votre devise '
            'locale et débité en local. Ailleurs, Paddle facture en EUR ou USD, la conversion locale '
            'est affichée à titre indicatif.',
      ),
      (
        'Le Studio Live est-il vraiment à 10 \$ ?',
        'Oui : 10 USD pour 30 jours, converti dans votre devise au moment du paiement. Aucun frais '
            'caché, aucun engagement.',
      ),
      (
        'Puis-je inviter un co-animateur ?',
        'Oui. Choisissez le format « Inviter un co-animateur » : un lien unique est généré. Votre '
            'partenaire le reçoit et monte dans la salle depuis n\'importe où.',
      ),
      (
        'Le Livre Guide est-il personnalisé ?',
        'Oui, il est rédigé à partir de votre métier, de votre pays et de votre offre. Il est envoyé '
            'par email dès l\'activation et reste disponible dans la régie.',
      ),
    ];

    return Column(
      children: <Widget>[
        const TitreSection(
          surtitre: 'Questions fréquentes',
          titre: 'Tout ce qu\'on nous demande',
          centre: true,
        ),
        const SizedBox(height: 18),
        for (final question in questions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: K.surface.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: K.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  iconColor: K.or,
                  collapsedIconColor: K.faint,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  title: Text(
                    question.$1,
                    style: const TextStyle(
                      color: K.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        question.$2,
                        style: const TextStyle(color: K.muted, fontSize: 11.5, height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _appelFinal() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF221C0D), Color(0xFF0B241D)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: K.or.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'Vous savez tout. À vous de jouer.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: K.text,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Un kit pour structurer, un studio pour vendre. Les deux sont à quelques clics.',
            textAlign: TextAlign.center,
            style: TextStyle(color: K.muted, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 220,
                child: OrButton(
                  label: 'Explorer La Boutique',
                  icone: Icons.storefront_rounded,
                  onPressed: () => Navigator.pushNamed(context, '/boutique'),
                ),
              ),
              SizedBox(
                width: 220,
                child: OrButton(
                  label: 'Studio Live — 10 \$',
                  icone: Icons.sensors_rounded,
                  plein: false,
                  onPressed: () => Navigator.pushNamed(context, '/studio-live'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EtapeGuide {
  const _EtapeGuide({
    required this.surtitre,
    required this.titre,
    required this.resume,
    required this.icone,
    required this.couleur,
    required this.points,
    required this.astuce,
    required this.action,
    required this.route,
  });

  final String surtitre;
  final String titre;
  final String resume;
  final IconData icone;
  final Color couleur;
  final List<String> points;
  final String astuce;
  final String action;
  final String route;
}

class _BoutonNavigation extends StatelessWidget {
  const _BoutonNavigation({
    required this.actif,
    required this.numero,
    required this.label,
    required this.icone,
    required this.onTap,
  });

  final bool actif;
  final String numero;
  final String label;
  final IconData icone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: actif ? K.or.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: actif ? K.or.withValues(alpha: 0.32) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icone, size: 15, color: actif ? K.or : K.faint),
              if (label.isNotEmpty) ...<Widget>[
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: actif ? K.text : K.faint,
                      fontSize: 11,
                      fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.etape, required this.index});

  final _EtapeGuide etape;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF131C2E), Color(0xFF0C1320)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: etape.couleur.withValues(alpha: 0.2)),
      ),
      child: index == 0
          ? _illustrationBoutique()
          : index == 1
              ? _illustrationRegie()
              : _illustrationChat(),
    );
  }

  Widget _illustrationBoutique() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _barreFenetre('ebooklive / boutique'),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            for (final emoji in <String>['🛍️', '🏠', '🍲'])
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: K.or.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: K.or.withValues(alpha: 0.18)),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _lignePrix('Pack Complet', '9 000 FCFA', K.or),
        const SizedBox(height: 6),
        _lignePrix('En EUR (Paddle)', '13,72 €', K.emeraude),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: K.bg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: K.border),
          ),
          child: const Row(
            children: <Widget>[
              Icon(Icons.public_rounded, size: 13, color: K.muted),
              SizedBox(width: 6),
              Text('🇲🇦 Maroc · MAD', style: TextStyle(color: K.text, fontSize: 10)),
              Spacer(),
              Text('≈ 165 MAD', style: TextStyle(color: K.faint, fontSize: 9)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _illustrationRegie() {
    return Column(
      children: <Widget>[
        _barreFenetre('ebooklive / studio-live'),
        const SizedBox(height: 10),
        Container(
          height: 92,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF0A1F1A), Color(0xFF101827)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: K.emeraude.withValues(alpha: 0.2)),
          ),
          child: const Center(
            child: Icon(Icons.videocam_rounded, color: K.emeraude, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            _petitePastille('Solo', Icons.person_rounded, false),
            const SizedBox(width: 6),
            _petitePastille('Duo', Icons.group_rounded, true),
            const SizedBox(width: 6),
            _petitePastille('Écran', Icons.screen_share_rounded, false),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: K.emeraude.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: K.emeraude.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: <Widget>[
              Icon(Icons.link_rounded, size: 12, color: K.emeraude),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '/live/ma-salle?invite=…',
                  style: TextStyle(color: K.emeraude, fontSize: 8.5),
                ),
              ),
              Text('Copier', style: TextStyle(color: K.muted, fontSize: 8)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _illustrationChat() {
    return Column(
      children: <Widget>[
        _barreFenetre('ebooklive / chat ia'),
        const SizedBox(height: 10),
        _bulle('Quel est le prix de la robe ?', false),
        _bulle('La robe wax est à 9 000 FCFA, livraison offerte aujourd\'hui.', true),
        _bulle('Je prends, comment commander ?', false),
        _bulle('Commandez sur WhatsApp : le lien est en bio. Je vous envoie le récap.', true),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: K.emeraude.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: K.emeraude.withValues(alpha: 0.25)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.copy_rounded, size: 11, color: K.emeraude),
              SizedBox(width: 5),
              Text('Copier en 1 clic', style: TextStyle(color: K.emeraude, fontSize: 8.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _barreFenetre(String titre) {
    return Row(
      children: <Widget>[
        for (final couleur in <Color>[K.danger, K.or, K.emeraude])
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: couleur.withValues(alpha: 0.7), shape: BoxShape.circle),
            ),
          ),
        const SizedBox(width: 6),
        Text(titre, style: const TextStyle(color: K.faint, fontSize: 8.5)),
      ],
    );
  }

  Widget _lignePrix(String label, String prix, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: K.bg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: K.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: const TextStyle(color: K.muted, fontSize: 9.5)),
          ),
          Text(
            prix,
            style: TextStyle(color: couleur, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _petitePastille(String label, IconData icone, bool actif) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: actif ? K.emeraude.withValues(alpha: 0.12) : K.bg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: actif ? K.emeraude.withValues(alpha: 0.35) : K.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icone, size: 10, color: actif ? K.emeraude : K.faint),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: actif ? K.emeraude : K.faint, fontSize: 8.5),
          ),
        ],
      ),
    );
  }

  Widget _bulle(String texte, bool assistant) {
    return Align(
      alignment: assistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: assistant ? K.emeraude.withValues(alpha: 0.08) : K.or.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: assistant ? K.emeraude.withValues(alpha: 0.2) : K.or.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          texte,
          style: const TextStyle(color: K.text, fontSize: 8.5, height: 1.4),
        ),
      ),
    );
  }
}
