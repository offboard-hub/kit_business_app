import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../widgets/logo_ebooklive.dart';

/// ============================================================================
///  PAGES LÉGALES ET FAQ — e-booklive
///  La Boutique (kits métiers) & Studio Live (abonnement 10 USD / 30 jours).
///  Paiement SasPay (23 pays, devise locale) ou Paddle (reste du monde).
/// ============================================================================
class PageTexteLegal extends StatelessWidget {
  const PageTexteLegal({super.key, required this.titre, required this.contenu});

  final String titre;
  final String contenu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.night,
      appBar: AppBar(
        backgroundColor: K.night,
        title: Text(
          titre,
          style: const TextStyle(color: K.text, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: K.muted),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: LogoEbooklive(size: 26)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 60),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              contenu,
              style: const TextStyle(color: K.sand, fontSize: 13.5, height: 1.75),
            ),
          ),
        ),
      ),
    );
  }
}

class CGVPage extends StatelessWidget {
  const CGVPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageTexteLegal(
      titre: 'Conditions Générales de Vente',
      contenu: '''
1. Objet
Les présentes Conditions Générales de Vente (CGV) régissent les relations entre e-booklive (édité par Offboard-Hub) et toute personne achetant un kit métier ou un abonnement Studio Live sur ${AppConfig.siteUrl}.

2. Produits et services
e-booklive propose deux univers distincts :
• La Boutique : des kits business numériques générés à la demande par intelligence artificielle — Livre stratégique, Prompts IA, Sheet automatisé et Pack complet — rédigés pour le métier déclaré par le client.
• Studio Live : un abonnement de 30 jours donnant accès à une régie live (Jitsi Meet), au partage d'écran, à un co-animateur à distance, à un chat IA commercial et à un Livre Guide Live personnalisé.

3. Prix et moyens de paiement
Les kits sont affichés à partir de 3 000 FCFA (tarif de référence XOF). Le prix est automatiquement converti dans la devise du pays sélectionné :
• dans les 23 pays couverts par SasPay, le débit est effectué dans la devise locale (XOF, XAF, CDF, GNF, NGN, GHS, SLE, KES, UGX, TZS, RWF, MWK, MZN, ZMW, INR) ;
• dans les autres pays, Paddle facture en USD, la conversion locale étant affichée à titre indicatif, avec TVA gérée par Paddle lorsque applicable.

L'abonnement Studio Live est fixé à 10 USD pour 30 jours, converti dans la devise de facturation du pays sélectionné. Il n'est pas renouvelé automatiquement : le client choisit librement de se réabonner à l'expiration.

Le paiement est exigible immédiatement. Selon le pays, il s'effectue via SasPay (mobile money ou carte) ou via Paddle (carte bancaire et moyens internationaux). Aucune donnée bancaire ne transite par nos serveurs.

4. Droit de rétractation et remboursement
S'agissant de contenus numériques fournis immédiatement, le client renonce à son droit de rétractation dès la génération du kit ou l'activation de l'abonnement. En cas d'échec technique empêchant la livraison, le paiement est remboursé ou une nouvelle génération est proposée sans frais.

La politique de remboursement détaillée est disponible sur ${AppConfig.siteUrl}/remboursement. Pour toute demande : ${AppConfig.emailSupport}.

5. Livraison
La livraison est considérée effectuée dès l'envoi des liens par email (Resend) ; ils restent également accessibles sur la page de confirmation. Pour le Studio Live, l'accès à la régie est activé dès confirmation du paiement et le Livre Guide est envoyé par email.

6. Usage personnel
Les kits sont destinés à l'usage personnel ou professionnel du client pour son propre projet. La revente en l'état des documents générés est interdite. L'abonnement Studio Live est nominatif ; le partage du compte est interdit, le lien de co-animation reste autorisé pour un direct.

7. Contact
Assistance WhatsApp : ${AppConfig.lienWhatsAppAide}
Email : ${AppConfig.emailSupport}
''',
    );
  }
}

class MentionsLegalesPage extends StatelessWidget {
  const MentionsLegalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageTexteLegal(
      titre: 'Mentions Légales',
      contenu: '''
Éditeur du site
e-booklive / Offboard-Hub
Email : ${AppConfig.emailSupport}
Site web : ${AppConfig.siteUrl}

Hébergement
Le site est hébergé par Netlify (www.netlify.com). Les fonctions serveur, la base de données et l'authentification sont hébergées par Supabase. Les salles vidéo du Studio Live reposent sur Jitsi Meet (meet.jit.si).

Paiements
Les paiements sont traités par SasPay (23 pays, devise locale) et Paddle (reste du monde, TVA gérée). Aucune donnée de carte bancaire n'est stockée sur nos serveurs.

Intelligence artificielle
Les contenus des kits, les réponses du chat live et le Livre Guide sont générés par des modèles d'intelligence artificielle (DeepSeek et Gemini). Le client doit vérifier les informations avant utilisation, notamment les prix et mentions réglementaires de son secteur.

Propriété intellectuelle
Les contenus générés (textes, livres, prompts, tableaux) sont produits pour le client. Le code, l'interface, le logo et la marque e-booklive restent la propriété de l'éditeur.

Données personnelles
Les données collectées (nom du projet ou de l'activité, pays, numéro WhatsApp, email, précisions, fiche produit) servent uniquement à :
• générer et livrer le kit acheté ;
• activer et sécuriser l'abonnement Studio Live ;
• fournir le chat IA pendant le direct ;
• répondre aux demandes d'assistance.
Aucune vidéo n'est stockée sur nos serveurs : seuls des textes (scripts, sous-titres, descriptions, fiches produit) sont conservés. Les messages du chat live sont purgés automatiquement après 30 jours.

Responsable de publication
Fatima Touré

Contact
WhatsApp : ${AppConfig.lienWhatsAppAide}
''',
    );
  }
}

class ConfidentialitePage extends StatelessWidget {
  const ConfidentialitePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageTexteLegal(
      titre: 'Politique de confidentialité',
      contenu: '''
Dernière mise à jour : 26 novembre 2026

1. Responsable du traitement
e-booklive est édité par Offboard-Hub. Pour toute question relative à vos données :
${AppConfig.emailSupport}

2. Données collectées
Nous collectons uniquement les données nécessaires au service :
• compte : nom, adresse email, mot de passe chiffré par Supabase Auth ;
• commande : pays, devise, métier, nom du projet, numéro WhatsApp, précisions et fiche produit ;
• Studio Live : nom d'activité, messages du chat, contenus du guide et statut de l'abonnement ;
• paiement : identifiant de transaction, montant, devise et statut. Aucune donnée de carte bancaire n'est stockée par e-booklive ;
• technique : journaux de connexion et adresse IP pour la sécurité et la prévention de la fraude.

3. Finalités et bases légales
• exécution du contrat : créer le compte, générer et livrer le kit, activer le Studio Live ;
• intérêt légitime : sécurité, prévention de la fraude, amélioration du service ;
• obligation légale : conservation des justificatifs de paiement ;
• consentement : communications facultatives.

4. Destinataires et sous-traitants
Les données sont traitées par :
• Supabase (authentification, base de données, fonctions serveur) ;
• Netlify (hébergement du site) ;
• Resend (emails transactionnels) ;
• Paddle et SasPay (paiements) ;
• Jitsi Meet (salles vidéo du Studio Live) ;
• DeepSeek et Gemini (génération de contenus et réponses du chat IA).
Ces prestataires n'utilisent vos données que pour fournir leurs services.

5. Durées de conservation
• compte : jusqu'à sa suppression, puis 30 jours de sauvegarde ;
• kits et commandes : durée nécessaire à la garantie et aux obligations comptables ;
• messages du chat live : purge automatique après 30 jours ;
• justificatifs de paiement : durée légale applicable ;
• journaux techniques : durée limitée de sécurité.

6. Vos droits
Vous disposez d'un droit d'accès, de rectification, d'effacement, de limitation, d'opposition et de portabilité. Écrivez à ${AppConfig.emailSupport}. Vous pouvez également saisir l'autorité de protection des données compétente.

7. Cookies et stockage local
Le site utilise uniquement des cookies et stockages techniques nécessaires (session, pays choisi, sécurité). Aucun cookie publicitaire n'est déposé par e-booklive. Les prestataires de paiement et de visioconférence peuvent déposer leurs propres cookies lors de leur utilisation.

8. Transferts internationaux
Certains prestataires peuvent traiter des données hors de votre pays. Ces transferts sont encadrés par les garanties contractuelles appropriées de ces prestataires.

9. Sécurité
Les accès sont protégés par authentification, les mots de passe sont chiffrés, les paiements sont traités par des prestataires certifiés et les secrets serveur ne sont jamais exposés au navigateur.

10. Contact
Email : ${AppConfig.emailSupport}
WhatsApp : ${AppConfig.lienWhatsAppAide}
''',
    );
  }
}

class RemboursementPage extends StatelessWidget {
  const RemboursementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageTexteLegal(
      titre: 'Politique de remboursement',
      contenu: '''
Dernière mise à jour : 26 novembre 2026

1. Produits numériques
Les kits (Livre stratégique, Prompts IA, Sheet automatisé, Pack complet) sont des contenus numériques générés à la demande et livrés immédiatement après le paiement. Conformément aux règles applicables aux contenus numériques fournis immédiatement, le client renonce à son droit de rétractation une fois le kit généré et les liens de livraison mis à disposition.

2. Cas de remboursement
Un remboursement peut être accordé si :
• le paiement a été débité mais le kit n'a pas été livré ;
• le contenu livré est corrompu ou techniquement inutilisable et ne peut pas être régénéré ;
• un doublon ou un débit non autorisé est constaté ;
• la loi applicable impose un remboursement.
Les demandes de changement d'avis après livraison ne sont pas remboursables, sauf geste commercial exceptionnel.

3. Studio Live
L'abonnement Studio Live donne accès à 30 jours de service et n'est pas renouvelé automatiquement. Une demande de remboursement peut être étudiée si l'accès n'a jamais été activé ou en cas de défaillance technique empêchant l'utilisation. Après activation et utilisation de la régie, les sommes correspondant au service consommé ne sont pas remboursables, sous réserve des droits légaux.

4. Procédure
Écrivez à ${AppConfig.emailSupport} ou sur WhatsApp (${AppConfig.lienWhatsAppAide}) avec :
• l'email utilisé lors de l'achat ;
• la référence de commande ou l'identifiant de transaction ;
• le motif de la demande et, si possible, une capture du problème.
Nous accusons réception sous 2 jours ouvrés et répondons sous 14 jours. Un remboursement accepté est effectué sur le moyen de paiement d'origine, généralement sous 5 à 10 jours ouvrés selon le prestataire.

5. Paiements Paddle et SasPay
Les remboursements sont traités via le prestataire ayant encaissé le paiement (Paddle ou SasPay). Les délais bancaires peuvent s'ajouter à notre délai de traitement.

6. Contact
Email : ${AppConfig.emailSupport}
WhatsApp : ${AppConfig.lienWhatsAppAide}
''',
    );
  }
}

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageTexteLegal(
      titre: 'Contact & assistance',
      contenu: '''
e-booklive — Offboard-Hub

Une question sur un kit, un paiement, le Studio Live ou vos données ?
Notre équipe répond du lundi au vendredi, de 9 h à 18 h (GMT+1).

Email : ${AppConfig.emailSupport}
WhatsApp : ${AppConfig.lienWhatsAppAide}

Pour une demande de remboursement, indiquez l'email d'achat et la référence de commande.
Pour une question sur vos données personnelles, écrivez à ${AppConfig.emailSupport} avec l'objet « Données personnelles ».

Liens utiles :
• Conditions générales de vente : ${AppConfig.siteUrl}/cgv
• Politique de confidentialité : ${AppConfig.siteUrl}/confidentialite
• Politique de remboursement : ${AppConfig.siteUrl}/remboursement
• Mentions légales : ${AppConfig.siteUrl}/mentions-legales
''',
    );
  }
}

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.night,
      appBar: AppBar(
        backgroundColor: K.night,
        title: const Text(
          'FAQ & Aide',
          style: TextStyle(color: K.text, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: K.muted),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: LogoEbooklive(size: 26)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: const <Widget>[
          FAQItem(
            question: 'Comment fonctionne e-booklive ?',
            reponse:
                'e-booklive réunit deux univers. Dans La Boutique, vous choisissez votre métier (8 secteurs ou « Autre métier »), '
                'votre kit et votre pays : l\'IA rédige un livre stratégique, des prompts et un tableau de gestion, envoyés immédiatement après paiement. '
                'Dans le Studio Live, vous activez une régie de vente en direct pour 10 USD / 30 jours, avec chat IA et Livre Guide offert.',
          ),
          FAQItem(
            question: 'Quels sont les prix des kits ?',
            reponse:
                'Prompts IA : 3 000 FCFA. Sheet Automatisé : 3 500 FCFA. Livre Stratégique : 5 000 FCFA. '
                'Pack Complet : 9 000 FCFA (le plus choisi). Paiement unique, sans abonnement. Les prix sont convertis automatiquement dans la devise de votre pays.',
          ),
          FAQItem(
            question: 'Combien coûte le Studio Live ?',
            reponse:
                '10 USD pour 30 jours, converti dans la devise de votre pays au moment du paiement. '
                'Sans engagement et sans reconduction automatique. Le Livre Guide Live personnalisé est inclus et offert.',
          ),
          FAQItem(
            question: 'Quels pays et quelles devises sont couverts ?',
            reponse:
                'Tous les pays du monde sont disponibles. 23 pays sont encaissés par SasPay dans leur devise locale '
                '(XOF, XAF, CDF, GNF, NGN, GHS, SLE, KES, UGX, TZS, RWF, MWK, MZN, ZMW, INR). '
                'Pour les autres pays, Paddle facture en EUR ou USD, avec conversion locale indicative et TVA gérée.',
          ),
          FAQItem(
            question: 'Comment payer depuis mon pays ?',
            reponse:
                'Sélectionnez votre pays : la route de paiement s\'affiche automatiquement. SasPay propose mobile money et carte dans les 23 pays concernés. '
                'Paddle couvre le reste du monde par carte bancaire et moyens internationaux.',
          ),
          FAQItem(
            question: 'Quand vais-je recevoir mon kit ?',
            reponse:
                'Immédiatement après confirmation du paiement. La génération prend généralement moins de deux minutes. '
                'Les liens s\'affichent sur la page de confirmation et sont envoyés par email.',
          ),
          FAQItem(
            question: 'Puis-je télécharger le livre en PDF ?',
            reponse:
                'Oui. Le livre s\'ouvre dans votre navigateur avec un bouton « Télécharger en PDF » (ou « Imprimer » puis '
                '« Enregistrer au format PDF » sur téléphone). Le Livre Guide Live se télécharge aussi en HTML depuis la régie.',
          ),
          FAQItem(
            question: 'Comment inviter un co-animateur ?',
            reponse:
                'Dans l\'onglet « Préparer mon Live », choisissez le format « Inviter un co-animateur ». Un lien unique '
                '(/live/votre-salle?invite=…) est généré : envoyez-le à votre partenaire, il monte dans la salle depuis n\'importe où.',
          ),
          FAQItem(
            question: 'Le chat IA répond-il vraiment aux spectateurs ?',
            reponse:
                'Oui. Le chat utilise votre Fiche Produit IA (titre, produits, prix, arguments) pour répondre en français. '
                'Pour une question posée sur TikTok ou Instagram, saisissez-la dans la régie : la réponse arrive avec un bouton « Copier en 1 clic ».',
          ),
          FAQItem(
            question: 'Comment obtenir de l\'aide ?',
            reponse:
                'Le plus rapide : le bouton « Aide WhatsApp » présent sur toutes les pages, ou l\'assistante Awa en bas à droite. '
                'Vous pouvez aussi écrire à contact@e-booklive.offboard-hub.com. Nous répondons sous 24 h.',
          ),
        ],
      ),
    );
  }
}

class FAQItem extends StatelessWidget {
  const FAQItem({super.key, required this.question, required this.reponse});

  final String question;
  final String reponse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: K.surface.withValues(alpha: 0.72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: K.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: K.or,
            collapsedIconColor: K.muted,
            title: Text(
              question,
              style: const TextStyle(
                color: K.text,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  reponse,
                  style: const TextStyle(color: K.muted, height: 1.6, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
