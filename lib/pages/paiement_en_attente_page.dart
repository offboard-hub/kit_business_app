import 'dart:async';

import 'package:flutter/material.dart';

import '../core/links.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../widgets/logo_ebooklive.dart';
import '../widgets/whatsapp.dart';
import 'confirmation_page.dart';
import 'studio_regie_page.dart';

/// ============================================================================
///  PAGE D'ATTENTE — vérifie le paiement SasPay ou Paddle, puis ouvre
///  la livraison du kit (ConfirmationPage) ou la régie Studio Live.
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
  AbonnementStudio? _abonnement;

  static const int _maxTentatives = 48;

  bool get _studio => widget.checkout.estStudio;

  @override
  void initState() {
    super.initState();
    _minuteur = Timer.periodic(const Duration(seconds: 5), (_) => _verifier(silencieux: true));
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
            'La confirmation tarde un peu. Si vous avez été débité, écrivez-nous sur WhatsApp : nous livrons manuellement.');
      }
      return;
    }

    setState(() {
      _verification = true;
      _tentatives += 1;
      if (!silencieux) _message = null;
    });

    try {
      final resultat = await ApiService.verifierPaiement(
        orderId: widget.checkout.orderId,
        subscriptionId: widget.checkout.subscriptionId,
        provider: widget.checkout.fournisseur.api,
      );
      if (!mounted) return;

      if (_studio) {
        final abonnement = resultat.abonnement;
        if (abonnement != null) _abonnement = abonnement;

        if (resultat.paid && abonnement != null && abonnement.estActif) {
          _minuteur?.cancel();
          setState(() => _verification = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(builder: (_) => const StudioRegiePage()),
          );
          return;
        }

        setState(() {
          _verification = false;
          _message = resultat.message ??
              (resultat.paid
                  ? 'Paiement reçu. Votre abonnement et votre Livre Guide se préparent…'
                  : 'Paiement non encore confirmé. Validez la demande sur votre téléphone.');
        });
        return;
      }

      if (resultat.paid && resultat.liens.aDesLiens) {
        _minuteur?.cancel();
        setState(() => _verification = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ConfirmationPage(
              orderId: widget.checkout.orderId,
              resultatInitial: resultat,
              nomProjet: widget.nomProjet,
              metier: widget.metier,
              montant: widget.checkout.montant.round(),
            ),
          ),
        );
        return;
      }

      setState(() {
        _verification = false;
        if (!resultat.paid) {
          _message = resultat.message ??
              'Paiement non encore confirmé. Validez la demande sur votre téléphone.';
        } else {
          _message = resultat.message ??
              'Paiement reçu. La génération de votre kit est en cours…';
        }
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _verification = false;
        _message = erreur is ApiException
            ? erreur.message
            : 'Vérification impossible pour le moment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkout = widget.checkout;

    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const LogoEbooklive(size: 34),
                        const SizedBox(width: 9),
                        const WordmarkEbooklive(taille: 17),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Fermer',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.close_rounded, color: K.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    GlassCard(
                      miseEnAvant: true,
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: <Widget>[
                          Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              const SizedBox(
                                width: 76,
                                height: 76,
                                child: CircularProgressIndicator(
                                  color: K.or,
                                  strokeWidth: 2.4,
                                  backgroundColor: K.border,
                                ),
                              ),
                              Icon(
                                _studio ? Icons.sensors_rounded : Icons.receipt_long_rounded,
                                color: K.or,
                                size: 30,
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Text(
                            _studio
                                ? 'Activation de votre Studio Live'
                                : 'En attente de votre paiement',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: K.text,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _studio
                                ? 'Dès la confirmation, votre abonnement de 30 jours et votre Livre Guide personnalisé sont activés.'
                                : 'Une page ${checkout.fournisseur.libelle} s\'est ouverte. Validez le paiement de ${checkout.montantAffiche} sur votre téléphone, puis revenez ici.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: K.muted, fontSize: 13, height: 1.6),
                          ),
                          const SizedBox(height: 22),
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: K.bg.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: K.border),
                            ),
                            child: Column(
                              children: <Widget>[
                                _Ligne('Projet', widget.nomProjet),
                                _Ligne('Offre', checkout.offre),
                                _Ligne('Montant', checkout.montantAffiche),
                                _Ligne('Pays', checkout.pays),
                                _Ligne('Paiement', checkout.fournisseur.libelle),
                                _Ligne('Référence', checkout.reference, petit: true),
                              ],
                            ),
                          ),
                          if (_abonnement != null) ...<Widget>[
                            const SizedBox(height: 12),
                            _PuceStatut(abonnement: _abonnement!),
                          ],
                          if (_message != null) ...<Widget>[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: K.or.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: K.or.withValues(alpha: 0.28)),
                              ),
                              child: Text(
                                _message!,
                                style: const TextStyle(color: K.text, fontSize: 12, height: 1.5),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          OrButton(
                            label: 'J\'ai payé, vérifier maintenant',
                            icone: Icons.refresh_rounded,
                            chargement: _verification,
                            onPressed: () => _verifier(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              if (checkout.checkoutUrl.isNotEmpty)
                                Expanded(
                                  child: OrButton(
                                    label: 'Rouvrir le paiement',
                                    plein: false,
                                    hauteur: 44,
                                    onPressed: () =>
                                        ouvrirLienAvecRetour(context, checkout.checkoutUrl),
                                  ),
                                ),
                              if (checkout.checkoutUrl.isNotEmpty) const SizedBox(width: 10),
                              Expanded(
                                child: OrButton(
                                  label: 'Annuler',
                                  plein: false,
                                  hauteur: 44,
                                  onPressed: () => Navigator.maybePop(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const AideWhatsApp(pleinLargeur: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'La confirmation peut prendre jusqu\'à 2 minutes selon votre opérateur. '
                      'Ne payez pas deux fois : la vérification est automatique.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: K.faint, fontSize: 10.5, height: 1.5),
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

class _Ligne extends StatelessWidget {
  const _Ligne(this.libelle, this.valeur, {this.petit = false});

  final String libelle;
  final String valeur;
  final bool petit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(libelle, style: const TextStyle(color: K.muted, fontSize: 11.5)),
          ),
          Expanded(
            child: Text(
              valeur,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: K.text,
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

class _PuceStatut extends StatelessWidget {
  const _PuceStatut({required this.abonnement});

  final AbonnementStudio abonnement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.verified_user_rounded, size: 14, color: K.emeraude),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            abonnement.libelleStatut,
            style: const TextStyle(color: K.emeraude, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}
