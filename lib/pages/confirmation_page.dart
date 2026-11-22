import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/links.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../widgets/app_header.dart';
import '../widgets/whatsapp.dart';

/// ============================================================================
///  CONFIRMATION — liens de consultation/téléchargement + état de la livraison
///  par email (Resend).
/// ============================================================================
class ConfirmationPage extends StatefulWidget {
  const ConfirmationPage({
    super.key,
    required this.orderId,
    this.resultatInitial,
    this.nomProjet,
    this.metier,
    this.montant,
  });

  final String orderId;
  final ResultatCommande? resultatInitial;
  final String? nomProjet;
  final String? metier;
  final int? montant;

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  ResultatCommande? _resultat;
  bool _chargement = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _resultat = widget.resultatInitial;
    if (_resultat == null || (!_resultat!.paid) || !_resultat!.liens.aDesLiens) {
      _charger();
    }
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final resultat = await ApiService.verifierPaiement(orderId: widget.orderId);
      if (!mounted) return;
      setState(() {
        _resultat = resultat;
        _chargement = false;
        if (resultat.paid && !resultat.liens.aDesLiens) {
          _erreur = resultat.message ?? 'Paiement reçu, mais les documents ne sont pas encore disponibles.';
        }
        if (!resultat.paid) {
          _erreur = resultat.message ??
              'Paiement non encore confirmé. Si vous venez de payer, patientez quelques secondes puis actualisez.';
        }
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = erreur is ApiException ? erreur.message : 'Vérification impossible pour le moment.';
      });
    }
  }

  void _copierLiens() {
    final liens = _resultat?.liens;
    if (liens == null) return;
    final lignes = <String>[
      if (liens.livre != null) 'Livre stratégique : ${liens.livre}',
      if (liens.prompts != null) 'Prompts IA : ${liens.prompts}',
      if (liens.sheet != null) 'Google Sheet : ${liens.sheet}',
    ];
    if (lignes.isEmpty) return;
    Clipboard.setData(ClipboardData(text: lignes.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Liens copiés. Conservez-les précieusement.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: K.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultat = _resultat;
    final paid = resultat?.paid ?? false;
    final liens = resultat?.liens;

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
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      child: Column(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: (paid ? K.success : K.gold).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: (paid ? K.success : K.gold).withValues(alpha: 0.5)),
                            ),
                            child: Icon(
                              paid ? Icons.check_rounded : Icons.hourglass_bottom_rounded,
                              color: paid ? K.success : K.gold,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            paid ? 'Votre kit est prêt 🎉' : 'Paiement en cours de confirmation',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: K.sand,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            paid
                                ? 'Vos liens sont ci-dessous. Ils ont aussi été envoyés par email à l\'adresse indiquée.'
                                : 'Dès que SasPay confirme le paiement, votre kit est généré et livré automatiquement.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: K.mist, fontSize: 13.5, height: 1.55),
                          ),
                          const SizedBox(height: 22),
                          _resume(resultat),
                          const SizedBox(height: 20),
                          if (paid && liens != null && liens.aDesLiens) ...[
                            _sectionLiens(liens),
                            const SizedBox(height: 18),
                            _etatLivraison(resultat),
                            const SizedBox(height: 18),
                            _conseils(),
                          ],
                          if (_chargement) ...[
                            const SizedBox(height: 20),
                            const CircularProgressIndicator(color: K.gold),
                            const SizedBox(height: 10),
                            const Text(
                              'Génération et livraison en cours…',
                              style: TextStyle(color: K.mist, fontSize: 12),
                            ),
                          ],
                          if (_erreur != null) ...[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: K.clay.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: K.clay.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                _erreur!,
                                style: const TextStyle(color: K.sand, fontSize: 12.5, height: 1.5),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          OrButton(
                            label: paid ? 'Actualiser mes liens' : 'Vérifier mon paiement',
                            icone: Icons.refresh_rounded,
                            chargement: _chargement,
                            onPressed: _charger,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.pushNamed(context, '/mon-espace'),
                                  icon: const Icon(Icons.folder_open_rounded, size: 17, color: K.gold),
                                  label: const Text(
                                    'Mon espace',
                                    style: TextStyle(color: K.gold, fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: K.gold.withValues(alpha: 0.45)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _copierLiens,
                                  icon: const Icon(Icons.copy_rounded, size: 17, color: K.mist),
                                  label: const Text(
                                    'Copier les liens',
                                    style: TextStyle(color: K.mist, fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: K.mist.withValues(alpha: 0.3)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const AideWhatsApp(pleinLargeur: true),
                          const SizedBox(height: 20),
                          Text(
                            'Référence commande : ${widget.orderId}',
                            style: TextStyle(color: K.mist.withValues(alpha: 0.6), fontSize: 10.5),
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
    );
  }

  Widget _resume(ResultatCommande? resultat) {
    final nom = resultat?.nomProjet ?? widget.nomProjet;
    final metier = resultat?.metier ?? widget.metier;
    final montant = resultat?.montant ?? widget.montant;
    final offre = resultat?.produitType == null ? null : offreParApiType(resultat!.produitType!);

    return GlassCard(
      child: Column(
        children: [
          if (nom != null) _ligne('Projet', nom),
          if (metier != null) _ligne('Kit métier', metier),
          if (offre != null) _ligne('Offre', offre.titre),
          if (montant != null) _ligne('Montant payé', AppConfig.fcfa(montant)),
          if (resultat?.whatsapp != null) _ligne('WhatsApp', resultat!.whatsapp!),
        ],
      ),
    );
  }

  Widget _sectionLiens(LiensKit liens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vos documents',
          style: TextStyle(color: K.sand, fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (liens.livre != null)
          _carteLien(
            titre: 'Livre stratégique',
            sousTitre: 'Lecture en ligne + téléchargement PDF',
            icone: Icons.menu_book_rounded,
            url: liens.livre!,
          ),
        if (liens.prompts != null)
          _carteLien(
            titre: 'Prompts IA',
            sousTitre: '10 prompts prêts à copier',
            icone: Icons.auto_awesome_rounded,
            url: liens.prompts!,
          ),
        if (liens.sheet != null)
          _carteLien(
            titre: 'Google Sheet automatisé',
            sousTitre: 'Ouvert en écriture sur votre compte Google',
            icone: Icons.table_chart_rounded,
            url: liens.sheet!,
          ),
      ],
    );
  }

  Widget _carteLien({
    required String titre,
    required String sousTitre,
    required IconData icone,
    required String url,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: K.night.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: K.gold.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: K.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icone, color: K.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: const TextStyle(color: K.sand, fontSize: 14, fontWeight: FontWeight.w800)),
                Text(sousTitre, style: const TextStyle(color: K.mist, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: () => ouvrirLienAvecRetour(context, url),
              style: ElevatedButton.styleFrom(
                backgroundColor: K.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text(
                'Ouvrir',
                style: TextStyle(color: K.night, fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _etatLivraison(ResultatCommande? resultat) {
    final livraison = resultat?.livraison;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Livraison',
            style: TextStyle(color: K.sand, fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _puceLivraison('Email', livraison?.email ?? false),
            ],
          ),
          if (livraison?.erreur != null) ...[
            const SizedBox(height: 10),
            Text(
              'L\'envoi de l\'email a échoué : ${livraison!.erreur}. Vos liens restent disponibles ci-dessus.',
              style: const TextStyle(color: K.mist, fontSize: 11, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _puceLivraison(String canal, bool envoye) {
    final couleur = envoye ? K.success : K.clay;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: couleur.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(envoye ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: couleur, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                envoye ? '$canal envoyé' : '$canal à revérifier',
                style: TextStyle(color: couleur, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conseils() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'À faire maintenant',
            style: TextStyle(color: K.sand, fontSize: 14, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            '1. Ouvrez le livre et enregistrez-le en PDF (bouton en haut de la page).\n'
            '2. Copiez les prompts dans ChatGPT, Gemini ou DeepSeek avec vos propres chiffres.\n'
            '3. Remplacez les données du Google Sheet par vos ventes réelles dès aujourd\'hui.',
            style: TextStyle(color: K.mist, fontSize: 12, height: 1.6),
          ),
          SizedBox(height: 8),
          Text(
            'Ces liens sont personnels : ne les partagez pas.',
            style: TextStyle(color: K.gold, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _ligne(String libelle, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(libelle, style: const TextStyle(color: K.mist, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              valeur,
              style: const TextStyle(color: K.sand, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
