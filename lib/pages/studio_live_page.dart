import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_state.dart';
import '../core/config.dart';
import '../core/countries.dart';
import '../core/models.dart';
import '../core/pricing.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../services/checkout_ouverture.dart';
import '../widgets/app_header.dart';
import '../widgets/country_picker.dart';
import '../widgets/logo_ebooklive.dart';
import '../widgets/site_assistant_chat.dart';
import '../widgets/whatsapp.dart';
import 'paiement_en_attente_page.dart';

/// ============================================================================
///  STUDIO LIVE — page publique
///  Abonnement 10 USD / 30 jours, converti dans la devise du pays choisi.
///  Régie pro, co-animateur, chat IA et Livre Guide offert.
/// ============================================================================
class StudioLivePage extends StatefulWidget {
  const StudioLivePage({super.key});

  @override
  State<StudioLivePage> createState() => _StudioLivePageState();
}

class _StudioLivePageState extends State<StudioLivePage> {
  final String? _abonnementId = Uri.base.queryParameters['abonnement'];
  AccesStudio? _acces;
  bool _essaiEnCours = false;
  Timer? _minuteurAcces;

  @override
  void initState() {
    super.initState();
    final abonnementId = _abonnementId;
    if (abonnementId == null || abonnementId.isEmpty) {
      _chargerAcces();
      _minuteurAcces = Timer.periodic(const Duration(seconds: 60), (_) {
        final acces = _acces;
        if (!mounted || acces == null) return;
        final essaiExpire = acces.essai != null && !acces.essai!.estActif;
        final abonnementExpire = acces.abonnement != null && !acces.estPaye;
        if (essaiExpire || abonnementExpire) _chargerAcces();
      });
    }
  }

  @override
  void dispose() {
    _minuteurAcces?.cancel();
    super.dispose();
  }

  Future<void> _chargerAcces() async {
    final acces = await ApiService.accesStudio();
    if (!mounted) return;
    setState(() => _acces = acces);
  }

  Future<void> _demarrerEssai() async {
    if (_essaiEnCours) return;
    final utilisateur = Supabase.instance.client.auth.currentUser;
    if (utilisateur == null) {
      _toast('Créez un compte ou connectez-vous pour démarrer votre essai gratuit.');
      Navigator.pushNamed(context, '/mon-espace');
      return;
    }
    if (utilisateur.emailConfirmedAt == null) {
      _toast(
        'Confirmez votre adresse email avant de démarrer l\'essai gratuit.',
        couleur: K.danger,
      );
      return;
    }

    setState(() => _essaiEnCours = true);
    try {
      await ApiService.demarrerEssai();
      await _chargerAcces();
      if (!mounted) return;
      setState(() => _essaiEnCours = false);
      Navigator.pushNamed(context, '/studio/regie');
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _essaiEnCours = false);
      _toast(
        erreur is ApiException ? erreur.message : 'Impossible de démarrer l\'essai gratuit.',
        couleur: K.danger,
      );
    }
  }

  void _toast(String message, {Color couleur = K.or}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: couleur == K.or ? null : couleur),
    );
  }

  @override
  Widget build(BuildContext context) {
    final abonnementId = _abonnementId;
    if (abonnementId != null && abonnementId.isNotEmpty) {
      return _StudioActivationPage(subscriptionId: abonnementId);
    }

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
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (_acces?.estPaye == true) ...<Widget>[
                            const SizedBox(height: 12),
                            _BandeauActif(abonnement: _acces!.abonnement!),
                          ] else if (_acces?.estEssai == true) ...<Widget>[
                            const SizedBox(height: 12),
                            _BandeauEssai(essai: _acces!.essai!),
                          ] else if (_acces?.essaiExpire == true) ...<Widget>[
                            const SizedBox(height: 12),
                            _BandeauEssaiTermine(onSouscrire: _ouvrirSouscription),
                          ],
                          _Hero(
                            acces: _acces,
                            essaiEnCours: _essaiEnCours,
                            onEssai: _demarrerEssai,
                            onSouscrire: _ouvrirSouscription,
                            onRegie: () => Navigator.pushNamed(context, '/studio/regie'),
                          ),
                          const SizedBox(height: 56),
                          _Avantages(),
                          const SizedBox(height: 64),
                          _Contenu(),
                          const SizedBox(height: 64),
                          _CommentCaMarche(),
                          const SizedBox(height: 64),
                          _AppelFinal(
                            onSouscrire: _ouvrirSouscription,
                            onEssai: _demarrerEssai,
                            essaiEnCours: _essaiEnCours,
                          ),
                          const SizedBox(height: 40),
                          _PiedDePage(),
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

  Future<void> _ouvrirSouscription() async {
    final achete = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _SouscriptionSheet(),
    );
    if (achete == true && mounted) {
      await _chargerAcces();
    }
  }
}

// ============================================================================
//  HÉRO
// ============================================================================
class _Hero extends StatelessWidget {
  const _Hero({
    required this.acces,
    required this.essaiEnCours,
    required this.onEssai,
    required this.onSouscrire,
    required this.onRegie,
  });

  final AccesStudio? acces;
  final bool essaiEnCours;
  final VoidCallback onEssai;
  final VoidCallback onSouscrire;
  final VoidCallback onRegie;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final large = contraintes.maxWidth > 900;
        final texte = _TexteHero(
          acces: acces,
          essaiEnCours: essaiEnCours,
          onEssai: onEssai,
          onSouscrire: onSouscrire,
          onRegie: onRegie,
        );
        const visuel = _VisuelRegie();

        return Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 10),
          child: large
              ? Row(
                  children: <Widget>[
                    Expanded(flex: 6, child: texte),
                    const SizedBox(width: 44),
                    const Expanded(flex: 5, child: visuel),
                  ],
                )
              : Column(
                  children: <Widget>[
                    texte,
                    const SizedBox(height: 32),
                    visuel,
                  ],
                ),
        );
      },
    );
  }
}

class _TexteHero extends StatelessWidget {
  const _TexteHero({
    required this.acces,
    required this.essaiEnCours,
    required this.onEssai,
    required this.onSouscrire,
    required this.onRegie,
  });

  final AccesStudio? acces;
  final bool essaiEnCours;
  final VoidCallback onEssai;
  final VoidCallback onSouscrire;
  final VoidCallback onRegie;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PaysMonde>(
      valueListenable: CountryStore.pays,
      builder: (context, pays, _) {
        final devis = Prix.devisStudio(pays);
        final paye = acces?.estPaye == true;
        final essaiActif = acces?.estEssai == true;
        final essaiExpire = acces?.essaiExpire == true;
        final essaiJamaisUtilise = acces?.essai == null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                const Puce(
                  texte: 'Studio Live',
                  icone: Icons.sensors_rounded,
                  couleur: K.emeraude,
                ),
                const Puce(texte: '10 USD / mois', icone: Icons.sell_rounded),
                if (essaiActif)
                  Puce(
                    texte: 'Essai · ${acces!.essai!.joursRestants} j restants',
                    icone: Icons.timer_rounded,
                    couleur: K.or,
                  )
                else if (essaiJamaisUtilise)
                  const Puce(
                    texte: 'Essai gratuit 3 jours',
                    icone: Icons.card_giftcard_rounded,
                    couleur: K.or,
                  ),
                Puce(
                  texte: pays.viaSasPay ? 'Paiement ${pays.devise}' : 'Paiement ${pays.devisePaddle}',
                  icone: Icons.public_rounded,
                  couleur: K.emeraude,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Votre studio de vente\nen direct, clé en main.',
              style: TextStyle(
                color: K.text,
                fontSize: 44,
                height: 1.07,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.6,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Une régie live professionnelle, un co-animateur à distance, un chat IA '
              'commercial qui répond aux spectateurs et un Livre Guide personnalisé '
              'pour votre métier. Essayez 3 jours gratuitement, sans carte, puis 10 \$ par mois.',
              style: TextStyle(color: K.muted, fontSize: 15.5, height: 1.65),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF0B241D), Color(0xFF111827)],
                ),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: K.emeraude.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: 6,
                          runSpacing: 2,
                          children: <Widget>[
                            Text(
                              devis.devise == 'USD' ? '10,00 \$' : devis.principal,
                              style: const TextStyle(
                                color: K.emeraudeSoft,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 5),
                              child: Text(
                                '/ mois',
                                style: TextStyle(color: K.faint, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          devis.devise == 'USD'
                              ? '${pays.drapeau} ${pays.nom} · prix fixe en USD'
                              : '${devis.indicatif ?? ''}  ·  équivalent de 10 \$',
                          style: const TextStyle(color: K.muted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const PaysSelector(compact: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                if (paye)
                  SizedBox(
                    width: 250,
                    child: OrButton(
                      label: 'Ouvrir ma régie',
                      icone: Icons.sensors_rounded,
                      onPressed: onRegie,
                    ),
                  )
                else if (essaiActif)
                  SizedBox(
                    width: 250,
                    child: OrButton(
                      label: 'Continuer mon essai · ${acces!.essai!.joursRestants} j',
                      icone: Icons.sensors_rounded,
                      onPressed: onRegie,
                    ),
                  )
                else if (essaiExpire)
                  SizedBox(
                    width: 290,
                    child: OrButton(
                      label: 'S\'abonner maintenant : 10 USD / mois',
                      icone: Icons.workspace_premium_rounded,
                      onPressed: onSouscrire,
                    ),
                  )
                else
                  SizedBox(
                    width: 270,
                    child: OrButton(
                      label: 'Essayer gratuitement 3 jours',
                      icone: Icons.card_giftcard_rounded,
                      chargement: essaiEnCours,
                      onPressed: essaiEnCours ? null : onEssai,
                    ),
                  ),
                if (!paye)
                  SizedBox(
                    width: 300,
                    child: OrButton(
                      label: essaiActif
                          ? 'S\'abonner maintenant : 10 USD / mois'
                          : (essaiExpire ? 'Voir le Studio Live' : 'S\'abonner maintenant : 10 USD / mois'),
                      icone: Icons.workspace_premium_rounded,
                      plein: false,
                      onPressed: onSouscrire,
                    ),
                  ),
                SizedBox(
                  width: 180,
                  child: OrButton(
                    label: 'Guide & tutoriel',
                    icone: Icons.menu_book_rounded,
                    plein: false,
                    onPressed: () => Navigator.pushNamed(context, '/guide'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(Icons.card_giftcard_rounded, size: 13, color: K.or),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    essaiExpire
                        ? 'Votre essai est terminé · aucun prélèvement automatique · abonnement facultatif'
                        : 'Essai 3 jours sans carte · 20 messages IA/jour · Livre Guide après paiement · sans engagement',
                    style: const TextStyle(color: K.faint, fontSize: 10.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const Icon(Icons.lock_outline_rounded, size: 13, color: K.faint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sans engagement · résiliable · paiement sécurisé ${Prix.libelleRoute(pays)}',
                    style: const TextStyle(color: K.faint, fontSize: 10.5),
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

class _BandeauEssai extends StatelessWidget {
  const _BandeauEssai({required this.essai});

  final EssaiStudio essai;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: K.or.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.or.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.card_giftcard_rounded, color: K.or, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Essai gratuit actif · ${essai.joursRestants} jours restants · 20 messages IA/jour · Livre Guide après paiement',
              style: const TextStyle(color: K.text, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/studio/regie'),
            child: const Text('Ma régie', style: TextStyle(color: K.or)),
          ),
        ],
      ),
    );
  }
}

class _BandeauEssaiTermine extends StatelessWidget {
  const _BandeauEssaiTermine({required this.onSouscrire});

  final VoidCallback onSouscrire;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: K.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.timer_off_rounded, color: K.danger, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Votre essai est terminé. Aucun prélèvement automatique n\'a eu lieu.',
              style: TextStyle(color: K.text, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: onSouscrire,
            child: const Text('S\'abonner', style: TextStyle(color: K.or)),
          ),
        ],
      ),
    );
  }
}

class _BandeauActif extends StatelessWidget {
  const _BandeauActif({required this.abonnement});

  final AbonnementStudio abonnement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: K.emeraude.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.emeraude.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.verified_rounded, color: K.emeraude, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Votre Studio Live est actif · ${abonnement.joursRestants} jours restants',
              style: const TextStyle(color: K.text, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/studio/regie'),
            child: const Text('Ma régie', style: TextStyle(color: K.emeraude)),
          ),
        ],
      ),
    );
  }
}

class _VisuelRegie extends StatelessWidget {
  const _VisuelRegie();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: GlassCard(
        padding: EdgeInsets.zero,
        rayon: 26,
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: K.border))),
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
                      'studio live · régie',
                      style: TextStyle(color: K.faint, fontSize: 10.5),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: K.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: K.danger.withValues(alpha: 0.35)),
                    ),
                    child: const Text(
                      '● EN DIRECT',
                      style: TextStyle(
                        color: K.danger,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[Color(0xFF0A1F1A), Color(0xFF101827)],
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: K.direct,
                              boxShadow: <BoxShadow>[
                                BoxShadow(color: K.emeraude.withValues(alpha: 0.28), blurRadius: 24),
                              ],
                            ),
                            child: const Icon(Icons.videocam_rounded, color: K.bg, size: 25),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              _BoutonOutil(icone: Icons.mic_rounded),
                              const SizedBox(width: 7),
                              _BoutonOutil(icone: Icons.videocam_rounded),
                              const SizedBox(width: 7),
                              _BoutonOutil(icone: Icons.screen_share_rounded, actif: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, color: K.border),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Row(
                            children: <Widget>[
                              Icon(Icons.auto_awesome_rounded, size: 13, color: K.emeraude),
                              SizedBox(width: 5),
                              Text(
                                'Chat IA',
                                style: TextStyle(
                                  color: K.emeraude,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          _MiniMessage(
                            texte: 'Quel est le prix de la robe ?',
                            assistant: false,
                          ),
                          _MiniMessage(
                            texte: 'La robe wax est à 9 000 FCFA, livraison offerte aujourd\'hui.',
                            assistant: true,
                          ),
                          _MiniMessage(
                            texte: 'Je prends ! Comment commander ?',
                            assistant: false,
                          ),
                          const Spacer(),
                          const Text(
                            'Réponse copiée en 1 clic pour TikTok.',
                            style: TextStyle(color: K.faint, fontSize: 8.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutonOutil extends StatelessWidget {
  const _BoutonOutil({required this.icone, this.actif = false});

  final IconData icone;
  final bool actif;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: actif ? K.emeraude.withValues(alpha: 0.2) : K.bg.withValues(alpha: 0.62),
        shape: BoxShape.circle,
        border: Border.all(
          color: actif ? K.emeraude.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Icon(icone, size: 14, color: actif ? K.emeraude : K.text),
    );
  }
}

class _MiniMessage extends StatelessWidget {
  const _MiniMessage({required this.texte, required this.assistant});

  final String texte;
  final bool assistant;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: assistant ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: assistant ? K.emeraude.withValues(alpha: 0.09) : K.or.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: assistant ? K.emeraude.withValues(alpha: 0.2) : K.or.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          texte,
          style: const TextStyle(color: K.text, fontSize: 8.5, height: 1.35),
        ),
      ),
    );
  }
}

// ============================================================================
//  AVANTAGES / CONTENU / ÉTAPES
// ============================================================================
class _Avantages extends StatelessWidget {
  const _Avantages();

  @override
  Widget build(BuildContext context) {
    const avantages = <(IconData, String, String, Color)>[
      (
        Icons.tune_rounded,
        'Régie modulaire',
        'Solo ou duo, caméra produits ou partage d\'écran, salle intégrée, TikTok, YouTube, Instagram.',
        K.or,
      ),
      (
        Icons.group_add_rounded,
        'Co-animateur à distance',
        'Un lien unique pour faire monter un partenaire où qu\'il soit dans le monde.',
        K.emeraude,
      ),
      (
        Icons.auto_awesome_rounded,
        'Chat IA commercial',
        'DeepSeek répond aux spectateurs en temps réel avec votre fiche produit, prêt à copier sur TikTok.',
        K.or,
      ),
      (
        Icons.menu_book_rounded,
        'Livre Guide offert',
        'Avec l\'abonnement : un guide personnalisé pour votre métier (accroche, structure, caméra, vente), envoyé par email.',
        K.emeraude,
      ),
    ];

    return Column(
      children: <Widget>[
        const TitreSection(
          surtitre: 'Tout est inclus',
          titre: 'Un vrai studio, sans matériel',
          sousTitre: 'Ce que les créateurs paient ailleurs en plusieurs abonnements, réuni ici pour 10 \$ par mois.',
          centre: true,
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, contraintes) {
            final colonnes = contraintes.maxWidth > 920
                ? 4
                : (contraintes.maxWidth > 560 ? 2 : 1);
            final largeur = (contraintes.maxWidth - (colonnes - 1) * 12) / colonnes;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (final avantage in avantages)
                  SizedBox(
                    width: largeur,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: K.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: K.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: avantage.$4.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: avantage.$4.withValues(alpha: 0.25)),
                            ),
                            child: Icon(avantage.$1, color: avantage.$4, size: 19),
                          ),
                          const SizedBox(height: 13),
                          Text(
                            avantage.$2,
                            style: const TextStyle(
                              color: K.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            avantage.$3,
                            style: const TextStyle(color: K.muted, fontSize: 11, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu();

  @override
  Widget build(BuildContext context) {
    const elements = <String>[
      'Salle de live intégrée e-booklive (Jitsi Meet)',
      'Multistream : TikTok Live, YouTube Live, Instagram Live',
      'Co-animateur à distance via lien d\'invitation unique',
      'Caméra produits ou partage d\'écran de travail',
      'Fiche Produit IA : titre, produits, prix, arguments, lien WhatsApp',
      'Chat Live IA temps réel + bouton Copier en 1 clic',
      'Livre Guide Live personnalisé, offert avec l\'abonnement et envoyé par email',
      'Support par WhatsApp et guide de démarrage pas à pas',
    ];

    return GlassCard(
      padding: const EdgeInsets.all(26),
      child: LayoutBuilder(
        builder: (context, contraintes) {
          final large = contraintes.maxWidth > 700;
          final gauche = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'CE QUE CONTIENT L\'ABONNEMENT',
                style: TextStyle(
                  color: K.emeraude,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tout votre studio,\ndans un seul onglet.',
                style: TextStyle(
                  color: K.text,
                  fontSize: 28,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'La régie est organisée en 3 onglets : Préparer mon Live, Salle en direct '
                'et chat IA, Mon Livre Guide Live.',
                style: TextStyle(color: K.muted, fontSize: 12.5, height: 1.6),
              ),
              const SizedBox(height: 18),
              const Puce(texte: '10 USD / mois', icone: Icons.sell_rounded, couleur: K.emeraude),
            ],
          );
          final droite = Column(
            children: <Widget>[
              for (final element in elements)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_rounded, color: K.emeraude, size: 15),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          element,
                          style: const TextStyle(color: K.text, fontSize: 12, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
          return large
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 4, child: gauche),
                    const SizedBox(width: 30),
                    Expanded(flex: 5, child: droite),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    gauche,
                    const SizedBox(height: 20),
                    droite,
                  ],
                );
        },
      ),
    );
  }
}

class _CommentCaMarche extends StatelessWidget {
  const _CommentCaMarche();

  @override
  Widget build(BuildContext context) {
    const etapes = <(String, String)>[
      ('Abonnez-vous', '10 USD / mois, converti dans votre devise, SasPay ou Paddle.'),
      ('Préparez votre live', 'Choisissez vos plateformes, votre format, votre mode visuel et votre fiche produit.'),
      ('Animez et vendez', 'Ouvrez la salle Jitsi, laissez le chat IA répondre, suivez votre Livre Guide.'),
    ];

    return Column(
      children: <Widget>[
        const TitreSection(
          surtitre: 'En 3 étapes',
          titre: 'De l\'abonnement au premier direct',
          centre: true,
        ),
        const SizedBox(height: 26),
        LayoutBuilder(
          builder: (context, contraintes) {
            final large = contraintes.maxWidth > 720;
            final elements = <Widget>[
              for (var i = 0; i < etapes.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: K.direct,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: K.bg,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        etapes[i].$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: K.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        etapes[i].$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: K.muted, fontSize: 11, height: 1.5),
                      ),
                      if (large) const SizedBox(height: 8),
                    ],
                  ),
                ),
            ];
            return large
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final element in elements) Expanded(child: element),
                    ],
                  )
                : Column(children: elements);
          },
        ),
      ],
    );
  }
}

class _AppelFinal extends StatelessWidget {
  const _AppelFinal({
    required this.onSouscrire,
    required this.onEssai,
    required this.essaiEnCours,
  });

  final VoidCallback onSouscrire;
  final VoidCallback onEssai;
  final bool essaiEnCours;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0B241D), Color(0xFF221C0D)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: K.emeraude.withValues(alpha: 0.32)),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.sensors_rounded, color: K.emeraude, size: 34),
          const SizedBox(height: 14),
          const Text(
            'Votre prochain live mérite une vraie régie.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: K.text,
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Essayez 3 jours gratuitement, sans carte. Puis 10 \$ par mois, sans engagement. '
            'Livre Guide offert dès l\'abonnement.',
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
                width: 270,
                child: OrButton(
                  label: 'Essayer gratuitement 3 jours',
                  icone: Icons.card_giftcard_rounded,
                  chargement: essaiEnCours,
                  onPressed: essaiEnCours ? null : onEssai,
                ),
              ),
              SizedBox(
                width: 280,
                child: OrButton(
                  label: 'S\'abonner maintenant : 10 USD / mois',
                  icone: Icons.workspace_premium_rounded,
                  plein: false,
                  onPressed: onSouscrire,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Déjà abonné ? Ouvrez votre régie depuis le menu Compte.',
            style: TextStyle(color: K.faint, fontSize: 10),
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
        const SizedBox(height: 16),
        const WordmarkEbooklive(taille: 18),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/guide'),
              child: const Text('Guide & Tutoriel', style: TextStyle(color: K.muted, fontSize: 11.5)),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/boutique'),
              child: const Text('La Boutique', style: TextStyle(color: K.muted, fontSize: 11.5)),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/cgv'),
              child: const Text('CGV', style: TextStyle(color: K.muted, fontSize: 11.5)),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/faq'),
              child: const Text('FAQ', style: TextStyle(color: K.muted, fontSize: 11.5)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '© ${DateTime.now().year} e-booklive · ${AppConfig.emailSupport}',
          style: const TextStyle(color: K.faint, fontSize: 10),
        ),
      ],
    );
  }
}

// ============================================================================
//  FEUILLE DE SOUSCRIPTION
// ============================================================================
class _SouscriptionSheet extends StatefulWidget {
  const _SouscriptionSheet();

  @override
  State<_SouscriptionSheet> createState() => _SouscriptionSheetState();
}

class _SouscriptionSheetState extends State<_SouscriptionSheet> {
  final TextEditingController _nom = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _whatsapp = TextEditingController();
  String _metierCode = 'ecommerce';
  bool _chargement = false;

  @override
  void initState() {
    super.initState();
    try {
      _email.text = Supabase.instance.client.auth.currentUser?.email ?? '';
    } catch (_) {}
  }

  @override
  void dispose() {
    _nom.dispose();
    _email.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _payer() async {
    if (_nom.text.trim().length < 3) {
      _erreur('Indiquez le nom de votre activité.');
      return;
    }
    final chiffres = _whatsapp.text.replaceAll(RegExp(r'\D'), '');
    if (chiffres.length < 6) {
      _erreur('Indiquez un numéro WhatsApp valide.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(_email.text.trim())) {
      _erreur('Indiquez un email valide pour recevoir votre guide.');
      return;
    }

    final pays = CountryStore.pays.value;
    final fournisseur = Prix.fournisseur(pays);
    final secteur = secteurParCode(_metierCode) ?? secteurs.first;

    setState(() => _chargement = true);
    try {
      final checkout = await ApiService.creerCheckoutStudio(
        nomActivite: _nom.text.trim(),
        metierCode: secteur.code,
        metierLabel: secteur.label,
        paysCode: pays.code,
        whatsapp: chiffres,
        email: _email.text.trim(),
        fournisseur: fournisseur,
      );
      if (!mounted) return;
      setState(() => _chargement = false);

      final navigator = Navigator.of(context);
      final ouvert = await lancerCheckout(context, checkout);
      if (!mounted) return;
      if (!ouvert) {
        _erreur(
          'Le paiement n\'a pas pu être ouvert. Vérifiez votre connexion ou écrivez-nous sur WhatsApp.',
        );
        return;
      }
      navigator.pop(true);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => PaiementEnAttentePage(
            checkout: checkout,
            nomProjet: _nom.text.trim(),
            metier: secteur.label,
            email: _email.text.trim(),
          ),
        ),
      );
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _chargement = false);
      _erreur(erreur is ApiException ? erreur.message : 'Paiement indisponible pour le moment.');
    }
  }

  void _erreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bas = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bas),
      child: Container(
        decoration: const BoxDecoration(
          color: K.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: K.borderLight)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const LogoEbooklive(size: 34),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Studio Live — 1 mois',
                                style: TextStyle(
                                  color: K.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Régie, co-animateur, chat IA, Livre Guide offert',
                                style: TextStyle(color: K.faint, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: K.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<PaysMonde>(
                      valueListenable: CountryStore.pays,
                      builder: (context, pays, _) {
                        final devis = Prix.devisStudio(pays);
                        return Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: K.emeraude.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: K.emeraude.withValues(alpha: 0.22)),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      devis.devise == 'USD' ? '10,00 \$' : devis.principal,
                                      style: const TextStyle(
                                        color: K.emeraudeSoft,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      '${pays.nom} · ${Prix.libelleRoute(pays)}',
                                      style: const TextStyle(color: K.faint, fontSize: 9.5),
                                    ),
                                  ],
                                ),
                              ),
                              const PaysSelector(compact: true),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nom,
                      style: const TextStyle(color: K.text),
                      decoration: champ(
                        label: 'Nom de votre activité',
                        hint: 'Ex : Studio Beauté Awa',
                        icone: Icons.storefront_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _metierCode,
                      dropdownColor: K.surface,
                      style: const TextStyle(color: K.text, fontSize: 13),
                      decoration: champ(label: 'Votre métier', icone: Icons.grid_view_rounded),
                      items: <DropdownMenuItem<String>>[
                        for (final secteur in secteurs)
                          DropdownMenuItem<String>(
                            value: secteur.code,
                            child: Text(
                              '${secteur.emoji}  ${secteur.label}',
                              style: const TextStyle(color: K.text, fontSize: 13),
                            ),
                          ),
                      ],
                      onChanged: (valeur) {
                        if (valeur != null) setState(() => _metierCode = valeur);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: K.text),
                      decoration: champ(
                        label: 'Email',
                        hint: 'vous@email.com',
                        icone: Icons.alternate_email_rounded,
                        helper: 'Utilisez le même email que votre compte e-booklive pour accéder à la régie.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _whatsapp,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: K.text),
                      decoration: champ(
                        label: 'Numéro WhatsApp',
                        icone: Icons.chat_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OrButton(
                      label: 'Payer 10 \$ — activer mon studio',
                      icone: Icons.lock_rounded,
                      chargement: _chargement,
                      hauteur: 52,
                      onPressed: _chargement ? null : _payer,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'En continuant, vous acceptez les CGV. Le guide est généré et envoyé '
                      'par email dès confirmation du paiement.',
                      style: TextStyle(color: K.faint, fontSize: 9.5, height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  PAGE D'ACTIVATION APRÈS RETOUR PAIEMENT (?abonnement=<id>)
// ============================================================================
class _StudioActivationPage extends StatefulWidget {
  const _StudioActivationPage({required this.subscriptionId});

  final String subscriptionId;

  @override
  State<_StudioActivationPage> createState() => _StudioActivationPageState();
}

class _StudioActivationPageState extends State<_StudioActivationPage> {
  Timer? _minuteur;
  bool _verification = false;
  AbonnementStudio? _abonnement;
  GuideLive? _guide;
  String? _message;

  @override
  void initState() {
    super.initState();
    _verifier();
    _minuteur = Timer.periodic(const Duration(seconds: 5), (_) => _verifier());
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _verifier() async {
    if (_verification) return;
    setState(() => _verification = true);
    try {
      final resultat = await ApiService.verifierPaiement(
        subscriptionId: widget.subscriptionId,
      );
      if (!mounted) return;
      setState(() {
        _abonnement = resultat.abonnement ?? _abonnement;
        _guide = resultat.guide ?? _guide;
        _message = resultat.message;
        _verification = false;
      });
      if (_abonnement?.estActif == true) _minuteur?.cancel();
    } catch (_) {
      if (!mounted) return;
      setState(() => _verification = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actif = _abonnement?.estActif == true;

    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: GlassCard(
                  miseEnAvant: true,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: <Widget>[
                      const LogoEbooklive(size: 56),
                      const SizedBox(height: 18),
                      Text(
                        actif ? 'Votre Studio Live est actif' : 'Activation en cours',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: K.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        actif
                            ? 'Votre abonnement de 30 jours est ouvert. Votre Livre Guide est en cours de rédaction et arrive par email.'
                            : 'Nous vérifions votre paiement. Cette page se met à jour automatiquement.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: K.muted, fontSize: 12.5, height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      if (_abonnement != null)
                        Text(
                          _abonnement!.libelleStatut,
                          style: TextStyle(
                            color: actif ? K.emeraude : K.or,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (_guide?.estPret == true) ...<Widget>[
                        const SizedBox(height: 8),
                        const Text(
                          'Votre Livre Guide est prêt.',
                          style: TextStyle(color: K.emeraude, fontSize: 12),
                        ),
                      ],
                      if (_message != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: K.faint, fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 22),
                      if (!actif) const CircularProgressIndicator(color: K.or),
                      if (actif) ...<Widget>[
                        OrButton(
                          label: 'Ouvrir ma régie',
                          icone: Icons.sensors_rounded,
                          onPressed: () =>
                              Navigator.pushNamedAndRemoveUntil(context, '/studio/regie', (r) => false),
                        ),
                        const SizedBox(height: 10),
                        OrButton(
                          label: 'Aller à mon espace',
                          plein: false,
                          onPressed: () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/mon-espace',
                            (r) => false,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      const AideWhatsApp(pleinLargeur: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
