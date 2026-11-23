import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../widgets/site_assistant_chat.dart';
import '../widgets/whatsapp.dart';
import 'paiement_en_attente_page.dart';

/// ============================================================================
///  LA BOUTIQUE — parcours en 2 étapes
///   1. Votre secteur (8 métiers + « Autre métier »)
///   2. Votre kit, votre pays, votre paiement (SasPay ou Paddle)
/// ============================================================================
class BoutiquePage extends StatefulWidget {
  const BoutiquePage({super.key, this.metierInitial, this.offreInitiale});

  final String? metierInitial;
  final String? offreInitiale;

  @override
  State<BoutiquePage> createState() => _BoutiquePageState();
}

class _BoutiquePageState extends State<BoutiquePage> {
  final TextEditingController _autre = TextEditingController();
  final TextEditingController _nomProjet = TextEditingController();
  final TextEditingController _whatsapp = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _precisions = TextEditingController();
  final ScrollController _defilement = ScrollController();

  int _etape = 0;
  Secteur? _secteur;
  Offre _offre = offres.last;
  bool _chargement = false;

  @override
  void initState() {
    super.initState();
    if (widget.metierInitial != null) {
      _secteur = secteurParCode(widget.metierInitial) ??
          secteurs.firstWhere(
            (s) => s.label.toLowerCase().contains(widget.metierInitial!.toLowerCase()),
            orElse: () => secteurs.first,
          );
      if (_secteur?.code == 'autre') _autre.text = widget.metierInitial!;
    }
    if (widget.offreInitiale != null) {
      _offre = offres.firstWhere(
        (offre) => offre.apiType == widget.offreInitiale,
        orElse: () => offres.last,
      );
    }
  }

  @override
  void dispose() {
    _autre.dispose();
    _nomProjet.dispose();
    _whatsapp.dispose();
    _email.dispose();
    _precisions.dispose();
    _defilement.dispose();
    super.dispose();
  }

  String get _metierLabel {
    if (_secteur == null) return '';
    if (_secteur!.code == 'autre') return _autre.text.trim();
    return _secteur!.label;
  }

  bool get _etape1Valide {
    if (_secteur == null) return false;
    if (_secteur!.code == 'autre') return _autre.text.trim().length >= 3;
    return true;
  }

  void _allerEtape(int etape) {
    setState(() => _etape = etape);
    if (_defilement.hasClients) {
      _defilement.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  void _toast(String message, {Color couleur = K.or}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: couleur == K.or ? null : couleur),
    );
  }

  Future<void> _payer() async {
    if (_secteur == null) {
      _toast('Choisissez d\'abord votre secteur.');
      return;
    }
    if (_nomProjet.text.trim().length < 3) {
      _toast('Renseignez le nom de votre projet (3 caractères minimum).');
      return;
    }
    final chiffres = _whatsapp.text.replaceAll(RegExp(r'\D'), '');
    if (chiffres.length < 6) {
      _toast('Renseignez un numéro WhatsApp valide.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(_email.text.trim())) {
      _toast('Renseignez un email valide pour recevoir votre kit.');
      return;
    }

    final pays = CountryStore.pays.value;
    final fournisseur = Prix.fournisseur(pays);
    setState(() => _chargement = true);

    try {
      final checkout = await ApiService.creerCheckoutKit(
        metierCode: _secteur!.code,
        metierLabel: _metierLabel,
        nomProjet: _nomProjet.text.trim(),
        paysCode: pays.code,
        whatsapp: chiffres,
        email: _email.text.trim(),
        produitType: _offre.apiType,
        fournisseur: fournisseur,
        precisions: _precisions.text.trim(),
      );

      if (!mounted) return;
      setState(() => _chargement = false);

      final ouvert = await lancerCheckout(context, checkout);
      if (!mounted) return;
      if (!ouvert) {
        _toast(
          'Le paiement n\'a pas pu être ouvert. Réessayez ou contactez-nous sur WhatsApp.',
          couleur: K.danger,
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PaiementEnAttentePage(
            checkout: checkout,
            nomProjet: _nomProjet.text.trim(),
            metier: _metierLabel,
            email: _email.text.trim(),
          ),
        ),
      );
      if (!mounted) return;
      setState(() => _chargement = false);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _chargement = false);
      _toast(
        erreur is ApiException ? erreur.message : 'Paiement indisponible pour le moment.',
        couleur: K.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            controller: _defilement,
            child: Column(
              children: <Widget>[
                const AppHeader(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _enTete(),
                          const SizedBox(height: 22),
                          _indicateurEtapes(),
                          const SizedBox(height: 28),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            child: _etape == 0
                                ? _etapeSecteur(key: const ValueKey<int>(0))
                                : _etapeKit(key: const ValueKey<int>(1)),
                          ),
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

  Widget _enTete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (_etape == 1)
              IconButton(
                tooltip: 'Retour',
                onPressed: () => _allerEtape(0),
                icon: const Icon(Icons.arrow_back_rounded, color: K.muted),
              ),
            Flexible(
              child: Text(
                _etape == 0 ? 'La Boutique' : 'Votre kit sur mesure',
                style: const TextStyle(
                  color: K.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Deux étapes suffisent. Le reste — livre stratégique, prompts IA, tableau '
          'de gestion — est rédigé pour votre métier et votre pays.',
          style: TextStyle(color: K.muted, fontSize: 13.5, height: 1.6),
        ),
      ],
    );
  }

  Widget _indicateurEtapes() {
    return Row(
      children: <Widget>[
        _PastilleEtape(
          numero: '1',
          label: 'Votre secteur',
          actif: _etape == 0,
          fait: _etape > 0,
          onTap: () => _allerEtape(0),
        ),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: _etape > 0 ? K.or.withValues(alpha: 0.5) : K.border,
          ),
        ),
        _PastilleEtape(
          numero: '2',
          label: 'Kit & paiement',
          actif: _etape == 1,
          fait: false,
          onTap: _etape1Valide ? () => _allerEtape(1) : null,
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  //  ÉTAPE 1 — SECTEUR
  // --------------------------------------------------------------------------
  Widget _etapeSecteur({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Text(
              'Quel est votre métier ?',
              style: TextStyle(
                color: K.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(width: 8),
            Puce(texte: '1 choix', icone: Icons.touch_app_rounded),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Le kit est écrit pour votre secteur réel, pas pour un business générique.',
          style: TextStyle(color: K.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, contraintes) {
            final colonnes = contraintes.maxWidth > 900
                ? 3
                : (contraintes.maxWidth > 560 ? 2 : 1);
            final largeur = (contraintes.maxWidth - (colonnes - 1) * 12) / colonnes;
            final tous = <Secteur>[...secteurs, secteurAutre];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (final secteur in tous)
                  SizedBox(
                    width: largeur,
                    child: _CarteSecteur(
                      secteur: secteur,
                      selectionne: _secteur?.code == secteur.code,
                      onTap: () => setState(() => _secteur = secteur),
                    ),
                  ),
              ],
            );
          },
        ),
        if (_secteur?.code == 'autre') ...<Widget>[
          const SizedBox(height: 16),
          TextField(
            controller: _autre,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: K.text),
            decoration: champ(
              label: 'Écrivez votre activité',
              hint: 'Ex : location de matériel photo à Abidjan',
              icone: Icons.edit_note_rounded,
              helper: 'Soyez précis : le kit sera rédigé pour cette activité.',
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            if (_secteur != null) ...<Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.check_circle_rounded, color: K.emeraude, size: 17),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _secteur!.code == 'autre' ? _autre.text.trim() : _secteur!.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: K.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 240,
                child: OrButton(
                  label: 'Continuer',
                  icone: Icons.arrow_forward_rounded,
                  onPressed: _etape1Valide ? () => _allerEtape(1) : null,
                ),
              ),
            ] else
              Expanded(
                child: OrButton(
                  label: 'Continuer',
                  icone: Icons.arrow_forward_rounded,
                  onPressed: null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Un doute ? Choisissez « Autre métier » et décrivez votre activité en une phrase.',
          style: TextStyle(color: K.faint, fontSize: 10.5),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  //  ÉTAPE 2 — KIT, PAYS, PAIEMENT
  // --------------------------------------------------------------------------
  Widget _etapeKit({Key? key}) {
    return LayoutBuilder(
      key: key,
      builder: (context, contraintes) {
        final large = contraintes.maxWidth > 900;
        final gauche = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _rappelSecteur(),
            const SizedBox(height: 24),
            const Text(
              'Choisissez votre kit',
              style: TextStyle(
                color: K.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Un paiement unique. Aucun abonnement. Tout est livré immédiatement.',
              style: TextStyle(color: K.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            _grilleKits(),
            const SizedBox(height: 26),
            const Text(
              'Votre pays',
              style: TextStyle(
                color: K.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _cartePays(),
            const SizedBox(height: 24),
            const Text(
              'Vos coordonnées',
              style: TextStyle(
                color: K.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _formulaire(),
          ],
        );

        if (!large) {
          return Column(
            children: <Widget>[
              gauche,
              const SizedBox(height: 22),
              _recapitulatif(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 7, child: gauche),
            const SizedBox(width: 22),
            SizedBox(width: 350, child: _recapitulatif()),
          ],
        );
      },
    );
  }

  Widget _rappelSecteur() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: K.or.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: K.or.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: <Widget>[
          Text(_secteur?.emoji ?? '✨', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'VOTRE SECTEUR',
                  style: TextStyle(
                    color: K.or,
                    fontSize: 9,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _metierLabel,
                  style: const TextStyle(
                    color: K.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _allerEtape(0),
            child: const Text('Modifier', style: TextStyle(color: K.muted, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _grilleKits() {
    return ValueListenableBuilder<PaysMonde>(
      valueListenable: CountryStore.pays,
      builder: (context, pays, _) {
        return LayoutBuilder(
          builder: (context, contraintes) {
            final colonnes = contraintes.maxWidth > 720 ? 2 : 1;
            final largeur = (contraintes.maxWidth - (colonnes - 1) * 11) / colonnes;
            return Wrap(
              spacing: 11,
              runSpacing: 11,
              children: <Widget>[
                for (final offre in offres)
                  SizedBox(
                    width: largeur,
                    child: _CarteKit(
                      offre: offre,
                      pays: pays,
                      selectionne: _offre.apiType == offre.apiType,
                      onTap: () => setState(() => _offre = offre),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _cartePays() {
    return ValueListenableBuilder<PaysMonde>(
      valueListenable: CountryStore.pays,
      builder: (context, pays, _) {
        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(pays.drapeau, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          pays.nom,
                          style: const TextStyle(
                            color: K.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${pays.devise} · ${pays.indicatif}',
                          style: const TextStyle(color: K.faint, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  BadgeFournisseur(nom: pays.viaSasPay ? 'SasPay' : 'Paddle'),
                  const SizedBox(width: 10),
                  PaysSelector(compact: true),
                ],
              ),
              const SizedBox(height: 12),
              RoutePaiementBandeau(pays: pays, compact: true),
            ],
          ),
        );
      },
    );
  }

  Widget _formulaire() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _nomProjet,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: K.text),
            decoration: champ(
              label: 'Nom de votre projet',
              hint: 'Ex : Maquis Le Baobab',
              icone: Icons.storefront_rounded,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<PaysMonde>(
            valueListenable: CountryStore.pays,
            builder: (context, pays, _) {
              return TextField(
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: K.text),
                decoration: champ(
                  label: 'Numéro WhatsApp',
                  hint: 'Votre numéro de contact',
                  icone: Icons.chat_rounded,
                  suffixe: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        pays.indicatif,
                        style: const TextStyle(
                          color: K.or,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: K.text),
            decoration: champ(
              label: 'Email de livraison',
              hint: 'vous@email.com',
              icone: Icons.alternate_email_rounded,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _precisions,
            maxLines: 3,
            maxLength: 800,
            style: const TextStyle(color: K.text),
            decoration: champ(
              label: 'Précisions (optionnel)',
              hint: 'Vos produits, vos prix, votre clientèle…',
              icone: Icons.notes_rounded,
              multiligne: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recapitulatif() {
    return ValueListenableBuilder<PaysMonde>(
      valueListenable: CountryStore.pays,
      builder: (context, pays, _) {
        final devis = Prix.devisKit(_offre.prix, pays);
        final fournisseur = Prix.fournisseur(pays);

        return GlassCard(
          miseEnAvant: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.receipt_long_rounded, color: K.or, size: 19),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Récapitulatif',
                      style: TextStyle(
                        color: K.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  BadgeFournisseur(
                    nom: fournisseur.libelle,
                    actif: fournisseur == Fournisseur.sasPay,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _LigneRecap(_offre.titre, 'Kit'),
              _LigneRecap(_metierLabel, 'Secteur'),
              _LigneRecap('${pays.drapeau} ${pays.nom}', 'Pays'),
              const Divider(height: 24, color: K.border),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(
                        color: K.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        devis.principal,
                        style: const TextStyle(
                          color: K.orSoft,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      if (devis.indicatif != null)
                        Text(
                          devis.indicatif!,
                          style: const TextStyle(color: K.faint, fontSize: 10),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Paiement unique · TVA incluse · aucun abonnement',
                style: TextStyle(color: K.faint, fontSize: 9.5),
              ),
              const SizedBox(height: 16),
              OrButton(
                label: 'Payer avec ${fournisseur.libelle}',
                icone: Icons.lock_rounded,
                chargement: _chargement,
                hauteur: 52,
                onPressed: _chargement ? null : _payer,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.shield_rounded, color: K.emeraude, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      Prix.explicationRoute(pays),
                      style: const TextStyle(color: K.faint, fontSize: 9.5, height: 1.45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.mail_rounded, color: K.or, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Livraison immédiate par email (Resend) et liens affichés à l\'écran.',
                      style: TextStyle(
                        color: K.faint.withValues(alpha: 0.95),
                        fontSize: 9.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const AideWhatsApp(pleinLargeur: true),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
//  SOUS-WIDGETS
// ============================================================================
class _PastilleEtape extends StatelessWidget {
  const _PastilleEtape({
    required this.numero,
    required this.label,
    required this.actif,
    required this.fait,
    this.onTap,
  });

  final String numero;
  final String label;
  final bool actif;
  final bool fait;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final couleur = fait || actif ? K.or : K.faint;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fait
                    ? K.or
                    : actif
                        ? K.or.withValues(alpha: 0.14)
                        : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: couleur.withValues(alpha: 0.6)),
              ),
              child: fait
                  ? const Icon(Icons.check_rounded, size: 16, color: K.bg)
                  : Text(
                      numero,
                      style: TextStyle(
                        color: actif ? K.or : K.faint,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: actif || fait ? K.text : K.faint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteSecteur extends StatefulWidget {
  const _CarteSecteur({
    required this.secteur,
    required this.selectionne,
    required this.onTap,
  });

  final Secteur secteur;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  State<_CarteSecteur> createState() => _CarteSecteurState();
}

class _CarteSecteurState extends State<_CarteSecteur> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _survol = true),
      onExit: (_) => setState(() => _survol = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.selectionne
                ? K.or.withValues(alpha: 0.09)
                : K.surface.withValues(alpha: _survol ? 0.72 : 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.selectionne
                  ? K.or.withValues(alpha: 0.65)
                  : _survol
                      ? K.borderLight
                      : K.border,
              width: widget.selectionne ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(widget.secteur.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.secteur.label,
                      style: const TextStyle(
                        color: K.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.secteur.description,
                      style: const TextStyle(color: K.muted, fontSize: 10.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                widget.selectionne
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: widget.selectionne ? K.or : K.borderLight,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarteKit extends StatelessWidget {
  const _CarteKit({
    required this.offre,
    required this.pays,
    required this.selectionne,
    required this.onTap,
  });

  final Offre offre;
  final PaysMonde pays;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final devis = Prix.devisKit(offre.prix, pays);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selectionne ? K.or.withValues(alpha: 0.08) : K.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selectionne ? K.or.withValues(alpha: 0.7) : K.border,
              width: selectionne ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(offre.icone, color: K.or, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      offre.titre,
                      style: const TextStyle(
                        color: K.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (selectionne)
                    const Icon(Icons.check_circle_rounded, color: K.or, size: 17),
                ],
              ),
              if (offre.populaire) ...<Widget>[
                const SizedBox(height: 6),
                const Text(
                  'LE PLUS CHOISI',
                  style: TextStyle(
                    color: K.or,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
              const SizedBox(height: 9),
              Text(
                offre.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: K.muted, fontSize: 10.5, height: 1.4),
              ),
              const SizedBox(height: 9),
              Text(
                devis.principal,
                style: const TextStyle(
                  color: K.orSoft,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              if (devis.indicatif != null)
                Text(
                  devis.indicatif!,
                  style: const TextStyle(color: K.faint, fontSize: 9),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LigneRecap extends StatelessWidget {
  const _LigneRecap(this.valeur, this.libelle);

  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 66,
            child: Text(libelle, style: const TextStyle(color: K.faint, fontSize: 10.5)),
          ),
          Expanded(
            child: Text(
              valeur,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: K.text,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
