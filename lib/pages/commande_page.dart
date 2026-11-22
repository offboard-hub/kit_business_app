import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/links.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../widgets/app_header.dart';
import '../widgets/whatsapp.dart';
import 'confirmation_page.dart';

/// ============================================================================
///  TUNNEL DE COMMANDE — sélection visuelle du kit métier, de l'offre,
///  puis coordonnées (nom du projet, pays, WhatsApp, précisions).
/// ============================================================================
class CommandePage extends StatefulWidget {
  const CommandePage({super.key, this.metierInitial, this.offreInitiale});

  final String? metierInitial;
  final String? offreInitiale;

  @override
  State<CommandePage> createState() => _CommandePageState();
}

class _CommandePageState extends State<CommandePage> {
  final _nomProjet = TextEditingController();
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  final _precisions = TextEditingController();

  String? _metierCode;
  Offre _offre = offres.last;
  Pays _pays = paysAfricains.first;
  bool _chargement = false;

  @override
  void initState() {
    super.initState();
    _metierCode = widget.metierInitial;
    if (widget.offreInitiale != null) {
      _offre = offres.firstWhere(
        (offre) => offre.apiType == widget.offreInitiale,
        orElse: () => offres.last,
      );
    }
  }

  @override
  void dispose() {
    _nomProjet.dispose();
    _whatsapp.dispose();
    _email.dispose();
    _precisions.dispose();
    super.dispose();
  }

  void _toast(String message, {Color couleur = K.clay}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: couleur,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _payer() async {
    if (_metierCode == null) {
      _toast('Choisissez d\'abord votre métier.');
      return;
    }
    if (_nomProjet.text.trim().length < 3) {
      _toast('Renseignez le nom de votre projet.');
      return;
    }
    final chiffres = _whatsapp.text.replaceAll(RegExp(r'\D'), '');
    if (chiffres.length < 6) {
      _toast('Renseignez un numéro WhatsApp valide.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(_email.text.trim())) {
      _toast('Renseignez un email valide pour recevoir vos liens.');
      return;
    }

    setState(() => _chargement = true);

    try {
      final checkout = await ApiService.creerPaiement(
        metierCode: _metierCode!,
        nomProjet: _nomProjet.text.trim(),
        paysCode: _pays.code,
        whatsapp: chiffres,
        email: _email.text.trim(),
        produitType: _offre.apiType,
        precisions: _precisions.text.trim(),
      );

      // Email d'accueil informatif (sans lien de confirmation), en arrière-plan.
      unawaited(ApiService.envoyerEmailAccueil(_email.text.trim(), source: 'commande'));

      if (!mounted) return;
      setState(() => _chargement = false);

      final ouvert = await ouvrirLien(checkout.checkoutUrl);
      if (!mounted) return;

      if (!ouvert) {
        await _afficherLienSecours(checkout.checkoutUrl);
        if (!mounted) return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaiementEnAttentePage(
            checkout: checkout,
            nomProjet: _nomProjet.text.trim(),
            metier: kitParCode(_metierCode!).label,
            email: _email.text.trim(),
          ),
        ),
      );
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _chargement = false);
      _toast(erreur is ApiException ? erreur.message : 'Paiement indisponible pour le moment.',
          couleur: K.danger);
    }
  }

  Future<void> _afficherLienSecours(String url) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: K.night,
        title: const Text('Finaliser le paiement', style: TextStyle(color: K.sand)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Votre navigateur a bloqué l\'ouverture de la page SasPay. Ouvrez ce lien :',
              style: TextStyle(color: K.mist, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SelectableText(url, style: const TextStyle(color: K.gold, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: K.mist)),
          ),
          ElevatedButton(
            onPressed: () => ouvrirLienAvecRetour(context, url),
            style: ElevatedButton.styleFrom(backgroundColor: K.gold),
            child: const Text('Ouvrir', style: TextStyle(color: K.night)),
          ),
        ],
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
                    constraints: const BoxConstraints(maxWidth: 940),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.maybePop(context),
                                icon: const Icon(Icons.arrow_back_rounded, color: K.mist),
                              ),
                              const Flexible(
                                child: Text(
                                  'Composer mon kit',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: K.sand, fontSize: 22, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Trois choix suffisent. Tout le reste est rédigé pour vous, en FCFA et pour votre pays.',
                            style: TextStyle(color: K.mist, fontSize: 13.5, height: 1.5),
                          ),
                          const SizedBox(height: 24),
                          _etapeTitre('1', 'Votre métier', 'Le kit est écrit pour votre secteur réel.'),
                          const SizedBox(height: 14),
                          _grilleMetiers(),
                          const SizedBox(height: 30),
                          _etapeTitre('2', 'Votre offre', 'Un paiement unique, aucun abonnement.'),
                          const SizedBox(height: 14),
                          _grilleOffres(),
                          const SizedBox(height: 30),
                          _etapeTitre('3', 'Vos coordonnées', 'Pour recevoir votre kit par email et retrouver vos liens.'),
                          const SizedBox(height: 14),
                          _formulaire(),
                          const SizedBox(height: 26),
                          _recapitulatif(),
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
    );
  }

  Widget _etapeTitre(String numero, String titre, String sousTitre) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: K.gold, shape: BoxShape.circle),
          child: Text(numero, style: const TextStyle(color: K.night, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: const TextStyle(color: K.sand, fontSize: 17, fontWeight: FontWeight.w800)),
              Text(sousTitre, style: const TextStyle(color: K.mist, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grilleMetiers() {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final colonnes = contraintes.maxWidth > 700 ? 3 : (contraintes.maxWidth > 460 ? 2 : 1);
        final largeur = (contraintes.maxWidth - (colonnes - 1) * 12) / colonnes;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final kit in kitsMetiers)
              SizedBox(
                width: largeur,
                child: _carteMetier(kit, selectionne: _metierCode == kit.code),
              ),
          ],
        );
      },
    );
  }

  Widget _carteMetier(KitMetier kit, {required bool selectionne}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _metierCode = kit.code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selectionne ? K.gold.withValues(alpha: 0.12) : K.night.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectionne ? K.gold : K.gold.withValues(alpha: 0.2),
            width: selectionne ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(kit.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kit.label,
                    style: const TextStyle(color: K.sand, fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ),
                if (selectionne) const Icon(Icons.check_circle_rounded, color: K.gold, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              kit.promesse,
              style: const TextStyle(color: K.mist, fontSize: 11.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grilleOffres() {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final colonnes = contraintes.maxWidth > 820 ? 4 : (contraintes.maxWidth > 480 ? 2 : 1);
        final largeur = (contraintes.maxWidth - (colonnes - 1) * 12) / colonnes;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final offre in offres)
              SizedBox(
                width: largeur,
                child: _carteOffre(offre, selectionnee: _offre.type == offre.type),
              ),
          ],
        );
      },
    );
  }

  Widget _carteOffre(Offre offre, {required bool selectionnee}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _offre = offre),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selectionnee ? K.gold.withValues(alpha: 0.12) : K.night.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectionnee ? K.gold : K.gold.withValues(alpha: 0.2),
            width: selectionnee ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(offre.icone, color: K.gold, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offre.titre,
                    style: const TextStyle(color: K.sand, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ],
            ),
            if (offre.populaire)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'LE PLUS CHOISI',
                  style: TextStyle(color: K.gold, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              AppConfig.fcfa(offre.prix),
              style: const TextStyle(color: K.goldSoft, fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              offre.description,
              style: const TextStyle(color: K.mist, fontSize: 11, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulaire() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          TextField(
            controller: _nomProjet,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: K.sand),
            decoration: champ(
              label: 'Nom de votre projet',
              hint: 'Ex : Maquis Le Baobab',
              icone: Icons.storefront_rounded,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: K.deep.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: K.gold.withValues(alpha: 0.18)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Pays>(
                value: _pays,
                isExpanded: true,
                dropdownColor: K.night,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: K.mist),
                items: [
                  for (final pays in paysAfricains)
                    DropdownMenuItem<Pays>(
                      value: pays,
                      child: Text(
                        '${pays.drapeau}  ${pays.nom}  (${pays.indicatif})',
                        style: const TextStyle(color: K.sand, fontSize: 14),
                      ),
                    ),
                ],
                onChanged: (pays) {
                  if (pays != null) setState(() => _pays = pays);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: K.sand),
            decoration: champ(
              label: 'Numéro WhatsApp (contact)',
              hint: 'Ex : 07 00 00 00 00',
              icone: Icons.chat_rounded,
              suffixe: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    _pays.indicatif,
                    style: const TextStyle(color: K.gold, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: K.sand),
            decoration: champ(
              label: 'Email',
              hint: 'vous@email.com',
              icone: Icons.alternate_email_rounded,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _precisions,
            maxLines: 3,
            maxLength: 1000,
            style: const TextStyle(color: K.sand),
            decoration: champ(
              label: 'Précisions supplémentaires (optionnel)',
              hint: 'Ex : je vends surtout le soir, budget de départ 300 000 FCFA…',
              icone: Icons.notes_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recapitulatif() {
    final kit = _metierCode == null ? null : kitParCode(_metierCode!);

    return GlassCard(
      miseEnAvant: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Récapitulatif',
            style: TextStyle(color: K.sand, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _ligneRecap('Kit métier', kit?.label ?? 'À sélectionner'),
          _ligneRecap('Offre', '${_offre.titre} · ${_offre.prixAffiche}'),
          _ligneRecap('Pays', '${_pays.drapeau} ${_pays.nom}'),
          _ligneRecap(
            'WhatsApp',
            _whatsapp.text.trim().isEmpty ? '${_pays.indicatif} …' : '${_pays.indicatif} ${_whatsapp.text.trim()}',
          ),
          const Divider(height: 26, color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Total à payer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: K.sand, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    AppConfig.fcfa(_offre.prix),
                    style: const TextStyle(color: K.goldSoft, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OrButton(
            label: 'Payer avec SasPay',
            icone: Icons.lock_rounded,
            chargement: _chargement,
            hauteur: 54,
            onPressed: _payer,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: K.green, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Paiement sécurisé par SasPay (mobile money ou carte). Aucune donnée bancaire ne transite par nos serveurs.',
                  style: TextStyle(color: K.mist.withValues(alpha: 0.9), fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.send_rounded, color: K.gold, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Livraison automatique par email dès confirmation du paiement, avec vos liens affichés immédiatement à l\'écran.',
                  style: TextStyle(color: K.mist.withValues(alpha: 0.9), fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const AideWhatsApp(pleinLargeur: true),
        ],
      ),
    );
  }

  Widget _ligneRecap(String libelle, String valeur) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(libelle, style: const TextStyle(color: K.mist, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(
              valeur,
              style: const TextStyle(color: K.sand, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
///  PAGE D'ATTENTE — vérifie le paiement SasPay puis affiche la livraison.
/// ============================================================================
class PaiementEnAttentePage extends StatefulWidget {
  const PaiementEnAttentePage({
    super.key,
    required this.checkout,
    required this.nomProjet,
    required this.metier,
    required this.email,
  });

  final CheckoutCree checkout;
  final String nomProjet;
  final String metier;
  final String email;

  @override
  State<PaiementEnAttentePage> createState() => _PaiementEnAttentePageState();
}

class _PaiementEnAttentePageState extends State<PaiementEnAttentePage> {
  Timer? _minuteur;
  int _tentatives = 0;
  bool _verification = false;
  String? _message;

  static const int _maxTentatives = 30;

  @override
  void initState() {
    super.initState();
    _minuteur = Timer.periodic(const Duration(seconds: 6), (_) => _verifier(silencieux: true));
    Future<void>.delayed(const Duration(seconds: 2), () => _verifier(silencieux: true));
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _verifier({bool silencieux = false}) async {
    if (_verification) return;
    if (_tentatives >= _maxTentatives) {
      _minuteur?.cancel();
      if (!silencieux && mounted) {
        setState(() => _message =
            'Nous n\'avons pas encore reçu la confirmation. Si vous avez été débité, écrivez-nous sur WhatsApp : nous livrons manuellement.');
      }
      return;
    }

    setState(() {
      _verification = true;
      _tentatives += 1;
      if (!silencieux) _message = null;
    });

    try {
      final resultat = await ApiService.verifierPaiement(orderId: widget.checkout.orderId);
      if (!mounted) return;

      if (resultat.paid && resultat.liens.aDesLiens) {
        _minuteur?.cancel();
        setState(() => _verification = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConfirmationPage(
              orderId: widget.checkout.orderId,
              resultatInitial: resultat,
              nomProjet: widget.nomProjet,
              metier: widget.metier,
              montant: widget.checkout.montant,
            ),
          ),
        );
        return;
      }

      if (resultat.paid && !resultat.liens.aDesLiens) {
        _minuteur?.cancel();
        setState(() {
          _verification = false;
          _message = resultat.message ??
              'Paiement reçu. La génération du kit est en cours, actualisez dans quelques instants.';
        });
        return;
      }

      setState(() {
        _verification = false;
        if (!silencieux) {
          _message = 'Paiement non encore confirmé. Validez la demande sur votre téléphone.';
        }
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _verification = false;
        if (!silencieux) {
          _message = erreur is ApiException ? erreur.message : 'Vérification impossible pour le moment.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkout = widget.checkout;

    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: GlassCard(
                  miseEnAvant: true,
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 54,
                        height: 54,
                        child: CircularProgressIndicator(color: K.gold, strokeWidth: 3),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'En attente de votre paiement',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: K.sand, fontSize: 21, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Une page SasPay s\'est ouverte. Validez le paiement ${AppConfig.fcfa(checkout.montant)} '
                        'sur votre téléphone, puis revenez ici.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: K.mist, fontSize: 13, height: 1.55),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: K.night.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: K.gold.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            _ligne('Projet', widget.nomProjet),
                            _ligne('Kit', widget.metier),
                            _ligne('Offre', checkout.offre),
                            _ligne('Montant', AppConfig.fcfa(checkout.montant)),
                            _ligne('Pays', checkout.pays),
                            _ligne('Référence', checkout.orderId, petit: true),
                          ],
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: K.clay.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: K.clay.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            _message!,
                            style: const TextStyle(color: K.sand, fontSize: 12, height: 1.45),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      OrButton(
                        label: 'J\'ai payé, vérifier maintenant',
                        icone: Icons.refresh_rounded,
                        chargement: _verification,
                        onPressed: () => _verifier(),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.maybePop(context),
                        child: const Text('Annuler et revenir', style: TextStyle(color: K.mist, fontSize: 13)),
                      ),
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

  Widget _ligne(String libelle, String valeur, {bool petit = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(libelle, style: const TextStyle(color: K.mist, fontSize: 11.5)),
          ),
          Expanded(
            child: Text(
              valeur,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: K.sand,
                fontSize: petit ? 10.5 : 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
