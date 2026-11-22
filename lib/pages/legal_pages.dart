import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';

/// ============================================================================
///  PAGES LÉGALES ET FAQ — mises à jour pour l'Afrique francophone (FCFA)
///  et le paiement exclusif SasPay.
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
        backgroundColor: K.deep,
        title: Text(titre, style: const TextStyle(color: K.gold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: K.gold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Text(
            contenu,
            style: const TextStyle(color: K.sand, fontSize: 14, height: 1.7),
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
Les présentes Conditions Générales de Vente (CGV) régissent les relations entre Kit Business (édité par Offboard-Hub) et toute personne achetant un kit sur ${AppConfig.siteUrl}.

2. Produits et services
Les produits sont des contenus numériques générés à la demande par intelligence artificielle :
• Livre stratégique (document HTML consultable et téléchargeable en PDF) ;
• Prompts IA (10 prompts prêts à copier) ;
• Google Sheet automatisé (tableau de gestion ouvert en écriture) ;
• Pack complet (les trois éléments).
Aucune livraison physique n'a lieu. Les documents sont livrés immédiatement après confirmation du paiement, par email et sur la page de confirmation.

3. Prix et moyens de paiement
Les prix sont indiqués en FCFA (XOF pour l'UEMOA, XAF pour la CEMAC), toutes taxes comprises :
• Prompts IA : 3 000 FCFA ;
• Sheet Automatisé : 3 500 FCFA ;
• Livre Stratégique : 5 000 FCFA ;
• Pack Complet : 9 000 FCFA.

Le paiement est exigible immédiatement et s'effectue exclusivement via SasPay (mobile money : Orange Money, Wave, MTN MoMo, Moov Money, Djamo… ou carte bancaire). Aucun autre prestataire de paiement n'est utilisé.

4. Droit de rétractation
S'agissant de contenus numériques fournis immédiatement, le client renonce à son droit de rétractation dès la génération du kit. En cas d'échec technique empêchant la livraison, le paiement est remboursé ou une nouvelle génération est proposée sans frais.

5. Livraison
Le client fournit une adresse email valide et un numéro WhatsApp de contact. La livraison est considérée effectuée dès l'envoi des liens par email ; ils restent également accessibles sur la page de confirmation et via l'assistance WhatsApp.

6. Usage personnel
Les kits sont destinés à l'usage personnel ou professionnel du client pour son propre projet. La revente en l'état des documents générés est interdite.

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
Kit Business / Offboard-Hub
Email : ${AppConfig.emailSupport}
Site web : ${AppConfig.siteUrl}

Hébergement
Le site est hébergé par Netlify (www.netlify.com).
Les fonctions serveur et la base de données sont hébergées par Supabase.

Propriété intellectuelle
Les contenus générés (textes, livres, prompts, tableaux) sont produits pour le client. Le code, l'interface et la marque Kit Business restent la propriété de l'éditeur.

Données personnelles
Les données collectées (nom du projet, pays, numéro WhatsApp, email, précisions) servent uniquement à :
• générer le kit acheté ;
• livrer les liens par email et les afficher sur la page de confirmation ;
• répondre aux demandes d'assistance.
Aucune donnée bancaire ne transite par nos serveurs : les paiements sont traités par SasPay.
Aucune vidéo n'est stockée sur nos serveurs : seuls des textes (scripts, sous-titres, descriptions) sont conservés.

Responsable de publication
Fatima Touré

Contact
WhatsApp : ${AppConfig.lienWhatsAppAide}
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
        backgroundColor: K.deep,
        title: const Text('FAQ & Aide', style: TextStyle(color: K.gold, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: K.gold),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          FAQItem(
            question: 'Comment fonctionne Kit Business ?',
            reponse:
                'Vous choisissez votre kit métier en 1 clic (restaurant, boutique en ligne, élevage, beauté, services ou financement), '
                'puis votre offre. Vous renseignez le nom de votre projet, votre pays, votre numéro WhatsApp et votre email. '
                'Après le paiement SasPay, l\'IA génère votre livre, vos prompts et votre Google Sheet, et vous recevez les liens par email — ils s\'affichent aussi immédiatement à l\'écran.',
          ),
          FAQItem(
            question: 'Quels sont les prix ?',
            reponse:
                'Prompts IA : 3 000 FCFA. Sheet Automatisé : 3 500 FCFA. Livre Stratégique : 5 000 FCFA. '
                'Pack Complet : 9 000 FCFA (le plus choisi). Paiement unique, sans abonnement.',
          ),
          FAQItem(
            question: 'Comment payer depuis mon pays ?',
            reponse:
                'Le paiement passe exclusivement par SasPay : mobile money (Orange Money, Wave, MTN MoMo, Moov Money, Djamo…) '
                'ou carte bancaire. Les montants sont en FCFA (XOF ou XAF selon votre pays).',
          ),
          FAQItem(
            question: 'Quels pays sont couverts ?',
            reponse:
                'Côte d\'Ivoire, Sénégal, Mali, Cameroun, Burkina Faso, Bénin, Togo, Gabon, Niger, Tchad, Congo, '
                'Centrafrique, Guinée-Bissau et Guinée Équatoriale. D\'autres pays de la zone FCFA peuvent être ajoutés sur demande.',
          ),
          FAQItem(
            question: 'Quand vais-je recevoir mon kit ?',
            reponse:
                'Immédiatement après confirmation du paiement. La génération prend généralement moins de deux minutes. '
                'Les liens s\'affichent aussi sur la page de confirmation : vous pouvez les ouvrir depuis votre téléphone.',
          ),
          FAQItem(
            question: 'Puis-je télécharger le livre en PDF ?',
            reponse:
                'Oui. Le livre s\'ouvre dans votre navigateur avec un bouton « Télécharger en PDF » (ou « Imprimer » puis '
                '« Enregistrer au format PDF » sur téléphone).',
          ),
          FAQItem(
            question: 'Le Google Sheet est-il vraiment à moi ?',
            reponse:
                'Oui. Le tableau est créé dans Google Sheets et partagé en écriture pour que vous puissiez saisir vos '
                'chiffres réels, vos prix et vos charges. Aucun de vos concurrents n\'y a accès.',
          ),
          FAQItem(
            question: 'Comment obtenir de l\'aide ?',
            reponse:
                'Le plus rapide : le bouton « Aide WhatsApp » présent sur toutes les pages. Vous pouvez aussi écrire à '
                'contact@e-booklive.offboard-hub.com. Nous répondons sous 24 h.',
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
    return Card(
      color: K.deep,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        iconColor: K.gold,
        collapsedIconColor: K.mist,
        title: Text(
          question,
          style: const TextStyle(color: K.sand, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(reponse, style: const TextStyle(color: K.mist, height: 1.55, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
